# Aurora PostgreSQL 詳細設計

## 1. 設定値の表記・管理対象

構成定義：`02_資材/02_temporary/terraform/database.tf`、`02_資材/02_temporary/terraform/variables.tf`。

設定値は固定値とTerraform参照式で記載する。`<account-id>`は対象AWSアカウント、ID・ARN・endpoint等の自動採番値は表中のリソース参照で解決する。「未指定」はTerraformから明示設定しない項目を示す。

## 2. DB構成・パラメータグループ

### aws_db_subnet_group.portfolio

Terraformリソース：`aws_db_subnet_group.portfolio`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-db-subnets` |
| 配置先サブネットID一覧 | `subnet_ids` | `data.aws_subnets.private.ids` |

### aws_rds_cluster_parameter_group.portfolio

Terraformリソース：`aws_rds_cluster_parameter_group.portfolio`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| 名前 | `name` | `portfolio-card-pg16` |
| DBパラメータグループの対応エンジン系列 | `family` | `aurora-postgresql16` |
| DB設定の名前：DBのタイムゾーン | `parameter[0].name` | `timezone` |
| DB設定の値：DBのタイムゾーン | `parameter[0].value` | `Asia/Tokyo` |
| DB設定の名前：DB接続のTLS強制 | `parameter[1].name` | `rds.force_ssl` |
| DB設定の値：DB接続のTLS強制 | `parameter[1].value` | `1` |
| DB設定の名前：SQL文のログ記録範囲 | `parameter[2].name` | `log_statement` |
| DB設定の値：SQL文のログ記録範囲 | `parameter[2].value` | `none` |
| DB設定の名前：遅延SQLのログ記録しきい値 | `parameter[3].name` | `log_min_duration_statement` |
| DB設定の値：遅延SQLのログ記録しきい値 | `parameter[3].value` | `-1` |
| DB設定の名前：SQLパラメータのログ記録上限 | `parameter[4].name` | `log_parameter_max_length` |
| DB設定の値：SQLパラメータのログ記録上限 | `parameter[4].value` | `0` |
| DB設定の名前：エラー時のSQLパラメータ記録上限 | `parameter[5].name` | `log_parameter_max_length_on_error` |
| DB設定の値：エラー時のSQLパラメータ記録上限 | `parameter[5].value` | `0` |
| DB設定の名前：エラー時のSQL文記録レベル | `parameter[6].name` | `log_min_error_statement` |
| DB設定の値：エラー時のSQL文記録レベル | `parameter[6].value` | `panic` |

### aws_rds_cluster.portfolio

Terraformリソース：`aws_rds_cluster.portfolio`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| DBクラスタ識別子 | `cluster_identifier` | `portfolio-card-db` |
| DBエンジン | `engine` | `aurora-postgresql` |
| DBエンジンの稼働方式 | `engine_mode` | `provisioned` |
| DBエンジンのバージョン | `engine_version` | `var.aurora_engine_version` |
| 初期作成するDB名 | `database_name` | `portfolio` |
| DB管理ユーザ名 | `master_username` | `portfolio_admin` |
| DB管理パスワードのSecrets Manager管理 | `manage_master_user_password` | `true` |
| Data APIの有効化 | `enable_http_endpoint` | `false` |
| DB配置先サブネットグループ名 | `db_subnet_group_name` | `aws_db_subnet_group.portfolio.name` |
| 適用するセキュリティグループID一覧 | `vpc_security_group_ids` | `[aws_security_group.db.id]` |
| DBクラスタのパラメータグループ名 | `db_cluster_parameter_group_name` | `aws_rds_cluster_parameter_group.portfolio.name` |
| DBストレージの暗号化 | `storage_encrypted` | `true` |
| 自動バックアップ保持期間（日） | `backup_retention_period` | `7` |
| 自動バックアップ時間帯（UTC） | `preferred_backup_window` | `18:00-18:30` |
| メンテナンス開始時間帯（UTC） | `preferred_maintenance_window` | `sat:18:30-sat:19:00` |
| 削除時の最終スナップショット省略 | `skip_final_snapshot` | `true` |
| DB削除保護 | `deletion_protection` | `false` |
| スナップショットへのタグ引継ぎ | `copy_tags_to_snapshot` | `true` |
| CloudWatch Logsへ出力するログ種別 | `enabled_cloudwatch_logs_exports` | `["postgresql"]` |

### aws_rds_cluster_instance.instance1

Terraformリソース：`aws_rds_cluster_instance.instance1`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| DBインスタンス識別子 | `identifier` | `portfolio-card-db-1` |
| DBクラスタ識別子 | `cluster_identifier` | `aws_rds_cluster.portfolio.id` |
| DBインスタンスクラス | `instance_class` | `db.t4g.medium` |
| DBエンジン | `engine` | `aurora-postgresql` |
| DBへのパブリックアクセス | `publicly_accessible` | `false` |
| フェイルオーバー昇格優先度 | `promotion_tier` | `1` |
| 配置先アベイラビリティゾーン | `availability_zone` | `ap-northeast-1a` |
| メンテナンス開始時間帯（UTC） | `preferred_maintenance_window` | `sat:19:00-sat:19:30` |

### aws_rds_cluster_instance.instance2

Terraformリソース：`aws_rds_cluster_instance.instance2`

| 意味 | パラメータ | 設定値・参照式 |
| --- | --- | --- |
| DBインスタンス識別子 | `identifier` | `portfolio-card-db-2` |
| DBクラスタ識別子 | `cluster_identifier` | `aws_rds_cluster.portfolio.id` |
| DBインスタンスクラス | `instance_class` | `db.t4g.medium` |
| DBエンジン | `engine` | `aurora-postgresql` |
| DBへのパブリックアクセス | `publicly_accessible` | `false` |
| フェイルオーバー昇格優先度 | `promotion_tier` | `0` |
| 配置先アベイラビリティゾーン | `availability_zone` | `ap-northeast-1c` |
| メンテナンス開始時間帯（UTC） | `preferred_maintenance_window` | `sat:20:00-sat:20:30` |

| 意味 | 変数 | 既定値 |
| --- | --- | --- |
| DBエンジンバージョンの入力変数 | `aurora_engine_version` | `16.15` |

`auto_minor_version_upgrade`、`performance_insights_enabled`、`max_connections`、`autovacuum`はTerraformでは未指定。設定値を固定する項目とサービス・プロバイダー既定に委ねる項目を区別する。Writer/Readerの役割はフェイルオーバーで変わるため、アプリはinstance endpointを固定せずcluster endpointを使用する。

## 3. アプリ接続設定

| 意味 | パラメータ | 値・参照 |
| --- | --- | --- |
| 業務処理のDB接続先 | `host（処理用）` | `aws_rds_cluster.portfolio.endpoint` |
| WebのDB接続先 | `host（Web）` | `aws_rds_cluster.portfolio.reader_endpoint` |
| 接続先DB名 | `dbname` | `portfolio` |
| DB接続のTLS検証方式 | `sslmode` | `verify-full` |
| DB接続のTLS検証用CA証明書パス | `sslrootcert` | `DB_SSLROOTCERT` |
| 接続タイムアウト（秒） | `connect_timeout` | `5` |
| DBスキーマの検索順序 | `search_path` | `badge,pg_catalog` |
| タイムゾーン | `timezone` | `Asia/Tokyo` |
| SQL実行時間の上限 | `statement_timeout` | `10000` |
| DBロック待機時間の上限 | `lock_timeout` | `3000` |
| トランザクション内の無操作時間上限 | `idle_in_transaction_session_timeout` | `15000` |

SQL側timeoutの単位はms。username/passwordは用途別Secretから新規接続ごとに取得する。Secret値の独立したTTLキャッシュは設けない。接続生存確認に失敗した接続は破棄する。失敗したトランザクションはrollbackし、処理単位の再実行に委ねる。接続復旧だけでSQLを自動再実行しない。

## 4. DB権限・ログ・復元

Webは参照専用、業務処理は必要なSELECT/INSERT/UPDATE・sequence利用、構築処理はDDL・ユーザ設定を行う。詳細は[DB・ファイル詳細設計](../02_アプリ/02_DB・ファイル詳細設計.md)に定める。

SQL本文・パラメータの記録を抑制し、遅延はCloudWatch指標で監視する。過去時点復元は別clusterへの復元と接続先切替を基本とし、DB・S3・外部送信結果を照合して再開する。フェイルオーバーとバックアップ復元を区別する。

自動バックアップは7日保持し、バックアップ時間帯は18:00–18:30 UTC（03:00–03:30 JST）。cluster保守時間帯は土18:30–19:00 UTC（日03:30–04:00 JST）。一時環境削除では最終スナップショットを取得しない。

## 5. メンテナンス

各時間枠はUTCで設定する。日本時間ではクラスタは毎週日曜03:30–04:00、instance1は04:00–04:30、instance2は05:00–05:30とする。日次バッチ（01:00）と自動バックアップ（03:00–03:30）を避け、インスタンス個別の時間枠は互いに分離する。

DBエンジン更新とクラスタ単位のOS更新にはクラスタの時間枠、インスタンス単位のOS更新には各インスタンスの時間枠を使用する。OS更新は原則としてクラスタ単位で計画実施し、Readerから順に更新してWriterを最後に更新する。Writer/Readerの役割は切替で変わるため、インスタンス番号と時間枠だけで更新順序を保証しない。

任意のOS更新は保守担当者が適用を計画する。必須更新は通知・期限を確認し、期限前に計画適用する。期限後の自動適用は無効化できない。時間枠は作業開始の範囲であり、作業終了時刻や停止60秒以内を保証しない。個別時間枠を離していても、作業が長引いた場合の重複は保証できない。

仕様参照：[AWS Auroraメンテナンス](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_UpgradeDBInstance.Maintenance.html)。
