# ECS / Fargate 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/ecs.tf`、`02_資材/02_temporary/terraform/web-autoscaling.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. Cluster・タスク定義・Service

### aws_ecs_cluster.portfolio

Terraformリソース：`aws_ecs_cluster.portfolio`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card` |

### aws_ecs_task_definition.web

Terraformリソース：`aws_ecs_task_definition.web`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| タスク定義のファミリー名 | `family` | `portfolio-card-web` |
| タスクのネットワーク方式 | `network_mode` | `awsvpc` |
| 対応する実行基盤 | `requires_compatibilities` | `["FARGATE"]` |
| 割当CPU（CPUユニット） | `cpu` | `256` |
| 割当メモリ（MiB） | `memory` | `512` |
| ECS起動時に使用するロールARN | `execution_role_arn` | `aws_iam_role.ecs_execution.arn` |
| コンテナ内処理の実行ロールARN | `task_role_arn` | `aws_iam_role.web_task.arn` |
| 名前 | `container_definitions[0].name` | `web` |
| コンテナイメージURI | `container_definitions[0].image` | `var.admin_image_uri` |
| 停止時にタスク全体を停止する必須コンテナ指定 | `container_definitions[0].essential` | `true` |
| ルートファイルシステムの読取専用化 | `container_definitions[0].readonlyRootFilesystem` | `true` |
| コンテナ実行ユーザ・グループID | `container_definitions[0].user` | `65532:65532` |
| 環境変数の名前：接続先DB名 | `container_definitions[0].environment[0].name` | `DB_NAME` |
| 環境変数の値：接続先DB名 | `container_definitions[0].environment[0].value` | `portfolio` |
| 環境変数の名前：DB接続先ホスト | `container_definitions[0].environment[1].name` | `DB_HOST` |
| 環境変数の値：DB接続先ホスト | `container_definitions[0].environment[1].value` | `aws_rds_cluster.portfolio.reader_endpoint` |
| 環境変数の名前：DB接続認証情報のSecret ARN | `container_definitions[0].environment[2].name` | `DB_SECRET_ARN` |
| 環境変数の値：DB接続認証情報のSecret ARN | `container_definitions[0].environment[2].value` | `aws_secretsmanager_secret.web.arn` |
| 環境変数の名前：業務処理用DB認証情報のSecret ARN | `container_definitions[0].environment[3].name` | `APP_SECRET_ARN` |
| 環境変数の値：業務処理用DB認証情報のSecret ARN | `container_definitions[0].environment[3].value` | `aws_secretsmanager_secret.app.arn` |
| 環境変数の名前：Web参照用DB認証情報のSecret ARN | `container_definitions[0].environment[4].name` | `WEB_SECRET_ARN` |
| 環境変数の値：Web参照用DB認証情報のSecret ARN | `container_definitions[0].environment[4].value` | `aws_secretsmanager_secret.web.arn` |
| ログドライバ | `container_definitions[0].logConfiguration.logDriver` | `awslogs` |
| ログ出力先グループ | `container_definitions[0].logConfiguration.options.awslogs-group` | `aws_cloudwatch_log_group.web.name` |
| ログ出力先リージョン | `container_definitions[0].logConfiguration.options.awslogs-region` | `ap-northeast-1` |
| ログストリーム名の接頭辞 | `container_definitions[0].logConfiguration.options.awslogs-stream-prefix` | `web` |
| コンテナの待受ポート | `container_definitions[0].portMappings[0].containerPort` | `8080` |
| 通信プロトコル | `container_definitions[0].portMappings[0].protocol` | `tcp` |
| コンテナ起動コマンド | `container_definitions[0].command` | `["gunicorn", "--bind=0.0.0.0:8080", "--workers=1", "--threads=2", "--worker-tmp-dir=/dev/shm", "--error-logfile=-", "web.app:app"]` |
| コンテナ停止の猶予時間（秒） | `container_definitions[0].stopTimeout` | `30` |
| コンテナの正常性確認コマンド | `container_definitions[0].healthCheck.command` | `["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3).close()"]` |
| コンテナの正常性確認間隔（秒） | `container_definitions[0].healthCheck.interval` | `30` |
| コンテナの正常性確認タイムアウト（秒） | `container_definitions[0].healthCheck.timeout` | `5` |
| コンテナを異常と判定する連続失敗回数 | `container_definitions[0].healthCheck.retries` | `3` |
| コンテナ起動時の正常性確認猶予（秒） | `container_definitions[0].healthCheck.startPeriod` | `30` |

### aws_ecs_task_definition.migration

Terraformリソース：`aws_ecs_task_definition.migration`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| タスク定義のファミリー名 | `family` | `portfolio-card-migration` |
| タスクのネットワーク方式 | `network_mode` | `awsvpc` |
| 対応する実行基盤 | `requires_compatibilities` | `["FARGATE"]` |
| 割当CPU（CPUユニット） | `cpu` | `256` |
| 割当メモリ（MiB） | `memory` | `512` |
| ECS起動時に使用するロールARN | `execution_role_arn` | `aws_iam_role.ecs_execution.arn` |
| コンテナ内処理の実行ロールARN | `task_role_arn` | `aws_iam_role.migration_task.arn` |
| 名前 | `container_definitions[0].name` | `migration` |
| コンテナイメージURI | `container_definitions[0].image` | `var.admin_image_uri` |
| 停止時にタスク全体を停止する必須コンテナ指定 | `container_definitions[0].essential` | `true` |
| ルートファイルシステムの読取専用化 | `container_definitions[0].readonlyRootFilesystem` | `true` |
| コンテナ実行ユーザ・グループID | `container_definitions[0].user` | `65532:65532` |
| 環境変数の名前：接続先DB名 | `container_definitions[0].environment[0].name` | `DB_NAME` |
| 環境変数の値：接続先DB名 | `container_definitions[0].environment[0].value` | `portfolio` |
| 環境変数の名前：DB接続先ホスト | `container_definitions[0].environment[1].name` | `DB_HOST` |
| 環境変数の値：DB接続先ホスト | `container_definitions[0].environment[1].value` | `aws_rds_cluster.portfolio.endpoint` |
| 環境変数の名前：DB接続認証情報のSecret ARN | `container_definitions[0].environment[2].name` | `DB_SECRET_ARN` |
| 環境変数の値：DB接続認証情報のSecret ARN | `container_definitions[0].environment[2].value` | `aws_rds_cluster.portfolio.master_user_secret[0].secret_arn` |
| 環境変数の名前：業務処理用DB認証情報のSecret ARN | `container_definitions[0].environment[3].name` | `APP_SECRET_ARN` |
| 環境変数の値：業務処理用DB認証情報のSecret ARN | `container_definitions[0].environment[3].value` | `aws_secretsmanager_secret.app.arn` |
| 環境変数の名前：Web参照用DB認証情報のSecret ARN | `container_definitions[0].environment[4].name` | `WEB_SECRET_ARN` |
| 環境変数の値：Web参照用DB認証情報のSecret ARN | `container_definitions[0].environment[4].value` | `aws_secretsmanager_secret.web.arn` |
| ログドライバ | `container_definitions[0].logConfiguration.logDriver` | `awslogs` |
| ログ出力先グループ | `container_definitions[0].logConfiguration.options.awslogs-group` | `aws_cloudwatch_log_group.web.name` |
| ログ出力先リージョン | `container_definitions[0].logConfiguration.options.awslogs-region` | `ap-northeast-1` |
| ログストリーム名の接頭辞 | `container_definitions[0].logConfiguration.options.awslogs-stream-prefix` | `migration` |
| コンテナ起動コマンド | `container_definitions[0].command` | `["python", "tools/migrate.py"]` |

### aws_ecs_service.admin

Terraformリソース：`aws_ecs_service.admin`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-web` |
| 所属ECSクラスタ | `cluster` | `aws_ecs_cluster.portfolio.id` |
| 使用するタスク定義ARN | `task_definition` | `aws_ecs_task_definition.web.arn` |
| 希望する稼働タスク数 | `desired_count` | `var.web_desired_count` |
| タスクの起動方式 | `launch_type` | `FARGATE` |
| ALBヘルスチェックの起動猶予時間（秒） | `health_check_grace_period_seconds` | `60` |
| デプロイ中の正常タスク数の最低割合（%） | `deployment_minimum_healthy_percent` | `100` |
| デプロイ中のタスク数の最大割合（%） | `deployment_maximum_percent` | `200` |
| デプロイ失敗検知の有効化 | `deployment_circuit_breaker[0].enable` | `true` |
| デプロイ失敗時の自動切戻し | `deployment_circuit_breaker[0].rollback` | `true` |
| 配置先サブネットID一覧 | `network_configuration[0].subnets` | `data.aws_subnets.private.ids` |
| 適用するセキュリティグループID一覧 | `network_configuration[0].security_groups` | `[aws_security_group.web.id]` |
| タスクへのパブリックIP割当 | `network_configuration[0].assign_public_ip` | `false` |
| 転送先ターゲットグループARN | `load_balancer[0].target_group_arn` | `aws_lb_target_group.admin.arn` |
| ALBの転送先コンテナ名 | `load_balancer[0].container_name` | `web` |
| ALBの転送先コンテナポート | `load_balancer[0].container_port` | `8080` |
| Terraform差分検出から除外する属性 | `lifecycle[0].ignore_changes` | `["desired_count"]` |

