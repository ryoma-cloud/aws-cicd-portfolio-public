# EventBridge 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/scheduler-eventbridge.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. Scheduler

### aws_scheduler_schedule_group.daily

Terraformリソース：`aws_scheduler_schedule_group.daily`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card` |

### aws_scheduler_schedule.daily

Terraformリソース：`aws_scheduler_schedule.daily`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-daily-request` |
| スケジュールグループ名 | `group_name` | `aws_scheduler_schedule_group.daily.name` |
| 起動日時のスケジュール式 | `schedule_expression` | `cron(0 1 * * ? *)` |
| スケジュール判定のタイムゾーン | `schedule_expression_timezone` | `Asia/Tokyo` |
| 実行スケジュールの有効状態 | `state` | `var.enable_daily_schedule ? "ENABLED" : "DISABLED"` |
| 起動時刻の柔軟な時間枠 | `flexible_time_window[0].mode` | `OFF` |
| スケジュールの起動先Lambda ARN | `target[0].arn` | `aws_lambda_alias.request_batch.arn` |
| 実行ロールARN | `target[0].role_arn` | `aws_iam_role.scheduler.arn` |
| 起動入力の形式バージョン | `target[0].input.schema_version` | `1` |
| 起動入力の処理モード | `target[0].input.mode` | `daily` |
| 配信失敗時の退避先DLQ ARN | `target[0].dead_letter_config[0].arn` | `aws_sqs_queue.schedule_delivery_dlq.arn` |
| 最大追加再試行回数 | `target[0].retry_policy[0].maximum_retry_attempts` | `2` |
| イベントの最大保持時間（秒） | `target[0].retry_policy[0].maximum_event_age_in_seconds` | `3600` |

### aws_scheduler_schedule.daily_check

Terraformリソース：`aws_scheduler_schedule.daily_check`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-daily-check` |
| スケジュールグループ名 | `group_name` | `aws_scheduler_schedule_group.daily.name` |
| 起動日時のスケジュール式 | `schedule_expression` | `cron(0 3 * * ? *)` |
| スケジュール判定のタイムゾーン | `schedule_expression_timezone` | `Asia/Tokyo` |
| 実行スケジュールの有効状態 | `state` | `var.enable_daily_schedule ? "ENABLED" : "DISABLED"` |
| 起動時刻の柔軟な時間枠 | `flexible_time_window[0].mode` | `OFF` |
| スケジュールの起動先Lambda ARN | `target[0].arn` | `aws_lambda_alias.request_batch.arn` |
| 実行ロールARN | `target[0].role_arn` | `aws_iam_role.scheduler.arn` |
| 起動入力の形式バージョン | `target[0].input.schema_version` | `1` |
| 起動入力の処理モード | `target[0].input.mode` | `check_daily` |
| 配信失敗時の退避先DLQ ARN | `target[0].dead_letter_config[0].arn` | `aws_sqs_queue.schedule_delivery_dlq.arn` |
| 最大追加再試行回数 | `target[0].retry_policy[0].maximum_retry_attempts` | `2` |
| イベントの最大保持時間（秒） | `target[0].retry_policy[0].maximum_event_age_in_seconds` | `3600` |

`enable_daily_schedule`は既定`false`。日次01:00 JSTと完了確認03:00 JSTを同時にENABLED/DISABLEDへ切り替える。初回はDISABLEDで構築する。配信再試行（2回・有効期間3600秒）は関数エラーの再試行とは別であり、発行依頼Lambdaの関数エラー再試行は0回。両スケジュールを停止した状態は自動検知しない。

## 3. EventBridge Rule・Target

### aws_cloudwatch_event_rule.result

Terraformリソース：`aws_cloudwatch_event_rule.result`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-transfer-result` |
| イベント発生元の抽出条件 | `event_pattern.source` | `["aws.transfer"]` |
| イベント種別の抽出条件 | `event_pattern.detail-type` | `["SFTP Connector File Send Completed", "SFTP Connector File Send Failed"]` |
| 対象SFTPコネクタIDの抽出条件 | `event_pattern.detail.connector-id` | `[awscc_transfer_connector.vendor.connector_id]` |
| 対象転送操作の抽出条件 | `event_pattern.detail.operation` | `["SEND"]` |

### aws_cloudwatch_event_rule.ecs_failure

