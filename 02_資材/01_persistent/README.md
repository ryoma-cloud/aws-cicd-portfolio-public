# 常設基盤の資材

一時環境の作成・削除を繰り返すための共通基盤をTerraformで管理する。

## 1. 管理する資材

| ファイル | 内容 |
| --- | --- |
| `vpc.tf`、`subnet.tf`、`internet_gateway.tf`、`route.tf` | VPC、2AZのPublic／Privateサブネット、インターネット接続とルーティング |
| `endpoints.tf` | PrivateサブネットからS3へ接続するGateway Endpoint |
| `ecr.tf` | Webアプリケーションのコンテナイメージ保管先と世代管理 |
| `logs.tf` | 常設側で管理するロググループと90日の保持設定 |
| `cost_budget.tf` | 月額30 USDの予算と、実績10・20・30・40 USD超過時のメール通知 |
| `security_evidence.tf` | AWS Configの証跡保管先、暗号化、公開防止、保存期間 |
| `iam_github.tf` | GitHub Actionsの既存IAMロールへ追加する構築用権限 |
| `state-policy.tf` | State保存先の保護設定に関する旧管理情報の引継ぎ |
| `portfolio_outputs.tf` | VPC、サブネット、ECR、ロググループの出力 |
| `backend.tf`、`provider.tf`、`versions.tf` | State保存先、リージョン、Terraform・Providerの条件 |

## 2. 一時環境との関係

常設基盤を先に作成し、一時環境は既存VPC、サブネット、S3接続経路、ECRなどを利用する。Interface Endpoint、業務用ロググループ、AWS Configの記録・評価設定は一時側で管理する。

一時環境を削除しても、このディレクトリで管理するリソースは残る。常設基盤も削除する場合は、一時環境を先に削除する。ECR内のイメージとConfig証跡保管先の内容は、常設基盤の削除時に削除される設定である。

## 3. 実行と入力

作成・削除は[ワークフローの操作手順](../../03_ワークフロー/01_ドキュメント/03_操作手順.md)に従う。Terraformの作業ディレクトリは本ディレクトリとし、Stateは一時環境と別のキーで保存する。

通知先はワークフローから`budget_email`へ渡す。State保存用S3、GitHub Actionsの接続用IAMロール、OIDC Providerは事前に用意する。接続用IAMロール本体は本ディレクトリの作成・削除対象に含めない。

全体の管理方針は[資材作成方針](../README.md)を参照する。
