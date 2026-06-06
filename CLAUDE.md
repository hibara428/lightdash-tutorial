# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

すべての dbt コマンドは `dbt/` ディレクトリで `--profiles-dir .` を付けて実行する（`profiles.yml` がプロジェクトルートにあるため）。

```bash
# dbt
cd dbt
dbt debug --profiles-dir .          # BigQuery 接続確認
dbt run --profiles-dir .            # 全モデル実行
dbt run --profiles-dir . -s customers  # 特定モデルのみ実行
dbt test --profiles-dir .           # 全テスト実行
dbt test --profiles-dir . -s stg_orders  # 特定モデルのテストのみ
dbt compile --profiles-dir .        # SQL コンパイル（Lightdash 用 manifest.json 生成）

# Lightdash (Docker)
docker compose up -d                # 起動
docker compose down                 # 停止
docker compose down -v              # 停止 + ボリューム削除（メタデータリセット）
docker compose logs -f lightdash    # ログ確認

# Lightdash CLI (dashboard as code)
lightdash login http://localhost:8080 --token YOUR_PAT
lightdash list projects
lightdash upload --project-uuid <UUID>   # YAML → Lightdash にデプロイ
lightdash download --project-uuid <UUID> # Lightdash → YAML に取得
```

## Architecture

### データフロー

```
bigquery-public-data.thelook_ecommerce  (source)
        ↓ dbt sources
dbt/models/staging/  → BigQuery: lightdash_tutorial.staging.*  (view)
        ↓ dbt refs
dbt/models/marts/    → BigQuery: lightdash_tutorial.marts.*    (table)
        ↓ Lightdash 接続
Lightdash UI / dashboard as code YAML
```

### dbt モデル構成

- **staging**: `stg_users`, `stg_orders`, `stg_order_items`, `stg_products` — source からのクレンジングのみ、view で実体化
- **marts**: `customers`（users + 注文集計）、`orders`（orders + order_items + products 集計）— table で実体化

### Lightdash メタ定義

`dbt/models/marts/schema.yml` が核心ファイル。各カラムの `meta:` ブロックで Lightdash の dimension/metrics を定義している。Lightdash はこのファイルと `dbt compile` で生成される `target/manifest.json` を読んで Tables・Dimensions・Metrics を構築する。

### Dashboard as Code

`dbt/lightdash/` 配下の YAML は Lightdash CLI (`lightdash upload`) でデプロイするもの。UI で作ったダッシュボードとは独立して共存する。

- `saved_queries/*.yml` — チャート定義（`tableName`, `metricQuery`, `chartConfig` を持つ）
- `dashboards/*.yml` — ダッシュボード定義（saved_queries を `savedChartName` で参照）

YAML の `fieldId` は `<tableName>_<fieldName>` 形式（例: `orders_total_revenue`）。実際のフィールド名が不明な場合は `lightdash download` で既存コンテンツから確認する。

### 環境変数・認証

- BigQuery 認証: `gcloud auth application-default login`（ADC）で行う。サービスアカウント JSON は不要。
- `GCP_PROJECT_ID` — dbt の `profiles.yml` が `env_var('GCP_PROJECT_ID')` で参照。シェルと `.env` 両方に設定する。
- `.env` — Docker Compose が読む（`LIGHTDASH_SECRET`, `PG*`, `PORT`）

### BigQuery データセット・スキーマ

dbt_project.yml の `+schema` 設定により、BigQuery での実際のデータセット名は `lightdash_tutorial_staging`（staging）と `lightdash_tutorial_marts`（marts）になる（dbt がプロジェクト名をプレフィックスとして付加する）。Lightdash のウェアハウス設定では dataset を `lightdash_tutorial` に設定し、dbt が生成する実際のデータセット名（`lightdash_tutorial_marts`）をターゲットにする。
