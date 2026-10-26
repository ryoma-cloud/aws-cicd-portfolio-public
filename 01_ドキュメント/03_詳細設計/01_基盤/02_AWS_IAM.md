# IAM 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/iam.tf`、`02_資材/01_persistent/iam_github.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. サービス実行ロール・信頼ポリシー

各信頼ポリシーは`Version=2012-10-17`、以下のStatementで定義する。ロール名・リソース識別子中の`mock`は実装値を維持する。

| リソース | 名前（name） | 許可・拒否（Effect） | 操作主体（Principal） | 対象操作（Action） | 適用条件（Condition） |
| --- | --- | --- | --- | --- | --- |
| `aws_iam_role.transfer` | `portfolio-card-transfer` | `Allow` | `{"Service": "transfer.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.vendor` | `portfolio-card-vendor` | `Allow` | `{"Service": "ec2.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.employee_intake` | `portfolio-card-employee_intake` | `Allow` | `{"Service": "lambda.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.employee_register` | `portfolio-card-employee_register` | `Allow` | `{"Service": "lambda.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.request_batch` | `portfolio-card-request_batch` | `Allow` | `{"Service": "lambda.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.transfer_result` | `portfolio-card-transfer_result` | `Allow` | `{"Service": "lambda.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.resend` | `portfolio-card-resend` | `Allow` | `{"Service": "lambda.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.scheduler` | `portfolio-card-scheduler` | `Allow` | `{"Service": "scheduler.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.ecs_execution` | `portfolio-card-ecs_execution` | `Allow` | `{"Service": "ecs-tasks.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.web_task` | `portfolio-card-web_task` | `Allow` | `{"Service": "ecs-tasks.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.migration_task` | `portfolio-card-migration_task` | `Allow` | `{"Service": "ecs-tasks.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.id_mock` | `portfolio-card-id-mock` | `Allow` | `{"Service": "lambda.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.config` | `portfolio-card-config` | `Allow` | `{"Service": "config.amazonaws.com"}` | `sts:AssumeRole` | `{}` |
| `aws_iam_role.transfer_logging` | `portfolio-card-transfer-logs` | `Allow` | `{"Service": "transfer.amazonaws.com"}` | `sts:AssumeRole` | `{"StringEquals": {"aws:SourceAccount": data.aws_caller_identity.current.account_id}, "ArnLike": {"aws:SourceArn": "arn:aws:transfer:ap-northeast-1:${data.aws_caller_identity.current.account_id}:connector/*"}}` |

## 3. 実行権限

AWS管理ポリシーを優先し、対象リソースの限定や不足権限の補完が必要な場合はカスタマー管理ポリシーを作成する。インラインポリシーは使用しない。信頼ポリシーとリソースポリシーはそれぞれのリソースに定義する。

カスタマー管理ポリシーは`aws_iam_policy`で作成し、`aws_iam_role_policy_attachment`でロールへ付与する。`Version`は`2012-10-17`。以下の権限表の各行は1つのStatementを示す。Conditionが`{}`の行には追加条件を設定しない。

### カスタマー管理ポリシーの作成・付与

