# Lightdash チュートリアル

dbt-core + BigQuery public dataset + Docker Compose (セルフホスト Lightdash) を使った入門チュートリアルです。

## アーキテクチャ

```
bigquery-public-data                 ホストマシン                    Docker
.thelook_ecommerce ──sources──→  dbt-core (dbt-bigquery)        ┌──────────────────┐
                                   ↓ dbt run                     │ lightdash:latest │
                  YOUR_PROJECT.lightdash_tutorial ←────────────→ │  :8080           │
                  （BigQuery dataset に mart を出力）             │ postgres:14      │
                                                                 │ (メタデータ用)    │
                                                                 └──────────────────┘
```

## 前提条件

- Python 3.9 以上
- Docker および Docker Compose（Docker Desktop 推奨）
- GCP プロジェクト（BigQuery API が有効であること）
- gcloud CLI（`gcloud auth application-default login` で ADC 認証済みであること）

---

## Part 1: dbt セットアップ

### ステップ 1: リポジトリのクローン

```bash
git clone <このリポジトリのURL>
cd lightdash-tutorial
```

### ステップ 2: Python 仮想環境と dbt のインストール

```bash
python3 -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate

pip install dbt-core dbt-bigquery
dbt --version
```

### ステップ 3: GCP 認証

Application Default Credentials (ADC) で認証します。サービスアカウント JSON は不要です。

```bash
gcloud auth application-default login
```

ブラウザが開いて Google アカウントの認証が完了したら、環境変数ファイルを作成します。

```bash
cp .env.example .env
```

`.env` と現在のシェルに `GCP_PROJECT_ID` を設定します。

```bash
export GCP_PROJECT_ID=your-gcp-project-id
```

### ステップ 4: dbt の動作確認

```bash
cd dbt
dbt debug --profiles-dir .
```

すべての項目が `OK` と表示されれば接続成功です。

### ステップ 5: dbt モデルの実行

```bash
dbt run --profiles-dir .
```

BigQuery に `lightdash_tutorial` データセットが作成され、以下のモデルが生成されます。

| モデル | 種別 | 内容 |
|--------|------|------|
| `staging.stg_users` | view | 顧客データ（クレンジング済み） |
| `staging.stg_orders` | view | 注文ヘッダ（クレンジング済み） |
| `staging.stg_order_items` | view | 注文明細（クレンジング済み） |
| `staging.stg_products` | view | 商品マスタ（クレンジング済み） |
| `marts.customers` | table | 顧客 + 注文集計 |
| `marts.orders` | table | 注文 + 商品集計 |

### ステップ 6: dbt テストの実行

```bash
dbt test --profiles-dir .
```

すべて `PASS` と表示されれば OK です。

---

## Part 2: Lightdash セットアップ

### ステップ 7: 環境変数の設定

`.env` の `LIGHTDASH_SECRET` に安全なランダム文字列を設定します。

```bash
openssl rand -hex 32   # 出力をコピーして .env に貼り付け
```

### ステップ 8: Lightdash の起動

プロジェクトルートに戻って Docker Compose を起動します。

```bash
cd ..
docker compose up -d
```

起動ログを確認します（「Lightdash is ready」が表示されれば OK）。

```bash
docker compose logs -f lightdash
```

### ステップ 9: ブラウザでアクセス

