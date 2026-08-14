[← 目次](README.md) | 前: [LLM Wiki とは](01-what-is-llm-wiki.md) | 次: [日々の使い方 →](03-daily-usage.md)

# 2. 導入する

所要時間は**30分ほど**です。この章を終えると、1つのプロジェクトで質問と取り込みができる状態になります。

すでに `~/wiki` がある場合は [ステップ4](#ステップ4-最初のプロジェクトを繋ぐ) から読んでください。

> **インストーラを使う場合はこの章を読む必要はありません。**
>
> ```sh
> ./install/install.sh            # macOS / Linux
> ```
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\install\install.ps1   # Windows
> ```
>
> この章は「インストーラが何をしているか」を説明したものです。手で組みたい人、仕組みを理解したい人向けです。

## Windows で読む場合

コマンド例は macOS / Linux 表記です。Windows では次の3点だけ読み替えてください。

| このドキュメント | Windows (PowerShell) |
|---|---|
| `~/wiki` | `$env:USERPROFILE\wiki` |
| `ln -sfn <実体> <リンク>` | `New-Item -ItemType Junction -Path <リンク> -Target <実体>` |
| `~/.claude/hooks/*.sh` | `~/.claude/hooks/*.ps1`（settings.json に `"shell": "powershell"` を付ける） |

**ジャンクションを使う理由**は、Windows のシンボリックリンクが管理者権限か開発者モードを要求するのに対し、ディレクトリのジャンクションは**通常の権限で作れる**ためです。Claude Code から見た挙動は同じです。

Git Bash を使っているなら、`.sh` 版のまま進めても動作します。

---

## 全体像

作るものは2つです。

```
~/wiki/                          ← ① 全プロジェクト共通の置き場（vault）
└── ...

~/development/<project>/         ← ② プロジェクトごとの Wiki
└── docs/
    ├── raw/
    └── wiki/
```

**なぜ2つに分けるのか。** プロジェクト固有の知識（このアプリの設計判断）と、どこでも使える知識（Stripe の使い方、Fly.io の罠）は性質が違うからです。前者はリポジトリと一緒に人へ渡すべきで、後者は自分の資産として1箇所に集めたい。詳しくは [5. 構成](05-structure.md) で説明します。

---

## ステップ1: vault を作る

```sh
mkdir -p ~/wiki/knowledge ~/wiki/projects ~/wiki/mounts
```

| フォルダ | 用途 |
|---|---|
| `knowledge/` | 複数プロジェクトで使える知識 |
| `projects/` | 各プロジェクトの概要ページ（ハブ） |
| `mounts/` | 各プロジェクトの Wiki へのショートカット（symlink） |

---

## ステップ2: ルールを書く

vault に3つのファイルを置きます。**これは AI に読ませるためのファイル**です。

### `~/wiki/SCHEMA.md` — ページの規約

ページの書き方（frontmatter、命名規則、置き場所の基準、3つの操作の手順）を定義します。**この1ファイルが唯一の正**とし、各プロジェクトには複製しません。

内容は [5. 構成とページの書き方](05-structure.md) にひな形があります。

### `~/wiki/index.md` — 目次

全ページの1行カタログ。**AI が最初に読む入口**になります。これが無いと、ページが増えた瞬間に全体を見失います。

### `~/wiki/log.md` — 操作ログ

追記のみ。「いつ何を取り込んで、どのページがどう変わったか」を残します。

> Claude Code に `~/wiki/SCHEMA.md を作って。LLM Wiki の規約として、frontmatter・命名規則・置き場所の基準・ingest/query/lint の手順を定義して` と頼めば下書きが作れます。そこから自分用に直すのが早いです。

---

## ステップ3: スキルを入れる

`/llm-wiki` というコマンドを全プロジェクトで使えるようにします。

置き場所は `~/.claude/skills/llm-wiki/SKILL.md` です。**ユーザーレベル（`~/.claude/`）に置くのがポイント**で、こうすると `~/development` 配下のどのプロジェクトからでも呼べます。

```
~/.claude/skills/llm-wiki/SKILL.md
```

中身は「ingest / query / lint をどう実行するか」の手順書です。冒頭に必ず **`~/wiki/SCHEMA.md` を読むこと**と書いておき、規約の重複を避けます。

既製のものを入れて直す方法もあります。

```sh
npx add-skill Astro-Han/karpathy-llm-wiki
```

### 動作確認

Claude Code を開き直して、`/llm-wiki` と打って候補に出れば成功です。

---

## ステップ4: 最初のプロジェクトを繋ぐ

**いきなり全プロジェクトに入れないでください。** まず1つで2週間ほど回して、ルールを自分に合わせて直すのが確実です。

対象は「これから数週間触り続けるもの」を選びます。

### 4-1. 器を作る

```sh
cd ~/development/<project>
mkdir -p docs/raw docs/wiki
ln -sfn ~/development/<project>/docs/wiki ~/wiki/mounts/<project>
```

3行目の `ln -sfn` は**ショートカット（symlink）を作るコマンド**です。これにより、`~/wiki` を1つのフォルダとして開くだけで、各プロジェクトの Wiki も一緒に見えるようになります。実体はプロジェクト側に残るので、リポジトリと一緒に git 管理できます。

### 4-2. AI に組ませる

Claude Code で、そのプロジェクトを開いて頼みます。

```
このプロジェクトを LLM Wiki に接続して。
CLAUDE.md を作って（規約は @~/wiki/SCHEMA.md を参照するだけにして）、
~/wiki/projects/<project>.md にハブページも作って。
そのあと README.md を ingest して
```

`CLAUDE.md` は Claude Code がそのプロジェクトを開くたびに自動で読むファイルです。ここに「作業前に `docs/wiki/index.md` を読むこと」と書いておくと、毎回指示しなくても Wiki を見に行くようになります。

### 4-3. git に追跡させる

**ここを飛ばさないでください。** 取り込み結果のレビューに `git diff` を使うため、追跡していないと運用が回りません。

```sh
echo "docs/local/" >> .gitignore   # ローカル専用メモがあれば除外
git add .gitignore docs/raw docs/wiki CLAUDE.md
git commit -m "LLM Wiki を導入"
```

---

## ステップ5: 最初の質問をしてみる

```
/llm-wiki query このプロジェクトの構成を教えて
```

回答に**ページ名の引用**（`taskflow-architecture.md より` など）が付いていれば、正しく Wiki を読んでいます。付いていなければ、`index.md` から読むよう指示し直してください。

---

## できあがり

```
~/wiki/
├── SCHEMA.md              規約（唯一の正）
├── index.md               全体の目次
├── log.md                 操作ログ
├── knowledge/             横断知識
├── projects/
│   └── <project>.md       ハブページ
└── mounts/
    └── <project> ─────┐   symlink
                       │
~/development/<project>/
├── CLAUDE.md              @~/wiki/SCHEMA.md を参照
└── docs/
    ├── raw/           ←   生の資料（書き換えない）
    └── wiki/          ←───┘ AI が維持するページ
```

---

## つまずいたら

| 症状 | 原因と対処 |
|---|---|
| `/llm-wiki` が出てこない | `~/.claude/skills/llm-wiki/SKILL.md` の場所を確認し、Claude Code を再起動 |
| 回答にページ名の引用がない | Wiki を読んでいない。`CLAUDE.md` に「作業前に docs/wiki/index.md を読む」と明記する |
| 何を取り込めばいいか分からない | まず `README.md` だけでよい。慣れてから増やす |

---

次: [3. 日々の使い方 →](03-daily-usage.md)
