# migrate.py 詳細設計書

## 1. 目的・呼出元

DB構造・権限の更新を行う。対象プログラムは`02_資材/02_temporary/app/tools/migrate.py`である。

deployment_runtimeが起動するECS migrationタスク内で実行する。

## 2. 関数・入出力

| 関数・引数 | 処理 | 戻り値・出力 |
| --- | --- | --- |
| `migrate(conn, paths)` | 未適用SQLを順に適用し履歴を記録する。 | None |
| `roles(conn, sm)` | DBユーザの資格情報と権限を設定する。 | None |

## 3. 処理・分岐・外部操作

1. CLIは管理用DB接続を開き、migrations/*.sqlをmigrateへ渡す。成功後にrolesを実行する。

2. migrateはpg_advisory_lockで排他し、schemaと履歴表を作成する。SQLをファイル名順に読み、内容のSHA-256を算出する。

3. SQLごとのトランザクションで履歴を照合する。既適用・同checksumならスキップし、不一致ならMIGRATION_CHECKSUM_MISMATCHで停止する。未適用ならSQLと履歴INSERTを同一トランザクションで実行する。finallyでadvisory lockを解放する。

4. rolesはAPP_SECRET_ARN・WEB_SECRET_ARNからpasswordを取得する。ResourceNotFoundExceptionの場合のみ32バイトのtoken_urlsafeでパスワードを生成し、DB変更前にSecretへ保存する。その他のAPIエラーや不正JSONは伝播する。

5. badge_appはSELECT/INSERT/UPDATE、badge_webはSELECTをcard_requestsへ付与する。ユーザがあればALTER ROLE、なければCREATE ROLEし、schema USAGEを付与、PUBLIC権限を取り消す。ユーザごとのトランザクションで実行する。戻り値は両関数ともNone。

6. SQL単位で確定するため、後続SQLやroles失敗時も先に成功したSQL・Secretは残る。再実行は同checksumのSQLを省略し、SecretとDB資格情報を再整合する。DB全体の復元・過去SQLの書換えは行わない。

## 4. 異常終了・再実行

主な停止理由は`MIGRATION_CHECKSUM_MISMATCH`。

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
