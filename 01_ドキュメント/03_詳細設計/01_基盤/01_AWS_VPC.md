# VPC 詳細設計

## 1. 設計概要

[基盤・非機能基本設計](../../02_基本設計/06_基盤・非機能基本設計.md)に従い、公開入口をPublic Subnet、業務処理・DB・Interface VPC EndpointをPrivate Subnetへ配置する。Private Subnetにはインターネット向けのデフォルトルートを設定せず、AWSサービスへの通信にVPC Endpointを使用する。

| 管理区分 | 対象 | Terraform配置先 |
| --- | --- | --- |
| 常設 | VPC、Subnet、Internet Gateway、ルートテーブル、S3 Gateway Endpoint | `02_資材/01_persistent/` |
| 一時 | 業務用SG、Interface VPC Endpoint | `02_資材/02_temporary/terraform/network.tf` |
| 一時 | カード発行業者のEC2・EIP・SFTP受信ルール | `02_資材/02_temporary/terraform/transfer.tf` |

本書の`<account-id>`は`data.aws_caller_identity.current.account_id`を示す。VPC ID、Subnet ID、SG ID、Endpoint ID等はTerraformで取得・参照し、固定値を設定しない。

## 2. VPC

| 意味 | 設定項目 | 設定値 |
| --- | --- | --- |
| 利用リージョン | Region | `ap-northeast-1` |
| Terraformリソース | Terraformリソース | `aws_vpc.portfolio` |
| Nameタグ | Nameタグ | `portfolio-vpc` |
| VPCのIPv4アドレス範囲 | `cidr_block` | `10.20.0.0/16` |
| VPC内DNS名前解決の有効化 | `enable_dns_support` | `true` |
| DNSホスト名の有効化 | `enable_dns_hostnames` | `true` |
| IPv6アドレス範囲の割当 | IPv6 CIDR | 割当なし |
| Private Subnetから外部への接続用ゲートウェイ | NAT Gateway | 作成しない |
| サブネット境界の通信制御 | NACL | デフォルトNACLを使用。独自ルールは作成しない |

### 2.1 タグ

VPC、Subnet、Internet Gateway、ルートテーブルには以下を設定する。Nameタグは各節の値を使用する。

| 意味 | キー | 値 |
| --- | --- | --- |
| プロジェクト識別タグ | `Project` | `aws-cicd-portfolio` |
| リソース管理方法のタグ | `ManagedBy` | `Terraform` |
| 環境識別タグ | `Environment` | `dev` |

## 3. Subnet

| Terraformリソース | Nameタグ | AZ | CIDR | 起動時のパブリックIP自動割当（`map_public_ip_on_launch`） | Tierタグ |
| --- | --- | --- | --- | --- | --- |
| `aws_subnet.public["a"]` | `portfolio-public-a` | `ap-northeast-1a` | `10.20.1.0/24` | `false` | `public` |
| `aws_subnet.public["c"]` | `portfolio-public-c` | `ap-northeast-1c` | `10.20.2.0/24` | `false` | `public` |
| `aws_subnet.private["a"]` | `portfolio-private-a` | `ap-northeast-1a` | `10.20.11.0/24` | `false` | `private` |
| `aws_subnet.private["c"]` | `portfolio-private-c` | `ap-northeast-1c` | `10.20.12.0/24` | `false` | `private` |

以降、各SubnetをPublic-a、Public-c、Private-a、Private-cと記載する。

| 配置先 | 対象 |
| --- | --- |
| Public-a・Public-c | ALB |
| Public Subnetのいずれか1個 | カード発行業者のSFTPサーバ（EC2） |
| Private-a・Private-c | ECS Fargate、VPC接続Lambda、Aurora、Interface VPC Endpoint |

カード発行業者のSFTPサーバは、外部システムを再現するモックとしてEC2上に構築する。配置先Subnetは`sort(data.aws_subnets.public.ids)[0]`で選択する。EC2には`associate_public_ip_address=true`を設定し、`aws_eip.vendor`を関連付ける。Subnet単位のPublic IP自動付与は無効とする。

ECS Fargateには`assign_public_ip=false`を設定する。

## 4. Internet Gateway・ルーティング

### 4.1 Internet Gateway

| 意味 | 設定項目 | 設定値 |
| --- | --- | --- |
| Terraformリソース | Terraformリソース | `aws_internet_gateway.portfolio` |
| Nameタグ | Nameタグ | `portfolio-igw` |
| 接続先 | 接続先 | `aws_vpc.portfolio.id` |

### 4.2 ルートテーブル

Public用・Private用を各1個作成し、それぞれ2AZで共用する。

