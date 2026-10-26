import os
from common import service, runtime
from common.repository import Repository

def repository():
    return Repository(runtime.db_connection())

def lambda_handler(event, context):
    return service.intake(event, runtime.client('sqs', intake=True), os.environ['REGISTRATION_QUEUE_URL'])
