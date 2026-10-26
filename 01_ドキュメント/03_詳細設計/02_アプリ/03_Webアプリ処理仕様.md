# Webアプリ 処理仕様

## 1. 機能・画面

ECS/Fargateで1つの参照画面を提供する。Flask + Jinja2のサーバ側HTML生成とし、SPA・専用管理API・認証基盤は追加しない。スタイルはHTMLテンプレート内に同梱し、JavaScriptおよび外部CDNは使用しない。PCは白背景・青基調、スマートフォンは条件欄を縦、表は横スクロール。

| Method / path | 入出力・処理 |
| --- | --- |
| GET / | 検索欄・状態・件数・一覧・前後ページ |
| GET /health | {"status":"ok"}、200、生存確認のみ |
| GET /ready | ReaderへSELECT 1、成功200・失敗503 |
| その他path / method | 404 / 405、DB更新しない |

## 2. 検索入力

| query | 値・既定値 | 検証 |
| --- | --- | --- |
| q | 検索文字列、既定空 | 最大100文字、前後空白を検索時のみ除去 |
| status | REQUESTED/SENT/SEND_FAILED、既定空（すべて） | 定義外は400 |
| page | 1以上整数、既定1 | 数字以外・0以下は400 |
| 1ページ件数 | 50固定 | パラメータから変更不可 |

psycopgとSQLAlchemy QueuePool（接続プール用途のみ）を使い、SQL値はバインド。qの%・_・バックスラッシュをLIKE用にエスケープし、ユーザ入力をワイルドカードとして扱わない。

| 条件 | SQLの意味 |
| --- | --- |
| qあり | employee_nameの部分一致 OR employee_id完全一致 OR badge_number完全一致 |
| statusあり | 上記検索とANDで状態一致 |
| qなし | 文字列検索条件なし |
| 並び | received_at DESC、employee_id ASC |
| ページ | OFFSET=(page-1)*50、LIMIT=50 |

要求のCOUNTと一覧は同じ参照トランザクションを使う。件数0は空表示。ページが最終ページを超えた場合は最終ページへ302で補正し、0件なら1ページ。検索ボタンはpage=1、クリアは/へ戻す。ページリンクでq・statusをURLエンコードして維持する。自動更新なし。

## 3. 表示項目・エラー

| 内部値 | 画面表示 |
| --- | --- |
| employee_id / employee_name / company_name | 社員番号 / 氏名 / 所属会社名 |
| badge_number | 入館証番号 |
| REQUESTED | 入館証発行依頼待ち |
| SENT | 入館証発行依頼済み |
| SEND_FAILED | 入館証発行依頼失敗 |
| updated_at | YYYY/MM/DD HH:mm:ss（JST） |
| 0件 | 該当する発行対象はありません。 |
| 入力不正 | 検索条件を確認してください。（400） |
| DB/Secret利用不可 | データを取得できません。時間をおいて再度お試しください。（503） |

HTMLはJinja2 autoescapeを有効とし、業務値をsafe扱いしない。検索条件はGETクエリとしてURLに含まれ、ページ移動時にも維持する。gunicorn/werkzeugの既定アクセスログは無効にし、Flaskのリクエスト前後フックでpath・status・duration_msをJSON記録する。pathは定義済みルートの形式を使用し、未定義パスは固定値`<unmatched>`とする。クエリ文字列・氏名・会社名・要求本文・生の例外本文は記録しない。DB照会失敗は`WEB_DB_UNAVAILABLE`、画面生成失敗は`WEB_RENDER_FAILED`、/readyの失敗は`WEB_READY_UNAVAILABLE`で記録する。Cache-Control=no-store、X-Content-Type-Options=nosniff、frame-ancestors 'none'を設定する。

## 4. 処理順序

| 順 | 処理 | 失敗 |
| --- | --- | --- |
| 1 | query検証 | 400画面、DB接続なし |
| 2 | Secret取得、Readerのプールから接続取得 | 503 |
| 3 | READ ONLY REPEATABLE READでCOUNT・一覧 | rollback、503 |
| 4 | 日時・状態を表示値へ変換 | 未定義状態は内部エラーとして記録 |
| 5 | エスケープしてHTML応答、接続返却 | 例外時接続を破棄 |

DBプール最大2、overflow=0、pool timeout=3秒。接続・SQL timeoutは06に従う。/readyはSELECT 1が可能かだけを確認し、Writerへの直接接続や書込は行わない。

Readerへの反映に伴う短い参照遅延は許容する。
