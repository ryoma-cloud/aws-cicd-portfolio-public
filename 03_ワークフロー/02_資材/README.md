# ワークフロー資材

補助プログラムの入出力・停止条件は[プログラム詳細設計](../01_ドキュメント/02_プログラム詳細設計/README.md)、実行順序の根拠は[ワークフロー概要](../01_ドキュメント/01_ワークフロー概要.md)に示す。

入口は`python -m tools.environment <persistent|temporary> <plan|apply|destroy-plan|destroy|status>`。Terraform操作を共通化し、SFTP鍵確定・migration前後の段階だけを制御する。

補助Pythonの用途は[tools/README.md](tools/README.md)を参照。業務アプリは`02_資材/02_temporary`、試験は`04_テスト`に配置する。YAMLは実行環境・OIDC・入力とPython起動を担当する。

