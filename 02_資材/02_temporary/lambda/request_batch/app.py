import os
from common import service, runtime
from common.repository import Repository

def repository():
    return Repository(runtime.db_connection())

def lambda_handler(event, context):
    if isinstance(event,dict) and event.get('mode')=='check_daily':
        return service.check_daily(event, repository, runtime.client('s3'), os.environ['EXCHANGE_BUCKET'])
    return service.daily(event, context, repository, runtime.client('s3', write=True), runtime.client('transfer', write=True), os.environ['EXCHANGE_BUCKET'], os.environ['CONNECTOR_ID'], os.environ['REMOTE_DIRECTORY'], max_rows=int(os.environ.get('MAX_CSV_ROWS',10000)), max_bytes=int(os.environ.get('MAX_CSV_BYTES',16777216)), max_files=int(os.environ.get('MAX_FILES_PER_RUN',100)))