| Terraformリソース | Nameタグ | 関連付けSubnet |
| --- | --- | --- |
| `aws_route_table.public` | `portfolio-public-rt` | Public-a、Public-c |
| `aws_route_table.private` | `portfolio-private-rt` | Private-a、Private-c |

| ルートテーブル | 宛先 | ターゲット |
| --- | --- | --- |
| Public | `10.20.0.0/16` | `local` |
| Public | `0.0.0.0/0` | `aws_internet_gateway.portfolio.id` |
| Private | `10.20.0.0/16` | `local` |
| Private | 東京リージョンのS3管理prefix list | `aws_vpc_endpoint.s3.id` |

`local`ルートはVPC作成時の自動生成を使用する。Private用ルートテーブルには`0.0.0.0/0`を設定しない。

## 5. VPC Endpoint

### 5.1 S3 Gateway Endpoint

| 意味 | 設定項目 | 設定値 |
| --- | --- | --- |
| Terraformリソース | Terraformリソース | `aws_vpc_endpoint.s3` |
| 接続するAWSサービス名 | `service_name` | `com.amazonaws.ap-northeast-1.s3` |
| VPCエンドポイントの方式 | `vpc_endpoint_type` | `Gateway` |
| 所属VPC ID | `vpc_id` | `aws_vpc.portfolio.id` |
| 関連付けるルートテーブルID一覧 | `route_table_ids` | `[aws_route_table.private.id]` |
| エンドポイントへのセキュリティグループ適用 | SG | 設定しない |
| Endpointポリシー | Endpointポリシー | Terraformでは未指定。既定のフルアクセスポリシーを使用 |
| Projectタグ | `Project`タグ | `aws-cicd-portfolio` |
| ManagedByタグ | `ManagedBy`タグ | `Terraform` |
| Lifecycleタグ | `Lifecycle`タグ | `persistent` |

S3への通信許可は、利用元SGの送信ルール、IAMポリシー、S3バケットポリシーで制御する。業務CSV操作およびECRイメージレイヤー取得に使用する。

一時環境では`data.aws_vpc_endpoint.s3.prefix_list_id`を取得し、S3向けSG送信ルールに設定する。

### 5.2 Interface VPC Endpoint

| Terraformリソース | 接続先AWSサービス名（`service_name`） |
| --- | --- |
| `aws_vpc_endpoint.ecr_api` | `com.amazonaws.ap-northeast-1.ecr.api` |
| `aws_vpc_endpoint.ecr_dkr` | `com.amazonaws.ap-northeast-1.ecr.dkr` |
| `aws_vpc_endpoint.logs` | `com.amazonaws.ap-northeast-1.logs` |
| `aws_vpc_endpoint.secret` | `com.amazonaws.ap-northeast-1.secretsmanager` |
| `aws_vpc_endpoint.transfer` | `com.amazonaws.ap-northeast-1.transfer` |

全Interface VPC Endpointに以下を設定する。

| 意味 | 設定項目 | 設定値 |
| --- | --- | --- |
| VPCエンドポイントの方式 | `vpc_endpoint_type` | `Interface` |
| 所属VPC ID | `vpc_id` | `data.aws_vpc.portfolio.id` |
| 配置先サブネットID一覧 | `subnet_ids` | `data.aws_subnets.private.ids`（Private-a・Private-c） |
| 適用するセキュリティグループID一覧 | `security_group_ids` | `[aws_security_group.endpoint.id]` |
| プライベートDNSの有効化 | `private_dns_enabled` | `true` |

SQS Interface EndpointおよびCloudWatch Monitoring Interface Endpointは作成しない。SQSイベントソースのポーリングおよびLambda非同期失敗時の送信先制御はAWSサービス側で実行し、独自メトリクスは標準出力のEMFログを使用する。

### 5.3 Interface Endpointポリシー

全ポリシーの共通値を以下に示す。

| 意味 | 項目 | 設定値 |
| --- | --- | --- |
| ポリシー言語のバージョン | `Version` | `2012-10-17` |
| アクセスの許可・拒否 | `Effect` | `Allow` |
| 操作主体 | `Principal` | `*` |
| アクセス条件の比較方法 | `Condition`演算子 | `ArnLike` |
| アクセス条件の対象キー | `Condition`キー | `aws:PrincipalArn` |
| アクセス条件の比較値 | `Condition`値 | `arn:aws:iam::<account-id>:role/portfolio-card-*` |

Principalは`*`とし、Conditionで同一アカウントの`portfolio-card-*`ロールに利用を限定する。各EndpointのAction・Resourceは以下とする。

