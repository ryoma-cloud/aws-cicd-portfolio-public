# Transfer Family 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/transfer.tf`、`02_資材/02_temporary/terraform/core.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. Connector

### awscc_transfer_connector.vendor

Terraformリソース：`awscc_transfer_connector.vendor`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| SFTP転送用のアクセスロール | `access_role` | `aws_iam_role.transfer.arn` |
| SFTP接続先URL | `url` | `sftp://${aws_eip.vendor.public_ip}:22` |
| SFTP暗号設定のセキュリティポリシー | `security_policy_name` | `TransferSFTPConnectorSecurityPolicy-2024-03` |
| ログ出力用ロール | `logging_role` | `aws_iam_role.transfer_logging.arn` |
| SFTP認証情報のSecret ARN | `sftp_config.user_secret_id` | `aws_secretsmanager_secret.sftp.arn` |
| 接続先の信頼済みホスト公開鍵 | `sftp_config.trusted_host_keys` | `var.sftp_host_keys` |
| 最大同時接続数 | `sftp_config.max_concurrent_connections` | `1` |

egress方式はTerraformでは明示指定せず、サービス管理の出口IPv4を`service_managed_egress_ip_addresses`から取得する。`sftp_host_keys`の既定値は空配列とし、apply前にSFTPサーバの実ホスト公開鍵を設定する。初回plan専用の仮鍵を運用に使用しない。

## 3. 対向SFTPサーバ・EIP

カード発行業者のSFTPサーバは、対向システムを再現するモックとしてEC2上に構築する。

### aws_instance.vendor

Terraformリソース：`aws_instance.vendor`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| OSイメージID | `ami` | `data.aws_ssm_parameter.ami.value` |
| EC2インスタンスタイプ | `instance_type` | `t3.micro` |
| 配置先サブネットID | `subnet_id` | `sort(data.aws_subnets.public.ids)[0]` |
| パブリックIPの割当 | `associate_public_ip_address` | `true` |
| 適用するセキュリティグループID一覧 | `vpc_security_group_ids` | `[aws_security_group.vendor.id]` |
| EC2に付与するインスタンスプロファイル | `iam_instance_profile` | `aws_iam_instance_profile.vendor.name` |
| メタデータ取得時のIMDSv2トークン要否 | `metadata_options[0].http_tokens` | `required` |
| ルートボリュームの暗号化 | `root_block_device[0].encrypted` | `true` |
| ルートボリュームの種類 | `root_block_device[0].volume_type` | `gp3` |
| EC2終了時のルートボリューム削除 | `root_block_device[0].delete_on_termination` | `true` |

### aws_eip.vendor

Terraformリソース：`aws_eip.vendor`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| Elastic IPの利用領域 | `domain` | `vpc` |
| Elastic IPの関連付け先EC2 | `instance` | `aws_instance.vendor.id` |

### aws_security_group_rule.vendor_sftp

Terraformリソース：`aws_security_group_rule.vendor_sftp`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 種別 | `type` | `ingress` |
| ルールを設定するセキュリティグループID | `security_group_id` | `aws_security_group.vendor.id` |
| 通信プロトコル | `protocol` | `tcp` |
| 許可するポート範囲の開始 | `from_port` | `22` |
| 許可するポート範囲の終了 | `to_port` | `22` |
| 許可するIPアドレス範囲 | `cidr_blocks` | `${[for ip in awscc_transfer_connector.vendor.service_managed_egress_ip_addresses : "${ip}/32"]}` |
| 説明 | `description` | `portfolio-connector` |

| 意味 | 参照値 | 設定 |
| --- | --- | --- |
| AMIの取得元SSMパラメータ名 | `data.aws_ssm_parameter.ami.name` | `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` |
| SFTP送信先ディレクトリ | `REMOTE_DIRECTORY` | `/inbox` |

## 4. 送信API

| 意味 | 引数・SDK設定 | 値 |
| --- | --- | --- |
| 呼び出すAPI | `API` | `StartFileTransfer` |
| 転送に使用するコネクタID | `ConnectorId` | `awscc_transfer_connector.vendor.connector_id` |
| 転送元S3ファイルパス一覧 | `SendFilePaths` | `["/<bucket>/transfer/<file> または /<bucket>/failed/<file>"]` |
| SFTP送信先ディレクトリ | `RemoteDirectoryPath` | `/inbox` |
| SDKの再試行方式 | `retries.mode` | `standard` |
| 初回を含む最大試行回数 | `total_max_attempts` | `1` |

1ファイル1回で要求する。TransferIdは要求受理の記録であり、完了判定には使用しない。Completed/FailedイベントをEventBridgeで受け、DB・S3へ反映する。失敗ファイルはfailed/に保持し、原因解消後に同名・同内容で手動再送する。送信後renameおよび自動全件再送は行わない。

## 5. 権限・ログ

access_roleとlogging_roleは別ロールとし、具体的な許可操作は[IAM詳細設計](02_AWS_IAM.md)に定める。ロググループは`/aws/transfer/<connector-id>`、保持90日。設定変更はTerraformで行い、構築プログラムからUpdateConnectorによる補修は行わない。

SFTPユーザ・鍵・sshdの設定は[カード発行業者モック](../../11_対向システム/02_カード発行会社/カード発行業者モック.md)に定める。秘密鍵はSecretへ保存し、Terraform stateへ保存しない。
