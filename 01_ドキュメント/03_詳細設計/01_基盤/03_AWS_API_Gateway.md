# API Gateway 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/api-gateway.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. API・Route・Integration・Stage

社員情報受付専用のHTTP APIとし、画面・再送APIは設けない。

### aws_apigatewayv2_api.employees

Terraformリソース：`aws_apigatewayv2_api.employees`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-employee` |
| APIのプロトコル種別 | `protocol_type` | `HTTP` |

### aws_apigatewayv2_integration.employees

Terraformリソース：`aws_apigatewayv2_integration.employees`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象API ID | `api_id` | `aws_apigatewayv2_api.employees.id` |
| バックエンドとの統合方式 | `integration_type` | `AWS_PROXY` |
| 呼出先Lambda ARN | `integration_uri` | `aws_lambda_alias.employee_intake.invoke_arn` |
| Lambdaへの受渡し形式バージョン | `payload_format_version` | `2.0` |
| API統合のタイムアウト（ミリ秒） | `timeout_milliseconds` | `30000` |

### aws_apigatewayv2_route.employees

Terraformリソース：`aws_apigatewayv2_route.employees`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象API ID | `api_id` | `aws_apigatewayv2_api.employees.id` |
| 受付HTTPメソッド・パス | `route_key` | `POST /employees` |
| API呼出しの認証方式 | `authorization_type` | `AWS_IAM` |
| ルートの転送先統合 | `target` | `integrations/${aws_apigatewayv2_integration.employees.id}` |

### aws_apigatewayv2_stage.employees

Terraformリソース：`aws_apigatewayv2_stage.employees`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 対象API ID | `api_id` | `aws_apigatewayv2_api.employees.id` |
| 名前 | `name` | `$default` |
| API変更の自動反映 | `auto_deploy` | `true` |
| 定常的なAPIリクエスト上限（件/秒） | `default_route_settings[0].throttling_rate_limit` | `5` |
| 瞬間的なAPIリクエスト上限 | `default_route_settings[0].throttling_burst_limit` | `10` |
| アクセスログ出力先ARN | `access_log_settings[0].destination_arn` | `aws_cloudwatch_log_group.api.arn` |
| アクセスログの形式 | `access_log_settings[0].format` | `{"requestId": "$context.requestId", "status": "$context.status", "routeKey": "$context.routeKey"}` |

CORSと`$default` Routeは作成しない。Stageの`$default`とは区別する。アクセスログの記録項目は`requestId`、`status`、`routeKey`の3項目とし、本文・Authorizationは出力しない。

## 3. 入力契約

UTF-8のJSONオブジェクト1件。Content-Typeはapplication/json（charset付与可）、欠落・異なる種別は400 INVALID_INPUT。余分な項目、配列、重複JSONキーは400。入力を自動trim・全半角変換せず、比較時にも同じ値を使用する。

| 意味 | 項目 | 型・必須 | 検証 |
| --- | --- | --- | --- |
| 社員番号 | employee_id | string、必須 | ASCII数字6桁（`^[0-9]{6}$`）。例：`000001`。先頭ゼロを保持する文字列 |
| 氏名 | employee_name | string、必須 | 1～100文字、空白のみ不可 |
| 所属会社名 | company_name | string、必須 | 1～100文字、空白のみ不可 |
| 共通 | 共通 | — | NUL・制御文字（改行・タブを含む）、UTF-8へ変換できない単独サロゲートを拒否。氏名・会社名のカンマ・二重引用符、有効な補助漢字は許可 |
| 本文サイズ | 本文サイズ | — | デコード後4096 bytes以下。超過は400 BODY_TOO_LARGE |

API Gateway自身のサービス上限で拒否される大きな要求のコードはAWS応答に従う。上記4096 bytesはLambda側の業務上限。

## 4. 応答

Content-Type=application/json、Cache-Control=no-store。社員情報本文は応答しない。

| HTTP | body例 | 条件 |
| --- | --- | --- |
| 202 | {"result":"ACCEPTED","request_id":"<API requestId>"} | SQS SendMessage成功 |
| 400 | {"error_code":"INVALID_INPUT","request_id":"..."} | 型・必須・文字数・形式不正 |
| 400 | {"error_code":"BODY_TOO_LARGE","request_id":"..."} | アプリ本文上限超過 |
| 500 | {"error_code":"QUEUE_UNAVAILABLE","request_id":"..."} | SQS登録がSDK再試行後も失敗 |

認証失敗・未定義経路・基盤タイムアウト・スロットリングはGatewayの4xx/5xxを使用し、業務エラーとして書き換えない。202はDB登録成功を保証しない。同一社員の内容比較は登録Lambdaだけで行う。

## 5. 呼出し権限

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

ID管理システムからIAM署名付きで呼び出す。署名対象の本文バイト列を変更しない。処理仕様は[Lambda処理仕様](../02_アプリ/01_Lambda処理仕様.md)に定める。
