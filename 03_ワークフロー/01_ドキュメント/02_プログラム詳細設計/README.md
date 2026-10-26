# プログラム詳細設計

プログラムファイルごとに、呼出元、関数・引数・戻り値、処理順序、分岐、外部操作、停止条件、待機・再実行を定義する。通常ワークフローから呼ばない独立試験・保守用プログラムも、各文書の呼出元で区別する。

| プログラム | 詳細設計書 |
| --- | --- |
| `deployment/build.py` | [Lambda配布ZIPの作成](01_build.md) |
| `deployment/setup_sftp.py` | [SFTP設定とホスト公開鍵取得](02_setup_sftp.md) |
| `environment.py` | [環境操作・状態確認の実行制御](03_environment.md) |
| `maintenance/replay_result.py` | [保留結果のDB限定再反映](04_replay_result.md) |
| `paths.py` | [資材パスの解決](05_paths.md) |
| `shared/deployment_runtime.py` | [ECSタスクの実行とState読取](06_deployment_runtime.md) |
| `status/security_inventory.py` | [共有セキュリティ設定の所有確認](07_security_inventory.md) |
| `02_資材/02_temporary/app/tools/migrate.py` | [DB構造・権限の更新](08_migrate.md) |

## CIテストプログラム

| プログラム | 詳細設計書 |
| --- | --- |
| `04_テスト/workflows/test_terraform_workflow.py` | [ワークフローの模擬実行テスト](09_test_terraform_workflow.md) |
