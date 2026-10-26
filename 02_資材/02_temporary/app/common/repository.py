"""Bound SQL, transaction boundaries and idempotency."""
from common.domain import ProcessingError, new_badge_number

class Repository:
    def __init__(self, connection):
        self.connection = connection

    def register(self, employee, received_at):
        with self.connection.transaction():
            with self.connection.cursor() as cur:
                cur.execute('''INSERT INTO badge.card_requests
                    (employee_id,employee_name,company_name,badge_number,received_at)
                    VALUES (%s,%s,%s,%s,%s) ON CONFLICT (employee_id) DO NOTHING
                    RETURNING employee_id''', (employee['employee_id'], employee['employee_name'], employee['company_name'], new_badge_number(), received_at))
                if cur.fetchone():
                    return
                cur.execute('SELECT employee_name,company_name FROM badge.card_requests WHERE employee_id=%s', (employee['employee_id'],))
                row = cur.fetchone()
                if not row or row['employee_name'] != employee['employee_name'] or row['company_name'] != employee['company_name']:
                    raise ProcessingError('EMPLOYEE_CONFLICT')

    def assign(self, filename, cutoff, limit):
        with self.connection.transaction():
            with self.connection.cursor() as cur:
                cur.execute('''WITH target AS (
                    SELECT employee_id FROM badge.card_requests
                    WHERE status='REQUESTED' AND send_filename IS NULL AND received_at < %s
                    ORDER BY received_at,employee_id LIMIT %s FOR UPDATE SKIP LOCKED)
                    UPDATE badge.card_requests r SET send_filename=%s,updated_at=CURRENT_TIMESTAMP
                    FROM target t WHERE r.employee_id=t.employee_id
                    RETURNING r.employee_id,r.employee_name,r.company_name,r.badge_number''', (cutoff,limit,filename))
                return cur.fetchall()

    def reflect(self, filename, status, event_time, place=None):
        def lock_rows(cur):
            cur.execute('''SELECT employee_id,status FROM badge.card_requests
                WHERE send_filename=%s ORDER BY employee_id FOR UPDATE''', (filename,))
            rows=cur.fetchall()
            if not rows:
                raise ProcessingError('DB_TARGET_NOT_FOUND')
            return rows

        def superseded(rows):
            return status=='SEND_FAILED' and any(row['status']=='SENT' for row in rows)

        with self.connection.transaction():
            with self.connection.cursor() as cur:
                if superseded(lock_rows(cur)):
                    return False
                cur.execute('''UPDATE badge.card_requests SET status=%s,updated_at=%s
                    WHERE send_filename=%s AND status IS DISTINCT FROM %s''', (status,event_time,filename,status))
        # Commit the authoritative result before S3. A failed move must not
        # roll back SENT. Reacquire the same row locks and recheck before S3:
        # a success may have committed between the two transactions.
        if place is not None:
            with self.connection.transaction():
                with self.connection.cursor() as cur:
                    cur.execute("SET LOCAL idle_in_transaction_session_timeout = '120s'")
                    if superseded(lock_rows(cur)):
                        return False
                    place()
        return True

    def pending_before(self, cutoff):
        with self.connection.transaction():
            with self.connection.cursor() as cur:
                cur.execute("SELECT count(*) AS total FROM badge.card_requests WHERE received_at < %s AND status <> 'SENT'", (cutoff,))
                return cur.fetchone()['total']

    def ready(self):
        with self.connection.transaction():
            with self.connection.cursor() as cur:
                cur.execute('SELECT 1')
                cur.fetchone()

    def search(self, q, status, page):
        where, params = [], []
        if q:
            escaped = q.replace('\\','\\\\').replace('%',r'\%').replace('_',r'\_')
            where.append("(employee_name LIKE %s ESCAPE E'\\\\' OR employee_id=%s OR badge_number=%s)")
            params += ['%'+escaped+'%', q, q]
        if status:
            where.append('status=%s')
            params.append(status)
        clause = ' WHERE ' + ' AND '.join(where) if where else ''
        with self.connection.transaction():
            with self.connection.cursor() as cur:
                cur.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY')
                cur.execute('SELECT count(*) AS total FROM badge.card_requests'+clause, params)
                total = cur.fetchone()['total']
                cur.execute('SELECT * FROM badge.card_requests'+clause+' ORDER BY received_at DESC,employee_id ASC LIMIT 50 OFFSET %s', params+[(page-1)*50])
                return total, cur.fetchall()

