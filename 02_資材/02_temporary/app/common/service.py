"""Injectable application services; handlers supply AWS/DB adapters."""
import base64
import binascii
import json
from datetime import datetime
from uuid import uuid4
from common.domain import (JST, FILENAME, ProcessingError, make_csv, normalize_result,
                           parse_time, strict_json, validate_employee)
from common.runtime import log, metric

def response(code, body):
    return {'statusCode':code, 'headers':{'content-type':'application/json','cache-control':'no-store'},
            'body':json.dumps(body, ensure_ascii=False)}

def intake(event, sqs, queue_url, now=None):
    request_id = event.get('requestContext',{}).get('requestId','unknown')
    try:
        headers = {k.lower():v for k,v in event.get('headers',{}).items()}
        if headers.get('content-type','').split(';')[0].strip().lower() != 'application/json':
            raise ProcessingError('INVALID_INPUT')
        raw = event.get('body','')
        raw = base64.b64decode(raw, validate=True) if event.get('isBase64Encoded') else raw.encode('utf-8')
        if len(raw) > 4096:
            raise ProcessingError('BODY_TOO_LARGE')
        employee = validate_employee(strict_json(raw.decode('utf-8')))
    except (ProcessingError, UnicodeError, ValueError, AttributeError, binascii.Error) as exc:
        code = str(exc) if isinstance(exc, ProcessingError) else 'INVALID_INPUT'
        return response(400, {'error_code':code,'request_id':request_id})
    body = {'schema_version':1, **employee, 'request_id':request_id,
            'received_at':(now or datetime.now(JST)).isoformat()}
    try:
        sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(body, ensure_ascii=False))
    except Exception:
        log('employee-intake','QUEUE_UNAVAILABLE',request_id=request_id)
        metric('employee-intake','FinalFailure')
        return response(500, {'error_code':'QUEUE_UNAVAILABLE','request_id':request_id})
    log('employee-intake','OK',stage='queue',request_id=request_id,employee_id=employee['employee_id'])
    return response(202, {'result':'ACCEPTED','request_id':request_id})

def register(event, repo_factory):
    failures=[]
    for record in event['Records']:
        try:
            message = strict_json(record['body'])
            if not isinstance(message,dict) or set(message) != {'schema_version','request_id','received_at','employee_id','employee_name','company_name'} or type(message['schema_version']) is not int or message['schema_version'] != 1 or not isinstance(message['request_id'],str):
                raise ProcessingError('INVALID_INPUT')
            employee = validate_employee({k:message[k] for k in ('employee_id','employee_name','company_name')})
            repo_factory().register(employee, parse_time(message['received_at']))
            log('employee-register','OK',stage='db',message_id=record['messageId'],request_id=message['request_id'],employee_id=employee['employee_id'])
        except Exception as exc:
            code = str(exc) if isinstance(exc,ProcessingError) else 'DB_UNAVAILABLE'
            log('employee-register', code, stage='db',level='WARN',message_id=record['messageId'])
            failures.append({'itemIdentifier':record['messageId']})
    return {'batchItemFailures':failures}

def list_files(s3, bucket, prefix):
    keys=[]
    for page in s3.get_paginator('list_objects_v2').paginate(Bucket=bucket, Prefix=prefix):
        for item in page.get('Contents',[]):
            key=item['Key']
            if key.startswith(prefix) and FILENAME.fullmatch(key[len(prefix):]):
                keys.append(key)
    return sorted(keys)

def send_files(keys, transfer, bucket, connector, remote, context, limit=100):
    requested=failed=0
    for key in keys[:limit]:
        if context and context.get_remaining_time_in_millis() < 15000:
            break
        try:
            result = transfer.start_file_transfer(ConnectorId=connector,
                SendFilePaths=[f'/{bucket}/{key}'], RemoteDirectoryPath=remote)
            log('transfer-request','OK', filename=key, transfer_id=result['TransferId'])
            requested+=1
        except Exception:
            failed+=1
            log('transfer-request','TRANSFER_REQUEST_FAILED', filename=key)
    return {'total':len(keys), 'requested':requested, 'failed':failed,
            'not_sent':len(keys)-requested-failed}

