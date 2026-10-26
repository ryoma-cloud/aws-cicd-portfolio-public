# test_terraform_workflow.py 詳細設計書

## 1. 目的・呼出元

GitHub Actionsの環境操作について、入力分岐、Terraform・補助プログラムの呼出順序、計画と適用の区別、異常時の停止、Terraform State保護、およびワークフロー定義との整合を自動検証する。

対象プログラムは`04_テスト/workflows/test_terraform_workflow.py`である。テスト対象は主に`03_ワークフロー/02_資材/tools/environment.py`と`.github/workflows/02_environment.yml`である。

`.github/workflows/01_ci.yml`から`unittest`として実行する。通常の環境操作ワークフローや状態確認ワークフローから本プログラムは呼び出さない。AWS認証・AWS APIへの接続・実リソースの作成変更削除は行わない。

## 2. 構成・関数・入出力

| 構成要素 | 役割 | 入力 | 戻り値・出力 |
| --- | --- | --- | --- |
| `ROOT` | テストファイルの2階層上を対象リポジトリのルートとして解決する。 | 本ファイルのパス | `Path` |
| `ENTRY` | 実際に検証する環境操作CLIを指定する。 | `ROOT` | `03_ワークフロー/02_資材/tools/environment.py`のパス |
| `MOCK` | 外部CLI・補助Pythonモジュールの代替プログラム。コマンド記録、模擬応答、障害注入を行う。 | 実行コマンド・環境変数 | 模擬標準出力、ファイル、終了コード、コマンド履歴 |
| `WorkflowSmoke.exercise(stack, operation, state="", extra=None, mode=None)` | テスト単位の一時実行環境を構築し、実物の`environment.py`を別プロセスで起動する。 | 環境種別、操作、模擬State、追加環境変数、UIのmode | `(subprocess.CompletedProcess, list[str])`。前者は標準出力・標準エラー・終了コード、後者は記録したコマンド列 |
| `WorkflowSmoke` | 模擬CLIによる環境操作の動作確認。 | `exercise`で作った実行結果 | `assert`による合否 |
| `WorkflowSyntax` | ワークフロー・共通ActionのYAMLおよび`run`に埋め込まれたPythonの検証。 | `.github/workflows/*.yml`、`.github/actions/**/*.yml` | `assert`による合否 |
| `UnifiedWorkflowInputs` | ワークフロー②の入力定義と`environment.py`起動引数の対応を検証する。 | `02_environment.yml`と環境変数 | `assert`による合否 |

`unittest.TestCase`の各`test_*`メソッドがテストケースであり、合格時の業務データなどの戻り値は持たない。失敗は`AssertionError`または実行時例外として`unittest`が記録する。定義済みのテストメソッドは計26個であり、`subTest`によって複数の条件を検査するケースもある。

## 3. 模擬実行方式

### 3.1 `exercise`の処理順序

| 番号 | 処理内容 |
| --- | --- |
| ① | `TemporaryDirectory`でテストごとに独立した一時領域を作成する。 |
| ② | `bin`配下に、`terraform`、`aws`、`docker`、`ssh-keygen`という実行可能な模擬CLIを生成する。 |
| ③ | `workspace`配下に必要なディレクトリと、`build`、`setup_sftp`、`deployment_runtime`、`security_inventory`の模擬モジュールを作成する。 |
| ④ | 環境変数から既存の`MOCK_*`、`TF_VAR_*`、`FAIL_MATCH`を除外し、`PATH`、`PYTHONPATH`、`MOCK_LOG`、`MOCK_STATE`、`TF_STATE_BUCKET`、`NOTIFICATION_EMAIL`、`GITHUB_SHA`、`RUNNER_TEMP`などをテスト用に設定する。`extra`があれば上書きする。 |
| ⑤ | `[sys.executable, ENTRY, stack, operation]`に必要に応じて`--mode`を追加し、`workspace`を作業ディレクトリとして別プロセス起動する。タイムアウトは30秒である。 |
| ⑥ | プロセスの終了コード・標準出力・標準エラーを取得し、模擬コマンドが`MOCK_LOG`へ記録した呼出履歴を読み込む。 |
| ⑦ | `CompletedProcess`とコマンド履歴の組を呼出元のテストに返す。一時領域はコンテキスト終了時に削除する。 |

実物の`environment.py`の分岐・実行制御は通すが、外部CLIと一部の補助モジュールは模擬処理に置換する。したがって、コマンドの「実行要求」や「順序」は検証できるが、Terraform・AWS・Docker・SFTP処理の実際の成功は検証しない。

### 3.2 模擬応答・障害注入

