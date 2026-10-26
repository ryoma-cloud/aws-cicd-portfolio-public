# ID管理システムモック 設計・仕様

## 1. 目的・構成

社員情報を本システムのAPIへ送信し、受付・重複防止・非同期登録を確認する。社員マスタや画面は作らず、VPC外のLambda 1関数で実現する。

| 項目 | 設計 |
| --- | --- |
| 起動 | GitHub Actionsの手動実行から、Lambdaを同期呼出し（`RequestResponse`） |
| 通信 | Lambda → 公開API Gateway、HTTPS・SigV4署名、1要求1人分 |
| 入力 | 起動イベントの`employees`配列、1～5件。負荷試験用ではない |
| 出力 | 入力順のHTTP受付結果と集計 |
| 保存 | CloudWatch Logsのみ。社員マスタ・再送キューは持たない |
| 対象外 | 定期送信、自動再送、DBへの直接接続、DB登録完了の待機 |

基本方式は[外部連携方式設計](../../02_基本設計/02_外部連携方式設計.md)に従う。本書はモックの実装仕様であり、AWS配置・試験完了を示さない。

## 2. 起動入力・API要求

### 2.1 起動イベント

```json
{
  "employees": [
    {
      "employee_id": "000001",
      "employee_name": "テスト 太郎",
      "company_name": "テスト株式会社"
    },
    {
      "employee_id": "000002",
      "employee_name": "テスト 花子",
      "company_name": "テスト株式会社"
    }
  ]
}
```

最上位は`employees`のみを持つJSONオブジェクトとする。配列は1～5個のJSONオブジェクトで構成する。構造不正・件数超過は送信開始前に入力エラーとして関数を異常終了し、APIを呼ばない。

各オブジェクトの業務項目はモックで検証・補完・変換しない。必須項目不足、空文字、型不正、余分な項目もそのまま送信し、本システムの入力検証を試験できるようにする。同じ社員番号も配列内で除去しない。

### 2.2 API接続仕様

| 項目 | 値・処理 |
| --- | --- |
| URL | 環境変数`API_ENDPOINT`の完全URL。起動入力では変更不可 |
| Method | `POST` |
| Path | `/employees`。ステージを含むURL全体は本システムの構築出力から取得 |
| Content-Type | `application/json; charset=utf-8` |
| JSON物理項目 | `employee_id`＝数字6桁の社員番号（文字列、先頭ゼロ保持）、`employee_name`＝氏名、`company_name`＝所属会社名 |
| 正常データ | 上記3項目を文字列で指定。社員番号は例のようなASCIIのテスト値を使用 |
| Body | 配列から取り出した1オブジェクト。`employees`の外側は送信しない |
| 文字列化 | `json.dumps(..., ensure_ascii=False, separators=(",", ":"))`をUTF-8化 |
| 署名 | Botocoreの`SigV4Auth`、サービス`execute-api`、リージョン`ap-northeast-1` |
| 認証情報 | Lambda実行ロールの一時認証情報。要求ごとに有効な認証情報を取得 |
| TLS | CAによるサーバ証明書検証を有効化 |
| 応答 | HTTPコードだけで判定。応答本文の項目・文言には依存しない |

**本システムとの接続契約：** メソッド・パス・JSON物理項目は本書と[社員情報受付APIの詳細設計](../../03_詳細設計/01_基盤/03_AWS_API_Gateway.md)で定義する。文字数上限等の業務検証は受付API側で行い、モックには重複実装しない。

## 3. 処理・異常時の動作

1. 設定と起動イベントを検証する。`API_ENDPOINT`はHTTPS、クエリ・フラグメントなし、パス末尾`/employees`とする。設定不正は送信前に異常終了する。
2. 入力順に1人ずつJSONバイト列を生成し、その同じバイト列とURL・ヘッダーに署名する。署名後に本文を再生成しない。
3. 署名付きヘッダーと本文を送信する。HTTPクライアントはurllib3を使用し、接続待ち3秒・読取待ち7秒、`retries=False`、`redirect=False`とする。応答本文を読み込まず接続を解放する。
4. 各人の結果を記録し、失敗しても後続を継続する。次の要求開始時にLambda残り時間が12秒未満なら、以降を`NOT_SENT`として送信せず集計する。
5. 全件の結果を返す。個人単位のHTTPエラーや通信例外では関数全体を異常終了させず、呼出し元が集計結果で成功・失敗を判定する。

| 条件 | `result` | `error_code` | 意味・再実行 |
| --- | --- | --- | --- |
| HTTP 202 | `ACCEPTED` | `null` | 要求受理。DB登録・入館証発行依頼の完了ではない |
| HTTP 400 | `FAILED` | `INVALID_INPUT` | 本文を修正して手動再連携 |
| HTTP 401 / 403 | `FAILED` | `AUTH_ERROR` | IAM・署名設定を確認 |
| HTTP 429 | `FAILED` | `THROTTLED` | 制限解消後に手動再連携 |
| HTTP 500～599 | `FAILED` | `API_ERROR` | 障害解消後に手動再連携 |
| 上記以外のHTTPコード | `FAILED` | `UNEXPECTED_STATUS` | 200を含め202以外は受付成功にしない。リダイレクト先へ送信しない |
| タイムアウト・通信・署名等の例外 | `FAILED` | `REQUEST_ERROR` | 受付成否不明の場合あり。同内容で再連携可能 |
| 残り時間不足で未送信 | `NOT_SENT` | `TIME_BUDGET` | その入力だけを後から実行 |

