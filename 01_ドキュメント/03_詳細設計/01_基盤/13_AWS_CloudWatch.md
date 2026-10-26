# CloudWatch 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/monitoring.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. ロググループ

| Terraformリソース | 名前（name） | ログ保持日数（retention_in_days） | 削除時のログ保持（skip_destroy） |
| --- | --- | --- | --- |
| `aws_cloudwatch_log_group.employee_intake` | `/aws/lambda/portfolio-card-employee-intake` | `90` | `false` |
| `aws_cloudwatch_log_group.employee_register` | `/aws/lambda/portfolio-card-employee-register` | `90` | `false` |
| `aws_cloudwatch_log_group.transfer_result` | `/aws/lambda/portfolio-card-transfer-result` | `90` | `false` |
| `aws_cloudwatch_log_group.resend` | `/aws/lambda/portfolio-card-resend` | `90` | `false` |
| `aws_cloudwatch_log_group.api` | `/aws/apigateway/portfolio-card-employee` | `90` | `false` |
| `aws_cloudwatch_log_group.web` | `/ecs/portfolio-card-web` | `90` | `false` |
| `aws_cloudwatch_log_group.id_mock` | `/aws/lambda/portfolio-id-system-mock` | `90` | `false` |
| `aws_cloudwatch_log_group.request_batch` | `/aws/lambda/portfolio-card-request-batch` | `90` | `false` |
| `aws_cloudwatch_log_group.rds_postgresql` | `/aws/rds/cluster/portfolio-card-db/postgresql` | `90` | `false` |
| `aws_cloudwatch_log_group.transfer_connector` | `/aws/transfer/${awscc_transfer_connector.vendor.connector_id}` | `90` | `false` |

各ロググループのタグは`Project=aws-cicd-portfolio`、`ManagedBy=Terraform`、`Lifecycle=temporary`。KMS keyは未指定とし、CloudWatch Logs標準の保存時暗号化を使用する。一時環境の削除時にロググループも削除し、90日保持は環境存続中に適用する。

## 3. アプリログ・独自メトリクス

| 意味 | 項目 | 値 |
| --- | --- | --- |
| 形式 | `形式` | `JSON 1行` |
| 日時 | `日時` | `Asia/Tokyo` |
| 独自メトリクスの名前空間 | `EMF Namespace` | `Portfolio/Card` |
| メトリクスの分類軸 | `Dimensions` | `["Process"]` |
| 出力するメトリクス名一覧 | `Metrics` | `["FinalFailure", "TransferFailed"]` |
| メトリクスの単位 | `Unit` | `Count` |

アプリログはtimestamp、level、process、stage、outcome、aws_request_id、request_id、employee_idまたはfilename、duration_ms、error_codeを記録する。未取得値はnullとし、氏名・会社名・SQLパラメータ・Secret・署名値・CSV本文は出力しない。社員番号・ファイル名はメトリクスdimensionに使用しない。

## 4. アラーム共通設定

| 意味 | パラメータ | 値 |
| --- | --- | --- |
| 異常検知時の通知先ARN | `alarm_actions` | `["aws_sns_topic.operations.arn"]` |
| 正常復帰時の通知先 | `ok_actions` | 未指定（OK通知なし） |
| データ不足時の通知先 | `insufficient_data_actions` | 未指定 |
| 監視データ欠損時の扱い | `treat_missing_data` | `notBreaching` |

以下のperiod単位は秒。Mはdatapoints_to_alarm、Nはevaluation_periods。Mを明示しないリソースは「未指定」と記載する。

