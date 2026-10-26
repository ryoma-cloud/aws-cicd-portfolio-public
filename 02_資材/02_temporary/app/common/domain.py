"""Business contracts shared by HTTP, queue, batch and result handlers."""
import csv
import hashlib
import io
import json
import re
import secrets
import string
from datetime import datetime
from zoneinfo import ZoneInfo

JST = ZoneInfo('Asia/Tokyo')
EMPLOYEE_FIELDS = ('employee_id', 'employee_name', 'company_name')
CSV_FIELDS = (*EMPLOYEE_FIELDS, 'badge_number')
FILENAME = re.compile(r'request_[0-9]{14}_[0-9a-f]{32}\.csv', re.ASCII)
STATES = ('REQUESTED', 'SENT', 'SEND_FAILED')

class ProcessingError(Exception):
    """Only fixed error codes may be surfaced or logged."""

def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ProcessingError('INVALID_INPUT')
            result[key] = value
        return result
    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
    except (ValueError, TypeError, UnicodeError) as exc:
        raise ProcessingError('INVALID_INPUT') from exc

def validate_employee(value):
    if not isinstance(value, dict) or set(value) != set(EMPLOYEE_FIELDS):
        raise ProcessingError('INVALID_INPUT')
    for key, item in value.items():
        if not isinstance(item, str) or not item.strip() or any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in item):
            raise ProcessingError('INVALID_INPUT')
        try:
            item.encode('utf-8')
        except UnicodeEncodeError as exc:
            raise ProcessingError('INVALID_INPUT') from exc
        if key == 'employee_id':
            if re.fullmatch('[0-9]{6}', item, flags=re.ASCII) is None:
                raise ProcessingError('INVALID_INPUT')
        elif len(item) > 100:
            raise ProcessingError('INVALID_INPUT')
    return dict(value)

def parse_time(value):
    try:
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if parsed.tzinfo is None:
            raise ValueError()
        return parsed.astimezone(JST)
    except (ValueError, TypeError, AttributeError) as exc:
        raise ProcessingError('INVALID_TIME') from exc

def new_badge_number():
    return secrets.choice(string.ascii_uppercase) + f'{secrets.randbelow(10**15):015d}'

def make_csv(rows, max_bytes=16777216):
    buf = io.StringIO(newline='')
    writer = csv.DictWriter(buf, CSV_FIELDS, lineterminator='\r\n', extrasaction='ignore')
    writer.writeheader()
    for row in sorted(rows, key=lambda row: row['employee_id']):
        writer.writerow(row)
    data = buf.getvalue().encode('utf-8')
    if len(data) > max_bytes:
        raise ProcessingError('CSV_TOO_LARGE')
    return data, hashlib.sha256(data).hexdigest()

def normalize_result(event, *, account, region, connector, bucket):
    try:
        detail = event['detail']
        location = detail['local-file-location']
        status_code = detail['status-code']
        expected_type = {'COMPLETED': 'SFTP Connector File Send Completed', 'FAILED': 'SFTP Connector File Send Failed'}[status_code]
        key = location['key']
        prefix, filename = key.split('/')
        valid = (event['source'] == 'aws.transfer' and event['account'] == account
                 and event['region'] == region and event['detail-type'] == expected_type
                 and detail['connector-id'] == connector and detail['operation'] == 'SEND'
                 and location['domain'] == 'S3' and location['bucket'] == bucket
                 and prefix in ('transfer', 'failed') and FILENAME.fullmatch(filename))
        if not valid:
            raise ValueError()
        return {'filename': filename, 'src': key,
                'status': 'SENT' if status_code == 'COMPLETED' else 'SEND_FAILED',
                'event_time': parse_time(event['time'])}
    except (KeyError, ValueError, TypeError, AttributeError) as exc:
        raise ProcessingError('INVALID_RESULT') from exc