`runtime_platform`、Serviceの`platform_version`、`availability_zone_rebalancing`、`enable_execute_command`はTerraformでは未指定。Linux 1.4.0やAZ rebalancing ENABLEDを明示固定した定義ではない。WebとDB変更用タスクは同一のdigest固定イメージを使用する。

## 3. コンテナ共通設定

| 意味 | 項目 | 値 |
| --- | --- | --- |
| コンテナの基底イメージ | `Docker base image` | `python:3.13-slim` |
| コンテナ内の作業ディレクトリ | `WORKDIR` | `/app` |
| コンテナ実行ユーザ・グループID | `USER` | `65532:65532` |
| Pythonモジュールの検索パス | `PYTHONPATH` | `/app` |
| DBのTLS検証用CA証明書パス | `DB_SSLROOTCERT` | `/app/certs/global-bundle.pem` |
| Pythonバイトコードファイルの生成抑止 | `PYTHONDONTWRITEBYTECODE` | `1` |
| Webワーカープロセス数・スレッド数 | `gunicorn workers / threads` | `1 / 2` |
| Webワーカーの一時ディレクトリ | `worker-tmp-dir` | `/dev/shm` |

WebタスクのSecret ARN環境変数は値そのものを含まない。WebロールのSecret取得権限はWeb用Secretだけとする。DB接続は最大2、overflow=0。依存とRDS CAはビルド時に同梱し、実行時の外部取得は行わない。

