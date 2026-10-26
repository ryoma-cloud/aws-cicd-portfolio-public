# ECR 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/01_persistent/ecr.tf`、`02_資材/02_temporary/terraform/security.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. Repository・ライフサイクル

### aws_ecr_repository.admin_web

Terraformリソース：`aws_ecr_repository.admin_web`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-admin-web` |
| イメージタグの上書き可否 | `image_tag_mutability` | `MUTABLE` |
| イメージが存在するリポジトリの強制削除 | `force_delete` | `true` |
| イメージ登録時の脆弱性スキャン | `image_scanning_configuration[0].scan_on_push` | `true` |

### aws_ecr_lifecycle_policy.admin_web

Terraformリソース：`aws_ecr_lifecycle_policy.admin_web`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象ECRリポジトリ名 | `repository` | `aws_ecr_repository.admin_web.name` |
| イメージ削除ルールの優先順位 | `policy.rules[0].rulePriority` | `1` |
| 説明 | `policy.rules[0].description` | `Keep the latest 10 images` |
| 削除候補イメージのタグ状態 | `policy.rules[0].selection.tagStatus` | `any` |
| イメージ削除の判定方式 | `policy.rules[0].selection.countType` | `imageCountMoreThan` |
| 保持するイメージ数 | `policy.rules[0].selection.countNumber` | `10` |
| 保持条件を超えたイメージの処理方式 | `policy.rules[0].action.type` | `expire` |

リポジトリの暗号化設定はTerraformでは未指定。明示設定した項目とサービス既定の暗号化を区別する。`force_delete=true`は常設リポジトリを削除する際の値であり、一時環境の削除ではリポジトリ本体を削除しない。

## 3. イメージ指定

| 意味 | 項目 | 値 |
| --- | --- | --- |
| ECRリポジトリURI | `repository URI` | `<account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/portfolio-admin-web` |
| ビルド時のイメージタグ | `build tag` | `Git commit SHA（GITHUB_SHA）` |
| Web・DB変更用イメージ | `Web・DB変更用イメージ` | `<repository URI>@sha256:<64桁digest>` |
| コンテナイメージURIの入力検証 | `admin_image_uriの検証式` | `@sha256:[0-9a-f]{64}$` |

WebとDB変更用タスクで同じイメージを使用する。タグはMUTABLEだがデプロイ時はdigestを固定する。LambdaはZIP配布とする。外部レジストリからの実行時取得を必要とするpull-through cacheやforeign layerは使用しない。

## 4. 脆弱性検査

### aws_ecr_registry_scanning_configuration.portfolio

Terraformリソース：`aws_ecr_registry_scanning_configuration.portfolio`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| リソースの作成数・作成条件 | `count` | `var.enable_account_security ? 1 : 0` |
| ECRスキャンの種類 | `scan_type` | `ENHANCED` |
| イメージのスキャン頻度 | `rule[0].scan_frequency` | `CONTINUOUS_SCAN` |
| 対象リポジトリの絞込み条件 | `rule[0].repository_filter[0].filter` | `portfolio-admin-web` |
| 対象リポジトリの絞込み方式 | `rule[0].repository_filter[0].filter_type` | `WILDCARD` |

`enable_account_security=true`ではInspectorのENHANCED/CONTINUOUS_SCANを使用し、フィルタを`portfolio-admin-web`とする。Repository単位の`scan_on_push=true`とアカウントの検査設定を区別する。所見の通知・対応は[セキュリティ・秘密情報詳細設計](16_セキュリティ・秘密情報詳細設計.md)に定める。
