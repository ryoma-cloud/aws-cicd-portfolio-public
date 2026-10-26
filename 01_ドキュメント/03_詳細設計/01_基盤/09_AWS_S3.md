# S3 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/storage.tf`、`02_資材/02_temporary/terraform/s3-lifecycle.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. バケット・暗号化・ポリシー・ライフサイクル

### aws_s3_bucket.card_exchange

Terraformリソース：`aws_s3_bucket.card_exchange`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| S3バケット名・参照先 | `bucket` | `portfolio-card-exchange-${data.aws_caller_identity.current.account_id}-ap-northeast-1` |
| バケット削除時のオブジェクト一括削除 | `force_destroy` | `true` |

### aws_s3_bucket_public_access_block.card_exchange

Terraformリソース：`aws_s3_bucket_public_access_block.card_exchange`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| S3バケット名・参照先 | `bucket` | `aws_s3_bucket.card_exchange.id` |
| 公開ACLの設定を禁止 | `block_public_acls` | `true` |
| 公開バケットポリシーの設定を禁止 | `block_public_policy` | `true` |
| 公開ACLの無効化 | `ignore_public_acls` | `true` |
| 公開ポリシーによるアクセスの制限 | `restrict_public_buckets` | `true` |

### aws_s3_bucket_server_side_encryption_configuration.card_exchange

Terraformリソース：`aws_s3_bucket_server_side_encryption_configuration.card_exchange`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| S3バケット名・参照先 | `bucket` | `aws_s3_bucket.card_exchange.id` |
| 保存時暗号化の方式 | `rule[0].apply_server_side_encryption_by_default[0].sse_algorithm` | `AES256` |

### aws_s3_bucket_versioning.card_exchange

Terraformリソース：`aws_s3_bucket_versioning.card_exchange`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| S3バケット名・参照先 | `bucket` | `aws_s3_bucket.card_exchange.id` |
| S3バージョニングの有効状態 | `versioning_configuration[0].status` | `Enabled` |

### aws_s3_bucket_policy.tls

Terraformリソース：`aws_s3_bucket_policy.tls`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| S3バケット名・参照先 | `bucket` | `aws_s3_bucket.card_exchange.id` |
| ポリシー言語のバージョン | `policy.Version` | `2012-10-17` |
| アクセスの許可・拒否 | `policy.Statement[0].Effect` | `Deny` |
| 操作主体 | `policy.Statement[0].Principal` | `*` |
| 対象操作 | `policy.Statement[0].Action` | `s3:*` |
| 対象リソース | `policy.Statement[0].Resource` | `[aws_s3_bucket.card_exchange.arn, "${aws_s3_bucket.card_exchange.arn}/*"]` |
| HTTPS通信の条件 | `policy.Statement[0].Condition.Bool.aws:SecureTransport` | `false` |

### aws_s3_bucket_lifecycle_configuration.card_exchange

Terraformリソース：`aws_s3_bucket_lifecycle_configuration.card_exchange`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| S3バケット名・参照先 | `bucket` | `aws_s3_bucket.card_exchange.id` |
| 識別子 | `rule[0].id` | `expire-noncurrent-versions` |
| ライフサイクルルールの有効状態 | `rule[0].status` | `Enabled` |
| ライフサイクル適用対象の絞込み条件 | `rule[0].filter[0]` | `{}` |
| 旧バージョンの保持期間（日） | `rule[0].noncurrent_version_expiration[0].noncurrent_days` | `30` |

Object OwnershipはTerraformでは未指定であり、`BucketOwnerEnforced`を明示設定した定義ではない。S3イベント通知と現行版のexpiration、未完了multipart upload中断ルールは設定しない。

## 3. Prefix・保持

| S3オブジェクトの接頭辞（prefix） | 用途 | 自動削除 |
| --- | --- | --- |
| transfer/ | 初回送信対象 | 現行版は削除しない |
| failed/ | 失敗・手動再送対象 | 現行版は削除しない |
| success/ | 送信成功 | 現行版は削除しない |
| daily/ | 当日日次処理の完了記録（YYYYMMDD.json） | 現行版は削除しない |
| 全prefixの非現行版 | 誤操作復旧 | 非現行化後30日 |

送信済みを含め、現行ファイルは一時環境が存続する間は保持する。保持期限判定用のタグや独自削除プログラムは追加しない。非現行版の復元が必要な障害は30日以内に対応する。環境を意図的に削除する場合は、force_destroyにより全versionを削除する。

CSVは単一Putで保存するため、未完了multipart uploadの自動中断ルールは設けない。大容量ファイル連携やmultipart uploadを採用する場合に再検討する。

## 4. ファイル操作

CSV仕様・ファイル名は[DB・ファイル詳細設計](../02_アプリ/02_DB・ファイル詳細設計.md)を参照する。

新規PutObjectは`IfNoneMatch=*`で既存名を上書きせず、単一Putで完成バイト列だけ保存する。`Content-Type=text/csv; charset=utf-8`、`Metadata.sha256`に生成バイト列のSHA-256を付ける。

配置変更はCopyObject → 内容確認 → DeleteObjectの順とする。再実行時は元と移動先の存在・内容を確認する。ETagをSHA-256とみなさず、GetObjectで取得した本文からSHA-256を計算してmetadataと照合する。Versioning有効バケットでのDeleteは削除マーカーを作成する。通常処理は履歴versionを直接操作しない。

移動先が既に存在する場合は、同内容を確認して元だけ削除する。コピー後はGetObjectで移動先を再取得し、本文とSHA-256が元と一致した場合だけ元を削除する。AccessDeniedを「存在しない」に読み替えない。

CSVは完成バイト列を単一Putで保存する。SFTP送信後の一時ファイルrenameは使用しない。

## 5. 環境削除

`force_destroy=true`により一時環境削除時に全versionを削除する。再構築時は同じTerraform定義からVersioning・ライフサイクルを作成し、設定を確認する。
