# Lambda 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/lambda.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. 関数・環境変数

表のMemory単位はMB、timeout単位は秒。予約同時実行の変数`enable_reserved_concurrency`の既定値は`true`。`false`では`-1`を設定して未予約枠を利用し、`0`による停止は行わない。

### aws_lambda_function.employee_intake

Terraformリソース：`aws_lambda_function.employee_intake`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `portfolio-card-employee-intake` |
| 実行ロール | `role` | `aws_iam_role.employee_intake.arn` |
| 実行ランタイム | `runtime` | `python3.13` |
| 実行開始ハンドラ | `handler` | `app.lambda_handler` |
| デプロイZIPのパス | `filename` | `${path.module}/build/employee_intake.zip` |
| 割当メモリ（MB） | `memory_size` | `128` |
| タイムアウト（秒） | `timeout` | `25` |
| 関数バージョンの発行 | `publish` | `true` |
| 環境変数：タイムゾーン | `environment[0].variables.TZ` | `Asia/Tokyo` |
| 環境変数：ログ出力レベル | `environment[0].variables.LOG_LEVEL` | `INFO` |
| 環境変数：システム識別名 | `environment[0].variables.SYSTEM_NAME` | `portfolio-card` |
| 環境変数：登録要求の送信先SQSキューURL | `environment[0].variables.REGISTRATION_QUEUE_URL` | `aws_sqs_queue.registration.id` |

### aws_lambda_function.employee_register

Terraformリソース：`aws_lambda_function.employee_register`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `portfolio-card-employee-register` |
| 実行ロール | `role` | `aws_iam_role.employee_register.arn` |
| 実行ランタイム | `runtime` | `python3.13` |
| 実行開始ハンドラ | `handler` | `app.lambda_handler` |
| デプロイZIPのパス | `filename` | `${path.module}/build/employee_register.zip` |
| 割当メモリ（MB） | `memory_size` | `256` |
| タイムアウト（秒） | `timeout` | `30` |
| 関数バージョンの発行 | `publish` | `true` |
| 環境変数：タイムゾーン | `environment[0].variables.TZ` | `Asia/Tokyo` |
| 環境変数：ログ出力レベル | `environment[0].variables.LOG_LEVEL` | `INFO` |
| 環境変数：システム識別名 | `environment[0].variables.SYSTEM_NAME` | `portfolio-card` |
| 環境変数：DB接続認証情報のSecret ARN | `environment[0].variables.DB_SECRET_ARN` | `aws_secretsmanager_secret.app.arn` |
| 環境変数：DB接続先ホスト | `environment[0].variables.DB_HOST` | `aws_rds_cluster.portfolio.endpoint` |
| 環境変数：接続先DB名 | `environment[0].variables.DB_NAME` | `portfolio` |
| 環境変数：DBのTLS検証用CA証明書パス | `environment[0].variables.DB_SSLROOTCERT` | `/var/task/certs/global-bundle.pem` |
| 予約同時実行数 | `reserved_concurrent_executions` | `var.enable_reserved_concurrency ? 5 : -1` |
| 配置先サブネットID一覧 | `vpc_config[0].subnet_ids` | `data.aws_subnets.private.ids` |
| 適用するセキュリティグループID一覧 | `vpc_config[0].security_group_ids` | `[aws_security_group.registration.id]` |

### aws_lambda_function.request_batch