[http://localhost:8080](http://localhost:8080) を開きます。

**初回セットアップ**:
1. 管理者アカウントを作成（名前・メール・パスワード）
2. 組織名を入力
3. 「Connect your project」画面へ

**dbt プロジェクトの接続**:

| 項目 | 設定値 |
|------|--------|
| Connection type | `dbt local server` |
| Project directory | `/usr/app/dbt` |
| Target | `dev` |

**BigQuery ウェアハウスの設定**:

> **認証について**: dbt は ADC（`gcloud auth application-default login`）を使いますが、Lightdash は Docker コンテナ内で動くため ADC にアクセスできません。Lightdash には**サービスアカウント JSON** を別途用意して設定します。

サービスアカウントに必要なロール:
- `BigQuery Data Viewer`（データ参照）
- `BigQuery Job User`（クエリ実行）

| 項目 | 設定値 |
|------|--------|
| Warehouse | `BigQuery` |
| Authentication method | `Service Account` |
| Project | `your-gcp-project-id` |
| Dataset | `lightdash_tutorial` |
| Location | `US` |
| Service Account JSON | サービスアカウント JSON の内容を貼り付け（ファイルは不要） |

「Test connection」で接続確認後、「Save」で保存します。

---

## Part 3: Lightdash でデータ探索

### ステップ 10: Tables を探索する

左メニュー「Tables」から `customers` または `orders` を選択します。

`schema.yml` の `meta` セクションから読み込まれた **Dimensions**（ディメンション）と **Metrics**（メトリクス）が表示されます。

### ステップ 11: チャートを作成する（UI）

`orders` テーブルで以下を試してみましょう。

1. Dimensions から「注文日 - Month」を選択
2. Metrics から「総売上」を選択
3. 「Run query」をクリック
4. Chart type を「Bar chart」に変更

「Save chart」で「月次売上（UI）」として保存します。

**他に試してほしいチャート**:

| チャート名 | テーブル | Dimension | Metric |
|-----------|---------|-----------|--------|
| 注文ステータス分布 | orders | ステータス | 注文件数 |
| 国別売上 | customers | 国 | 総売上 |
| カテゴリ別平均注文金額 | orders | 主カテゴリ | 平均注文金額 |

### ステップ 12: ダッシュボードを作成する（UI）

1. 左メニュー「Dashboards」→「+ Create dashboard」
2. ダッシュボード名を入力（例: 「売上分析（UI版）」）
3. 「+ Add tile」→「Saved charts」から保存したチャートを追加
4. タイルをドラッグして配置を調整
5. 「Save」で保存

---

## Part 4: Dashboard as Code

UI で作成したダッシュボードとは別に、YAML ファイルでダッシュボードを定義してコードとして管理します。

### ステップ 13: Lightdash CLI のインストール

```bash
npm install -g @lightdash/cli
```

### ステップ 14: Personal Access Token の取得

1. Lightdash UI → 右上のユーザーアイコン → 「Settings」
2. 「Personal Access Tokens」→「+ Generate token」
3. トークン名を入力して「Generate」
4. 表示されたトークンをコピー（一度しか表示されません）

### ステップ 15: Lightdash CLI でログイン

```bash
lightdash login http://localhost:8080 --token YOUR_PAT
```

プロジェクト UUID を確認します。

```bash
lightdash list projects
```

### ステップ 16: YAML ファイルを確認・編集

`dbt/lightdash/` 配下に定義済みのファイルがあります。

```
dbt/lightdash/
├── saved_queries/
│   ├── monthly_revenue.yml       # 月次売上（棒グラフ）
│   ├── order_status.yml          # ステータス分布（円グラフ）
│   └── top_countries.yml         # 国別売上（テーブル）
└── dashboards/
    └── sales_dashboard.yml       # 売上分析ダッシュボード
```

`monthly_revenue.yml` を開いて `label` を変更してみましょう。

```yaml
label: 月次売上（コード管理）   # ← 変更
```

### ステップ 17: ダッシュボードをデプロイする

```bash
cd dbt
lightdash upload --project-uuid <YOUR_PROJECT_UUID>
```

### ステップ 18: ブラウザで確認

Lightdash の「Dashboards」に「売上分析ダッシュボード」が追加されているか確認します。
これは UI で作ったダッシュボードとは独立して存在します。

**YAML 変更 → 再デプロイ → ブラウザで確認** のサイクルを試してみてください。

> **ポイント**: `lightdash upload` は YAML に定義されたダッシュボードのみを更新します。UI で作ったダッシュボードには影響しません。ダッシュボードごとにコード管理か UI 管理かを選択できます。

---

## Lightdash の停止

```bash
docker compose down
```

データを完全に削除する場合（Lightdash のメタデータも削除）:

```bash
docker compose down -v
```

---

## トラブルシューティング

### `dbt debug` で BigQuery への接続エラーが発生する

- `gcloud auth application-default login` が完了しているか確認
- `GCP_PROJECT_ID` 環境変数が設定されているか確認（`echo $GCP_PROJECT_ID`）
- `gcloud auth application-default print-access-token` でトークンが取得できるか確認

### Lightdash が起動しない

```bash
docker compose logs lightdash
docker compose logs db
```

`.env` の `LIGHTDASH_SECRET` が設定されているか確認してください。

### Lightdash で BigQuery に接続できない

- BigQuery の dataset `lightdash_tutorial` が存在するか（`dbt run` が完了しているか）確認
- サービスアカウントに BigQuery Job User ロールがあるか確認（クエリ実行に必要）

### ポート 8080 が使用中

`docker-compose.yml` の `ports` を `"8081:8080"` に変更し、`http://localhost:8081` でアクセスしてください。

### `lightdash upload` でエラーが発生する

`lightdash download` で既存の YAML フォーマットを確認し、`saved_queries/*.yml` の構造を合わせてください。

```bash
lightdash download --project-uuid <YOUR_PROJECT_UUID>
```

---

## ファイル構成

```
lightdash-tutorial/
├── .env.example              # 環境変数テンプレート
├── .gitignore
├── README.md                 # このファイル
├── docker-compose.yml        # Lightdash + PostgreSQL
└── dbt/
    ├── dbt_project.yml
    ├── profiles.yml          # BigQuery 接続設定
    ├── models/
    │   ├── sources.yml       # thelook_ecommerce public dataset
    │   ├── staging/          # ステージングモデル（view）
    │   └── marts/            # マートモデル（table）+ Lightdash meta
    └── lightdash/
        ├── saved_queries/    # チャート定義 YAML（dashboard as code）
        └── dashboards/       # ダッシュボード定義 YAML（dashboard as code）
```
