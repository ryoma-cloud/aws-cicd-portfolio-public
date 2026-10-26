CREATE SCHEMA IF NOT EXISTS badge;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE TABLE badge.card_requests (
  employee_id varchar(6) PRIMARY KEY
    CHECK (employee_id ~ '^[0-9]{6}$'),
  employee_name varchar(100) NOT NULL
    CHECK (length(btrim(employee_name)) > 0),
  company_name varchar(100) NOT NULL
    CHECK (length(btrim(company_name)) > 0),
  badge_number varchar(16) NOT NULL UNIQUE
    CHECK (badge_number ~ '^[A-Za-z][0-9]{15}$'),
  status varchar(11) NOT NULL DEFAULT 'REQUESTED'
    CHECK (status IN ('REQUESTED','SENT','SEND_FAILED')),
  send_filename varchar(64)
    CHECK (send_filename ~ '^request_[0-9]{14}_[0-9a-f]{32}[.]csv$'),
  received_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX card_requests_filename_idx
  ON badge.card_requests(send_filename)
  WHERE send_filename IS NOT NULL;
CREATE INDEX card_requests_unassigned_idx
  ON badge.card_requests(received_at, employee_id)
  WHERE status='REQUESTED' AND send_filename IS NULL;
CREATE INDEX card_requests_received_idx
  ON badge.card_requests(received_at DESC, employee_id ASC);