| ポリシーリソース | 名前（name） | 付与リソース | 付与先ロール（role） | 付与ポリシーARN（policy_arn） |
| --- | --- | --- | --- | --- |
| `aws_iam_policy.transfer` | `portfolio-card-transfer-policy` | `aws_iam_role_policy_attachment.transfer` | `aws_iam_role.transfer.name` | `aws_iam_policy.transfer.arn` |
| `aws_iam_policy.employee_intake` | `portfolio-card-employee-intake-policy` | `aws_iam_role_policy_attachment.employee_intake` | `aws_iam_role.employee_intake.name` | `aws_iam_policy.employee_intake.arn` |
| `aws_iam_policy.employee_register` | `portfolio-card-employee-register-policy` | `aws_iam_role_policy_attachment.employee_register` | `aws_iam_role.employee_register.name` | `aws_iam_policy.employee_register.arn` |
| `aws_iam_policy.request_batch` | `portfolio-card-request-batch-policy` | `aws_iam_role_policy_attachment.request_batch` | `aws_iam_role.request_batch.name` | `aws_iam_policy.request_batch.arn` |
| `aws_iam_policy.transfer_result` | `portfolio-card-transfer-result-policy` | `aws_iam_role_policy_attachment.transfer_result` | `aws_iam_role.transfer_result.name` | `aws_iam_policy.transfer_result.arn` |
| `aws_iam_policy.resend` | `portfolio-card-resend-policy` | `aws_iam_role_policy_attachment.resend` | `aws_iam_role.resend.name` | `aws_iam_policy.resend.arn` |
| `aws_iam_policy.scheduler` | `portfolio-card-scheduler-policy` | `aws_iam_role_policy_attachment.scheduler` | `aws_iam_role.scheduler.name` | `aws_iam_policy.scheduler.arn` |
| `aws_iam_policy.ecs_execution` | `portfolio-card-ecs-execution-policy` | `aws_iam_role_policy_attachment.ecs_execution` | `aws_iam_role.ecs_execution.name` | `aws_iam_policy.ecs_execution.arn` |
| `aws_iam_policy.web_task` | `portfolio-card-web-task-policy` | `aws_iam_role_policy_attachment.web_task` | `aws_iam_role.web_task.name` | `aws_iam_policy.web_task.arn` |
| `aws_iam_policy.migration_task` | `portfolio-card-migration-task-policy` | `aws_iam_role_policy_attachment.migration_task` | `aws_iam_role.migration_task.name` | `aws_iam_policy.migration_task.arn` |
| `aws_iam_policy.id_mock` | `portfolio-card-id-mock-policy` | `aws_iam_role_policy_attachment.id_mock` | `aws_iam_role.id_mock.name` | `aws_iam_policy.id_mock.arn` |
| `aws_iam_policy.config_delivery` | `portfolio-card-config-delivery-policy` | `aws_iam_role_policy_attachment.config_delivery` | `aws_iam_role.config[0].name` | `aws_iam_policy.config_delivery[count.index].arn` |
| `aws_iam_policy.transfer_logging` | `portfolio-card-transfer-logging-policy` | `aws_iam_role_policy_attachment.transfer_logging` | `aws_iam_role.transfer_logging.name` | `aws_iam_policy.transfer_logging.arn` |

`config_delivery`のポリシーと付与リソースは、いずれも`count = var.enable_account_security ? 1 : 0`とする。その他は各1個を作成する。

### aws_iam_policy.transfer

付与先：`aws_iam_role.transfer.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]` | `["${aws_s3_bucket.card_exchange.arn}/transfer/*", "${aws_s3_bucket.card_exchange.arn}/failed/*"]` | `{}` |
| `Allow` | `["s3:ListBucket", "s3:GetBucketLocation"]` | `aws_s3_bucket.card_exchange.arn` | `{}` |
| `Allow` | `["secretsmanager:GetSecretValue"]` | `aws_secretsmanager_secret.sftp.arn` | `{}` |

### aws_iam_policy.employee_intake

付与先：`aws_iam_role.employee_intake.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["logs:CreateLogStream", "logs:PutLogEvents"]` | `["arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"]` | `{}` |
| `Allow` | `["sqs:SendMessage"]` | `aws_sqs_queue.registration.arn` | `{}` |

### aws_iam_policy.employee_register

付与先：`aws_iam_role.employee_register.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["logs:CreateLogStream", "logs:PutLogEvents"]` | `["arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"]` | `{}` |
| `Allow` | `["ec2:DescribeSubnets"]` | `*` | `{}` |
| `Allow` | `["secretsmanager:GetSecretValue"]` | `aws_secretsmanager_secret.app.arn` | `{}` |
| `Allow` | `["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]` | `aws_sqs_queue.registration.arn` | `{}` |

### aws_iam_policy.request_batch

付与先：`aws_iam_role.request_batch.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["logs:CreateLogStream", "logs:PutLogEvents"]` | `["arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"]` | `{}` |
| `Allow` | `["ec2:DescribeSubnets"]` | `*` | `{}` |
| `Allow` | `["secretsmanager:GetSecretValue"]` | `aws_secretsmanager_secret.app.arn` | `{}` |
| `Allow` | `["s3:ListBucket"]` | `aws_s3_bucket.card_exchange.arn` | `{}` |
| `Allow` | `["transfer:StartFileTransfer"]` | `arn:aws:transfer:ap-northeast-1:${data.aws_caller_identity.current.account_id}:connector/${awscc_transfer_connector.vendor.connector_id}` | `{}` |
| `Allow` | `["s3:PutObject"]` | `${aws_s3_bucket.card_exchange.arn}/transfer/*` | `{}` |
| `Allow` | `["s3:PutObject", "s3:GetObject"]` | `${aws_s3_bucket.card_exchange.arn}/daily/*` | `{}` |

