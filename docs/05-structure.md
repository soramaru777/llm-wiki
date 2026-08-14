[← 目次](README.md) | 前: [レビューと lint](04-review-and-lint.md) | 次: [よくある質問 →](06-faq.md)

# 5. 構成とページの書き方

---

## ディレクトリ構成

```
~/wiki/                              グローバル vault（個人・横断）
├── SCHEMA.md                        ページの規約（唯一の正）
├── OPERATIONS.md                    運用手順（いつ何を実行するか）
├── index.md                         全ページの1行カタログ
├── log.md                           操作ログ（追記のみ）
├── knowledge/                       横断知識
│   ├── deepgram-streaming-ja.md
│   └── fly-io-deployment.md
├── projects/
│   └── termlens.md                  プロジェクトのハブページ
└── mounts/
    └── termlens ──────────┐         symlink
                           │
~/development/TermLens/    │
├── CLAUDE.md              │         @~/wiki/SCHEMA.md を参照
└── docs/                  │
    ├── raw/               │         生の資料（書き換えない）
    │   └── 2026-08-13-fly-deploy.md
    └── wiki/  ←───────────┘         AI が維持するページ
        ├── index.md
        ├── log.md
        └── termlens-*.md
```

---

## なぜ2箇所に分けるのか

**判断基準はこれだけです。**

> そのリポジトリを他人に渡したとき、一緒に行くべき知識か？

| 答え | 置き場所 | 例 |
|---|---|---|
| **Yes** | `<repo>/docs/wiki/` | アーキテクチャ、設計判断、既知の課題、運用手順 |
| **No** | `~/wiki/knowledge/` | ライブラリや API の一般的な知見、自分の作業スタイル |

### 昇格ルール

**同じ知見が2プロジェクト以上で出てきたら `~/wiki/knowledge/` へ移し**、各プロジェクトからはリンクで参照します。重複を放置すると、どちらが最新か分からなくなります。

> **実例**
> 「Fly.io はカード未登録だとマシンが5分で強制停止される」はTermLens 固有ではないので `knowledge/fly-io-deployment.md` に昇格させ、TermLens 側からはリンクを張りました。

### symlink の役割

`mounts/` の symlink があることで、**`~/wiki` を1つのフォルダとして開くだけで全プロジェクトの Wiki が横断表示・横断検索できます**。実体はプロジェクト側に残るので、リポジトリと一緒に git 管理できます。

「集約の利便性」と「リポジトリ単位の管理」を両立させるための工夫です。

---

## 必ず要る2つのファイル

見落とされがちですが、この2つが骨格です。

### `index.md` — 目次

全ページの1行カタログ。**AI が最初に読む入口**です。

これが無いと、ページが増えた瞬間に AI も人も全体を見失います。ページを追加したら必ず1行足します。

### `log.md` — 操作ログ

追記のみ、新しいものを下に足します。

```
2026-08-13 ingest — README.md と status メモを取り込み。5ページを生成。
2026-08-14 doc — OPERATIONS.md を新規作成。index.md に追加。
```

「いつ何がどう変わったか」を追えるようにするためです。

---

## ページの書き方

### frontmatter（全ページ必須）

ファイル先頭の `---` で囲まれた部分です。

```yaml
---
title: TermLens アーキテクチャ
type: concept
project: termlens
scope: shared
sources:
  - README.md
  - docs/raw/2026-08-13-fly-deploy.md
related: [[termlens-stt-pipeline]], [[termlens-open-issues]]
confidence: high
updated: 2026-08-14
---
```

| 項目 | 意味 |
|---|---|
| `title` | 人間が読むタイトル |
| `type` | ページの種類（下記） |
| `project` | プロジェクト名、または `global` |
| `scope` | `shared`（共有可）/ `private`（個人的な好み・作業ログ） |
| `sources` | **出典。空なら lint で警告される** |
| `related` | 関連ページ |
| `confidence` | `high` / `medium` / `low`。**low は未検証** |
| `updated` | 最終更新日 |

`sources` と `confidence` は**ハルシネーション対策の要**です。省略させないでください。

### type の種類

| type | 使いどころ |
|---|---|
| `concept` | 仕組み・考え方の説明 |
| `entity` | 人・組織・製品など固有のもの |
| `decision` | 設計判断とその理由 |
| `issue` | 課題・既知の問題 |
| `source-summary` | 特定の資料の要約 |
| `comparison` | 複数の選択肢の比較 |
| `howto` | 手順書 |
| `hub` | 入口となるまとめページ |

### 命名規則

- ケバブケース（小文字とハイフン）
- **`<project>-<topic>.md`** の形にする → 例: `termlens-architecture.md`
- **プロジェクト名の接頭辞は必須**。`architecture.md` のような汎用名は、mounts で集約したときに衝突する
- `knowledge/` 配下は接頭辞不要 → 例: `deepgram-streaming-ja.md`

### 本文

- **冒頭1〜2行で「このページは何か」**を書く。ここだけ読んで判断できること
- 関連概念は `[[wikilink]]` で結ぶ
- **存在しないページへリンクを張ってよい**。「次に書くべきページ」の印になり、lint が拾ってくれる
- **推測と事実を混ぜない**。未検証は `confidence: low` にし、本文にも明記する

---

## SCHEMA.md のひな形

`~/wiki/SCHEMA.md` に書く内容の骨組みです。

```markdown
# LLM Wiki スキーマ

このファイルが唯一の正のスキーマ定義。各プロジェクトの CLAUDE.md は
このファイルを参照するだけにし、内容を複製しないこと。

## 1. 構成
（ディレクトリ構成と、置き場所の判断基準・昇格ルール）

## 2. ページ
（frontmatter の項目、type の種類、命名規則、本文の書き方）

## 3. 操作
### ingest
1. ソースを raw/ に置く（以後書き換えない）
2. 全文を読む
3. 既存ページを更新する ← 新規追加だけで済ませない
4. 新しい概念はページを新規作成
5. index.md に1行、log.md に追記
6. 1ソースで複数ページに波及するのが正常

### query
1. index.md → 関連ページの順に読む。生ソースは最後の手段
2. 回答には必ずページ名を引用する
3. Wiki に無ければ「無い」と明言してから調べる。推測で埋めない

### lint
（検出項目の一覧）
lint は検出を報告するだけで、自動修正しない。

## 4. 運用ルール
- raw/ は不変
- すべて可逆に（破壊的な整理の前に commit）
- 機密を書かない
- 出典のない断定を書かない
```

---

## CLAUDE.md の書き方

各プロジェクトに置きます。**規約は複製せず、参照だけ**にするのが要点です。

```markdown
# <プロジェクト名>

## LLM Wiki

このプロジェクトは LLM Wiki パターンで知識を管理している。
スキーマの定義は @~/wiki/SCHEMA.md を参照すること（ここには複製しない）。

- `docs/raw/` — 不変のソース。LLM は読むだけ
- `docs/wiki/` — LLM が保守するページ。入口は docs/wiki/index.md

**作業を始める前に `docs/wiki/index.md` を読むこと。**

設計判断・既知の課題が変わったら、コードと一緒に docs/wiki/ を更新する。
他プロジェクトでも通用する知見は ~/wiki/knowledge/ に昇格させる。
```

規約を各プロジェクトに複製すると、10箇所に増えた時点で必ず腐ります。**参照は1本に絞ってください。**

---

次: [6. よくある質問 →](06-faq.md)
