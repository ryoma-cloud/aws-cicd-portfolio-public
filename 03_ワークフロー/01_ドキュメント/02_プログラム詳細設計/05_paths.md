# paths.py 詳細設計書

## 1. 目的・呼出元

資材パスの解決を行う。対象プログラムは`03_ワークフロー/02_資材/tools/paths.py`である。

build.py等から定数をimportする。

## 2. 関数・入出力

関数定義はない。定義する定数を次節に示す。

## 3. 処理・分岐・外部操作

1. __file__の絶対パスからparents[3]をPROJECT_ROOTとして決定する。

2. ASSET_ROOT=PROJECT_ROOT/02_資材、TEMP_ROOT=ASSET_ROOT/02_temporary、WORKFLOW_ASSETS=PROJECT_ROOT/03_ワークフロー/02_資材をモジュール定数として定義する。

3. 関数・CLI引数・AWS操作・ファイル作成はない。パスの存在確認は呼出側が行う。

### 定数

| 定数 | 定義 |
| --- | --- |
| `PROJECT_ROOT` | `Path(__file__).resolve().parents[3]` |
| `ASSET_ROOT` | `PROJECT_ROOT / '02_資材'` |
| `TEMP_ROOT` | `ASSET_ROOT / '02_temporary'` |
| `WORKFLOW_ASSETS` | `PROJECT_ROOT / '03_ワークフロー' / '02_資材'` |

## 4. 異常終了・再実行

処理内で明示していないAPI・ファイル・JSON等の例外は呼出元へ伝播し、CLIでは非正常終了となる。自動切り戻しは行わない。再実行は入口から行い、成功済みの副作用と入力・証跡を確認する。待機や再試行は第3節に記載した箇所のみ明示的に実装し、SDK内部の再試行とは区別する。