#### ECR API

| 意味 | 項目 | 設定値 |
| --- | --- | --- |
| 対象操作 | `Action` | `ecr:GetAuthorizationToken`、`ecr:BatchGetImage`、`ecr:GetDownloadUrlForLayer`、`ecr:BatchCheckLayerAvailability` |
| 対象リソース | `Resource` | `*` |

#### ECR Docker Registry

| 意味 | 項目 | 設定値 |
| --- | --- | --- |
| 対象操作 | `Action` | `ecr:BatchGetImage`、`ecr:GetDownloadUrlForLayer`、`ecr:BatchCheckLayerAvailability` |
| 対象リソース | `Resource` | `*` |

ECR Endpointでは対象リポジトリを限定せず、ECS起動ロールのIAMポリシーでイメージ取得先を限定する。

#### CloudWatch Logs

| 意味 | 項目 | 設定値 |
| --- | --- | --- |
| 対象操作 | `Action` | `logs:CreateLogStream`、`logs:PutLogEvents` |
| 対象リソース | `Resource` | `arn:aws:logs:ap-northeast-1:<account-id>:log-group:*` |

Endpointでは同一アカウント・東京リージョンのロググループを許可し、実行ロールのIAMポリシーで書込み先を制限する。

#### Secrets Manager

| 意味 | 項目 | 設定値 |
| --- | --- | --- |
| 対象操作 | `Action` | `secretsmanager:GetSecretValue`、`secretsmanager:PutSecretValue` |
| アクセス対象の業務処理用Secret ARN | `Resource`：処理用DB Secret | `aws_secretsmanager_secret.app.arn` |
| アクセス対象のWeb参照用Secret ARN | `Resource`：Web用DB Secret | `aws_secretsmanager_secret.web.arn` |
| アクセス対象のDB管理用Secret ARN | `Resource`：Aurora管理Secret | `aws_rds_cluster.portfolio.master_user_secret[0].secret_arn` |

3つのARNをResource配列に設定する。ロールごとの取得・更新権限はIAMポリシーで分離する。

#### Transfer Family

| 意味 | 項目 | 設定値 |
| --- | --- | --- |
| 対象操作 | `Action` | `transfer:StartFileTransfer` |
| 対象リソース | `Resource` | `arn:aws:transfer:ap-northeast-1:<account-id>:connector/<connector-id>` |
| コネクタIDの取得元 | `<connector-id>`の参照先 | `awscc_transfer_connector.vendor.connector_id` |

## 6. セキュリティグループ

### 6.1 SG一覧

全SGを対象VPC内に作成する。

| Terraformリソース | 名前（`name`） | 説明（`description`） | アタッチ先 |
| --- | --- | --- | --- |
| `aws_security_group.alb` | `portfolio-card-alb` | `Portfolio alb` | ALB |
| `aws_security_group.web` | `portfolio-card-web` | `Portfolio web` | Webタスク |
| `aws_security_group.registration` | `portfolio-card-registration` | `Portfolio registration` | 登録Lambda |
| `aws_security_group.request` | `portfolio-card-request` | `Portfolio request` | 発行依頼Lambda |
| `aws_security_group.resend` | `portfolio-card-resend` | `Portfolio resend` | 再送Lambda |
| `aws_security_group.result` | `portfolio-card-result` | `Portfolio result` | 結果反映Lambda |
| `aws_security_group.migration` | `portfolio-card-migration` | `Portfolio migration` | DB変更用タスク |
| `aws_security_group.db` | `portfolio-card-db` | `Portfolio db` | Aurora |
| `aws_security_group.endpoint` | `portfolio-card-endpoint` | `Portfolio endpoint` | 全Interface VPC Endpoint |
| `aws_security_group.vendor` | `portfolio-card-vendor` | `Portfolio vendor` | カード発行業者のSFTPサーバ（EC2） |

全SGに以下のタグを設定する。

| 意味 | キー | 値 |
| --- | --- | --- |
| プロジェクト識別タグ | `Project` | `aws-cicd-portfolio` |
| リソース管理方法のタグ | `ManagedBy` | `Terraform` |
| 常設・一時の管理区分タグ | `Lifecycle` | `temporary` |

以降、SG名は`portfolio-card-`を省略して記載する。SGを指定する通信ルールは、対象SGのIDを参照する。

### 6.2 受信ルール

全ルールのプロトコルはTCPとし、`from_port`と`to_port`に同じポート番号を設定する。