| リソース末尾・アラーム名（リソース末尾 / alarm_name） | 名前空間・メトリクス名（namespace / metric_name） | 統計方法（statistic） | 比較演算子・しきい値（比較演算子 / threshold） | 評価間隔（秒）・異常判定数・評価期間数（period / M / N） |
| --- | --- | --- | --- | --- |
| `registration_dlq` / `portfolio-card-registration_dlq` | `AWS/SQS` / `ApproximateNumberOfMessagesVisible` | `Maximum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `result_delivery_dlq` / `portfolio-card-result_delivery_dlq` | `AWS/SQS` / `ApproximateNumberOfMessagesVisible` | `Maximum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `result_execution_dlq` / `portfolio-card-result_execution_dlq` | `AWS/SQS` / `ApproximateNumberOfMessagesVisible` | `Maximum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `schedule_delivery_dlq` / `portfolio-card-schedule_delivery_dlq` | `AWS/SQS` / `ApproximateNumberOfMessagesVisible` | `Maximum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `employee_intake_final` / `portfolio-card-employee_intake-final` | `Portfolio/Card` / `FinalFailure` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `request_batch_final` / `portfolio-card-request_batch-final` | `Portfolio/Card` / `FinalFailure` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `resend_final` / `portfolio-card-resend-final` | `Portfolio/Card` / `FinalFailure` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `transfer_failed` / `portfolio-card-transfer-failed` | `Portfolio/Card` / `TransferFailed` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `employee_intake_errors` / `portfolio-card-employee_intake-errors` | `AWS/Lambda` / `Errors` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `request_batch_errors` / `portfolio-card-request_batch-errors` | `AWS/Lambda` / `Errors` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `resend_errors` / `portfolio-card-resend-errors` | `AWS/Lambda` / `Errors` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `AsyncEventsDropped` / `portfolio-card-AsyncEventsDropped` | `AWS/Lambda` / `AsyncEventsDropped` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `DestinationDeliveryFailures` / `portfolio-card-DestinationDeliveryFailures` | `AWS/Lambda` / `DestinationDeliveryFailures` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |
| `registration_age` / `portfolio-card-registration-age` | `AWS/SQS` / `ApproximateAgeOfOldestMessage` | `Maximum` | `GreaterThanOrEqualToThreshold` / `600` | `300` / `2` / `2` |
| `employee_intake_throttles` / `portfolio-card-employee-intake-throttles` | `AWS/Lambda` / `Throttles` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `300` / `2` / `2` |
| `employee_register_throttles` / `portfolio-card-employee-register-throttles` | `AWS/Lambda` / `Throttles` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `300` / `2` / `2` |
| `request_batch_throttles` / `portfolio-card-request-batch-throttles` | `AWS/Lambda` / `Throttles` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `300` / `2` / `2` |
| `transfer_result_throttles` / `portfolio-card-transfer-result-throttles` | `AWS/Lambda` / `Throttles` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `300` / `2` / `2` |
| `resend_throttles` / `portfolio-card-resend-throttles` | `AWS/Lambda` / `Throttles` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `300` / `2` / `2` |
| `result_dlq_delivery_failure` / `portfolio-card-result-dlq-delivery-failure` | `AWS/Events` / `InvocationsFailedToBeSentToDlq` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `1` / `1` |
| `scheduler_dlq_delivery_failure` / `portfolio-card-scheduler-dlq-delivery-failure` | `AWS/Scheduler` / `InvocationsFailedToBeSentToDeadLetterCount` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `1` / `1` |
| `alb_unhealthy` / `portfolio-card-alb-unhealthy` | `AWS/ApplicationELB` / `UnHealthyHostCount` | `Maximum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `3` / `3` |
| `alb_target_5xx` / `portfolio-card-alb-target-5xx` | `AWS/ApplicationELB` / `HTTPCode_Target_5XX_Count` | `Sum` | `GreaterThanOrEqualToThreshold` / `5` | `60` / `2` / `2` |
| `instance1_cpu` / `portfolio-card-instance1-cpu` | `AWS/RDS` / `CPUUtilization` | `Average` | `GreaterThanOrEqualToThreshold` / `80` | `300` / `3` / `3` |
| `instance1_memory` / `portfolio-card-instance1-memory` | `AWS/RDS` / `FreeableMemory` | `Minimum` | `LessThanThreshold` / `268435456` | `300` / `3` / `3` |
| `instance1_connections` / `portfolio-card-instance1-connections` | `AWS/RDS` / `DatabaseConnections` | `Maximum` | `GreaterThanOrEqualToThreshold` / `40` | `300` / `3` / `3` |
| `instance2_cpu` / `portfolio-card-instance2-cpu` | `AWS/RDS` / `CPUUtilization` | `Average` | `GreaterThanOrEqualToThreshold` / `80` | `300` / `3` / `3` |
| `instance2_memory` / `portfolio-card-instance2-memory` | `AWS/RDS` / `FreeableMemory` | `Minimum` | `LessThanThreshold` / `268435456` | `300` / `3` / `3` |
| `instance2_connections` / `portfolio-card-instance2-connections` | `AWS/RDS` / `DatabaseConnections` | `Maximum` | `GreaterThanOrEqualToThreshold` / `40` | `300` / `3` / `3` |
| `daily_check_final` / `portfolio-card-daily-check-final` | `Portfolio/Card` / `FinalFailure` | `Sum` | `GreaterThanOrEqualToThreshold` / `1` | `60` / `未指定` / `1` |

### dimension

| リソース末尾 | 監視対象の分類軸（dimensions） |
| --- | --- |
| `registration_dlq` | `{"QueueName": aws_sqs_queue.registration_dlq.name}` |
| `result_delivery_dlq` | `{"QueueName": aws_sqs_queue.result_delivery_dlq.name}` |
| `result_execution_dlq` | `{"QueueName": aws_sqs_queue.result_execution_dlq.name}` |
| `schedule_delivery_dlq` | `{"QueueName": aws_sqs_queue.schedule_delivery_dlq.name}` |
| `employee_intake_final` | `{"Process": "employee-intake"}` |
| `request_batch_final` | `{"Process": "request-batch"}` |
| `resend_final` | `{"Process": "resend"}` |
| `transfer_failed` | `{"Process": "transfer-result"}` |
| `employee_intake_errors` | `{"FunctionName": aws_lambda_function.employee_intake.function_name}` |
| `request_batch_errors` | `{"FunctionName": aws_lambda_function.request_batch.function_name}` |
| `resend_errors` | `{"FunctionName": aws_lambda_function.resend.function_name}` |
| `AsyncEventsDropped` | `{"FunctionName": aws_lambda_function.transfer_result.function_name}` |
| `DestinationDeliveryFailures` | `{"FunctionName": aws_lambda_function.transfer_result.function_name}` |
| `registration_age` | `{"QueueName": aws_sqs_queue.registration.name}` |
| `employee_intake_throttles` | `{"FunctionName": aws_lambda_function.employee_intake.function_name}` |
| `employee_register_throttles` | `{"FunctionName": aws_lambda_function.employee_register.function_name}` |
| `request_batch_throttles` | `{"FunctionName": aws_lambda_function.request_batch.function_name}` |
| `transfer_result_throttles` | `{"FunctionName": aws_lambda_function.transfer_result.function_name}` |
| `resend_throttles` | `{"FunctionName": aws_lambda_function.resend.function_name}` |
| `result_dlq_delivery_failure` | `{"RuleName": aws_cloudwatch_event_rule.result.name}` |
| `scheduler_dlq_delivery_failure` | `{"ScheduleGroup": aws_scheduler_schedule_group.daily.name}` |
| `alb_unhealthy` | `{"LoadBalancer": aws_lb.admin.arn_suffix, "TargetGroup": aws_lb_target_group.admin.arn_suffix}` |
| `alb_target_5xx` | `{"LoadBalancer": aws_lb.admin.arn_suffix}` |
| `instance1_cpu` | `{"DBInstanceIdentifier": aws_rds_cluster_instance.instance1.identifier}` |
| `instance1_memory` | `{"DBInstanceIdentifier": aws_rds_cluster_instance.instance1.identifier}` |
| `instance1_connections` | `{"DBInstanceIdentifier": aws_rds_cluster_instance.instance1.identifier}` |
| `instance2_cpu` | `{"DBInstanceIdentifier": aws_rds_cluster_instance.instance2.identifier}` |
| `instance2_memory` | `{"DBInstanceIdentifier": aws_rds_cluster_instance.instance2.identifier}` |
| `instance2_connections` | `{"DBInstanceIdentifier": aws_rds_cluster_instance.instance2.identifier}` |
| `daily_check_final` | `{"Process": "daily-check"}` |

## 5. RDSイベント通知

### aws_db_event_subscription.cluster

Terraformリソース：`aws_db_event_subscription.cluster`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-db-cluster` |
| RDSイベントの通知先SNSトピックARN | `sns_topic` | `aws_sns_topic.operations.arn` |
| RDS通知対象リソースの種類 | `source_type` | `db-cluster` |
| RDS通知対象リソースの識別子一覧 | `source_ids` | `[aws_rds_cluster.portfolio.id]` |
| RDS通知対象イベントの分類 | `event_categories` | `["failover", "failure"]` |
| 設定の有効化 | `enabled` | `true` |