Terraformリソース：`aws_lambda_function.request_batch`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `portfolio-card-request-batch` |
| 実行ロール | `role` | `aws_iam_role.request_batch.arn` |
| 実行ランタイム | `runtime` | `python3.13` |
| 実行開始ハンドラ | `handler` | `app.lambda_handler` |
| デプロイZIPのパス | `filename` | `${path.module}/build/request_batch.zip` |
| 割当メモリ（MB） | `memory_size` | `512` |
| タイムアウト（秒） | `timeout` | `300` |
| 関数バージョンの発行 | `publish` | `true` |
| 環境変数：タイムゾーン | `environment[0].variables.TZ` | `Asia/Tokyo` |
| 環境変数：ログ出力レベル | `environment[0].variables.LOG_LEVEL` | `INFO` |
| 環境変数：システム識別名 | `environment[0].variables.SYSTEM_NAME` | `portfolio-card` |
| 環境変数：DB接続認証情報のSecret ARN | `environment[0].variables.DB_SECRET_ARN` | `aws_secretsmanager_secret.app.arn` |
| 環境変数：DB接続先ホスト | `environment[0].variables.DB_HOST` | `aws_rds_cluster.portfolio.endpoint` |
| 環境変数：接続先DB名 | `environment[0].variables.DB_NAME` | `portfolio` |
| 環境変数：DBのTLS検証用CA証明書パス | `environment[0].variables.DB_SSLROOTCERT` | `/var/task/certs/global-bundle.pem` |
| 環境変数：連携ファイル格納先S3バケット | `environment[0].variables.EXCHANGE_BUCKET` | `aws_s3_bucket.card_exchange.bucket` |
| 環境変数：SFTP転送コネクタID | `environment[0].variables.CONNECTOR_ID` | `awscc_transfer_connector.vendor.connector_id` |
| 環境変数：SFTP送信先ディレクトリ | `environment[0].variables.REMOTE_DIRECTORY` | `/inbox` |
| 環境変数：操作対象として検証するAWSアカウントID | `environment[0].variables.EXPECTED_ACCOUNT_ID` | `data.aws_caller_identity.current.account_id` |
| 予約同時実行数 | `reserved_concurrent_executions` | `var.enable_reserved_concurrency ? 1 : -1` |
| 配置先サブネットID一覧 | `vpc_config[0].subnet_ids` | `data.aws_subnets.private.ids` |
| 適用するセキュリティグループID一覧 | `vpc_config[0].security_group_ids` | `[aws_security_group.request.id]` |

### aws_lambda_function.transfer_result

Terraformリソース：`aws_lambda_function.transfer_result`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `portfolio-card-transfer-result` |
| 実行ロール | `role` | `aws_iam_role.transfer_result.arn` |
| 実行ランタイム | `runtime` | `python3.13` |
| 実行開始ハンドラ | `handler` | `app.lambda_handler` |
| デプロイZIPのパス | `filename` | `${path.module}/build/transfer_result.zip` |
| 割当メモリ（MB） | `memory_size` | `256` |
| タイムアウト（秒） | `timeout` | `60` |
| 関数バージョンの発行 | `publish` | `true` |
| 環境変数：タイムゾーン | `environment[0].variables.TZ` | `Asia/Tokyo` |
| 環境変数：ログ出力レベル | `environment[0].variables.LOG_LEVEL` | `INFO` |
| 環境変数：システム識別名 | `environment[0].variables.SYSTEM_NAME` | `portfolio-card` |
| 環境変数：DB接続認証情報のSecret ARN | `environment[0].variables.DB_SECRET_ARN` | `aws_secretsmanager_secret.app.arn` |
| 環境変数：DB接続先ホスト | `environment[0].variables.DB_HOST` | `aws_rds_cluster.portfolio.endpoint` |
| 環境変数：接続先DB名 | `environment[0].variables.DB_NAME` | `portfolio` |
| 環境変数：DBのTLS検証用CA証明書パス | `environment[0].variables.DB_SSLROOTCERT` | `/var/task/certs/global-bundle.pem` |
| 環境変数：連携ファイル格納先S3バケット | `environment[0].variables.EXCHANGE_BUCKET` | `aws_s3_bucket.card_exchange.bucket` |
| 環境変数：SFTP転送コネクタID | `environment[0].variables.CONNECTOR_ID` | `awscc_transfer_connector.vendor.connector_id` |
| 環境変数：SFTP送信先ディレクトリ | `environment[0].variables.REMOTE_DIRECTORY` | `/inbox` |
| 環境変数：操作対象として検証するAWSアカウントID | `environment[0].variables.EXPECTED_ACCOUNT_ID` | `data.aws_caller_identity.current.account_id` |
| 予約同時実行数 | `reserved_concurrent_executions` | `var.enable_reserved_concurrency ? 5 : -1` |
| 配置先サブネットID一覧 | `vpc_config[0].subnet_ids` | `data.aws_subnets.private.ids` |
| 適用するセキュリティグループID一覧 | `vpc_config[0].security_group_ids` | `[aws_security_group.result.id]` |