| 環境変数 | 使用目的 |
| --- | --- |
| `MOCK_STATE` | `terraform state list`の管理アドレス一覧を模擬する。 |
| `MOCK_TEMP_STATE` | 常設環境削除時など、一時環境のStateを別内容で模擬する。 |
| `MOCK_STATE_ERROR` | State一覧取得の失敗とエラーメッセージを模擬する。 |
| `MOCK_PLAN_EXIT` | `terraform plan -detailed-exitcode`の終了コードを指定する。 |
| `MOCK_POLICY` | State保存先S3の既存バケットポリシー取得結果を模擬する。 |
| `MOCK_POLICY_ERROR` | バケットポリシー取得の失敗を模擬する。 |
| `FAIL_MATCH` | コマンド文字列に指定値が含まれると、該当する模擬コマンドを終了コード1で失敗させる。 |
| `MOCK_LOG` | 呼び出されたコマンドを順番に記録するファイルを指定する。 |

模擬CLIは必要に応じてState表示、Terraform出力JSON、ECRのイメージURIとdigest、SFTPホスト公開鍵、SSM接続状態、S3ポリシーを固定値で返す。`put-bucket-policy`の入力ポリシーはコマンド履歴へ`POLICY`として記録し、内容の検証に使用する。

## 4. テストケース詳細

### 4.1 `WorkflowSmoke`：環境操作の分岐・制御（23件）

| テスト関数 | 試験条件・操作 | 合格条件 |
| --- | --- | --- |
| `test_plan_is_read_only` | 常設環境の`plan`を実行する。 | 終了0、`terraform plan`を呼ぶ、`terraform apply`を呼ばない。 |
| `test_apply_accepts_replace` | 常設環境の`apply`を実行する。 | 終了0、`terraform apply`の呼出が1回。※このテスト自体は`-replace`指定値を検証しない。 |
| `test_temporary_update_migrates_before_web` | 既存Auto Scaling targetなどを含むStateで一時環境を更新する。 | migration定義のtarget適用要求 → DB更新モジュール → 最後の通常planの順。SFTP設定処理を呼び、`aws ecs update-service`を直接呼ばない。 |
| `test_temporary_new_orders_sftp_db_web` | Stateが空の一時環境を作成する。 | SFTP設定 → DB更新 → ECSサービス起動要求の順で、Terraform適用要求が計3回。 |
| `test_destroy_plan_has_no_apply` | 一時環境の`destroy-plan`を実行する。 | `terraform plan -destroy`を呼び、適用しない。 |
| `test_destroy_applies` | 一時環境の`destroy`を実行する。 | `terraform apply`を1回呼ぶ。 |
| `test_status_plans` | Stateが存在する常設環境の`status`を実行する。 | `plan -detailed-exitcode`を呼び、終了0。 |
| `test_status_reports_drift` | 状態確認のplan終了コードを2とする。 | 差分ありを示す文言を出力し、CLIは終了0。 |
| `test_empty_state_status` | Stateが空の常設環境を状態確認する。 | `EMPTY_STATE`を表示し、差分用planを実行しない。 |
| `test_temporary_plan_does_not_publish_or_initialize` | Stateが空の一時環境で`plan`を実行する。 | `BOOTSTRAP_PLAN_ONLY`を表示し、適用・Docker処理・SFTP初期設定を行わない。 |
| `test_status_propagates_plan_error` | 状態確認のplan終了コードを1とする。 | CLIが終了1となる。 |
| `test_partial_initial_apply_keeps_web_stopped_until_migration` | 一時環境のStateにECSサービスとConnectorが存在し、初回構築の途中から再開する。 | Terraform適用要求が3回あり、`ecs update-service`を呼ぶ。※Web停止中の状態そのものを観測する試験ではない。 |
| `test_persistent_destroy_rejects_live_temporary_dependencies` | 一時環境Stateに管理リソースを残したまま常設環境を削除する。 | 非正常終了、`DELETE_TEMPORARY_FIRST`を表示し、適用しない。 |
| `test_backend_policy_stays_outside_destroy` | 通常の常設環境削除を実行する。 | 終了0、`terraform state rm`および`put-bucket-policy`を呼ばない。 |
| `test_destroy_never_deletes_legacy_backend_policy` | 常設Stateに旧`aws_s3_bucket_policy.state_tls[0]`が残る状態で`destroy-plan`と`destroy`を検証する。 | いずれも非正常終了、`BACKEND_STATE_MIGRATION_REQUIRED`を表示し、削除plan・適用をしない。 |
| `test_failures_stop_following_stages` | Docker build、SFTP設定、DB更新モジュールをそれぞれ失敗させる。 | 各条件で終了1、失敗した呼出が履歴末尾になり、後続の`ecs update-service`を呼ばない。 |
| `test_plan_failure_prevents_apply` | 常設環境apply中のplanを失敗させる。 | 終了1、適用しない。 |
| `test_state_errors_are_not_empty_state` | State取得で`AccessDenied`を返す。 | 終了1、`EMPTY_STATE`と誤表示せず、plan・適用を実行しない。 |
| `test_missing_state_is_empty` | State取得で`No state file was found`を返す。 | 終了0、`EMPTY_STATE`を表示する。 |
| `test_backend_policy_preserves_existing_statements` | 既存StatementのあるS3ポリシーを返して常設applyする。 | 既存Statementを維持し、`PortfolioRequireSecureTransport`が1件となり、模擬パスワードを標準出力・標準エラーに出さない。 |
| `test_policy_access_denied_stops_apply` | S3ポリシー取得で`AccessDenied`を返す。 | 終了1、ポリシー書換え・適用を実行しない。 |
| `test_ui_modes` | 常設／一時 × 作成・変更／削除 × 計画／適用の8組合せを実行する。 | 全条件で終了0、`mode=apply`のときだけTerraform適用要求を発行する。 |
| `test_invalid_arguments_do_not_run_commands` | 不正な環境名、操作、modeをそれぞれ渡す。 | 各条件で終了2、外部コマンド履歴が空。 |