Terraformリソース：`aws_cloudwatch_event_rule.ecs_failure`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-ecs-failure` |
| イベント発生元の抽出条件 | `event_pattern.source` | `["aws.ecs"]` |
| イベント種別の抽出条件 | `event_pattern.detail-type` | `["ECS Service Action"]` |
| 対象リソースの抽出条件 | `event_pattern.resources` | `[aws_ecs_service.admin.id]` |
| 対象API操作の抽出条件 | `event_pattern.detail.eventName` | `["SERVICE_TASK_START_IMPAIRED", "SERVICE_TASK_PLACEMENT_FAILURE", "SERVICE_TASK_CONFIGURATION_FAILURE", "SERVICE_DEPLOYMENT_FAILED"]` |

### aws_cloudwatch_event_rule.security_high

Terraformリソース：`aws_cloudwatch_event_rule.security_high`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| リソースの作成数・作成条件 | `count` | `var.enable_account_security ? 1 : 0` |
| 名前 | `name` | `portfolio-card-security-high` |
| イベント発生元の抽出条件 | `event_pattern.source` | `["aws.securityhub"]` |
| イベント種別の抽出条件 | `event_pattern.detail-type` | `["Security Hub Findings - Imported"]` |
| 検出結果の重大度の抽出条件 | `event_pattern.detail.findings.Severity.Label` | `["HIGH", "CRITICAL"]` |
| 検出結果の記録状態の抽出条件 | `event_pattern.detail.findings.RecordState` | `["ACTIVE"]` |
| 検出結果の対応状態の抽出条件 | `event_pattern.detail.findings.Workflow.Status` | `["NEW"]` |

### aws_cloudwatch_event_target.result

Terraformリソース：`aws_cloudwatch_event_target.result`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象EventBridgeルール名 | `rule` | `aws_cloudwatch_event_rule.result.name` |
| 対象リソースARN | `arn` | `aws_lambda_alias.transfer_result.arn` |
| 配信失敗時の退避先DLQ ARN | `dead_letter_config[0].arn` | `aws_sqs_queue.result_delivery_dlq.arn` |
| 最大追加再試行回数 | `retry_policy[0].maximum_retry_attempts` | `2` |
| イベントの最大保持時間（秒） | `retry_policy[0].maximum_event_age_in_seconds` | `3600` |

### aws_cloudwatch_event_target.ecs_failure

Terraformリソース：`aws_cloudwatch_event_target.ecs_failure`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象EventBridgeルール名 | `rule` | `aws_cloudwatch_event_rule.ecs_failure.name` |
| 対象リソースARN | `arn` | `aws_sns_topic.operations.arn` |

### aws_cloudwatch_event_target.security_high

Terraformリソース：`aws_cloudwatch_event_target.security_high`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| リソースの作成数・作成条件 | `count` | `var.enable_account_security ? 1 : 0` |
| 対象EventBridgeルール名 | `rule` | `aws_cloudwatch_event_rule.security_high[0].name` |
| 対象リソースARN | `arn` | `aws_sns_topic.operations.arn` |

Event busは未指定でdefaultを使用する。各event_patternは表の配列値・キーで一致条件を設定する。`enable_account_security=false`ではセキュリティ通知rule・targetは作成しない。

## 4. 入力・権限・通知

各Targetに`input`、`input_path`、`input_transformer`を設定せず、イベント全体を渡す。Security Hub通知も項目抽出・要約は行わず、選択条件に一致したイベントをSNSへ渡す。通知対象は`Severity.Label=HIGH/CRITICAL`、`RecordState=ACTIVE`、`Workflow.Status=NEW`。更新・再配信による重複通知は許容する。

結果反映LambdaのInvoke許可は`aws_lambda_permission.result`で対象rule ARNに限定する。結果配信DLQのSendMessage許可は`aws_sqs_queue_policy.delivery`で同じrule ARNに限定する。SNS通知の許可は[SNS詳細設計](15_AWS_SNS.md)に定める。ECS・Security Hub通知Targetには個別のretry_policy・DLQを明示設定しない。

結果反映では`detail.local-file-location`でbucket/keyを特定し、account・region・connector-id・operation・domain・prefix・ファイル名・status-codeの整合性を検証する。`transfer-id`はログ追跡に使用しDBへ保存しない。業務処理は[Lambda処理仕様](../02_アプリ/01_Lambda処理仕様.md)に定める。