### aws_iam_policy.transfer_result

付与先：`aws_iam_role.transfer_result.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["logs:CreateLogStream", "logs:PutLogEvents"]` | `["arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"]` | `{}` |
| `Allow` | `["ec2:DescribeSubnets"]` | `*` | `{}` |
| `Allow` | `["secretsmanager:GetSecretValue"]` | `aws_secretsmanager_secret.app.arn` | `{}` |
| `Allow` | `["s3:GetObject"]` | `["${aws_s3_bucket.card_exchange.arn}/transfer/*", "${aws_s3_bucket.card_exchange.arn}/failed/*", "${aws_s3_bucket.card_exchange.arn}/success/*"]` | `{}` |
| `Allow` | `["s3:ListBucket"]` | `aws_s3_bucket.card_exchange.arn` | `{}` |
| `Allow` | `["s3:PutObject", "s3:DeleteObject"]` | `["${aws_s3_bucket.card_exchange.arn}/transfer/*", "${aws_s3_bucket.card_exchange.arn}/failed/*", "${aws_s3_bucket.card_exchange.arn}/success/*"]` | `{}` |
| `Allow` | `["sqs:SendMessage"]` | `aws_sqs_queue.result_execution_dlq.arn` | `{}` |

### aws_iam_policy.resend

付与先：`aws_iam_role.resend.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["logs:CreateLogStream", "logs:PutLogEvents"]` | `["arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"]` | `{}` |
| `Allow` | `["ec2:DescribeSubnets"]` | `*` | `{}` |
| `Allow` | `["s3:ListBucket"]` | `aws_s3_bucket.card_exchange.arn` | `{}` |
| `Allow` | `["transfer:StartFileTransfer"]` | `arn:aws:transfer:ap-northeast-1:${data.aws_caller_identity.current.account_id}:connector/${awscc_transfer_connector.vendor.connector_id}` | `{}` |

### aws_iam_policy.scheduler

付与先：`aws_iam_role.scheduler.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["lambda:InvokeFunction"]` | `aws_lambda_alias.request_batch.arn` | `{}` |
| `Allow` | `["sqs:SendMessage"]` | `aws_sqs_queue.schedule_delivery_dlq.arn` | `{}` |

### aws_iam_policy.ecs_execution

付与先：`aws_iam_role.ecs_execution.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["ecr:GetAuthorizationToken"]` | `*` | `{}` |
| `Allow` | `["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]` | `local.ecr_repository_arn` | `{}` |
| `Allow` | `["logs:CreateLogStream", "logs:PutLogEvents"]` | `${aws_cloudwatch_log_group.web.arn}:*` | `{}` |

### aws_iam_policy.web_task

付与先：`aws_iam_role.web_task.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["secretsmanager:GetSecretValue"]` | `aws_secretsmanager_secret.web.arn` | `{}` |

### aws_iam_policy.migration_task

付与先：`aws_iam_role.migration_task.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["secretsmanager:GetSecretValue"]` | `[aws_rds_cluster.portfolio.master_user_secret[0].secret_arn, aws_secretsmanager_secret.app.arn, aws_secretsmanager_secret.web.arn]` | `{}` |
| `Allow` | `["secretsmanager:PutSecretValue"]` | `[aws_secretsmanager_secret.app.arn, aws_secretsmanager_secret.web.arn]` | `{}` |

### aws_iam_policy.id_mock

