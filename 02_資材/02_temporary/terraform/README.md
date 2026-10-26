# 一時環境 Terraform

このディレクトリを一時環境のTerraform作業ディレクトリとする。

- `backend.tf`: S3 backend
- `provider.tf`: AWS provider（Cloud Controlの接続設定はtransfer.tf）
- `versions.tf`: Terraform / Providerバージョン制約
- `core.tf`: Data Source・locals
- `network.tf`: Security Group・VPC Endpoint
- `storage.tf`: S3
- `messaging.tf`: SQS / DLQ
- `database.tf`: Aurora PostgreSQL
- `secrets.tf`: Secrets Manager
- `iam.tf`: IAMロール・AWS管理ポリシー／カスタマー管理ポリシー
- `transfer.tf`: Transfer Family Connector・カード発行業者モックEC2
- `lambda.tf`: Lambda
- `api-gateway.tf`: API Gateway
- `scheduler-eventbridge.tf`: EventBridge / Scheduler
- `ecs.tf`: ECS / Fargate
- `alb.tf`: ALB・Target Group・Listener
- `monitoring.tf`: CloudWatchログ・メトリクス・アラーム
- `security.tf`: Config・Security Hub・GuardDuty・Inspector
- `variables.tf` / `outputs.tf`: 変数・出力
- `web-autoscaling.tf`: Fargate WebサービスのApplication Auto Scaling
- `s3-lifecycle.tf`: S3ライフサイクル
- `notifications.tf`: SNSメール購読
- `security-controls.tf`: Security Hub評価範囲・GuardDuty追加機能
- `connector-migration.tf`: 既存Connector・SFTPルールの管理引継ぎ
- `build/`: Lambda ZIPの生成先。生成物のためGit管理対象外

アプリケーションコードは`../app`、Lambdaエントリポイントは`../lambda`、構築・運用ツールはルートの`03_ワークフロー/02_資材/tools`で管理する。

## 構築入力

| 変数 | 用途・初期値 |
| --- | --- |
| `admin_image_uri` | Web・DB更新用コンテナ。digest付きのECR URIを指定する |
| `aurora_engine_version` | Aurora PostgreSQLのバージョン。既定値は`16.15` |
| `sftp_host_keys` | SFTP接続先のホスト公開鍵。構築処理が実際の鍵を取得して設定する |
| `web_desired_count` | 初回準備は0、準備完了後は2～4。運用中の台数は自動増減で管理する |
| `enable_reserved_concurrency` | Lambdaの予約済み同時実行数を設定する。既定値はtrue |
| `enable_account_security` | アカウント・リージョン単位のセキュリティ設定を管理する。既定値はfalse |
| `enable_daily_schedule` | 日次処理と完了確認のスケジュールを有効にする。既定値はfalse |
| `budget_email` | SNSのメール通知先。ワークフローから渡す |

通常のワークフローは、予約済み同時実行数とセキュリティ設定を有効にし、日次スケジュールは既存状態を引き継ぐ。Terraform変数の既定値と、ワークフローから渡す値を区別する。

セキュリティ設定は適用前に既存設定の管理状況を確認し、他の環境と共用する設定を無断で取り込まない。既存Connectorの管理引継ぎ用変数は`connector-migration.tf`に定義するが、通常の構築処理は旧管理情報を検出すると停止するため、移行は別途実施する。

実行順序と確認方法は[一時環境の資材](../README.md)と[操作手順](../../../03_ワークフロー/01_ドキュメント/03_操作手順.md)を参照する。
