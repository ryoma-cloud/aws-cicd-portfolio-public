# build.py 詳細設計書

## 1. 目的・呼出元

Lambda配布ZIPの作成を行う。対象プログラムは`03_ワークフロー/02_資材/tools/deployment/build.py`である。

environment.temporary_inputsから起動する。plan・削除・statusでも非空State等の条件により実行する。

## 2. 関数・入出力

| 関数・引数 | 処理 | 戻り値・出力 |
| --- | --- | --- |
| `build()` | 固定日時・並び順で依存ライブラリとLambdaをZIP化し、SHA-256のmanifestをローカル生成する。AWSへは配布しない。 | ZIP名をキーとするSHA-256辞書 |

## 3. 処理・分岐・外部操作

1. TEMP_ROOTのterraform/buildとapp/certsを準備する。RDS CA証明書がなければHTTPSで取得する（タイムアウト30秒）。

2. 既存stagingを削除して作り直し、requirements.lockをpip install --targetで導入する。commonとcertsをコピーする。

3. employee_intake、employee_register、request_batch、transfer_result、resend、id_mockの6つをZIP化する。収録順をソートし、日時を2020-01-01に固定する。id_mockのみid_system_simulator/handler.pyをapp.pyとして収録する。

4. 各ZIPのSHA-256をmanifest.jsonへ保存し、同じ辞書を返す。アップロードとLambda更新はTerraformが担当する。

## 4. 異常終了・再実行

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
