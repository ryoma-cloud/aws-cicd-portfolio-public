# ALB 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/alb.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. ALB・Target Group・Listener

### aws_lb.admin

Terraformリソース：`aws_lb.admin`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-web` |
| 内部向けロードバランサの指定 | `internal` | `false` |
| ロードバランサの種類 | `load_balancer_type` | `application` |
| 適用するセキュリティグループID一覧 | `security_groups` | `[aws_security_group.alb.id]` |
| 配置先サブネットID一覧 | `subnets` | `data.aws_subnets.public.ids` |

### aws_lb_target_group.admin

Terraformリソース：`aws_lb_target_group.admin`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-web` |
| 接続・待受ポート番号 | `port` | `8080` |
| 通信プロトコル | `protocol` | `HTTP` |
| 転送先の登録方式 | `target_type` | `ip` |
| 所属VPC ID | `vpc_id` | `data.aws_vpc.portfolio.id` |
| ヘルスチェックの確認先パス | `health_check[0].path` | `/health` |
| 正常と判定するHTTP応答コード | `health_check[0].matcher` | `200` |
| ヘルスチェック間隔（秒） | `health_check[0].interval` | `30` |
| ヘルスチェックのタイムアウト（秒） | `health_check[0].timeout` | `5` |
| 正常復帰と判定する連続成功回数 | `health_check[0].healthy_threshold` | `2` |
| 異常と判定する連続失敗回数 | `health_check[0].unhealthy_threshold` | `3` |

### aws_lb_listener.admin

Terraformリソース：`aws_lb_listener.admin`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 接続先ロードバランサARN | `load_balancer_arn` | `aws_lb.admin.arn` |
| 接続・待受ポート番号 | `port` | `80` |
| 通信プロトコル | `protocol` | `HTTP` |
| 種別 | `default_action[0].type` | `forward` |
| 転送先ターゲットグループARN | `default_action[0].target_group_arn` | `aws_lb_target_group.admin.arn` |

## 3. Terraform未指定項目

| 意味 | 項目 | 扱い |
| --- | --- | --- |
| IPアドレスの種類 | `ip_address_type` | 未指定 |
| 無通信時のタイムアウト（秒） | `idle_timeout` | 未指定 |
| ロードバランサの削除保護 | `enable_deletion_protection` | 未指定 |
| ALBアクセスログ出力 | `access_logs` | 未設定 |
| ターゲット登録解除の待機時間（秒） | `deregistration_delay` | 未指定 |
| AZをまたぐ負荷分散設定 | `cross-zone関連属性` | 未指定 |

これらは明示した設定値とは区別し、サービス・プロバイダーの既定動作を使用する。HTTPS Listenerと画面認証は対象外とする。SGは[VPC詳細設計](01_AWS_VPC.md)に定める。

## 4. 正常性判定・障害監視

ALBとコンテナは`/health`でDBに依存しない生存確認を行う。`/ready`はDB疎通確認に使用し、ALBの判定には使用しない。画面のDB取得失敗は503、未知のパスは404で応答する。

DB障害をタスク置換へ直結させず、DB指標・Target 5xx・アプリログから調査する。アクセスがない状態のDB接続障害をTarget 5xxだけで検知する構成ではない。通知条件は[CloudWatch詳細設計](13_AWS_CloudWatch.md)に定める。
