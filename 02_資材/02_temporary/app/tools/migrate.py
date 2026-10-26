"""Checksum-protected forward migrations and idempotent DB credential setup."""
import hashlib
import json
import os
import secrets
from pathlib import Path
from psycopg import sql
from common.runtime import open_db_connection,client

def migrate(conn, paths):
    with conn.cursor() as cur:
        cur.execute("SELECT pg_advisory_lock(hashtext('portfolio-card-migration'))")
    try:
        with conn.transaction():
            conn.execute('CREATE SCHEMA IF NOT EXISTS badge')
            conn.execute('CREATE TABLE IF NOT EXISTS badge.badge_schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP)')
        for path in sorted(paths):
            content=path.read_text(); checksum=hashlib.sha256(content.encode()).hexdigest()
            with conn.transaction():
                row=conn.execute('SELECT checksum FROM badge.badge_schema_migrations WHERE version=%s',(path.name,)).fetchone()
                if row:
                    if row['checksum']!=checksum:
                        raise RuntimeError('MIGRATION_CHECKSUM_MISMATCH')
                    continue
                conn.execute(content)
                conn.execute('INSERT INTO badge.badge_schema_migrations(version,checksum) VALUES (%s,%s)',(path.name,checksum))
    finally:
        conn.execute("SELECT pg_advisory_unlock(hashtext('portfolio-card-migration'))")

def roles(conn,sm):
    from botocore.exceptions import ClientError
    for name,secret_env,rights in [('badge_app','APP_SECRET_ARN','SELECT,INSERT,UPDATE'),('badge_web','WEB_SECRET_ARN','SELECT')]:
        arn=os.environ[secret_env]
        try:
            value=json.loads(sm.get_secret_value(SecretId=arn)['SecretString'])
            password=value['password']
        except ClientError as exc:
            if exc.response['Error']['Code']!='ResourceNotFoundException':
                raise
            password=secrets.token_urlsafe(32)
            # Persist first; a retry can safely align the DB to the same value.
            sm.put_secret_value(SecretId=arn,SecretString=json.dumps({'username':name,'password':password}))
        with conn.transaction():
            exists=conn.execute('SELECT 1 FROM pg_roles WHERE rolname=%s',(name,)).fetchone()
            statement='ALTER ROLE {} LOGIN PASSWORD {}' if exists else 'CREATE ROLE {} LOGIN PASSWORD {}'
            conn.execute(sql.SQL(statement).format(sql.Identifier(name),sql.Literal(password)))
            conn.execute(sql.SQL('GRANT USAGE ON SCHEMA badge TO {}').format(sql.Identifier(name)))
            conn.execute('REVOKE ALL ON badge.card_requests FROM PUBLIC')
            conn.execute(sql.SQL('GRANT '+rights+' ON badge.card_requests TO {}').format(sql.Identifier(name)))

if __name__=='__main__':
    with open_db_connection() as conn:
        migrate(conn,Path(__file__).resolve().parents[1].joinpath('migrations').glob('*.sql'))
        roles(conn,client('secretsmanager',write=True))
