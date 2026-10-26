"""AWS adapters: lazy clients, TLS DB connections, safe JSON / EMF logging."""
import hashlib
import json
import os
import time
from datetime import datetime
from functools import lru_cache

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from common.domain import JST, ProcessingError

@lru_cache(maxsize=None)
def client(service, write=False, intake=False):
    return boto3.client(service, config=Config(
        retries={'mode': 'standard', 'total_max_attempts': 3 if intake or not write else 1},
        connect_timeout=1 if intake else 3, read_timeout=2 if intake else 5))

def log(process, code, **fields):
    # Call sites pass fixed codes, counts and file / request identifiers only.
    record={'timestamp':datetime.now(JST).isoformat(),
            'level':'INFO' if code=='OK' else 'ERROR','process':process,
            'stage':None,'outcome':'SUCCESS' if code=='OK' else 'FAILURE',
            'aws_request_id':None,'request_id':None,'duration_ms':None,
            'error_code':None if code=='OK' else code}
    record.update(fields)
    print(json.dumps(record, ensure_ascii=False))

def metric(process, name):
    print(json.dumps({'_aws': {'Timestamp': int(time.time()*1000), 'CloudWatchMetrics': [
        {'Namespace': 'Portfolio/Card', 'Dimensions': [['Process']],
         'Metrics': [{'Name': name, 'Unit': 'Count'}]}]}, 'Process': process, name: 1}))

_connections = {}
def db_connection(role='app'):
    import psycopg
    from psycopg.rows import dict_row
    key = (role, os.environ['DB_HOST'], os.environ['DB_SECRET_ARN'])
    conn = _connections.get(key)
    if conn is not None and not conn.closed and not conn.broken:
        try:
            conn.execute('SELECT 1')
            return conn
        except Exception:
            conn.close()
    conn = open_db_connection()
    _connections[key] = conn
    return conn

def open_db_connection():
    import psycopg
    from psycopg.rows import dict_row
    secret = json.loads(client('secretsmanager').get_secret_value(SecretId=os.environ['DB_SECRET_ARN'])['SecretString'])
    return psycopg.connect(host=os.environ['DB_HOST'], dbname=os.environ.get('DB_NAME','portfolio'),
        user=secret['username'], password=secret['password'], connect_timeout=5,
        sslmode='verify-full', sslrootcert=os.environ['DB_SSLROOTCERT'], row_factory=dict_row,
        autocommit=True,
        options='-c search_path=badge,pg_catalog -c timezone=Asia/Tokyo -c statement_timeout=10000 -c lock_timeout=3000 -c idle_in_transaction_session_timeout=15000')

class ObjectStore:
    def __init__(self, s3, bucket):
        self.s3, self.bucket = s3, bucket

    def read(self, key):
        try:
            result = self.s3.get_object(Bucket=self.bucket, Key=key)
        except ClientError as exc:
            if exc.response['Error']['Code'] in ('NoSuchKey', '404', 'NotFound'):
                return None
            raise ProcessingError('S3_ACCESS_ERROR') from exc
        body = result['Body']
        try:
            data = body.read()
        finally:
            body.close()
        checksum = hashlib.sha256(data).hexdigest()
        if result.get('Metadata', {}).get('sha256') != checksum:
            raise ProcessingError('CHECKSUM_MISMATCH')
        return data, checksum

    def move(self, src, dest):
        original = self.read(src)
        if src == dest:
            if original is None:
                raise ProcessingError('FILE_NOT_FOUND')
            return
        target = self.read(dest)
        if original is None:
            if target is None:
                raise ProcessingError('FILE_NOT_FOUND')
            return
        if target is not None and target != original:
            raise ProcessingError('CONTENT_MISMATCH')
        if target is None:
            self.s3.copy_object(Bucket=self.bucket, Key=dest,
                CopySource={'Bucket':self.bucket, 'Key':src}, MetadataDirective='COPY')
            if self.read(dest) != original:
                raise ProcessingError('CONTENT_MISMATCH')
        self.s3.delete_object(Bucket=self.bucket, Key=src)