## 4. ヘルスチェック・DB変更

`/health`はDB照会を行わず200を返す。コンテナ内HTTPクライアントのtimeoutは3秒、ECS healthCheckのtimeoutは5秒。`/ready`はDBのSELECT 1成功で200、失敗で503を返し、構築・変更後の確認に使用する。

DB変更は単発Fargateタスクで`python tools/migrate.py`を実行する。起動パラメータは`launchType=FARGATE`、`assignPublicIp=DISABLED`、subnetsは`private_subnet_ids`、securityGroupsは`migration_security_group`とする。停止待機は`Delay=10`秒・`MaxAttempts=60`で、コンテナ終了コード0を成功条件とする。DB変更失敗時は新Webの適用へ進まない。

## 5. 自動増減

### aws_appautoscaling_target.web

Terraformリソース：`aws_appautoscaling_target.web`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| リソースの作成数・作成条件 | `count` | `var.web_desired_count > 0 ? 1 : 0` |
| 最小タスク数 | `min_capacity` | `2` |
| 最大タスク数 | `max_capacity` | `4` |
| スケーリング対象リソースID | `resource_id` | `service/${aws_ecs_cluster.portfolio.name}/${aws_ecs_service.admin.name}` |
| スケーリングする属性 | `scalable_dimension` | `ecs:service:DesiredCount` |
| スケーリング対象AWSサービス | `service_namespace` | `ecs` |

### aws_appautoscaling_policy.web_requests

Terraformリソース：`aws_appautoscaling_policy.web_requests`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| リソースの作成数・作成条件 | `count` | `var.web_desired_count > 0 ? 1 : 0` |
| 名前 | `name` | `portfolio-card-web-requests` |
| スケーリングポリシーの方式 | `policy_type` | `TargetTrackingScaling` |
| スケーリング対象リソースID | `resource_id` | `aws_appautoscaling_target.web[0].resource_id` |
| スケーリングする属性 | `scalable_dimension` | `aws_appautoscaling_target.web[0].scalable_dimension` |
| スケーリング対象AWSサービス | `service_namespace` | `aws_appautoscaling_target.web[0].service_namespace` |
| 1タスク当たりの目標リクエスト数（件/分） | `target_tracking_scaling_policy_configuration[0].target_value` | `10` |
| スケールアウト後の待機時間（秒） | `target_tracking_scaling_policy_configuration[0].scale_out_cooldown` | `60` |
| スケールイン後の待機時間（秒） | `target_tracking_scaling_policy_configuration[0].scale_in_cooldown` | `300` |
| スケールインの無効化 | `target_tracking_scaling_policy_configuration[0].disable_scale_in` | `false` |
| スケーリング判定に使用する標準メトリクス | `target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type` | `ALBRequestCountPerTarget` |
| メトリクス対象のALB・ターゲットグループ識別子 | `target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].resource_label` | `${aws_lb.admin.arn_suffix}/${aws_lb_target_group.admin.arn_suffix}` |

`web_desired_count`は既定0、許可値は0または整数2～4。0は初回DB準備専用とし、DB変更後に2へ起動する。稼働中の希望タスク数はApplication Auto Scalingが管理し、Terraformは`ignore_changes=[desired_count]`で維持する。

目標10は1ターゲット当たり1分間のリクエスト数であり、性能上限ではない。AWS管理アラームの判定・起動・正常化を経て増減する。希望数の最大は4だが、ローリング更新のmaximum=200%により一時的に最大8タスクとなり得る。WebのDB接続数は通常最大8、更新中最大16とし、Lambda・DB変更用接続を別途加算する。

Web処理は[Webアプリ処理仕様](../02_アプリ/03_Webアプリ処理仕様.md)、構築は[CI/CD・構築処理仕様](../03_構築保守/02_CICD・構築処理仕様.md)に定める。