### aws_db_event_subscription.instances

Terraformリソース：`aws_db_event_subscription.instances`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-db-instances` |
| RDSイベントの通知先SNSトピックARN | `sns_topic` | `aws_sns_topic.operations.arn` |
| RDS通知対象リソースの種類 | `source_type` | `db-instance` |
| RDS通知対象リソースの識別子一覧 | `source_ids` | `[aws_rds_cluster_instance.instance1.id, aws_rds_cluster_instance.instance2.id]` |
| RDS通知対象イベントの分類 | `event_categories` | `["failure"]` |
| 設定の有効化 | `enabled` | `true` |

ECSのService Action通知条件は[EventBridge詳細設計](10_AWS_EventBridge.md)、SNS・KMS設定は[SNS詳細設計](15_AWS_SNS.md)に定める。

## 6. 検知・通知の運用

定例の手動日次点検、月次報告機構は追加しない。03:00 JSTの自動完了確認は当日の完了記録と前日以前の未処理件数を照合する。障害通知を起点に保守担当者が調査する。

入力不正は業務エラーとして障害通知しない。自動再試行の途中失敗は原則として発報せず、最終失敗・DLQ滞留・配信不能を通知する。

送信成功がDB上で確定しているファイルに対し、古い失敗結果を再受信した場合は状態を後退させず、`ignored_after_success=true`を正常ログへ記録して`TransferFailed`を再発報しない。DB状態を確認できずS3変更を保留した処理は再試行し、最終失敗時は既存の失敗保存キューで検知する。

ALARMへの遷移で通知する。結果反映の途中Errorsでは通常通知せず、最終失敗保存・配信失敗を監視する。欠測は正常稼働の証明とは扱わず、構築後に実データポイントとdimensionを確認する。ECS自動増減用アラームはAWS管理とし、本書のSNS障害通知アラームとは分ける。
