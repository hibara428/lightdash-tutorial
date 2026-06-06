# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

依存関係は `uv` で管理する。`pyproject.toml` がプロジェクトルートにある。

```bash
# 依存インストール（初回・pyproject.toml 変更時）
uv sync
```

dbt コマンドは `dbt/` ディレクトリで実行する。`dbt/.env` に `GCP_PROJECT_ID` と `DBT_PROFILES_DIR=.` を設定済みのため追加フラグ不要。

```bash
# dbt（cd dbt してから実行）
uv run --env-file .env dbt debug
uv run --env-file .env dbt run
uv run --env-file .env dbt run -s customers
uv run --env-file .env dbt test
uv run --env-file .env dbt test -s stg_orders
uv run --env-file .env dbt compile

# Lightdash (Docker)
docker compose up -d                # 起動
docker compose down                 # 停止
docker compose down -v              # 停止 + ボリューム削除（メタデータリセット）
docker compose logs -f lightdash    # ログ確認

# Lightdash CLI (dashboard as code)
# npm install の後は npx lightdash で実行
npx lightdash login http://localhost:8080 --token YOUR_PAT
npx lightdash list projects
npx lightdash deploy --project-dir dbt --profiles-dir dbt
npx lightdash upload --project-uuid <UUID>   # YAML → Lightdash にデプロイ
npx lightdash download --project-uuid <UUID> # Lightdash → YAML に取得
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
- `GCP_PROJECT_ID` — dbt の `profiles.yml` が参照。`dbt/.env` に設定（uv が自動で読む）。
- `.env`（ルート） — Docker Compose 用（`LIGHTDASH_SECRET`, `PG*`, `PORT`）。
- `dbt/.env` — dbt 用（`GCP_PROJECT_ID` と `DBT_PROFILES_DIR=.`）。両ファイルとも `.gitignore` 済み。

### BigQuery データセット・スキーマ

dbt_project.yml の `+schema` 設定により、BigQuery での実際のデータセット名は `lightdash_tutorial_staging`（staging）と `lightdash_tutorial_marts`（marts）になる（dbt がプロジェクト名をプレフィックスとして付加する）。Lightdash のウェアハウス設定では dataset を `lightdash_tutorial` に設定し、dbt が生成する実際のデータセット名（`lightdash_tutorial_marts`）をターゲットにする。
