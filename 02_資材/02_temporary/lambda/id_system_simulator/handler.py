"""ID system mock: exact documented input/output, signed POST, no retries/redirects."""
import json
import os
import time
import urllib.parse
from datetime import datetime
from zoneinfo import ZoneInfo
import boto3
import urllib3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def lambda_handler(event, context):
    if not isinstance(event,dict) or set(event)!={'employees'} or not isinstance(event['employees'],list) or not 1<=len(event['employees'])<=5 or any(not isinstance(e,dict) for e in event['employees']):
        raise ValueError('INVALID_INPUT')
    endpoint=os.environ['API_ENDPOINT']
    parsed=urllib.parse.urlsplit(endpoint)
    if parsed.scheme!='https' or not parsed.hostname or parsed.query or parsed.fragment or not parsed.path.endswith('/employees'):
        raise ValueError('INVALID_ENDPOINT')
    http=urllib3.PoolManager(cert_reqs='CERT_REQUIRED',timeout=urllib3.Timeout(connect=3,read=7),retries=False)
    session=boto3.Session()
    results=[]
    for index,employee in enumerate(event['employees']):
        start=time.monotonic();status=None;error=None
        if context.get_remaining_time_in_millis()<12000:
            result='NOT_SENT';error='TIME_BUDGET'
        else:
            try:
                body=json.dumps(employee,ensure_ascii=False,separators=(',',':')).encode('utf-8')
                signed=AWSRequest(method='POST',url=endpoint,data=body,headers={'Content-Type':'application/json; charset=utf-8'})
                SigV4Auth(session.get_credentials().get_frozen_credentials(),'execute-api','ap-northeast-1').add_auth(signed)
                response=http.request('POST',endpoint,body=body,headers=dict(signed.headers),retries=False,redirect=False,preload_content=False)
                try:status=response.status
                finally:response.close();response.release_conn()
                result='ACCEPTED' if status==202 else 'FAILED'
                if status!=202:
                    error='INVALID_INPUT' if status==400 else 'AUTH_ERROR' if status in (401,403) else 'THROTTLED' if status==429 else 'API_ERROR' if 500<=status<=599 else 'UNEXPECTED_STATUS'
            except Exception:
                result='FAILED';error='REQUEST_ERROR'
        item={'index':index,'employee_id':employee.get('employee_id') if isinstance(employee.get('employee_id'),str) else None,
              'http_status':status,'result':result,'error_code':error}
        results.append(item)
        print(json.dumps({**item,'timestamp':datetime.now(ZoneInfo('Asia/Tokyo')).isoformat(),
            'aws_request_id':context.aws_request_id,'duration_ms':round((time.monotonic()-start)*1000)},ensure_ascii=False))
    summary={'total_count':len(results),'accepted_count':sum(r['result']=='ACCEPTED' for r in results),
             'failed_count':sum(r['result']=='FAILED' for r in results),'not_sent_count':sum(r['result']=='NOT_SENT' for r in results)}
    print(json.dumps(summary))
    return {**summary,'results':results}