### 4.2 `WorkflowSyntax`：YAML・実行ステップ形式（1件）

| テスト関数 | 試験条件・操作 | 合格条件 |
| --- | --- | --- |
| `test_yaml_and_python_steps` | `.github/workflows`直下のYAMLと`.github/actions`配下のYAMLを`yaml.BaseLoader`で読み、各`run`を検査する。 | ワークフローYAMLが3ファイル。`shell: python`の`run`が`compile`可能。それ以外の`run`は`python `で始まる単一行で、`shell: bash`を指定していない。旧`terraform.sh`が存在しない。 |

`yaml.BaseLoader`による構文の読取と上記の形式検査であり、GitHub Actionsのすべての構文・権限・実行時仕様を検証するものではない。

### 4.3 `UnifiedWorkflowInputs`：手動起動UIとCLIの整合（2件）

| テスト関数 | 試験条件・操作 | 合格条件 |
| --- | --- | --- |
| `test_all_input_combinations_reach_existing_cli` | `02_environment.yml`の`workflow_dispatch`、入力選択肢、ジョブ条件、排他制御、最終ステップを確認し、全8組合せの入力を模擬実行する。 | 入力は`stack=persistent/temporary`、`operation=apply/destroy`、`mode=plan/apply`（既定plan）。`main`ブランチ制約、`portfolio-environment`排他グループと`cancel-in-progress=false`、最終ステップの`shell: python`・入力環境変数が指定どおり。各入力が`python -m tools.environment <stack> <operation> --mode <mode>`に渡され、`run-name`にも各入力を反映する。 |
| `test_dispatch_failure_is_propagated` | 最終ステップから起動する子プロセスが`CalledProcessError`を送出する。 | エラーを握りつぶさず呼出元へ伝播する。 |

上記のYAML起動検証では`subprocess.run`を`unittest.mock.patch`で置換しており、CLI自体は起動しない。実物の`environment.py`の動作は第4.1節で別途検証する。

## 5. 判定・異常終了・試験の制約

各ケースは`assertEqual`、`assertTrue`、`assertFalse`、`assertIn`、`assertLess`、`assertRaises`などで期待値を判定する。分岐を複数回検証する箇所は`subTest`を使用する。模擬CLIの異常は原則終了コード1で表現し、引数検証エラーは2、Terraformの差分ありは2を想定する。各`exercise`呼出は30秒でタイムアウトする。試験用の一時領域は各呼出終了時に廃棄する。

本プログラムの試験範囲は制御フローと定義の一部であり、Terraform計画内容の妥当性、AWS上の実資源の状態、IAM権限、実際のSFTP通信、Dockerビルド成果物、DB更新結果、GitHub Actionsの実ランナー環境全体は確認できない。また、複数段階の適用回数・順序を確認するケースは、各段階のAWS側状態まで保証しない。

## 6. 実行方法

Python 3.13およびPyYAML 6.0.3を使用し、リポジトリのルートから実行する。

```bash
python -m pip install PyYAML==6.0.3
python -m unittest discover -s 04_テスト/workflows -p 'test_*.py' -v
```

GitHub Actionsでは`01_ci.yml`の「ワークフローの模擬実行テスト（AWS接続なし）」で実行する。テストが合格しても、AWS実環境への適用・疎通・運用試験が完了したことは意味しない。これらは別途実環境の検証記録によって判定する。
