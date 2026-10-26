import os
from common import service, runtime
from common.repository import Repository

def repository():
    return Repository(runtime.db_connection())

def lambda_handler(event, context):
    return service.reflect(event, repository, runtime.ObjectStore(runtime.client('s3', write=True), os.environ['EXCHANGE_BUCKET']), {'account':os.environ['EXPECTED_ACCOUNT_ID'],'region':os.environ['AWS_REGION'],'connector':os.environ['CONNECTOR_ID'],'bucket':os.environ['EXCHANGE_BUCKET']})
