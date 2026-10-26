# SQS 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/messaging.tf`、`02_資材/02_temporary/terraform/lambda.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. キュー設定

### aws_sqs_queue.registration_dlq

Terraformリソース：`aws_sqs_queue.registration_dlq`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-registration-dlq` |
| メッセージ保持期間（秒） | `message_retention_seconds` | `1209600` |
| SQS管理キーによる保存時暗号化 | `sqs_managed_sse_enabled` | `true` |

### aws_sqs_queue.result_delivery_dlq

Terraformリソース：`aws_sqs_queue.result_delivery_dlq`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-result-delivery-dlq` |
| メッセージ保持期間（秒） | `message_retention_seconds` | `1209600` |
| SQS管理キーによる保存時暗号化 | `sqs_managed_sse_enabled` | `true` |

### aws_sqs_queue.result_execution_dlq

Terraformリソース：`aws_sqs_queue.result_execution_dlq`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-result-execution-dlq` |
| メッセージ保持期間（秒） | `message_retention_seconds` | `1209600` |
| SQS管理キーによる保存時暗号化 | `sqs_managed_sse_enabled` | `true` |

### aws_sqs_queue.schedule_delivery_dlq

Terraformリソース：`aws_sqs_queue.schedule_delivery_dlq`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-schedule-delivery-dlq` |
| メッセージ保持期間（秒） | `message_retention_seconds` | `1209600` |
| SQS管理キーによる保存時暗号化 | `sqs_managed_sse_enabled` | `true` |

### aws_sqs_queue.registration

Terraformリソース：`aws_sqs_queue.registration`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-registration` |
| 処理中メッセージの非表示時間（秒） | `visibility_timeout_seconds` | `180` |
| メッセージ保持期間（秒） | `message_retention_seconds` | `345600` |
| SQS管理キーによる保存時暗号化 | `sqs_managed_sse_enabled` | `true` |
| 失敗メッセージの退避先DLQ ARN | `redrive_policy.deadLetterTargetArn` | `aws_sqs_queue.registration_dlq.arn` |
| DLQ移動までの最大受信回数 | `redrive_policy.maxReceiveCount` | `3` |

`fifo_queue`、`receive_wait_time_seconds`、DLQ側の`visibility_timeout_seconds`、`redrive_allow_policy`はTerraformでは未指定。登録キューのみ可視性タイムアウトを180秒に設定する。DLQ側を300秒、キュー側のlong pollingを20秒に明示設定した構成ではない。全キューでSSE-SQSを有効化し、自動コンシューマは登録キューだけに設定する。

## 3. 登録イベントソース

### aws_lambda_event_source_mapping.registration

Terraformリソース：`aws_lambda_event_source_mapping.registration`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 起動元リソースARN | `event_source_arn` | `aws_sqs_queue.registration.arn` |
| 関数名・参照先 | `function_name` | `aws_lambda_alias.employee_register.arn` |
| 1回の起動で処理するメッセージ数 | `batch_size` | `1` |
| 部分失敗時の応答方式 | `function_response_types` | `["ReportBatchItemFailures"]` |
| 最大同時実行数 | `scaling_config[0].maximum_concurrency` | `5` |

`maximum_batching_window_in_seconds`は未指定。可視性180秒は登録Lambdaのtimeout 30秒の6倍とする。

| 処理結果 | 応答 |
| --- | --- |
| 成功 | `{"batchItemFailures": []}` |
| 失敗 | `{"batchItemFailures": [{"itemIdentifier": "<messageId>"}]}` |

失敗時は関数からDeleteMessageせず、可視性期限後の再配信と`maxReceiveCount=3`によって登録DLQへ隔離する。同じ社員番号の異内容も既存情報を変更せず、同じ失敗経路で隔離する。受信回数は厳密な実行回数保証ではない。

## 4. 配信DLQポリシー

### aws_sqs_queue_policy.delivery

Terraformリソース：`aws_sqs_queue_policy.delivery`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象キューURL | `queue_url` | `aws_sqs_queue.result_delivery_dlq.id` |
| ポリシー言語のバージョン | `policy.Version` | `2012-10-17` |
| アクセスの許可・拒否 | `policy.Statement[0].Effect` | `Allow` |
| 操作を許可するAWSサービス | `policy.Statement[0].Principal.Service` | `events.amazonaws.com` |
| 対象操作 | `policy.Statement[0].Action` | `sqs:SendMessage` |
| 対象リソース | `policy.Statement[0].Resource` | `aws_sqs_queue.result_delivery_dlq.arn` |
| 呼出元リソースARNの制限 | `policy.Statement[0].Condition.ArnEquals.aws:SourceArn` | `aws_cloudwatch_event_rule.result.arn` |

Scheduler配信DLQとLambda実行失敗保存先へのSendMessageは、それぞれ実行ロールのIAMポリシーで許可する。SQSの全キューにTLS必須Denyを設定する定義はない。

## 5. メッセージ形式

| 保存先 | Body |
| --- | --- |
| 登録キュー | `schema_version=1`、request_id、employee_id、employee_name、company_name、received_at（JST、ISO8601） |
| EventBridge DLQ | 元のTransferイベントJSON。配信失敗理由はMessageAttributes |
| Lambda実行失敗 | Lambda destination実行記録。元イベントは`requestPayload` |
| Scheduler DLQ | 配信失敗した起動入力と属性 |

登録入力は受付と同じ項目規則、`received_at`はoffset付き日時として登録側でも検証する。不正スキーマは再試行後DLQへ保存する。SQS本文・実行記録をログへ丸ごと出さない。

## 6. 監視・手動復旧

失敗保存先の`ApproximateNumberOfMessagesVisible >= 1`を1分・1/1で通知する。登録キューの最古メッセージ経過`>=600秒`を5分・2/2で通知する。欠測は`notBreaching`。

最終保存失敗はLambda `DestinationDeliveryFailures`、EventBridge `InvocationsFailedToBeSentToDlq`、Scheduler `InvocationsFailedToBeSentToDeadLetterCount`を別監視する。

保守処理は受信 → 同期処理 → 成功確認 → `DeleteMessage`の順とする。失敗時は削除しない。保持期限までに復旧する運用とし、無期限保存は保証しない。