def daily(event, context, repo_factory, s3, transfer, bucket, connector, remote,
          now=None, max_rows=10000, max_bytes=16777216, max_files=100):
    if not isinstance(event,dict) or event != {'schema_version':1,'mode':'daily'} or type(event.get('schema_version')) is not int:
        raise ProcessingError('INVALID_INPUT')
    current=(now or datetime.now(JST)).astimezone(JST)
    cutoff=current.replace(hour=0,minute=0,second=0,microsecond=0)
    filename=f'request_{current:%Y%m%d%H%M%S}_{uuid4().hex}.csv'
    assigned=0; prepared=None; errors=[]
    try:
        rows=repo_factory().assign(filename,cutoff,max_rows)
        assigned=len(rows)
        if rows:
            data,sha=make_csv(rows,max_bytes)
            s3.put_object(Bucket=bucket,Key='transfer/'+filename,Body=data,
                          Metadata={'sha256':sha},ContentType='text/csv; charset=utf-8',IfNoneMatch='*')
            prepared=filename
    except Exception:
        errors.append('CSV_PREPARE_FAILED')
        log('request-batch','CSV_PREPARE_FAILED',filename=filename)
    try:
        keys=list_files(s3,bucket,'transfer/')
        counts=send_files(keys,transfer,bucket,connector,remote,context,max_files)
    except Exception:
        errors.append('LIST_FAILED')
        counts={'total':0,'requested':0,'failed':0,'not_sent':0}
    ok=not errors and counts['failed']==counts['not_sent']==0
    if ok:
        try:
            s3.put_object(Bucket=bucket, Key=f'daily/{current:%Y%m%d}.json',
                          Body=json.dumps({'date':f'{current:%Y%m%d}', 'completed_at':current.isoformat()}).encode(),
                          ContentType='application/json')
        except Exception:
            errors.append('DAILY_RECORD_FAILED')
            ok=False
    log('request-batch','OK' if ok else 'BATCH_INCOMPLETE',stage='summary',
        assigned_count=assigned,prepared_file=prepared,errors=errors,**counts)
    if not ok:
        metric('request-batch','FinalFailure')
    return {'overall':'OK' if ok else 'PARTIAL_FAILURE','assigned_count':assigned,
            'prepared_file':prepared,'requested_count':counts['requested'],
            'failed_count':counts['failed'],'not_sent_count':counts['not_sent'],'errors':errors}

def reflect(event, repo_factory, store, expected):
    db_only=isinstance(event,dict) and event.get('mode')=='db_only'
    if db_only and set(event) != {'mode','event'}:
        raise ProcessingError('INVALID_RESULT')
    result=normalize_result(event['event'] if db_only else event,**expected)
    errors=[]
    def place():
        try:
            dest=('success/' if result['status']=='SENT' else 'failed/')+result['filename']
            store.move(result['src'],dest)
            log('transfer-result','OK',stage='s3',filename=result['filename'],status=result['status'])
        except Exception:
            errors.append('S3_MOVE_FAILED')
    applied=None
    try:
        applied=repo_factory().reflect(result['filename'],result['status'],result['event_time'],place=None if db_only else place)
        log('transfer-result','OK',stage='db',filename=result['filename'],status=result['status'],ignored_after_success=applied is False)
    except Exception:
        errors.append('DB_UPDATE_FAILED')
    if result['status']=='SEND_FAILED' and applied is not False:
        metric('transfer-result','TransferFailed')
    for error in errors:
        log('transfer-result',error,stage='db' if error=='DB_UPDATE_FAILED' else 's3',level='WARN',filename=result['filename'])
    if errors:
        raise ProcessingError('RESULT_APPLY_FAILED')
    return {'ok':True,'filename':result['filename'],'db':'OK','s3':'SKIPPED' if db_only or applied is False else 'OK','ignored_after_success':applied is False}

def resend(event, context, s3, transfer, bucket, connector, remote, limit=100):
    if not isinstance(event,dict) or event != {'mode':'resend_failed','placement_checked':True} or event.get('placement_checked') is not True:
        raise ProcessingError('INVALID_INPUT')
    try:
        counts=send_files(list_files(s3,bucket,'failed/'),transfer,bucket,connector,remote,context,limit)
    except Exception:
        metric('resend','FinalFailure')
        raise ProcessingError('LIST_FAILED') from None
    ok=counts['failed']==counts['not_sent']==0
    log('resend','OK' if ok else 'RESEND_INCOMPLETE',stage='summary',**counts)
    if not ok:
        metric('resend','FinalFailure')
    return {'ok':ok, **counts}



def check_daily(event, repo_factory, s3, bucket, now=None):
    """At 03:00 JST, confirm today's run and pre-midnight requests reached SENT."""
    if not isinstance(event,dict) or event != {'schema_version':1,'mode':'check_daily'} or type(event.get('schema_version')) is not int:
        raise ProcessingError('INVALID_INPUT')
    current=(now or datetime.now(JST)).astimezone(JST)
    errors=[]; pending=None
    try:
        obj=s3.get_object(Bucket=bucket, Key=f'daily/{current:%Y%m%d}.json')
        body=obj['Body']
        try: record=json.loads(body.read())
        finally: body.close()
        if record.get('date') != f'{current:%Y%m%d}':
            raise ProcessingError('INVALID_DAILY_RECORD')
    except Exception:
        errors.append('DAILY_RECORD_MISSING_OR_UNREADABLE')
    try:
        pending=repo_factory().pending_before(current.replace(hour=0,minute=0,second=0,microsecond=0))
        if pending: errors.append('DAILY_PENDING')
    except Exception:
        errors.append('DAILY_DB_CHECK_FAILED')
    ok=not errors
    log('daily-check','OK' if ok else 'DAILY_INCOMPLETE',pending_count=pending,errors=errors)
    if not ok: metric('daily-check','FinalFailure')
    return {'ok':ok,'pending_count':pending,'errors':errors}
