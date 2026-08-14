# LLM Wiki for Claude Code

**AI に知識ベースの司書をやらせる仕組み**を、Claude Code にセットアップするためのテンプレート一式です。

Andrej Karpathy が2026年4月に提唱した [LLM Wiki パターン](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)を、複数プロジェクトで運用できる形にしたもの。macOS / Linux / Windows 対応。

> このリポジトリに入っているのは**仕組みだけ**です。Wiki の中身（あなたの知識）は `~/wiki` と各プロジェクトの `docs/wiki/` に置かれ、ここには含まれません。

---

## 何が解決されるか

Claude Code を使っていると、こうなりがちです。

- セッションが変わるたびに**プロジェクトの経緯を説明し直している**
- 「前に決めたはずのこと」を毎回コードから読み直させていて、**遅いし高い**
- 調べた結果がチャットログの底に沈んで、**二度と見つからない**

LLM Wiki は、調べた結果・決めたことを AI が Markdown の Wiki として書き溜め、**次からはそれを読む**ようにします。ベクトル DB も埋め込みも不要で、実体は素の Markdown フォルダです。

```
[取り込み] 資料や会話を ingest → AI が Wiki を書き、既存ページを書き換える
[質問]     index.md → 関連ページを読む → 根拠のページ名を引用して答える
[点検]     週1回 lint → 矛盾・古い記述・孤立ページを検出（修正判断は人間）
```

---

## インストール

### macOS / Linux

```sh
git clone https://github.com/<owner>/llm-wiki.git
cd llm-wiki
./install/install.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/<owner>/llm-wiki.git
cd llm-wiki
powershell -ExecutionPolicy Bypass -File .\install\install.ps1
```

インストーラが行うこと:

| 配置先 | 内容 |
|---|---|
| `~/wiki/` | vault（SCHEMA.md / OPERATIONS.md / index.md / log.md / knowledge / projects / mounts） |
| `~/.claude/skills/llm-wiki/` | `/llm-wiki` コマンド（ingest / query / lint） |
| `~/.claude/rules/llm-wiki.md` | Wiki のファイルに触れたときだけ規約を読み込む path-scoped rule |
| `~/.claude/hooks/` | セッション開始時に `docs/wiki/index.md` を注入するフック |
| `~/.claude/settings.json` | SessionStart フックの登録（`.bak` を残します） |

既存ファイルは上書きしません。`~/wiki` の場所を変えるには `LLM_WIKI_VAULT`（sh）または `-Vault`（ps1）を指定します。

インストール後、**Claude Code を再起動**してください（または `/hooks` を一度開く）。

---

## プロジェクトを接続する

```sh
cd ~/path/to/your-project
~/path/to/llm-wiki/install/install.sh --connect .
```

```powershell
cd C:\path\to\your-project
& C:\path\to\llm-wiki\install\install.ps1 -Connect .
```

`docs/raw/` と `docs/wiki/` を作り、vault の `mounts/` から繋ぎ、`CLAUDE.md` を配置します。そのあと Claude Code で:

```
/llm-wiki ingest README.md
```

最後に git 追跡へ加えてください。`git diff docs/wiki` での差分レビューが運用の要になります。

**いきなり全プロジェクトに入れないでください。** まず1つで2週間ほど回し、`~/wiki/SCHEMA.md` を自分に合わせて直すのが確実です。

---

## 使い方（4つだけ）

| いつ | コマンド | 目安 |
|---|---|---|
| 作業を始めるとき | `/llm-wiki query 今の状況と次にやることは？` | 10秒 |
| 作業の区切り | `/llm-wiki ingest 今日の作業内容` | 5〜10分 |
| ingest の直後 | `git diff docs/wiki` で差分レビュー | 5分 |
| 週1回 | `/llm-wiki lint` → 矛盾を裁定 | 15〜30分 |

**人間の負荷は週30〜60分**です。これを払えないなら、入れるソースを絞るか導入を見送ってください。lint と差分レビューを飛ばすと、Wiki は誤りを固定して繰り返す側に転びます。

---

## ドキュメント

はじめての人は上から順に。

| # | ドキュメント | 内容 |
|---|---|---|
| 1 | [LLM Wiki とは](docs/01-what-is-llm-wiki.md) | 何をする仕組みか。RAG や普通のメモとの違い |
| 2 | [導入する](docs/02-getting-started.md) | 手動セットアップの手順（インストーラの中身） |
| 3 | [日々の使い方](docs/03-daily-usage.md) | 4つのコマンドと1日の流れ |
| 4 | [レビューと lint](docs/04-review-and-lint.md) | 人間が判断する部分。運用の要 |
| 5 | [構成とページの書き方](docs/05-structure.md) | ディレクトリ構成、frontmatter、置き場所の基準 |
| 6 | [よくある質問](docs/06-faq.md) | つまずきどころ、Windows 固有の話、チーム利用 |
| — | [用語集](docs/glossary.md) | ingest / vault / 昇格 など |

---

## リポジトリの構成

```
llm-wiki/
├── template/     ~/wiki に配置される vault の雛形
│   ├── SCHEMA.md          ページの規約（AI が読む唯一の正）
│   ├── OPERATIONS.md      運用手順
│   ├── index.md / log.md
│   └── CLAUDE.md.example  プロジェクトに置く CLAUDE.md の雛形
├── skill/        ~/.claude/skills/llm-wiki/ に配置（/llm-wiki コマンド）
├── rules/        ~/.claude/rules/ に配置（path-scoped rule）
├── hooks/        ~/.claude/hooks/ に配置（.sh = mac/Linux, .ps1 = Windows）
├── install/      インストーラ
└── docs/         入門から運用までのドキュメント
```

---

## Windows について

3点だけ挙動が異なります。詳細は [FAQ](docs/06-faq.md#windows) を参照してください。

- **フックは PowerShell 版**（`.ps1`）を使います。settings.json には `"shell": "powershell"` が付きます
- **mounts はシンボリックリンクではなくジャンクション**を使います。管理者権限も開発者モードも不要です
- **PowerShell 7 (pwsh) を推奨**します。5.1 でも動きますが、日本語の出力エンコーディングに注意が必要です

Git Bash を使っている場合は `.sh` 版でも動作します。

---

## 前提

- **Claude Code**（他のエージェントでも考え方は同じですが、スキルとフックは Claude Code 前提です）
- **git** — 差分レビューに使うため実質必須
- **jq**（任意・macOS/Linux）— あれば settings.json を自動更新します。無ければ追加すべき JSON を表示します
- Obsidian は**任意**です

---

## ライセンス

MIT
