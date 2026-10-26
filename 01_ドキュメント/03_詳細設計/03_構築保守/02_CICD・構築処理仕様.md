# CI/CD・構築処理仕様

現行の3本のワークフロー、入力、コマンド、補助Python、順序、制約は[03_ワークフロー](../../../03_ワークフロー/README.md)を正とする。

CIはPython構文、ワークフロー模擬実行、Terraform fmt/validateを検証する。AWS認証・業務テストは行わない。

環境操作はUbuntu上で既存OIDC認証を使い、Terraform CLIを実行する。StateはS3に常設・一時を分離して保存する。作成・変更は共通のplan/apply。削除はplan -destroy/apply。置換・定義削除も標準動作として許可する。

一時の初回はSFTPホスト鍵が作成後に確定するため、先行対象を適用して設定・鍵取得後に全体を適用する。DB migration完了後にWebを起動する。変更もSFTP置換とmigration先行に対応し、既存Web台数はAuto Scalingへ委ねる。計画の範囲・段階は[ワークフロー概要](../../../03_ワークフロー/01_ドキュメント/01_ワークフロー概要.md)を参照。

削除は一時→常設。State用S3・TLSポリシー・OIDC実行基盤は保持する。旧State内のbackendポリシーは02の常設環境・作成変更のapplyでremoved/destroy=falseを適用して管理を分離する。destroyではこの保持指定が効かないため、旧登録が残る場合は02の常設環境・削除を停止し、常設環境・作成変更での分離を先に案内する。新規環境ではbackendポリシーを環境Stateへ登録しない。ログ保持期間の通常設定は維持し、環境削除ではログも削除する。KMSは削除待機期間を持つ。

03_Terraform状態確認はTerraform state listとplanによる定義差分の確認であり、アプリ・プロセス・業務・管理外リソースの正常性を保証しない。