付与先：`aws_iam_role.id_mock.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `execute-api:Invoke` | `${aws_apigatewayv2_api.employees.execution_arn}/*/POST/employees` | `{}` |
| `Allow` | `["logs:CreateLogStream", "logs:PutLogEvents"]` | `${aws_cloudwatch_log_group.id_mock.arn}:*` | `{}` |

### aws_iam_policy.config_delivery

付与先：`aws_iam_role.config[0].id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["s3:GetBucketAcl", "s3:ListBucket"]` | `arn:aws:s3:::portfolio-card-config-${data.aws_caller_identity.current.account_id}-ap-northeast-1` | `{}` |
| `Allow` | `s3:PutObject` | `arn:aws:s3:::portfolio-card-config-${data.aws_caller_identity.current.account_id}-ap-northeast-1/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*` | `{}` |

### aws_iam_policy.transfer_logging

付与先：`aws_iam_role.transfer_logging.id`

| 許可・拒否（Effect） | 対象操作（Action） | 対象リソース（Resource） | 適用条件（Condition） |
| --- | --- | --- | --- |
| `Allow` | `["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]` | `[aws_cloudwatch_log_group.transfer_connector.arn, "${aws_cloudwatch_log_group.transfer_connector.arn}:*"]` | `{}` |

### AWS管理ポリシー・インスタンスプロファイル

### aws_iam_role_policy_attachment.lambda_eni

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 繰返し作成の対象集合 | `for_each` | `{ employee_register = aws_iam_role.employee_register.name, request_batch = aws_iam_role.request_batch.name, transfer_result = aws_iam_role.transfer_result.name, resend = aws_iam_role.resend.name }` |
| 実行ロール | `role` | `each.value` |
| 付与するポリシーARN | `policy_arn` | `arn:aws:iam::aws:policy/service-role/AWSLambdaENIManagementAccess` |

AWS管理ポリシーにより、`ec2:CreateNetworkInterface`、`ec2:DescribeNetworkInterfaces`、`ec2:DeleteNetworkInterface`、`ec2:AssignPrivateIpAddresses`、`ec2:UnassignPrivateIpAddresses`を`Resource=*`で許可する。`ec2:DescribeSubnets`は各カスタマー管理ポリシーで補完する。

### aws_iam_role_policy_attachment.vendor_ssm

Terraformリソース：`aws_iam_role_policy_attachment.vendor_ssm`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 実行ロール | `role` | `aws_iam_role.vendor.name` |
| 付与するポリシーARN | `policy_arn` | `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore` |

### aws_iam_role_policy_attachment.config

Terraformリソース：`aws_iam_role_policy_attachment.config`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| リソースの作成数・作成条件 | `count` | `var.enable_account_security ? 1 : 0` |
| 実行ロール | `role` | `aws_iam_role.config[0].name` |
| 付与するポリシーARN | `policy_arn` | `arn:aws:iam::aws:policy/service-role/AWS_ConfigRole` |

### aws_iam_instance_profile.vendor

Terraformリソース：`aws_iam_instance_profile.vendor`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-vendor` |
| 実行ロール | `role` | `aws_iam_role.vendor.name` |

AWS管理ポリシーはENI管理、SSM接続、Configの構成情報収集に使用する。ログ・ECR・S3・SQS・Secrets Manager等は対象リソースを限定するためカスタマー管理ポリシーとする。Lambda・ECSタスク定義・Scheduler・Config Recorder、およびVPC LambdaのENIは、必要なポリシーの付与完了後に作成し、削除時は権限を最後まで維持する。Transfer Connectorはアクセス用ポリシーの付与完了後に作成する。ログ用ポリシーはConnector IDを含むロググループの作成後に付与し、ファイル転送開始前に構築を完了する。

業務Lambdaのログ書込み先は`/aws/lambda/portfolio-card-*`の範囲とする。S3のListBucketにはprefix条件を設定せず、オブジェクト操作のResourceで対象prefixを指定する。LambdaのENI操作は`Resource=*`とし、`lambda:SourceFunctionArn`条件は設定しない。DB権限は[DB・ファイル詳細設計](../02_アプリ/02_DB・ファイル詳細設計.md)に定める。

## 4. GitHub Actions操作用ロール

| 意味 | 項目 | 設定値 |
| --- | --- | --- |
| ロール名 | `role name` | `GitHubActionsTerraformPortfolioRole` |
| 参照変数 | `参照変数` | `AWS_ROLE_ARN` |
| OIDCトークンの発行者 | `OIDC issuer（信頼設定の要求値）` | `token.actions.githubusercontent.com` |
| OIDCトークンの宛先 | `aud（信頼設定の要求値）` | `sts.amazonaws.com` |
| OIDCトークンの対象リポジトリ・ブランチ | `sub（信頼設定の要求値）` | `repo:<owner>/<repository>:ref:refs/heads/main` |

`<owner>/<repository>`は使用するリポジトリの所有者名・リポジトリ名に置き換える。

既存ロールは`data.aws_iam_role.terraform`で参照する。信頼ポリシー全体と既存の付与権限は本Terraformの管理対象外であり、上表の要求値と実設定を変更時に照合する。構築・保守・状態確認は共通ロールを使用し、ワークフロー間でIAM権限を分離しない。PR CIにはAWS変更ロールを渡さない。

### aws_iam_policy.terraform_scaling_metadata

Terraformリソース：`aws_iam_policy.terraform_scaling_metadata`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `PortfolioTerraformScalingMetadataPolicy` |
| 説明 | `description` | `Read scalable target tags in the portfolio account and Tokyo region` |
| ポリシー言語のバージョン | `policy.Version` | `2012-10-17` |
| アクセスの許可・拒否 | `policy.Statement[0].Effect` | `Allow` |
| 対象操作 | `policy.Statement[0].Action` | `["application-autoscaling:ListTagsForResource"]` |
| 対象リソース | `policy.Statement[0].Resource` | `arn:${data.aws_partition.terraform.partition}:application-autoscaling:ap-northeast-1:${data.aws_caller_identity.terraform.account_id}:scalable-target/*` |
| リクエスト先リージョンの制限 | `policy.Statement[0].Condition.StringEquals.aws:RequestedRegion` | `ap-northeast-1` |
| アクセスの許可・拒否 | `policy.Statement[1].Effect` | `Allow` |
| 対象操作 | `policy.Statement[1].Action` | `["cloudformation:CreateResource", "cloudformation:GetResource", "cloudformation:UpdateResource", "cloudformation:DeleteResource", "cloudformation:GetResourceRequestStatus", "cloudformation:CancelResourceRequest"]` |
| 対象リソース | `policy.Statement[1].Resource` | `*` |
| リクエスト先リージョンの制限 | `policy.Statement[1].Condition.StringEquals.aws:RequestedRegion` | `ap-northeast-1` |

Auto Scalingのタグ参照とTransfer ConnectorのCloud Control操作を1つのカスタマー管理ポリシーにまとめ、既存の管理ポリシー付与数を増やさない。

### aws_iam_role_policy_attachment.terraform_scaling_metadata

Terraformリソース：`aws_iam_role_policy_attachment.terraform_scaling_metadata`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 実行ロール | `role` | `data.aws_iam_role.terraform.name` |
| 付与するポリシーARN | `policy_arn` | `aws_iam_policy.terraform_scaling_metadata.arn` |

## 5. リソースポリシー

### aws_lambda_permission.api

Terraformリソース：`aws_lambda_permission.api`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 権限ステートメント識別子 | `statement_id` | `ApiInvoke` |
| 許可する操作 | `action` | `lambda:InvokeFunction` |
| 関数名・参照先 | `function_name` | `aws_lambda_function.employee_intake.function_name` |
| 対象エイリアス・バージョン | `qualifier` | `live` |
| 操作を許可する主体 | `principal` | `apigateway.amazonaws.com` |
| 呼出元リソースARNの制限 | `source_arn` | `${aws_apigatewayv2_api.employees.execution_arn}/*/POST/employees` |

### aws_lambda_permission.result

Terraformリソース：`aws_lambda_permission.result`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 権限ステートメント識別子 | `statement_id` | `EventBridgeInvoke` |
| 許可する操作 | `action` | `lambda:InvokeFunction` |
| 関数名・参照先 | `function_name` | `aws_lambda_function.transfer_result.function_name` |
| 対象エイリアス・バージョン | `qualifier` | `live` |
| 操作を許可する主体 | `principal` | `events.amazonaws.com` |
| 呼出元リソースARNの制限 | `source_arn` | `aws_cloudwatch_event_rule.result.arn` |

### aws_sqs_queue_policy.delivery

Terraformリソース：`aws_sqs_queue_policy.delivery`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象キューURL | `queue_url` | `aws_sqs_queue.result_delivery_dlq.id` |
| ポリシー言語のバージョン | `policy.Version` | `2012-10-17` |
| アクセスの許可・拒否 | `policy.Statement[0].Effect` | `Allow` |
| 操作を許可するAWSサービス | `policy.Statement[0].Principal.Service` | `events.amazonaws.com` |
| 対象操作 | `policy.Statement[0].Action` | `sqs:SendMessage` |
| 対象リソース | `policy.Statement[0].Resource` | `aws_sqs_queue.result_delivery_dlq.arn` |
| 呼出元リソースARNの制限 | `policy.Statement[0].Condition.ArnEquals.aws:SourceArn` | `aws_cloudwatch_event_rule.result.arn` |

SNS・KMSポリシーは[SNS詳細設計](15_AWS_SNS.md)、Endpointポリシーは[VPC詳細設計](01_AWS_VPC.md)、S3のTLS拒否は[S3詳細設計](09_AWS_S3.md)に定める。SQS全体にTLS必須Denyを追加するポリシーは定義していない。
