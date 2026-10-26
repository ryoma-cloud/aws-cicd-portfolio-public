# Budgets 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/01_persistent/cost_budget.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. 予算設定

Terraformリソース：`aws_budgets_budget.monthly_cost`

| 意味 | パラメータ | 設定値 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-monthly-cost` |
| 予算の管理対象 | `budget_type` | `COST` |
| 予算金額 | `limit_amount` | `30` |
| 予算金額の通貨 | `limit_unit` | `USD` |
| 予算の集計期間 | `time_unit` | `MONTHLY` |
| クレジットの費用集計への反映 | `cost_types[0].include_credit` | `false` |
| 返金の費用集計への反映 | `cost_types[0].include_refund` | `false` |
| 税金の費用集計への算入 | `cost_types[0].include_tax` | `true` |
| サポート料金の費用集計への算入 | `cost_types[0].include_support` | `true` |

## 3. 通知設定

| 意味 | パラメータ | 値 |
| --- | --- | --- |
| 通知する費用のしきい値 | `threshold` | `[10, 20, 30, 40]` |
| 通知しきい値の指定方式 | `threshold_type` | `ABSOLUTE_VALUE` |
| 通知判定に使用する費用種別 | `notification_type` | `ACTUAL` |
| しきい値との比較方法 | `comparison_operator` | `GREATER_THAN` |
| 費用通知先メールアドレス | `subscriber_email_addresses` | `[var.budget_email]` |
| 通知先メール変数の型 | `budget_email.type` | `string` |
| 通知先メール変数の機密情報指定 | `budget_email.sensitive` | `true` |
| 予算超過時の自動アクション | `budget action` | 設定なし |
| 費用集計の対象絞込み | `cost filter` | 設定なし（アカウント全体） |

30 USDは警戒ラインであり、料金を強制停止する上限ではない。実メールアドレスは記載せず、ワークフローのNOTIFICATION_EMAILから変数へ渡す。Aurora・ALB・Interface Endpoint・EC2/EIP・Transfer Family・セキュリティサービスの費用を含め、未使用時は一時環境を削除する。
