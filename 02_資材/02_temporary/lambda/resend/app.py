import os
from common import service, runtime
from common.repository import Repository

def repository():
    return Repository(runtime.db_connection())

def lambda_handler(event, context):
    return service.resend(event, context, runtime.client('s3', write=True), runtime.client('transfer', write=True), os.environ['EXCHANGE_BUCKET'], os.environ['CONNECTOR_ID'], os.environ['REMOTE_DIRECTORY'], int(os.environ.get('MAX_FILES_PER_RUN',100)))
