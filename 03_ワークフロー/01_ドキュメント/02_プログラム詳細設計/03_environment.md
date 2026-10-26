# environment.py 詳細設計書

## 1. 目的・呼出元

環境操作・状態確認の実行制御を行う。対象プログラムは`03_ワークフロー/02_資材/tools/environment.py`である。

02・03のYAMLからモジュールとして起動する。

## 2. 関数・入出力

| 関数・引数 | 処理 | 戻り値・出力 |
| --- | --- | --- |
| `run(*command, capture=False, input=None, check=True)` | 外部コマンドを引数リストで実行する。capture=Trueなら標準出力・エラーを取得し、通常ログへ流さない。 | subprocess.CompletedProcess |
| `tf(stack, *args, **kwargs)` | 環境名からTerraformの作業ディレクトリを選び、標準CLIを実行する。 | subprocess.CompletedProcess |
| `aws(*args)` | AWS CLIの結果を文字列として取得する。参照か変更かは渡すサブコマンドで決まる。 | 標準出力の前後空白を除いた文字列 |
| `helper(module, *args, input=None)` | 現在と同じPythonで補助モジュールを起動する。秘密を含むJSONは必要に応じ標準入力で渡す。 | None |
| `required(name)` | 必須環境変数を取得する。未設定・空文字なら後続処理を止める。 | 非空の環境変数値 |
| `initialize(stack)` | S3バケット名を渡してterraform initを行い、既存の依存ロックを維持する。 | None |
| `state_list(stack)` | State内の管理アドレスを列挙する。State未作成は空扱い、権限不足などはエラーとして停止する。 | 管理アドレスのリスト |
| `resources(stack)` | terraform showのJSONからリソース属性を取得する。現在の構成はroot_module直下を対象とする。 | アドレスをキーとする属性辞書 |
| `persistent_inputs(operation, work)` | 常設の通知先を設定する。apply時だけ、State用S3にTLS必須ポリシーを追加・更新する。 | None。TF_VAR_budget_emailと必要時S3ポリシーを更新 |
| `temporary_inputs(entries, work)` | Lambda ZIPをローカル生成し、Stateの既存値や初回plan用の仮値をTerraform変数へ設定する。 | None。TF_VAR_*とローカル資材を更新 |
| `plan(stack, planfile, *options)` | Terraformの変更計画をファイルへ保存する。AWSリソースへの変更は適用しない。 | None。保存計画ファイルを生成 |
| `apply(stack, planfile, *options)` | この実行内で計画を作り直し、その保存planを適用する。別runの事前planは引き継がない。 | None。保存計画を適用 |
| `apply_temporary(planfile)` | ECR公開→SFTP先行構築・設定→DB更新→Web適用の順に一時環境を作成・変更する。 | None。段階構築を実行 |
| `execute(stack, operation, work)` | 初期化と入力準備を共通実行し、状態確認・計画・適用・削除へ分岐する。 | 終了コード（正常0） |
| `main()` | CLI引数とUIのmodeを解釈し、一時ファイル権限・終了コード・エラー表示を管理する。 | 終了コード、または各CLIの処理完了（本文参照） |

## 3. 処理・分岐・外部操作

1. mainが引数を検証し、--modeを内部操作へ変換する。apply+planはplan、destroy+planはdestroy-plan、destroy+applyはdestroyとなる。不正引数はargparseが終了コード2で拒否する。

2. umaskを077とし、AWS_REGIONの未設定時はap-northeast-1、TF_IN_AUTOMATION=true、TF_INPUT=falseを設定する。RUNNER_TEMP配下の一時領域を確保してexecuteへ渡す。

3. executeはinitialize→state_listを実行する。旧TLS管理情報が残る常設環境の削除を拒否する。status・削除でStateが空ならEMPTY_STATEを表示し0で終了する。

4. persistent_inputsは通知先をTF_VAR_budget_emailへ設定する。applyでは通知先を必須とし、既存S3ポリシーの同じSidだけを置き換えてTLS拒否設定を更新する。planではAWSポリシーを変更しない。

5. temporary_inputsはZIP生成後、旧aws_transfer_connector.vendorを拒否する。Stateのmigrationイメージ・実ホスト鍵を再利用し、不在時はゼロdigestの仮URIとECDSA 256ビットの計画用鍵を生成する。日次処理は既存ENABLEDの場合のみtrue、WebはAuto Scaling targetがあれば2、なければ0を指定する。

6. planは保存計画を生成してshowする。一時環境のSecurity HubアカウントがStateにない場合はBOOTSTRAP（EC2・EIP・SFTP Secret・Security Hubと依存先）を対象とする。applyは同一実行内で再計画したファイルを適用する。

7. 一時環境applyでは通知先必須確認→共有設定の所有確認→Docker build/push→ECR digest取得→BOOTSTRAP適用→SSM接続待ち→SFTP設定・実鍵取得の順に処理する。digestがsha256:で始まらなければ停止する。

8. WebのAuto Scaling targetがない場合は初回と判定し、Web 0台で全体適用する。更新時はmigrationタスク定義をtarget適用する。Terraform Outputsをdeployment_runtimeへ渡してDB更新の成功を待ち、全体適用する。初回はWeb 2台を指定しecs update-serviceも実行する。

9. 削除はplan -destroy→show→apply選択時のみ保存計画適用の順とする。常設環境の削除実行では一時環境を初期化してState残存を検査し、残存時はDELETE_TEMPORARY_FIRSTで停止する。

10. statusはState一覧とplan -detailed-exitcodeを表示する。終了2は差分ありとして0へ変換し、その他の終了コードを返す。

### 定数

| 定数 | 定義 |
| --- | --- |
| `DIRECTORIES` | `{'persistent': '02_資材/01_persistent', 'temporary': '02_資材/02_temporary/terraform'}` |
| `BOOTSTRAP` | `('aws_instance.vendor', 'aws_eip.vendor', 'aws_secretsmanager_secret.sftp', 'aws_securityhub_account.portfolio')` |

## 4. 異常終了・再実行

主な停止理由は`BACKEND_STATE_MIGRATION_REQUIRED: run persistent plan/apply once before destroy.`、`DELETE_TEMPORARY_FIRST`、`ECR_DIGEST_NOT_FOUND`、`Legacy connector state requires migration before simplified workflow`、`SSM_NOT_ONLINE`。

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
