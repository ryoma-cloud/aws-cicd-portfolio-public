# security_inventory.py 詳細設計書

## 1. 目的・呼出元

共有セキュリティ設定の所有確認を行う。対象プログラムは`03_ワークフロー/02_資材/tools/status/security_inventory.py`である。

environment.apply_temporaryのECR登録前にState JSONを標準入力として渡す。独立試験でも使用する。

## 2. 関数・入出力

| 関数・引数 | 処理 | 戻り値・出力 |
| --- | --- | --- |
| `inventory(ownership_only=False)` | 共有アカウントのセキュリティ機能を照会する。ownership_onlyでは所有確認に必要な情報へ絞る。 | 照会結果・APIエラーの辞書 |
| `assert_owned_security(observed, state)` | 実AWSとStateの所有情報を照合する。他用途の共有設定を取り込まないよう不一致なら停止する。 | None（不一致は例外） |
| `read(name, call)` | AWS照会結果またはAPIエラーコードを項目別に記録し、所有判定へ渡す。 | None。resultへ照会結果またはエラーを格納 |
| `subscriptions()` | SNS購読のプロトコルと確認状況を取得する。通知先の連絡先は返さない。 | 通知先を含まない購読状況のリスト |
| `attrs(kind)` | Stateからportfolio名の指定種類のリソース属性だけを抽出する。 | アドレスと属性辞書の組のリスト |

## 3. 処理・分岐・外部操作

1. inventoryはGuardDuty・Inspector・Config recorder・Security Hub・ECRスキャンを照会する。ownership_only=Falseでは基準、Lambda上限・使用量、SNS購読状態も取得する。SNS通知先の値は返さない。ClientErrorは項目ごとにerrorコードへ変換する。

2. assert_owned_securityはStateのmanaged・name=portfolioから対象属性を抽出する。GuardDuty ID集合、Config recorder名・role ARN、Security Hub ARNを実環境と照合する。

3. InspectorがStateにない場合に有効な設定が存在すれば停止する。ECRはStateがない場合BASICかつrules空を期待し、Stateがある場合はscan_typeとruleを比較する。

4. 不一致・照会不能を各OWNERSHIP_CHANGED等のRuntimeErrorとして伝播する。所有一致時はNoneを返し、CLIはAccount security ownership verifiedを表示する。設定の取込や変更は行わない。

## 4. 異常終了・再実行

主な停止理由は`CONFIG_OWNERSHIP_CHANGED`、`CONFIG_ROLE_CHANGED`、`ECR_SCANNING_OWNERSHIP_CHANGED`、`GUARDDUTY_OWNERSHIP_CHANGED`、`INSPECTOR_INVENTORY_UNAVAILABLE`、`INSPECTOR_OWNERSHIP_CHANGED`、`SECURITYHUB_OWNERSHIP_CHANGED`。

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