| 対象SG | ポート | 送信元 |
| --- | --- | --- |
| `alb` | `80` | `0.0.0.0/0` |
| `web` | `8080` | `alb` SG |
| `db` | `5432` | `web` SG |
| `db` | `5432` | `registration` SG |
| `db` | `5432` | `request` SG |
| `db` | `5432` | `result` SG |
| `db` | `5432` | `migration` SG |
| `endpoint` | `443` | `web` SG |
| `endpoint` | `443` | `registration` SG |
| `endpoint` | `443` | `request` SG |
| `endpoint` | `443` | `resend` SG |
| `endpoint` | `443` | `result` SG |
| `endpoint` | `443` | `migration` SG |
| `vendor` | `22` | Connector出口IPv4全件の各`/32` |

`registration`、`request`、`resend`、`result`、`migration`には受信ルールを設定しない。

vendorの受信ルールは以下で定義する。

| 意味 | 設定項目 | 設定値 |
| --- | --- | --- |
| Terraformリソース | Terraformリソース | `aws_security_group_rule.vendor_sftp` |
| 種別 | `type` | `ingress` |
| 通信プロトコル | `protocol` | `tcp` |
| 許可するポート範囲の開始・終了 | `from_port` / `to_port` | `22` / `22` |
| 許可するIPアドレス範囲 | `cidr_blocks` | `[for ip in awscc_transfer_connector.vendor.service_managed_egress_ip_addresses : "${ip}/32"]` |
| 説明 | `description` | `portfolio-connector` |

### 6.3 送信ルール

全ルールの`ip_protocol`は`tcp`とし、`from_port`と`to_port`に同じポート番号を設定する。

| 対象SG | ポート | 宛先 |
| --- | --- | --- |
| `alb` | `8080` | `web` SG |
| `web` | `5432` | `db` SG |
| `web` | `443` | `endpoint` SG |
| `web` | `443` | S3管理prefix list |
| `registration` | `5432` | `db` SG |
| `registration` | `443` | `endpoint` SG |
| `request` | `5432` | `db` SG |
| `request` | `443` | `endpoint` SG |
| `request` | `443` | S3管理prefix list |
| `resend` | `443` | `endpoint` SG |
| `resend` | `443` | S3管理prefix list |
| `result` | `5432` | `db` SG |
| `result` | `443` | `endpoint` SG |
| `result` | `443` | S3管理prefix list |
| `migration` | `5432` | `db` SG |
| `migration` | `443` | `endpoint` SG |
| `migration` | `443` | S3管理prefix list |
| `vendor` | `443` | `0.0.0.0/0` |

S3管理prefix listは`data.aws_vpc_endpoint.s3.prefix_list_id`を設定する。

`db`および`endpoint`には送信ルールを設定しない。SGはステートフルであり、許可済み通信の応答に対する個別ルールは追加しない。

受付LambdaおよびID管理システムの連携処理を実行するLambdaはVPC外で実行し、SGを設定しない。

## 7. VPC関連通信経路

本章は、VPC内リソースの通信およびVPCへの入出力経路を示す。システム全体の通信・イベント連携は基本設計の[主要通信経路図](../../02_基本設計/51_画像/ネットワーク通信経路図.svg)、各サービス間の連携設定は各詳細設計に定める。

| 通信元 | 通信先 | 経路・ポート |
| --- | --- | --- |
| ユーザ | Web | Internet → ALB TCP80 → Webタスク TCP8080 |
| Webタスク | Aurora Reader | VPC内、TCP5432 |
| 登録・発行依頼・結果反映Lambda | Aurora Writer | VPC内、TCP5432 |
| DB変更用タスク | Aurora Writer | VPC内、TCP5432 |
| VPC内処理 | ECR・Logs・Secrets Manager・Transfer Family API | Interface VPC Endpoint、TCP443 |
| VPC内処理 | S3 | S3 Gateway Endpoint、TCP443 |
| Transfer Family Connector | カード発行業者のSFTPサーバ | AWS管理の送信経路 → EC2 EIP、TCP22 |
| カード発行業者のSFTPサーバ | SSM・OSパッケージ取得先 | Internet Gateway、TCP443 |

Interface VPC EndpointのPrivate DNSを有効化し、通常のAWSサービス名によるアクセスをPrivate経路へ接続する。

S3バケット全体に`aws:SourceVpce`必須のDenyは設定しない。VPC外から実行されるTransfer Family Connectorおよび構築処理のアクセスは、IAM・バケットポリシーで制御する。

IAM権限は[IAM詳細設計](02_AWS_IAM.md)、S3バケット設定は[S3詳細設計](09_AWS_S3.md)、Connector設定は[Transfer Family詳細設計](11_AWS_Transfer_Family.md)に定める。
