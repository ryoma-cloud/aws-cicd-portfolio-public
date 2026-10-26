# setup_sftp.py 詳細設計書

## 1. 目的・呼出元

SFTP設定とホスト公開鍵取得を行う。対象プログラムは`03_ワークフロー/02_資材/tools/deployment/setup_sftp.py`である。

environment.apply_temporaryから--instance・--secret・--outを指定して起動する。

## 2. 関数・入出力

| 関数・引数 | 処理 | 戻り値・出力 |
| --- | --- | --- |
| `ssm_command(ssm, instance, commands)` | EC2へSSMコマンドを送信し、成功まで待つ。失敗または待機期限超過なら停止する。 | SSMコマンドの標準出力文字列 |
| `setup(sm, ssm, instance, secret)` | SFTP認証鍵を再利用またはSecretへ保存し、EC2のユーザー・sshdを設定してホスト公開鍵を返す。 | ホスト公開鍵のリスト |
| `ensure(sm, ssm, instance, secret)` | EC2に既存設定があればホスト公開鍵を再利用し、未設定ならsetupで初期化する。 | 再利用または初期設定したホスト公開鍵のリスト |
| `verify_connector(transfer, ec2, connector, group)` | Connectorの同時接続数とSGの許可元IPを照合する。設定の自動修復はしない。 | None（不一致は例外） |

## 3. 処理・分岐・外部操作

1. ensureはSSMでsshd設定とauthorized_keysを確認し、ECDSA公開鍵を1件取得できた場合は再利用する。それ以外はsetupを実行する。

2. setupはSecretから認証秘密鍵を再利用する。ResourceNotFoundExceptionの場合のみRSA 3072ビット鍵を生成し、UsernameとPrivateKeyをSecretへ保存する。他のAPIエラーは伝播する。

3. SSM経由でbadge_sftpユーザ、chrootディレクトリ、authorized_keys、sshd設定を作成する。パスワード認証・rootログイン・転送機能を禁止し、sshd -t成功後にsshdを再起動する。

4. ssm_commandはAWS-RunShellScriptをTimeoutSeconds=120で起動し、180秒の期限まで2秒間隔で照会する。InvocationDoesNotExistは待機を続行する。Success時に標準出力を返し、Failed・TimedOut・Cancelled・CancellingはSSM_COMMAND_FAILED、期限超過はSSM_TIMEOUTとする。

5. setupはECDSAホスト公開鍵がちょうど1件でなければHOST_KEY_UNAVAILABLEとする。CLIはsftp_host_keys配列を指定JSONへ保存する。秘密鍵を出力しない。

6. verify_connectorは独立試験用で通常applyから呼ばない。同時接続数1、TCP/22のみ、許可元IPv4がConnector送信元IPの/32と完全一致することを検査し、不一致なら停止する。設定修復は行わない。

## 4. 異常終了・再実行

主な停止理由は`CONNECTOR_CONCURRENCY_MISMATCH`、`CONNECTOR_EGRESS_UNAVAILABLE`、`CONNECTOR_SECURITY_GROUP_MISMATCH`、`HOST_KEY_UNAVAILABLE`、`SSM_COMMAND_FAILED`、`SSM_TIMEOUT`。

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
