"""Read account security ownership and quotas without exporting contact/secret values."""
import boto3
from botocore.exceptions import ClientError


# 共有アカウントのセキュリティ機能を照会する。ownership_onlyでは所有確認に必要な情報へ絞る。
def inventory(ownership_only=False):
    result = {}
    # AWS照会結果またはAPIエラーコードを項目別に記録し、所有判定へ渡す。
    def read(name, call):
        try:
            result[name] = call()
        except ClientError as exc:
            result[name] = {'error': exc.response['Error']['Code']}
    read('guardduty', lambda: boto3.client('guardduty').list_detectors()['DetectorIds'])
    read('inspector', lambda: boto3.client('inspector2').batch_get_account_status()['accounts'])
    read('config_recorders', lambda: boto3.client('config').describe_configuration_recorders()['ConfigurationRecorders'])
    read('securityhub', lambda: boto3.client('securityhub').describe_hub())
    if not ownership_only:
        read('securityhub_standards', lambda: boto3.client('securityhub').get_enabled_standards()['StandardsSubscriptions'])
        read('lambda_quota', lambda: boto3.client('lambda').get_account_settings()['AccountLimit'])
        read('lambda_usage', lambda: boto3.client('lambda').get_account_settings()['AccountUsage'])
    # SNS購読のプロトコルと確認状況を取得する。通知先の連絡先は返さない。
    def subscriptions():
        return [{'protocol': s['Protocol'], 'confirmed': s['SubscriptionArn'] != 'PendingConfirmation',
                 'portfolio_topic': 'portfolio' in s['TopicArn']} for page in boto3.client('sns').get_paginator('list_subscriptions').paginate() for s in page['Subscriptions']]
    if not ownership_only:
        read('sns_subscriptions', subscriptions)
    read('ecr_scanning', lambda: boto3.client('ecr').get_registry_scanning_configuration()['scanningConfiguration'])
    return result



# 実AWSとStateの所有情報を照合する。他用途の共有設定を取り込まないよう不一致なら停止する。
def assert_owned_security(observed,state):
    """Allow retries of our partial apply, never adopt foreign account services."""
    # Stateからportfolio名の指定種類のリソース属性だけを抽出する。
    def attrs(kind):
        return [i['attributes'] for r in state.get('resources',[]) if r.get('mode')=='managed' and r.get('type')==kind and r.get('name')=='portfolio' for i in r.get('instances',[])]
    detectors={a['id'] for a in attrs('aws_guardduty_detector')}
    if not isinstance(observed['guardduty'],list) or set(observed['guardduty'])!=detectors:raise RuntimeError('GUARDDUTY_OWNERSHIP_CHANGED')
    recorders=attrs('aws_config_configuration_recorder')
    if not isinstance(observed['config_recorders'],list) or {r['name'] for r in observed['config_recorders']}!={a['name'] for a in recorders}:raise RuntimeError('CONFIG_OWNERSHIP_CHANGED')
    for r in observed['config_recorders']:
        expected=next(a for a in recorders if a['name']==r['name'])
        if r['roleARN']!=expected['role_arn']:raise RuntimeError('CONFIG_ROLE_CHANGED')
    hubs=attrs('aws_securityhub_account');hub=observed['securityhub']
    if hubs:
        if hub.get('HubArn')!=hubs[0]['arn']:raise RuntimeError('SECURITYHUB_OWNERSHIP_CHANGED')
    elif hub.get('error')!='InvalidAccessException':raise RuntimeError('SECURITYHUB_OWNERSHIP_CHANGED')
    inspector=attrs('aws_inspector2_enabler')
    if not isinstance(observed['inspector'],list):raise RuntimeError('INSPECTOR_INVENTORY_UNAVAILABLE')
    if not inspector and any(a['state']['status']!='DISABLED' for a in observed['inspector']):raise RuntimeError('INSPECTOR_OWNERSHIP_CHANGED')
    scanning=attrs('aws_ecr_registry_scanning_configuration')
    expected={'scanType':'BASIC','rules':[]}
    if scanning:
        a=scanning[0]
        expected={'scanType':a['scan_type'],'rules':[{'scanFrequency':r['scan_frequency'],'repositoryFilters':[{'filter':f['filter'],'filterType':f['filter_type']} for f in r['repository_filter']]} for r in a['rule']]}
    if observed['ecr_scanning']!=expected:raise RuntimeError('ECR_SCANNING_OWNERSHIP_CHANGED')


if __name__ == '__main__':
    import json
    import sys
    assert_owned_security(inventory(ownership_only=True), json.load(sys.stdin))
    print('Account security ownership verified')
