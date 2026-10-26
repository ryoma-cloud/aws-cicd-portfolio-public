# CIテストコード

本フォルダには、GitHub Actionsで実行するワークフローの模擬実行テストを配置する。システム全体のテスト方針・確認項目は[テスト資料](../01_ドキュメント/04_テスト/README.md)に定義する。

## 1. 構成・検証範囲

| ファイル | 確認内容 |
| --- | --- |
| [test_terraform_workflow.py](workflows/test_terraform_workflow.py) | 環境操作の入力分岐、外部コマンドの呼出順序、失敗時の停止、State保護、ワークフロー定義との整合 |

Terraform・AWS CLI・Docker等を模擬コマンドに置き換えて実行する。AWSへの接続や実リソースの変更は行わない。AWS APIの実動作、IAM権限の充足、アプリケーションの業務処理、および実環境の疎通は確認範囲に含めない。

## 2. 実行方法

Python 3.13とPyYAML 6.0.3を使用する。Linux上で、リポジトリのルートから実行する。

```bash
python -m pip install PyYAML==6.0.3
python -m unittest discover -s 04_テスト/workflows -p 'test_*.py' -v
```

GitHub Actionsの[CI定義](../.github/workflows/01_ci.yml)では、上記に加えてPythonの構文確認、Terraformの書式確認、およびバックエンド接続を無効化した初期化・定義検証を実行する。CIの成功はこれらの検査に合格したことを示し、AWS実環境での業務・運用試験の合格とは区別する。