### aws_lambda_function.resend

Terraformリソース：`aws_lambda_function.resend`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `portfolio-card-resend` |
| 実行ロール | `role` | `aws_iam_role.resend.arn` |
| 実行ランタイム | `runtime` | `python3.13` |
| 実行開始ハンドラ | `handler` | `app.lambda_handler` |
| デプロイZIPのパス | `filename` | `${path.module}/build/resend.zip` |
| 割当メモリ（MB） | `memory_size` | `256` |
| タイムアウト（秒） | `timeout` | `300` |
| 関数バージョンの発行 | `publish` | `true` |
| 環境変数：タイムゾーン | `environment[0].variables.TZ` | `Asia/Tokyo` |
| 環境変数：ログ出力レベル | `environment[0].variables.LOG_LEVEL` | `INFO` |
| 環境変数：システム識別名 | `environment[0].variables.SYSTEM_NAME` | `portfolio-card` |
| 環境変数：連携ファイル格納先S3バケット | `environment[0].variables.EXCHANGE_BUCKET` | `aws_s3_bucket.card_exchange.bucket` |
| 環境変数：SFTP転送コネクタID | `environment[0].variables.CONNECTOR_ID` | `awscc_transfer_connector.vendor.connector_id` |
| 環境変数：SFTP送信先ディレクトリ | `environment[0].variables.REMOTE_DIRECTORY` | `/inbox` |
| 環境変数：操作対象として検証するAWSアカウントID | `environment[0].variables.EXPECTED_ACCOUNT_ID` | `data.aws_caller_identity.current.account_id` |
| 予約同時実行数 | `reserved_concurrent_executions` | `var.enable_reserved_concurrency ? 1 : -1` |
| 配置先サブネットID一覧 | `vpc_config[0].subnet_ids` | `data.aws_subnets.private.ids` |
| 適用するセキュリティグループID一覧 | `vpc_config[0].security_group_ids` | `[aws_security_group.resend.id]` |

### aws_lambda_function.id_mock

Terraformリソース：`aws_lambda_function.id_mock`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `portfolio-id-system-mock` |
| 実行ロール | `role` | `aws_iam_role.id_mock.arn` |
| 実行ランタイム | `runtime` | `python3.13` |
| 実行開始ハンドラ | `handler` | `app.lambda_handler` |
| デプロイZIPのパス | `filename` | `${path.module}/build/id_mock.zip` |
| 割当メモリ（MB） | `memory_size` | `128` |
| タイムアウト（秒） | `timeout` | `60` |
| 関数バージョンの発行 | `publish` | `true` |
| 環境変数：社員情報受付APIのURL | `environment[0].variables.API_ENDPOINT` | `${aws_apigatewayv2_api.employees.api_endpoint}/employees` |

`source_code_hash`は各ZIPの`filebase64sha256`。ZIPはLinux x86_64向け依存とRDS CA bundleを同梱する。`architectures`、`package_type`、`ephemeral_storage`はTerraformでは未指定とし、明示設定値とは扱わない。秘密値は環境変数へ設定しない。

## 3. Version・Alias

| Aliasリソース | 名前（name） | 関数名（function_name） | 関数バージョン（function_version） |
| --- | --- | --- | --- |
| `aws_lambda_alias.employee_intake` | `live` | `aws_lambda_function.employee_intake.function_name` | `aws_lambda_function.employee_intake.version` |
| `aws_lambda_alias.employee_register` | `live` | `aws_lambda_function.employee_register.function_name` | `aws_lambda_function.employee_register.version` |
| `aws_lambda_alias.request_batch` | `live` | `aws_lambda_function.request_batch.function_name` | `aws_lambda_function.request_batch.version` |
| `aws_lambda_alias.transfer_result` | `live` | `aws_lambda_function.transfer_result.function_name` | `aws_lambda_function.transfer_result.version` |
| `aws_lambda_alias.resend` | `live` | `aws_lambda_function.resend.function_name` | `aws_lambda_function.resend.version` |
| `aws_lambda_alias.id_mock` | `live` | `aws_lambda_function.id_mock.function_name` | `aws_lambda_function.id_mock.version` |

