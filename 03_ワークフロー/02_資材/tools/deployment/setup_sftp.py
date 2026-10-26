"""Generate/reuse user credentials, provision public key over SSM, attest host key."""
import json
import shlex
import time
from botocore.exceptions import ClientError
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from common.domain import ProcessingError

# EC2へSSMコマンドを送信し、成功まで待つ。失敗または待機期限超過なら停止する。
def ssm_command(ssm, instance, commands):
    command=ssm.send_command(InstanceIds=[instance],DocumentName='AWS-RunShellScript',Parameters={'commands':commands},TimeoutSeconds=120)['Command']['CommandId']
    deadline=time.monotonic()+180
    while time.monotonic()<deadline:
        try:
            result=ssm.get_command_invocation(CommandId=command,InstanceId=instance)
        except ClientError as exc:
            if exc.response['Error']['Code']!='InvocationDoesNotExist':raise
            time.sleep(2);continue
        if result['Status']=='Success':return result['StandardOutputContent']
        if result['Status'] in ('Failed','TimedOut','Cancelled','Cancelling'):
            raise ProcessingError('SSM_COMMAND_FAILED')
        time.sleep(2)
    raise ProcessingError('SSM_TIMEOUT')

# SFTP認証鍵を再利用またはSecretへ保存し、EC2のユーザー・sshdを設定してホスト公開鍵を返す。
def setup(sm,ssm,instance,secret):
    try:
        credential=json.loads(sm.get_secret_value(SecretId=secret)['SecretString'])
        key=serialization.load_pem_private_key(credential['PrivateKey'].encode(),password=None)
    except ClientError as exc:
        if exc.response['Error']['Code']!='ResourceNotFoundException':raise
        key=rsa.generate_private_key(public_exponent=65537,key_size=3072)
        pem=key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.TraditionalOpenSSL,serialization.NoEncryption()).decode()
        sm.put_secret_value(SecretId=secret,SecretString=json.dumps({'Username':'badge_sftp','PrivateKey':pem}))
    public=key.public_key().public_bytes(serialization.Encoding.OpenSSH,serialization.PublicFormat.OpenSSH).decode()
    config='''PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
HostKey /etc/ssh/ssh_host_ecdsa_key
Match User badge_sftp
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
'''
    commands=['set -eu','id badge_sftp >/dev/null 2>&1 || useradd -m -s /sbin/nologin badge_sftp',
      "usermod -p '*' badge_sftp",'mkdir -p /srv/sftp/badge_sftp/inbox /home/badge_sftp/.ssh',
      'chown root:root /srv/sftp /srv/sftp/badge_sftp','chmod 755 /srv/sftp /srv/sftp/badge_sftp',
      'chown badge_sftp:badge_sftp /srv/sftp/badge_sftp/inbox /home/badge_sftp/.ssh',
      'chmod 700 /home/badge_sftp/.ssh',
      'printf %s '+shlex.quote(public+'\n')+' > /home/badge_sftp/.ssh/authorized_keys',
      'chown badge_sftp:badge_sftp /home/badge_sftp/.ssh/authorized_keys','chmod 600 /home/badge_sftp/.ssh/authorized_keys',
      'printf %s '+shlex.quote(config)+' > /etc/ssh/sshd_config.d/00-portfolio.conf',
      'test -f /etc/ssh/ssh_host_ecdsa_key || ssh-keygen -q -t ecdsa -b 256 -N "" -f /etc/ssh/ssh_host_ecdsa_key',
      'sshd -t','systemctl restart sshd',"awk '{print $1\" \"$2}' /etc/ssh/ssh_host_ecdsa_key.pub"]
    output=ssm_command(ssm,instance,commands)
    hostkeys=[line.strip() for line in output.splitlines() if line.startswith('ecdsa-sha2-nistp256 ')]
    if len(hostkeys)!=1:raise ProcessingError('HOST_KEY_UNAVAILABLE')
    return hostkeys

# EC2に既存設定があればホスト公開鍵を再利用し、未設定ならsetupで初期化する。
def ensure(sm, ssm, instance, secret):
    """Reuse initialized host settings; initialize only a fresh/replaced server."""
    observed = ssm_command(ssm, instance, [
        'set -eu',
        'if test -s /etc/ssh/sshd_config.d/00-portfolio.conf && test -s /home/badge_sftp/.ssh/authorized_keys; then '
        "awk '{print $1\" \"$2}' /etc/ssh/ssh_host_ecdsa_key.pub; "
        'else echo SETUP_REQUIRED; fi',
    ])
    keys = [line.strip() for line in observed.splitlines() if line.startswith('ecdsa-sha2-nistp256 ')]
    return keys if len(keys) == 1 else setup(sm, ssm, instance, secret)

if __name__=='__main__':
    import argparse
    from pathlib import Path
    from common.runtime import client
    p=argparse.ArgumentParser();p.add_argument('--instance',required=True);p.add_argument('--secret',required=True);p.add_argument('--out',required=True)
    args=p.parse_args()
    # Output contains public keys only.
    Path(args.out).write_text(json.dumps({'sftp_host_keys':ensure(client('secretsmanager',write=True),client('ssm',write=True),args.instance,args.secret)}))

# Connectorの同時接続数とSGの許可元IPを照合する。設定の自動修復はしない。
def verify_connector(transfer,ec2,connector,group):
    """Read back Terraform-owned connector settings; never repair them here."""
    observed=transfer.describe_connector(ConnectorId=connector)['Connector']
    if observed['SftpConfig'].get('MaxConcurrentConnections')!=1:
        raise ProcessingError('CONNECTOR_CONCURRENCY_MISMATCH')
    addresses=observed['ServiceManagedEgressIpAddresses']
    if not addresses:raise ProcessingError('CONNECTOR_EGRESS_UNAVAILABLE')
    rules=ec2.describe_security_groups(GroupIds=[group])['SecurityGroups'][0]['IpPermissions']
    allowed={ip+'/32' for ip in addresses}
    if (len(rules)!=1 or rules[0].get('IpProtocol')!='tcp'
            or rules[0].get('FromPort')!=22 or rules[0].get('ToPort')!=22
            or {r['CidrIp'] for r in rules[0].get('IpRanges',[])}!=allowed
            or any(rules[0].get(k) for k in ('Ipv6Ranges','UserIdGroupPairs','PrefixListIds'))):
        raise ProcessingError('CONNECTOR_SECURITY_GROUP_MISMATCH')

