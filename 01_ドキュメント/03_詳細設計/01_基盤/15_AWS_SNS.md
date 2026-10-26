# SNS 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/monitoring.tf`、`02_資材/02_temporary/terraform/notifications.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. Topic・購読

### aws_sns_topic.operations

Terraformリソース：`aws_sns_topic.operations`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-operations` |
| 暗号化に使用するKMSキー | `kms_master_key_id` | `aws_kms_key.sns.arn` |

### aws_sns_topic_subscription.operations_email

Terraformリソース：`aws_sns_topic_subscription.operations_email`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| リソースの作成数・作成条件 | `count` | `nonsensitive(var.budget_email != "") ? 1 : 0` |
| 通知先SNSトピックARN | `topic_arn` | `aws_sns_topic.operations.arn` |
| 通信プロトコル | `protocol` | `email` |
| 通知先メールアドレス | `endpoint` | `var.budget_email` |

`budget_email`はstring・sensitive、既定値は空文字。空文字の場合は購読resourceを作成しない。現行ワークフローはNOTIFICATION_EMAILから設定する。Terraformのcountは`nonsensitive(var.budget_email != "") ? 1 : 0`とする。Topicのfifo_topicは未指定。

## 3. Topicポリシー

### aws_sns_topic_policy.operations

Terraformリソース：`aws_sns_topic_policy.operations`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象リソースARN | `arn` | `aws_sns_topic.operations.arn` |
| ポリシー言語のバージョン | `policy.Version` | `2012-10-17` |
| アクセスの許可・拒否 | `policy.Statement[0].Effect` | `Allow` |
| 操作を許可するAWSサービス | `policy.Statement[0].Principal.Service` | `["cloudwatch.amazonaws.com", "events.amazonaws.com"]` |
| 対象操作 | `policy.Statement[0].Action` | `SNS:Publish` |
| 対象リソース | `policy.Statement[0].Resource` | `aws_sns_topic.operations.arn` |
| 呼出元AWSアカウントの制限 | `policy.Statement[0].Condition.StringEquals.aws:SourceAccount` | `data.aws_caller_identity.current.account_id` |
| ポリシーステートメントの識別子 | `policy.Statement[0].Sid` | `AllowPortfolioPublish1` |
| アクセスの許可・拒否 | `policy.Statement[1].Effect` | `Allow` |
| 操作を許可するAWSサービス | `policy.Statement[1].Principal.Service` | `events.rds.amazonaws.com` |
| 対象操作 | `policy.Statement[1].Action` | `SNS:Publish` |
| 対象リソース | `policy.Statement[1].Resource` | `aws_sns_topic.operations.arn` |
| 呼出元AWSアカウントの制限 | `policy.Statement[1].Condition.StringEquals.aws:SourceAccount` | `data.aws_caller_identity.current.account_id` |
| ポリシーステートメントの識別子 | `policy.Statement[1].Sid` | `AllowPortfolioPublish2` |

`SourceAccount`で発行元アカウントを限定し、`SourceArn`による個別アラーム・rule制限は設定しない。

## 4. KMS鍵・Keyポリシー

### aws_kms_key.sns

Terraformリソース：`aws_kms_key.sns`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 説明 | `description` | `Portfolio temporary notification key` |
| KMSキー削除前の待機期間（日） | `deletion_window_in_days` | `7` |
| 暗号化キーの自動ローテーション | `enable_key_rotation` | `true` |
| ポリシー言語のバージョン | `policy.Version` | `2012-10-17` |
| アクセスの許可・拒否 | `policy.Statement[0].Effect` | `Allow` |
| 操作を許可するAWS主体 | `policy.Statement[0].Principal.AWS` | `arn:aws:iam::${data.aws_caller_identity.current.account_id}:root` |
| 対象操作 | `policy.Statement[0].Action` | `kms:*` |
| 対象リソース | `policy.Statement[0].Resource` | `*` |
| アクセスの許可・拒否 | `policy.Statement[1].Effect` | `Allow` |
| 操作を許可するAWSサービス | `policy.Statement[1].Principal.Service` | `["cloudwatch.amazonaws.com", "events.amazonaws.com"]` |
| 対象操作 | `policy.Statement[1].Action` | `["kms:Decrypt", "kms:GenerateDataKey*"]` |
| 対象リソース | `policy.Statement[1].Resource` | `*` |
| アクセスの許可・拒否 | `policy.Statement[2].Effect` | `Allow` |
| 操作を許可するAWSサービス | `policy.Statement[2].Principal.Service` | `events.rds.amazonaws.com` |
| 対象操作 | `policy.Statement[2].Action` | `["kms:Decrypt", "kms:GenerateDataKey*"]` |
| 対象リソース | `policy.Statement[2].Resource` | `*` |
| 呼出元AWSアカウントの制限 | `policy.Statement[2].Condition.StringEquals.aws:SourceAccount` | `data.aws_caller_identity.current.account_id` |

Key aliasは作成しない。root principalの管理権限と通知サービスの暗号化権限を区別する。CloudWatch・EventBridgeのKMS StatementにはSourceAccount/SourceArn条件を設定せず、SNS Topicポリシー側で発行元を制限する。RDS用KMS StatementにはSourceAccount条件を設定する。

## 5. 通知内容・受信確認

| 経路 | 通知内容 |
| --- | --- |
| CloudWatch Alarm → SNS | AWSのAlarm通知本文。FinalFailure・TransferFailed等を含む |
| ECS → EventBridge → SNS | ruleに一致したECSイベント全体 |
| Security Hub → EventBridge → SNS | ACTIVE・NEW・HIGH/CRITICALに一致したイベント全体 |
| RDS event subscription → SNS | RDSのイベント通知本文 |

EventBridge Targetにinput_transformerを設定しないため、通知を特定フィールドだけに要約する構成ではない。通知集約Lambdaは設けず、重複通知を許容する。アプリログ・通知用独自メトリクスに秘密値や社員情報本文を含めない。

SNSメール購読は保守担当者が確認リンクで有効化する。購読状態、SNS配信、実メール受信を別々に確認し、Topic再作成時は購読確認をやり直す。確認条件は[テスト仕様書](../../04_テスト/テスト仕様書.md)に定める。