受理済みの同内容を再連携しても、本システム側で重複登録を防ぐ。同じ社員番号・異内容はAPIが202を返した後に非同期登録でDLQ隔離されるため、モックの`ACCEPTED`をDB登録成功と解釈しない。

### 3.1 戻り値・ログ

```json
{
  "total_count": 1,
  "accepted_count": 1,
  "failed_count": 0,
  "not_sent_count": 0,
  "results": [
    {
      "index": 0,
      "employee_id": "000001",
      "http_status": 202,
      "result": "ACCEPTED",
      "error_code": null
    }
  ]
}
```

`index`は0開始の入力位置。社員番号が文字列でなければ出力・ログの`employee_id`は`null`、HTTP応答がなければ`http_status`は`null`とする。各結果を1件ずつJSONログに記録し、`timestamp`（JST・ISO 8601）、`aws_request_id`、`duration_ms`を追加する。最後に集計ログを記録する。氏名・所属会社名・本文・署名ヘッダー・一時認証情報・生の例外メッセージは記録しない。

WorkflowはInvokeの通信成功、`FunctionError`なし、`failed_count=0`かつ`not_sent_count=0`をすべて満たす場合だけ成功とする。`ACCEPTED`は要求受理を表し、DB登録完了とは区別する。

## 4. パラメータ・権限

以下はモック用の採用値。AWS識別子は構築時に決まる入力であり、未決定の業務仕様ではない。

| パラメータ | 意味 | 既定値 | 設定値 | 理由 |
| --- | --- | --- | --- | --- |
| `function_name` | 関数名 | 指定必須 | `portfolio-id-system-mock` | 本システムと区別 |
| `runtime` | 言語 | 指定必須 | `python3.13` | サポート中のPythonを使用 |
| `handler` | 呼出し先 | 指定必須 | `app.lambda_handler` | ZIP内`app.py`の関数 |
| `architectures` | CPU | `x86_64` | `x86_64` | 小規模モックの構築を簡素化 |
| `memory_size` | メモリ | 128 MB | 128 MB | 少量の逐次送信 |
| `timeout` | 関数実行上限 | 3秒 | 60秒 | 最大5件を送信し、時間不足は未送信として返す |
| `vpc_config` | VPC接続 | なし | なし | 公開APIへ接続 |
| `API_ENDPOINT` | 接続先完全URL | アプリ独自・なし | 本システムの社員情報受付URL | ソースへ固定しない |
| `MAX_EMPLOYEES` | 起動件数上限 | アプリ定数 | 5 | 手動の機能確認に限定 |
| `retention_in_days` | ログ保持 | 無期限 | 90日 | 本体・モックのログ保持期間を統一 |
| `InvocationType` | 起動方式 | 呼出し側で指定 | `RequestResponse` | 結果をその場で確認、自動再送なし |

実行ロールの信頼先は`lambda.amazonaws.com`。権限は事前作成した`/aws/lambda/portfolio-id-system-mock`への`logs:CreateLogStream`・`logs:PutLogEvents`と、`execute-api:Invoke`だけとする。API権限のResourceは`arn:aws:execute-api:ap-northeast-1:<account-id>:<api-id>/<stage>/POST/employees`に限定する。API側は当該ルートを`AWS_IAM`認証とする。GitHub Actionsの起動ロールには当該関数への`lambda:InvokeFunction`を付与する。

Botocoreとurllib3、およびその依存をZIPへ同梱し、検証した組合せをロックファイルへ固定する。ライブラリ版の選定・更新は実装時に行い、Lambda同梱版との混在を避ける。Terraformでは関数・ログ・権限・環境変数を一時リソースとして管理する。

## 5. 実装の確認条件

| 入力・条件 | 期待結果 |
| --- | --- |
| 正常な社員情報1件 | 202・`ACCEPTED`。本システムでDB登録・採番 |
| 同じ正常入力を再実行 | 202。DBの件数・入館証番号・既存日時・状態は維持 |
| 同じ社員番号で氏名変更 | 202。その後の非同期登録で既存情報維持・DLQ隔離 |
| 必須項目なし／型不正 | モックから送信され、APIの400を`INVALID_INPUT`として記録 |
| 正常・不正・正常の3件 | 入力順に全件を送信し、各結果と件数を区別 |
| 403・500・通信例外 | 当該件を失敗扱いにして後続継続。自動再送なし |
| 200・302 | 失敗扱い。302で転送先へ署名付き要求を送らない |
| 6件／配列以外 | 送信開始前に入力エラー |
| 残り時間12秒未満 | 残りを`NOT_SENT`として戻り値に含める |

参考：[IAM認証とSigV4](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-access-control-iam.html)、[Lambdaランタイム・依存関係](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)。

