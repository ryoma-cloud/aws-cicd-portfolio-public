# deployment_runtime.py 詳細設計書

## 1. 目的・呼出元

ECSタスクの実行とState読取を行う。対象プログラムは`03_ワークフロー/02_資材/tools/shared/deployment_runtime.py`である。

通常applyはTerraform output -jsonを標準入力に渡して起動する。read_stateは独立試験から利用する。

## 2. 関数・入出力

| 関数・引数 | 処理 | 戻り値・出力 |
| --- | --- | --- |
| `task(outputs, command)` | 指定コマンドをECS Fargateタスクで実行し、停止待ちとコンテナ終了コードの確認を行う。 | None（失敗は例外） |
| `read_state(allow_absent=False)` | 独立した受入試験用にS3から一時環境Stateを読む。許可された場合だけState未作成を空扱いにする。 | State辞書 |

## 3. 処理・分岐・外部操作

1. CLIはTerraform Outputsのvalueを取り出し、taskへpython tools/migrate.pyを渡す。taskはcluster_name・migration_task_definition・private_subnet_ids・migration_security_groupを参照する。

2. Fargateをprivate subnetへ、assignPublicIp=DISABLEDで起動する。failuresが存在する、またはtasksが空の場合はTASK_START_FAILEDとする。

3. tasks_stopped waiterをDelay=10秒・MaxAttempts=60で実行する。停止後の先頭コンテナexitCodeが0でない場合はTASK_FAILEDとする。waiter/APIエラーも伝播する。戻り値はNone。

4. read_stateはTF_STATE_BUCKETの一時環境Stateを取得して辞書を返し、Bodyを必ず閉じる。allow_absent=Trueの場合のみNoSuchKey・404を空のresources/outputsとして扱う。その他のエラーは伝播する。

## 4. 異常終了・再実行

主な停止理由は`TASK_FAILED`、`TASK_START_FAILED`。

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
