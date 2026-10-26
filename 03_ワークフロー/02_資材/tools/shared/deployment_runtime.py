"""Execute an ECS migration task and read State for independent acceptance tests."""
import json
import os
import boto3

# 指定コマンドをECS Fargateタスクで実行し、停止待ちとコンテナ終了コードの確認を行う。
def task(outputs,command):
    ecs=boto3.client('ecs')
    task=ecs.run_task(cluster=outputs['cluster_name'],taskDefinition=outputs['migration_task_definition'],launchType='FARGATE',
      networkConfiguration={'awsvpcConfiguration':{'subnets':outputs['private_subnet_ids'],'securityGroups':[outputs['migration_security_group']],'assignPublicIp':'DISABLED'}},
      overrides={'containerOverrides':[{'name':'migration','command':command}]})
    if task.get('failures') or not task.get('tasks'):raise RuntimeError('TASK_START_FAILED')
    arn=task['tasks'][0]['taskArn']
    ecs.get_waiter('tasks_stopped').wait(cluster=outputs['cluster_name'],tasks=[arn],WaiterConfig={'Delay':10,'MaxAttempts':60})
    result=ecs.describe_tasks(cluster=outputs['cluster_name'],tasks=[arn])['tasks'][0]
    if result['containers'][0].get('exitCode')!=0:raise RuntimeError('TASK_FAILED')


# 独立した受入試験用にS3から一時環境Stateを読む。許可された場合だけState未作成を空扱いにする。
def read_state(allow_absent=False):
    from botocore.exceptions import ClientError
    try:
        body=boto3.client('s3').get_object(Bucket=os.environ['TF_STATE_BUCKET'],Key='aws-cicd-portfolio/temporary/terraform.tfstate')['Body']
    except ClientError as exc:
        if allow_absent and exc.response['Error']['Code'] in ('NoSuchKey','404'):
            return {'resources':[],'outputs':{}}
        raise
    try:return json.loads(body.read())
    finally:body.close()


if __name__ == '__main__':
    import sys
    values = {key: value['value'] for key, value in json.load(sys.stdin).items()}
    task(values, ['python', 'tools/migrate.py'])
