# replay_result.py 詳細設計書

## 1. 目的・呼出元

保留結果のDB限定再反映を行う。対象プログラムは`03_ワークフロー/02_資材/tools/maintenance/replay_result.py`である。

通常の02・03から呼ばない。障害対応時に--kindと--message-idを指定して手動実行する。

## 2. 関数・入出力

| 関数・引数 | 処理 | 戻り値・出力 |
| --- | --- | --- |
| `replay(sqs, invoke, queue, kind, message_id, function, expected)` | 指定メッセージの結果をDBへ再反映する。応答の成功を検証した場合だけSQSメッセージを削除する。 | 検証済みLambda応答辞書 |

## 3. 処理・分岐・外部操作

1. kindはdeliveryまたはexecution、message_idは非空を必須とする。EXPECTED_ACCOUNT_ID・AWS_REGION・CONNECTOR_ID・EXCHANGE_BUCKETと、対応するQUEUE_URL・RESULT_FUNCTIONを環境変数から読む。

2. SQSを最大20回、1件・WaitTimeSeconds=10・VisibilityTimeout=300で受信する。指定ID以外のメッセージは削除せず続行する（受信したメッセージの可視性には影響する）。

3. executionではrequestPayloadを取り出し、deliveryでは本文を使用する。normalize_resultで期待する接続先等を検証し、Lambdaへmode=db_onlyで同期呼出しする。

4. FunctionErrorがなく、応答のok=True、db=OK、s3=SKIPPED、filename一致を必須とする。余剰キーはignored_after_successのみ許容し、存在時はboolを必須とする。

5. 成功応答を検証した場合のみ元メッセージを削除し応答辞書を返す。不正入力はINVALID_INPUT、失敗応答はREPLAY_FAILED、20回で未発見ならMESSAGE_NOT_FOUND。自動再投入は行わない。

## 4. 異常終了・再実行

主な停止理由は`INVALID_INPUT`、`MESSAGE_NOT_FOUND`、`REPLAY_FAILED`。

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
