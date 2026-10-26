# Python補助ツール

処理部品ごとの目的・入出力・異常時の停止条件は[プログラム詳細設計](../../01_ドキュメント/02_プログラム詳細設計/README.md)、呼出し順と依存関係は[ワークフロー概要](../../01_ドキュメント/01_ワークフロー概要.md)を参照する。

GitHub Actionsは`environment.py`を入口としてTerraform CLIを実行する。Terraformによる依存関係の解決を基本とし、SFTP設定・DBマイグレーション等の順序制御だけPythonで補完する。

| ファイル | 用途 |
| --- | --- |
| `environment.py` | 環境作成・変更・削除・Terraform Stateと差分の確認 |
| `deployment/build.py` | Lambda ZIP・manifest生成 |
| `deployment/setup_sftp.py` | SSM経由のSFTP初期設定・ホスト公開鍵の取得 |
| `shared/deployment_runtime.py` | ECSマイグレーションタスクの起動・終了確認 |
| `status/security_inventory.py` | 構築前のセキュリティ設定の所有範囲確認 |
| `maintenance/replay_result.py` | 障害時の結果再反映と成功後のSQSメッセージ削除 |
| `paths.py` | 資材ディレクトリの共通パス定義 |

環境操作の入口と呼出し順序は[プログラム詳細設計](../../01_ドキュメント/02_プログラム詳細設計/README.md)および[ワークフロー概要](../../01_ドキュメント/01_ワークフロー概要.md)に記載する。本フォルダには環境操作・状態確認・保守に使用するコードを配置し、ワークフローの模擬実行テストは[04_テスト](../../../04_テスト/README.md)に配置する。
