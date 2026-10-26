"""Replay one retained result; never delete until a validated DB-only success."""
import argparse
import json
import os
from common.domain import ProcessingError, normalize_result
from common.runtime import client

# 指定メッセージの結果をDBへ再反映する。応答の成功を検証した場合だけSQSメッセージを削除する。
def replay(sqs, invoke, queue, kind, message_id, function, expected):
    if kind not in ('delivery','execution') or not message_id:
        raise ProcessingError('INVALID_INPUT')
    for _ in range(20):
        items=sqs.receive_message(QueueUrl=queue,MaxNumberOfMessages=1,WaitTimeSeconds=10,VisibilityTimeout=300).get('Messages',[])
        for item in items:
            if item['MessageId'] != message_id:
                continue
            record=json.loads(item['Body'])
            event=record['requestPayload'] if kind=='execution' else record
            filename=normalize_result(event,**expected)['filename']
            response=invoke.invoke(FunctionName=function,InvocationType='RequestResponse',
                Payload=json.dumps({'mode':'db_only','event':event}).encode())
            if response.get('FunctionError'):
                raise ProcessingError('REPLAY_FAILED')
            result=json.loads(response['Payload'].read())
            required={'ok','db','s3','filename'}
            if (not isinstance(result,dict)
                or not required.issubset(result)
                or set(result)-required-{'ignored_after_success'}
                or result['ok'] is not True
                or result['db'] != 'OK' or result['s3'] != 'SKIPPED'
                or result['filename'] != filename
                or ('ignored_after_success' in result and type(result['ignored_after_success']) is not bool)):
                raise ProcessingError('REPLAY_FAILED')
            sqs.delete_message(QueueUrl=queue,ReceiptHandle=item['ReceiptHandle'])
            return result
    raise ProcessingError('MESSAGE_NOT_FOUND')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--kind',choices=['delivery','execution'],required=True)
    parser.add_argument('--message-id',required=True)
    args=parser.parse_args()
    expected={k:os.environ[v] for k,v in {'account':'EXPECTED_ACCOUNT_ID','region':'AWS_REGION','connector':'CONNECTOR_ID','bucket':'EXCHANGE_BUCKET'}.items()}
    replay(client('sqs',write=True),client('lambda',write=True),os.environ[args.kind.upper()+'_QUEUE_URL'],args.kind,args.message_id,os.environ['RESULT_FUNCTION'],expected)
