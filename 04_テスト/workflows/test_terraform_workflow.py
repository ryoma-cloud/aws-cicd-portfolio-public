"""Execute the Python CLI with fake external programs; never contacts AWS."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "03_ワークフロー/02_資材/tools/environment.py"
MOCK = r'''import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
command = name + " " + " ".join(args)
if name.endswith(".py"):
    modules = {"build": "tools.deployment.build", "setup_sftp": "tools.deployment.setup_sftp",
               "deployment_runtime": "tools.shared.deployment_runtime", "security_inventory": "tools.status.security_inventory"}
    command = "python -m " + modules[Path(name).stem] + (" " + " ".join(args) if args else "")
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(command + "\n")
if os.environ.get("FAIL_MATCH") and os.environ["FAIL_MATCH"] in command:
    print("mock command failed", file=sys.stderr)
    sys.exit(1)
if name == "terraform":
    if "state" in args and "list" in args:
        if os.environ.get("MOCK_STATE_ERROR"):
            print(os.environ["MOCK_STATE_ERROR"], file=sys.stderr)
            sys.exit(1)
        key = "MOCK_TEMP_STATE" if "02_temporary" in args[0] and "MOCK_TEMP_STATE" in os.environ else "MOCK_STATE"
        print(os.environ.get(key, ""))
    elif "show" in args and "-json" in args:
        image = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/portfolio-admin-web@sha256:" + "a" * 64
        resources = [
            {"address": "aws_ecs_task_definition.migration", "values": {"container_definitions": json.dumps([{"image": image}])}},
            {"address": "awscc_transfer_connector.vendor", "values": {"sftp_config": {"trusted_host_keys": ["ecdsa-sha2-nistp256 TUVTU0FHRQ=="]}}},
            {"address": "aws_instance.vendor", "values": {"id": "i-123"}},
        ]
        print(json.dumps({"values": {"root_module": {"resources": resources}}}))
    elif "plan" in args and "-detailed-exitcode" in args:
        sys.exit(int(os.environ.get("MOCK_PLAN_EXIT", "0")))
    elif "pull" in args or "output" in args:
        print("{}")
elif name == "aws":
    if "get-bucket-policy" in args:
        if os.environ.get("MOCK_POLICY_ERROR"):
            print(os.environ["MOCK_POLICY_ERROR"], file=sys.stderr)
            sys.exit(1)
        print(os.environ.get("MOCK_POLICY", '{"Version":"2012-10-17","Statement":[]}'))
    elif "put-bucket-policy" in args:
        policy = Path(args[args.index("--policy") + 1].removeprefix("file://")).read_text()
        with open(os.environ["MOCK_LOG"], "a") as log:
            log.write("POLICY " + policy + "\n")
    elif "get-caller-identity" in args:
        print("123456789012")
    elif "describe-repositories" in args:
        print("123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/portfolio-admin-web")
    elif "get-login-password" in args:
        print("test-password")
    elif "describe-images" in args:
        print("sha256:" + "a" * 64)
    elif "describe-instance-information" in args:
        print("Online")
elif name == "ssh-keygen":
    Path(args[args.index("-f") + 1] + ".pub").write_text("ecdsa-sha2-nistp256 TUVTU0FHRQ== temporary")
elif name == "setup_sftp.py":
    Path(args[args.index("--out") + 1]).write_text(json.dumps({"sftp_host_keys": ["ecdsa-sha2-nistp256 TUVTU0FHRQ=="]}))
elif name in ("deployment_runtime.py", "security_inventory.py") or (name == "docker" and "login" in args):
    sys.stdin.read()
'''


class WorkflowSmoke(unittest.TestCase):
    # 偽のCLI・補助モジュールを用意して実際の入口を起動し、終了結果とコマンド履歴を返す。AWSへは接続しない。
    def exercise(self, stack, operation, state="", extra=None, mode=None):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            bin_dir = base / "bin"
            bin_dir.mkdir()
            for name in ("terraform", "aws", "docker", "ssh-keygen"):
                exe = bin_dir / name
                exe.write_text("#!" + sys.executable + "\n" + MOCK)
                exe.chmod(0o755)
            workspace = base / "workspace"
            (workspace / "02_資材/02_temporary/terraform").mkdir(parents=True)
            for path in ("tools/deployment/build.py", "tools/deployment/setup_sftp.py",
                         "tools/shared/deployment_runtime.py", "tools/status/security_inventory.py"):
                module = workspace / path
                module.parent.mkdir(parents=True, exist_ok=True)
                module.write_text(MOCK)
            log = base / "commands.log"
            env = {k: v for k, v in os.environ.items() if not k.startswith(("MOCK_", "TF_VAR_")) and k != "FAIL_MATCH"}
            env.update(
                PATH=f"{bin_dir}:{os.environ['PATH']}", PYTHONPATH=str(workspace),
                MOCK_LOG=str(log), MOCK_STATE=state, TF_STATE_BUCKET="mock-state",
                NOTIFICATION_EMAIL="test@example.invalid", GITHUB_SHA="abcd1234", RUNNER_TEMP=str(base),
            )
            if extra:
                env.update(extra)
            command = [sys.executable, str(ENTRY), stack, operation]
            if mode:
                command += ["--mode", mode]
            result = subprocess.run(command, cwd=workspace, env=env, capture_output=True, text=True, timeout=30)
            commands = log.read_text().splitlines() if log.exists() else []
            return result, commands

    # 常設planで計画を生成し、applyしないことを確認する。
    def test_plan_is_read_only(self):
        result, cmd = self.exercise("persistent", "plan")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any(" plan " in c for c in cmd))
        self.assertFalse(any("terraform " in c and " apply " in c for c in cmd))

    # 常設applyが適用コマンドへ進むことを確認する。実際の置換内容の検証ではない。
    def test_apply_accepts_replace(self):
        result, cmd = self.exercise("persistent", "apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum("terraform " in c and " apply " in c for c in cmd), 1)

    # 更新時はmigration定義→DB更新→全体適用の順で、既存Webの台数を直接戻さないことを確認する。
    def test_temporary_update_migrates_before_web(self):
        state = "aws_appautoscaling_target.web[0]\nawscc_transfer_connector.vendor\naws_ecs_service.admin"
        result, cmd = self.exercise("temporary", "apply", state)
        self.assertEqual(result.returncode, 0, result.stderr)
        target = next(i for i,c in enumerate(cmd) if "-target=aws_ecs_task_definition.migration" in c)
        migration = next(i for i,c in enumerate(cmd) if c == "python -m tools.shared.deployment_runtime")
        normal_plan = max(i for i,c in enumerate(cmd) if "terraform " in c and " plan " in c)
        self.assertLess(target, migration)
        self.assertLess(migration, normal_plan)
        self.assertTrue(any("setup_sftp" in c for c in cmd))  # Existing hosts are inspected, not reinitialized.
        self.assertFalse(any("aws ecs update-service" in c for c in cmd))

    # 初回はSFTP設定→DB更新→Web起動の順に進み、3段階で適用することを確認する。
    def test_temporary_new_orders_sftp_db_web(self):
        result, cmd = self.exercise("temporary", "apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        setup = next(i for i,c in enumerate(cmd) if "setup_sftp" in c)
        migration = next(i for i,c in enumerate(cmd) if c == "python -m tools.shared.deployment_runtime")
        web = next(i for i,c in enumerate(cmd) if "ecs update-service" in c)
        self.assertLess(setup, migration)
        self.assertLess(migration, web)
        self.assertEqual(sum("terraform " in c and " apply " in c for c in cmd), 3)

    # 一時削除planが-destroyを使い、適用しないことを確認する。
    def test_destroy_plan_has_no_apply(self):
        result, cmd = self.exercise("temporary", "destroy-plan", "awscc_transfer_connector.vendor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any(" plan -destroy " in c for c in cmd))
        self.assertFalse(any("terraform " in c and " apply " in c for c in cmd))

    # 一時destroyが削除計画を適用することを確認する。
    def test_destroy_applies(self):
        result, cmd = self.exercise("temporary", "destroy", "awscc_transfer_connector.vendor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum("terraform " in c and " apply " in c for c in cmd), 1)

    # 状態確認で-detailed-exitcode付きplanを呼ぶことを確認する。
    def test_status_plans(self):
        result, cmd = self.exercise("persistent", "status", "aws_vpc.portfolio")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any(" plan -detailed-exitcode " in c for c in cmd))

    # plan終了コード2を差分ありと表示し、正常終了することを確認する。
    def test_status_reports_drift(self):
        result, _ = self.exercise("persistent", "status", "aws_vpc.portfolio", {"MOCK_PLAN_EXIT": "2"})
        self.assertEqual(result.returncode, 0)
        self.assertIn("drift or configuration changes", result.stdout + result.stderr)

    # 空StateではEMPTY_STATEを表示して差分計画を省略することを確認する。
    def test_empty_state_status(self):
        result, cmd = self.exercise("persistent", "status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("EMPTY_STATE", result.stdout)
        self.assertFalse(any("plan -detailed-exitcode" in c for c in cmd))

    # 初回一時planでECR公開・SFTP初期化・applyを実行しないことを確認する。
    def test_temporary_plan_does_not_publish_or_initialize(self):
        result, cmd = self.exercise("temporary", "plan")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(" apply " in c or c.startswith("docker ") or "setup_sftp" in c for c in cmd))
        self.assertIn("BOOTSTRAP_PLAN_ONLY", result.stdout)

    # plan終了コード1を状態確認の失敗として返すことを確認する。
    def test_status_propagates_plan_error(self):
        result, _ = self.exercise("persistent", "status", "aws_vpc.portfolio", {"MOCK_PLAN_EXIT": "1"})
        self.assertEqual(result.returncode, 1)

    # 初回構築の中断後も、初期化用の3段階を通ってWeb起動へ進むことを確認する。
    def test_partial_initial_apply_keeps_web_stopped_until_migration(self):
        result, cmd = self.exercise("temporary", "apply", "aws_ecs_service.admin\nawscc_transfer_connector.vendor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum("terraform " in c and " apply " in c for c in cmd), 3)
        self.assertTrue(any("ecs update-service" in c for c in cmd))

    # 一時Stateに管理対象があれば常設削除を停止することを確認する。
    def test_persistent_destroy_rejects_live_temporary_dependencies(self):
        result, cmd = self.exercise("persistent", "destroy", "aws_vpc.portfolio", {"MOCK_TEMP_STATE": "aws_instance.vendor"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DELETE_TEMPORARY_FIRST", result.stderr)
        self.assertFalse(any(" apply " in c for c in cmd))

    # 通常の常設削除でState削除操作やbackendポリシー書換えを行わないことを確認する。
    def test_backend_policy_stays_outside_destroy(self):
        result, cmd = self.exercise("persistent", "destroy", "aws_vpc.portfolio", {"MOCK_TEMP_STATE": ""})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any("state rm" in c or "put-bucket-policy" in c for c in cmd))

    # 旧TLSポリシーがStateに登録されたままなら、削除計画より前に停止することを確認する。
    def test_destroy_never_deletes_legacy_backend_policy(self):
        for operation in ("destroy-plan", "destroy"):
            result, cmd = self.exercise("persistent", operation, "aws_s3_bucket_policy.state_tls[0]\naws_vpc.portfolio")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("BACKEND_STATE_MIGRATION_REQUIRED", result.stderr)
            self.assertFalse(any(" plan -destroy " in c or " apply " in c for c in cmd))


    # Docker・SFTP設定・migrationの失敗を模擬し、後続のWeb起動へ進まないことを確認する。
    def test_failures_stop_following_stages(self):
        for stage in ("docker build", "setup_sftp", "tools.shared.deployment_runtime"):
            with self.subTest(stage=stage):
                result, cmd = self.exercise("temporary", "apply", extra={"FAIL_MATCH": stage})
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertFalse(any("ecs update-service" in c for c in cmd))
                self.assertIn(stage, cmd[-1])

    # 計画失敗時にapplyしないことを確認する。
    def test_plan_failure_prevents_apply(self):
        result, cmd = self.exercise("persistent", "apply", extra={"FAIL_MATCH": " plan "})
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any(" apply " in c for c in cmd))

    # State取得の権限エラーを空Stateと誤認せず、計画・適用を停止することを確認する。
    def test_state_errors_are_not_empty_state(self):
        result, cmd = self.exercise("persistent", "destroy", extra={"MOCK_STATE_ERROR": "AccessDenied"})
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("EMPTY_STATE", result.stdout)
        self.assertFalse(any(" plan " in c or " apply " in c for c in cmd))

    # State未作成の既知メッセージを空Stateとして扱うことを確認する。
    def test_missing_state_is_empty(self):
        result, _ = self.exercise("temporary", "status", extra={"MOCK_STATE_ERROR": "No state file was found"})
        self.assertEqual(result.returncode, 0)
        self.assertIn("EMPTY_STATE", result.stdout)

    # TLSポリシー追加時に既存Statementを残し、パスワードを標準ログへ出さないことを確認する。
    def test_backend_policy_preserves_existing_statements(self):
        existing = {"Sid": "Existing", "Effect": "Allow", "Action": "s3:GetObject", "Resource": "*", "Principal": "*"}
        result, cmd = self.exercise("persistent", "apply", extra={"MOCK_POLICY": json.dumps({"Version": "2012-10-17", "Statement": [existing]})})
        self.assertEqual(result.returncode, 0, result.stderr)
        policy = json.loads(next(c.removeprefix("POLICY ") for c in cmd if c.startswith("POLICY ")))
        self.assertIn(existing, policy["Statement"])
        self.assertEqual(sum(s["Sid"] == "PortfolioRequireSecureTransport" for s in policy["Statement"]), 1)
        self.assertNotIn("test-password", result.stdout + result.stderr)

    # backendポリシー取得の権限エラー時に書換え・適用へ進まないことを確認する。
    def test_policy_access_denied_stops_apply(self):
        result, cmd = self.exercise("persistent", "apply", extra={"MOCK_POLICY_ERROR": "AccessDenied"})
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any("put-bucket-policy" in c or " apply " in c for c in cmd))

    # 環境・作成削除・UIのplan/applyの組合せが、想定した適用有無へ変換されることを確認する。
    def test_ui_modes(self):
        for stack in ("persistent", "temporary"):
            for operation in ("apply", "destroy"):
                for mode in ("plan", "apply"):
                    with self.subTest(stack=stack, operation=operation, mode=mode):
                        result, cmd = self.exercise(stack, operation, "awscc_transfer_connector.vendor" if stack == "temporary" else "aws_vpc.portfolio", {"MOCK_TEMP_STATE": ""} if stack == "persistent" else {}, mode=mode)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(any(" apply " in c for c in cmd), mode == "apply")

    # 不正な環境・操作・modeを外部コマンド実行前に拒否することを確認する。
    def test_invalid_arguments_do_not_run_commands(self):
        for stack, operation, mode in (("bad", "plan", None), ("persistent", "bad", None), ("persistent", "apply", "bad")):
            result, cmd = self.exercise(stack, operation, mode=mode)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(cmd, [])


class WorkflowSyntax(unittest.TestCase):
    # 3ワークフローと共通Actionを読み、埋込Python構文と実行形式を確認する。
    def test_yaml_and_python_steps(self):
        import yaml
        paths = list((ROOT / '.github/workflows').glob('*.yml'))
        self.assertEqual(len(paths), 3)
        paths += list((ROOT / '.github/actions').rglob('*.yml'))
        for path in paths:
            source = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
            if 'jobs' in source:
                steps = [step for job in source['jobs'].values() for step in job.get('steps', [])]
            else:
                steps = source.get('runs', {}).get('steps', [])
            for step in steps:
                if 'run' not in step:
                    continue
                if step.get('shell') == 'python':
                    compile(step['run'], str(path), 'exec')
                else:
                    self.assertTrue(step['run'].startswith('python '), f"{path}: {step['run']}")
                    self.assertNotIn('\n', step['run'].strip())
                self.assertNotEqual(step.get('shell'), 'bash')
        self.assertFalse((ROOT / '03_ワークフロー/02_資材/terraform.sh').exists())


class UnifiedWorkflowInputs(unittest.TestCase):
    def test_all_input_combinations_reach_existing_cli(self):
        from unittest.mock import patch
        import yaml
        workflow = yaml.load((ROOT / '.github/workflows/02_environment.yml').read_text(), Loader=yaml.BaseLoader)
        self.assertEqual(set(workflow['on']), {'workflow_dispatch'})
        inputs = workflow['on']['workflow_dispatch']['inputs']
        self.assertEqual(inputs['stack']['options'], ['persistent', 'temporary'])
        self.assertEqual(inputs['operation']['options'], ['apply', 'destroy'])
        self.assertEqual(inputs['mode']['options'], ['plan', 'apply'])
        self.assertEqual(inputs['mode']['default'], 'plan')
        job = workflow['jobs']['run']
        self.assertEqual(job['if'], "github.ref == 'refs/heads/main'")
        self.assertEqual(workflow['concurrency']['group'], 'portfolio-environment')
        self.assertEqual(workflow['concurrency']['cancel-in-progress'], 'false')
        step = job['steps'][-1]
        self.assertEqual(step['shell'], 'python')
        self.assertNotIn('${{', step['run'])
        self.assertEqual(step['env'], {
            'TARGET_STACK': '${{ inputs.stack }}',
            'TARGET_OPERATION': '${{ inputs.operation }}',
            'EXECUTION_MODE': '${{ inputs.mode }}',
        })
        for stack in inputs['stack']['options']:
            for operation in inputs['operation']['options']:
                for mode in inputs['mode']['options']:
                    with self.subTest(stack=stack, operation=operation, mode=mode):
                        with patch.dict(os.environ, TARGET_STACK=stack, TARGET_OPERATION=operation, EXECUTION_MODE=mode), patch('subprocess.run') as run:
                            exec(compile(step['run'], '02_environment.yml', 'exec'), {})
                        run.assert_called_once_with([sys.executable, '-m', 'tools.environment', stack, operation, '--mode', mode], check=True)
                        for key in ('stack', 'operation', 'mode'):
                            self.assertIn('inputs.' + key, workflow['run-name'])

    def test_dispatch_failure_is_propagated(self):
        from unittest.mock import patch
        import yaml
        workflow = yaml.load((ROOT / '.github/workflows/02_environment.yml').read_text(), Loader=yaml.BaseLoader)
        command = workflow['jobs']['run']['steps'][-1]['run']
        with patch.dict(os.environ, TARGET_STACK='temporary', TARGET_OPERATION='apply', EXECUTION_MODE='apply'), patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, ['python'])):
            with self.assertRaises(subprocess.CalledProcessError):
                exec(compile(command, '02_environment.yml', 'exec'), {})


if __name__ == "__main__":
    unittest.main()