## 4. 起動・再試行

### aws_lambda_event_source_mapping.registration

Terraformリソース：`aws_lambda_event_source_mapping.registration`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 起動元リソースARN | `event_source_arn` | `aws_sqs_queue.registration.arn` |
| 関数名・参照先 | `function_name` | `aws_lambda_alias.employee_register.arn` |
| 1回の起動で処理するメッセージ数 | `batch_size` | `1` |
| 部分失敗時の応答方式 | `function_response_types` | `["ReportBatchItemFailures"]` |
| 最大同時実行数 | `scaling_config[0].maximum_concurrency` | `5` |

### aws_lambda_function_event_invoke_config.transfer_result

Terraformリソース：`aws_lambda_function_event_invoke_config.transfer_result`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `aws_lambda_function.transfer_result.function_name` |
| 対象エイリアス・バージョン | `qualifier` | `aws_lambda_alias.transfer_result.name` |
| 最大追加再試行回数 | `maximum_retry_attempts` | `2` |
| イベントの最大保持時間（秒） | `maximum_event_age_in_seconds` | `3600` |
| 失敗時の送信先ARN | `destination_config[0].on_failure[0].destination` | `aws_sqs_queue.result_execution_dlq.arn` |

### aws_lambda_function_event_invoke_config.request_batch

Terraformリソース：`aws_lambda_function_event_invoke_config.request_batch`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 関数名・参照先 | `function_name` | `aws_lambda_function.request_batch.function_name` |
| 対象エイリアス・バージョン | `qualifier` | `aws_lambda_alias.request_batch.name` |
| 最大追加再試行回数 | `maximum_retry_attempts` | `0` |
| イベントの最大保持時間（秒） | `maximum_event_age_in_seconds` | `3600` |

受付はAPI同期起動、登録はSQSイベントソース、発行依頼はScheduler非同期起動、結果反映はEventBridge非同期起動、再送は保守同期起動とする。SQS再配信とLambda非同期再試行を区別する。発行依頼は関数全体のエラー再試行を0回とし、結果反映は最大2回追加する。配信重複・スロットリングを含む総実行回数は保証しない。

## 5. アプリケーション内の既定値

次の上限はTerraformの環境変数には設定せず、アプリが環境変数未指定時の既定値として使用する。

| 意味 | 変数 | 対象 | 既定値 |
| --- | --- | --- | --- |
| CSVの最大行数 | `MAX_CSV_ROWS` | 発行依頼 | `10000` |
| CSVの最大サイズ（バイト） | `MAX_CSV_BYTES` | 発行依頼 | `16777216` |
| 1回の実行で処理する最大ファイル数 | `MAX_FILES_PER_RUN` | 発行依頼・再送 | `100` |

| 意味 | SDK設定 | 受付SQS | 通常読取 | 書込み・転送要求 |
| --- | --- | --- | --- | --- |
| SDKの再試行方式 | `retries.mode` | `standard` | `standard` | `standard` |
| 初回を含む最大試行回数 | `total_max_attempts` | `3` | `3` | `1` |
| connect_timeout（秒） | `connect_timeout（秒）` | `1` | `3` | `3` |
| read_timeout（秒） | `read_timeout（秒）` | `2` | `5` | `5` |

DB接続は実行環境内で再利用し、新規接続時にSecretを取得する。接続設定は[Aurora詳細設計](06_AWS_Aurora_PostgreSQL.md)に定める。

## 6. 構築・監視

標準構成の予約同時実行合計は12（登録5・発行依頼1・結果反映5・再送1）。構築時のアカウント設定・所有範囲の確認は`tools.status.security_inventory`で行う。日次と完了確認は`enable_daily_schedule=false`で停止状態から構築する。

最終失敗・DLQ・強制終了・スロットリングの通知条件は[CloudWatch詳細設計](13_AWS_CloudWatch.md)、業務処理は[Lambda処理仕様](../02_アプリ/01_Lambda処理仕様.md)、保守処理は[保守ツール処理仕様](../03_構築保守/03_保守ツール処理仕様.md)に定める。
