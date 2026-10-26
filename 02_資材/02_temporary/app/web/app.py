import logging
import math
import re
from time import perf_counter
from contextlib import contextmanager
from flask import Flask, g, render_template, request, redirect, url_for
from common.domain import JST, STATES
from common.repository import Repository
from common.runtime import log

logging.getLogger('werkzeug').disabled = True

@contextmanager
def repository():
    from sqlalchemy.pool import QueuePool
    if not hasattr(repository,'pool'):
        # Pool owns each connection; the Lambda connection cache is bypassed.
        from common.runtime import open_db_connection
        repository.pool=QueuePool(open_db_connection,pool_size=2,max_overflow=0,timeout=3)
    conn=repository.pool.connect()
    try:
        yield Repository(conn.dbapi_connection)
    except Exception:
        conn.invalidate()
        raise
    finally:
        conn.close()

def create_app(repo_context=repository):
    app=Flask(__name__)
    labels={'REQUESTED':'入館証発行依頼待ち','SENT':'入館証発行依頼済み','SEND_FAILED':'入館証発行依頼失敗'}

    def log_path():
        # Log the fixed route template, never query values or an arbitrary URL.
        return request.url_rule.rule if request.url_rule is not None else '<unmatched>'

    @app.before_request
    def start_request():
        g.request_started_at = perf_counter()

    @app.after_request
    def access_log(resp):
        code = ('HTTP_SERVER_ERROR' if resp.status_code >= 500 else
                'HTTP_CLIENT_ERROR' if resp.status_code >= 400 else 'OK')
        log('web-access', code, stage='response', path=log_path(),
            status=resp.status_code,
            duration_ms=round((perf_counter() - g.request_started_at) * 1000, 3),
            level='ERROR' if resp.status_code >= 500 else
                  'WARN' if resp.status_code >= 400 else 'INFO')
        return resp

    @app.after_request
    def headers(resp):
        resp.headers.update({'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',
            'Content-Security-Policy':"default-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'"})
        return resp

    @app.get('/health')
    def health():
        return {'status':'ok'}

    @app.get('/ready')
    def ready():
        try:
            with repo_context() as repo:
                repo.ready()
            return {'status':'ok'}
        except Exception:
            log('web', 'WEB_READY_UNAVAILABLE', stage='db', path=log_path())
            return {'status':'unavailable'},503

    @app.get('/')
    def index():
        q=request.args.get('q','').strip()
        status=request.args.get('status','')
        page=request.args.get('page','1')
        if len(q)>100 or status not in ('',*STATES) or re.fullmatch('[0-9]{1,9}',page) is None or int(page)<1:
            return '検索条件を確認してください。',400
        page=int(page)
        stage='db'
        try:
            with repo_context() as repo:
                total,rows=repo.search(q,status,page)
            stage='render'
            pages=max(1,math.ceil(total/50))
            if page>pages:
                return redirect(url_for('index',q=q,status=status,page=pages))
            for row in rows:
                row['display_status']=labels[row['status']]
                row['display_time']=row['updated_at'].astimezone(JST).strftime('%Y/%m/%d %H:%M:%S')
            return render_template('index.html',rows=rows,total=total,page=page,pages=pages,q=q,status=status,labels=labels)
        except Exception:
            code = 'WEB_DB_UNAVAILABLE' if stage == 'db' else 'WEB_RENDER_FAILED'
            log('web', code, stage=stage, path=log_path())
            return 'データを取得できません。時間をおいて再度お試しください。',503
    return app

app=create_app()
