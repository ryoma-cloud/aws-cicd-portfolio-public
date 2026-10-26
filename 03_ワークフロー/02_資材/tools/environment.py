"""GitHub Actionsの実行制御。AWS資源はTerraform、段階実行はこの入口で管理する。"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

DIRECTORIES = {
    "persistent": "02_資材/01_persistent",
    "temporary": "02_資材/02_temporary/terraform",
}
BOOTSTRAP = (
    "aws_instance.vendor", "aws_eip.vendor",
    "aws_secretsmanager_secret.sftp", "aws_securityhub_account.portfolio",
)


# 外部コマンドを引数リストで実行する。capture=Trueなら標準出力・エラーを取得し、通常ログへ流さない。
def run(*command, capture=False, input=None, check=True):
    """シェルを介さず実行。秘密を含む入力や取得結果はログへ出さない。"""
    return subprocess.run(
        command, text=True, input=input, check=check,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


# 環境名からTerraformの作業ディレクトリを選び、標準CLIを実行する。
def tf(stack, *args, **kwargs):
    return run("terraform", f"-chdir={DIRECTORIES[stack]}", *args, **kwargs)


# AWS CLIの結果を文字列として取得する。参照か変更かは渡すサブコマンドで決まる。
def aws(*args):
    return run("aws", *args, capture=True).stdout.strip()


# 現在と同じPythonで補助モジュールを起動する。秘密を含むJSONは必要に応じ標準入力で渡す。
def helper(module, *args, input=None):
    run(sys.executable, "-m", module, *args, input=input)


# 必須環境変数を取得する。未設定・空文字なら後続処理を止める。
def required(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"{name} is required")
    return value


# S3バケット名を渡してterraform initを行い、既存の依存ロックを維持する。
def initialize(stack):
    tf(stack, "init", "-input=false", "-lockfile=readonly",
       f"-backend-config=bucket={required('TF_STATE_BUCKET')}")


# State内の管理アドレスを列挙する。State未作成は空扱い、権限不足などはエラーとして停止する。
def state_list(stack):
    result = tf(stack, "state", "list", capture=True, check=False)
    if result.returncode:
        message = result.stdout + result.stderr
        if "No state file" in message:
            return []
        raise subprocess.CalledProcessError(result.returncode, result.args,
                                            output=result.stdout, stderr=result.stderr)
    return [line for line in result.stdout.splitlines() if line.strip()]


# terraform showのJSONからリソース属性を取得する。現在の構成はroot_module直下を対象とする。
def resources(stack):
    state = json.loads(tf(stack, "show", "-json", capture=True).stdout)
    return {r["address"]: r.get("values", {})
            for r in state.get("values", {}).get("root_module", {}).get("resources", [])}


# 常設の通知先を設定する。apply時だけ、State用S3にTLS必須ポリシーを追加・更新する。
def persistent_inputs(operation, work):
    if operation == "apply":
        required("NOTIFICATION_EMAIL")
        bucket = required("TF_STATE_BUCKET")
        result = run("aws", "s3api", "get-bucket-policy", "--bucket", bucket,
                     "--query", "Policy", "--output", "text", capture=True, check=False)
        if result.returncode == 0:
            policy = json.loads(result.stdout)
        elif "NoSuchBucketPolicy" in result.stderr:
            policy = {"Version": "2012-10-17", "Statement": []}
        else:
            raise subprocess.CalledProcessError(result.returncode, result.args,
                                                stderr=result.stderr)
        statements = policy.get("Statement", [])
        if isinstance(statements, dict):
            statements = [statements]
        policy["Statement"] = [s for s in statements
                               if s.get("Sid") != "PortfolioRequireSecureTransport"] + [{
            "Sid": "PortfolioRequireSecureTransport", "Effect": "Deny", "Principal": "*",
            "Action": "s3:*", "Resource": [f"arn:aws:s3:::{bucket}", f"arn:aws:s3:::{bucket}/*"],
            "Condition": {"Bool": {"aws:SecureTransport": "false"}},
        }]
        policy_file = work / "backend-policy.json"
        policy_file.write_text(json.dumps(policy), encoding="utf-8")
        aws("s3api", "put-bucket-policy", "--bucket", bucket,
            "--policy", f"file://{policy_file}")
    os.environ["TF_VAR_budget_email"] = os.environ.get("NOTIFICATION_EMAIL") or "plan-only@example.invalid"


# Lambda ZIPをローカル生成し、Stateの既存値や初回plan用の仮値をTerraform変数へ設定する。
def temporary_inputs(entries, work):
    helper("tools.deployment.build")
    if "aws_transfer_connector.vendor" in entries:
        raise ValueError("Legacy connector state requires migration before simplified workflow")
    account = aws("sts", "get-caller-identity", "--query", "Account", "--output", "text")
    current = resources("temporary") if entries else {}
    migration = current.get("aws_ecs_task_definition.migration", {})
    containers = json.loads(migration.get("container_definitions", "[]"))
    image = containers[0].get("image") if containers else None
    os.environ["TF_VAR_admin_image_uri"] = image or (
        f"{account}.dkr.ecr.ap-northeast-1.amazonaws.com/portfolio-admin-web@sha256:" + "0" * 64)
    keys = current.get("awscc_transfer_connector.vendor", {}).get("sftp_config", {}).get("trusted_host_keys", [])
    if not keys:
        # 初回計画専用。applyではSFTPサーバの実ホスト公開鍵へ置き換える。
        key_file = work / "plan-sftp-host-key"
        run("ssh-keygen", "-q", "-t", "ecdsa", "-b", "256", "-N", "", "-f", str(key_file), capture=True)
        keys = [" ".join(key_file.with_suffix(".pub").read_text().split()[:2])]
    os.environ.update(
        TF_VAR_sftp_host_keys=json.dumps(keys),
        TF_VAR_budget_email=os.environ.get("NOTIFICATION_EMAIL") or "plan-only@example.invalid",
        TF_VAR_enable_reserved_concurrency="true",
        TF_VAR_enable_account_security="true",
        TF_VAR_enable_daily_schedule=str(current.get("aws_scheduler_schedule.daily", {}).get("state") == "ENABLED").lower(),
        TF_VAR_web_desired_count="2" if "aws_appautoscaling_target.web[0]" in entries else "0",
    )


# Terraformの変更計画をファイルへ保存する。AWSリソースへの変更は適用しない。
def plan(stack, planfile, *options):
    tf(stack, "plan", "-input=false", "-lock-timeout=60s", f"-out={planfile}", *options)


# この実行内で計画を作り直し、その保存planを適用する。別runの事前planは引き継がない。
def apply(stack, planfile, *options):
    plan(stack, planfile, *options)
    tf(stack, "apply", "-input=false", "-lock-timeout=60s", str(planfile))


# ECR公開→SFTP先行構築・設定→DB更新→Web適用の順に一時環境を作成・変更する。
def apply_temporary(planfile):
    required("NOTIFICATION_EMAIL")
    entries = state_list("temporary")
    inventory = tf("temporary", "state", "pull", capture=True).stdout if entries else '{"resources":[]}'
    helper("tools.status.security_inventory", input=inventory)
    first_web = "aws_appautoscaling_target.web[0]" not in entries

    # 1. Web用DockerイメージをECRへ公開し、変更不能なdigestで指定する。
    repo = aws("ecr", "describe-repositories", "--repository-names", "portfolio-admin-web",
               "--query", "repositories[0].repositoryUri", "--output", "text")
    password = aws("ecr", "get-login-password")
    run("docker", "login", "--username", "AWS", "--password-stdin", repo.split("/")[0],
        input=password + "\n", capture=True)
    tag = f"{repo}:{required('GITHUB_SHA')}"
    run("docker", "build", "-t", tag, "02_資材/02_temporary/app")
    run("docker", "push", tag)
    digest = aws("ecr", "describe-images", "--repository-name", "portfolio-admin-web",
                 "--image-ids", f"imageTag={required('GITHUB_SHA')}",
                 "--query", "imageDetails[0].imageDigest", "--output", "text")
    if not digest.startswith("sha256:"):
        raise ValueError("ECR_DIGEST_NOT_FOUND")
    os.environ["TF_VAR_admin_image_uri"] = f"{repo}@{digest}"

    # SFTPサーバの作成・置換を先に完了し、実ホスト鍵をConnectorへ渡す。
    apply("temporary", planfile, *(f"-target={target}" for target in BOOTSTRAP))
    instance = resources("temporary").get("aws_instance.vendor", {}).get("id")
    if instance:
        # 2. EC2がSSMに接続できてからSFTP設定と実ホスト鍵の取得を行う。
        for _ in range(20):
            ping = aws("ssm", "describe-instance-information", "--filters", f"Key=InstanceIds,Values={instance}",
                       "--query", "InstanceInformationList[0].PingStatus", "--output", "text")
            if ping == "Online":
                break
            time.sleep(15)
        else:
            raise ValueError("SSM_NOT_ONLINE")
        output = Path(DIRECTORIES["temporary"]) / "sftp.auto.tfvars.json"
        helper("tools.deployment.setup_sftp", "--instance", instance,
               "--secret", "portfolio/mock/card-vendor/sftp", "--out", str(output))
        os.environ["TF_VAR_sftp_host_keys"] = json.dumps(json.loads(output.read_text())["sftp_host_keys"])

    # 3. 初回はWebを止めて基盤を構築する。更新時はDB更新用タスク定義を先に適用する。
    if first_web:
        os.environ["TF_VAR_web_desired_count"] = "0"
        apply("temporary", planfile)
    else:
        # 更新時はmigration定義を先に登録し、新Webを公開する前にDBを更新。
        apply("temporary", planfile, "-target=aws_ecs_task_definition.migration")
    # 4. DBのmigration完了を確認する。失敗したら新Webの適用へ進まない。
    outputs = tf("temporary", "output", "-json", capture=True).stdout
    helper("tools.shared.deployment_runtime", input=outputs)
    # 5. DB更新後に全体を適用する。初回だけWebを2台へ起動する。
    if first_web:
        os.environ["TF_VAR_web_desired_count"] = "2"
    apply("temporary", planfile)
    if first_web:
        aws("ecs", "update-service", "--cluster", "portfolio-card", "--service", "portfolio-card-web", "--desired-count", "2")
    print("Terraform apply completed (application readiness not checked)")


# 初期化と入力準備を共通実行し、状態確認・計画・適用・削除へ分岐する。
def execute(stack, operation, work):
    initialize(stack)
    entries = state_list(stack)
    if stack == "persistent" and operation in ("destroy-plan", "destroy") and "aws_s3_bucket_policy.state_tls[0]" in entries:
        raise ValueError("BACKEND_STATE_MIGRATION_REQUIRED: run persistent plan/apply once before destroy.")
    if not entries and operation in ("status", "destroy-plan", "destroy"):
        print("EMPTY_STATE (Terraform-managed resources: none)")
        return 0
    if stack == "persistent":
        persistent_inputs(operation, work)
    else:
        temporary_inputs(entries, work)
    planfile = work / f"{stack}-{operation}.tfplan"
    # 状態確認はState一覧とplan差分。アプリ稼働確認・AWS全体の棚卸しは行わない。
    if operation == "status":
        print(f"=== {stack} : Terraform managed resources ===")
        print("\n".join(state_list(stack)))
        result = tf(stack, "plan", "-detailed-exitcode", "-input=false", "-no-color", "-lock-timeout=60s", check=False)
        if result.returncode == 2:
            print("Terraform drift or configuration changes found")
            return 0
        return result.returncode
    if operation == "plan":
        targets = []
        if stack == "temporary":
            print("NOTE: 初回のSFTP鍵・ECR URIはplan用仮値。applyで再計画します。")
            if "aws_securityhub_account.portfolio" not in entries:
                print("BOOTSTRAP_PLAN_ONLY: SFTP server, credentials and Security Hub plus Terraform dependencies; full infrastructure and Web plans are generated during apply.")
                targets = [f"-target={target}" for target in BOOTSTRAP]
        plan(stack, planfile, *targets)
        tf(stack, "show", "-no-color", str(planfile))
        print("PLAN_ONLY: no infrastructure changes")
    elif operation == "apply":
        if stack == "temporary":
            apply_temporary(planfile)
        else:
            apply(stack, planfile)
    else:
        if stack == "persistent" and operation == "destroy":
            initialize("temporary")
            if state_list("temporary"):
                raise ValueError("DELETE_TEMPORARY_FIRST")
        # 削除もまず計画を保存し、destroy指定時だけ同じファイルを適用する。
        tf(stack, "plan", "-destroy", "-input=false", "-lock-timeout=60s", f"-out={planfile}")
        tf(stack, "show", "-no-color", str(planfile))
        if operation == "destroy":
            tf(stack, "apply", "-input=false", "-lock-timeout=60s", str(planfile))
    return 0


# CLI引数とUIのmodeを解釈し、一時ファイル権限・終了コード・エラー表示を管理する。
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stack", choices=DIRECTORIES)
    parser.add_argument("operation", choices=("plan", "apply", "destroy-plan", "destroy", "status"))
    # YAMLのmode引数を内部操作へ変換する。
    parser.add_argument("--mode", choices=("plan", "apply"))
    args = parser.parse_args()
    operation = args.operation
    if args.mode:
        if operation == "apply":
            operation = args.mode
        elif operation == "destroy":
            operation = "destroy-plan" if args.mode == "plan" else "destroy"
        else:
            parser.error("--mode requires apply or destroy")
    os.umask(0o077)
    os.environ.setdefault("AWS_REGION", "ap-northeast-1")
    os.environ.update(TF_IN_AUTOMATION="true", TF_INPUT="false")
    try:
        with tempfile.TemporaryDirectory(prefix="portfolio-", dir=os.environ.get("RUNNER_TEMP")) as folder:
            return execute(args.stack, operation, Path(folder))
    except subprocess.CalledProcessError as error:
        # captured stdoutにはState等が含まれ得るので出力しない。
        if error.stderr:
            print(error.stderr, file=sys.stderr)
        print(f"Command failed ({error.returncode}): {error.cmd[0]}", file=sys.stderr)
        return error.returncode if error.returncode > 0 else 1
    except (ValueError, OSError, KeyError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
