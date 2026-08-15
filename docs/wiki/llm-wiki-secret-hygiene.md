---
title: 生資料を追跡しない方針と秘密情報の検査
type: decision
project: llm-wiki
scope: shared
sources:
  - https://github.com/soramaru777/llm-wiki/pull/3
  - githooks/pre-commit
  - template/raw-README.md
  - docs/06-faq.md
related: [[llm-wiki-hook-distribution]] [[llm-wiki-branch-flow]]
confidence: high
updated: 2026-08-15
---

`docs/raw/`（生資料）は **git 追跡しない**。`README.md` だけを追跡する。加えて pre-commit フックが秘密情報の混入をコミット前に止める。v0.2.0 で導入。

## なぜ生資料を追跡しないか

取り込み前のセッション記録・議事録・調査メモには **API キーや個人情報が混ざりやすい**。そして一度コミットすると `git rm` しても**履歴からは消えない**。リポジトリを公開する可能性が少しでもあるなら、「後から消せる」前提で設計しない。

要約・構造化された知識は `docs/wiki/` に入り、そちらは追跡する。**LLM が要約する過程が実質的なフィルタになる**ため、共有すべき内容は wiki 側に残る。

この方針から派生する運用ルール:

- **Issue・PR・コミットメッセージで `docs/raw/` のファイル名に言及しない。** 追跡していないファイルを参照しても他人には辿れないため
- チーム内で生資料も共有したい場合は、方針を変えず**別の private リポジトリに分ける**。公開範囲の異なるものを1つのリポジトリに混ぜない
- 出典としての名前は wiki ページの frontmatter `sources:` に残す。実体がローカルにしか無くても provenance の記録として意味がある

`install --connect` が接続先の `.gitignore` に以下を追記する。

```
docs/raw/*
!docs/raw/README.md
```

## pre-commit による検査

`githooks/pre-commit` が3段階で検査する。フックの配布方法は [[llm-wiki-hook-distribution]] を参照。

1. **`.env` 系ファイルそのものの混入** — ステージされていれば中止（`.env.example` は許可）
2. **gitleaks があれば委譲** — `gitleaks protect --staged --redact` の結果に従う
3. **無ければ内蔵パターン検査** — 追加行（`+` で始まる行）だけを対象にする。既存行の再検出を避けるため

内蔵パターンが見るもの:

| 対象 | パターンの例 |
|---|---|
| Anthropic | `sk-ant-` + 20文字以上 |
| OpenAI 系 | `sk-` + 32文字以上 |
| GitHub | `ghp_` / `gho_` / `ghu_` / `ghs_` / `ghr_` / `github_pat_` + 20文字以上 |
| AWS | `AKIA` + 英数16文字 |
| Fly.io | `FlyV1 ` + 20文字以上 |
| 秘密鍵 | `-----BEGIN ... PRIVATE KEY-----` |
| 汎用 | `API_KEY` / `SECRET` / `TOKEN` / `PASSWORD` への16文字以上の代入 |

**値が実際に入っているものだけを検出する。** `<KEY>`、`${VAR}`、`***`、`xxx`、`example`、`placeholder`、`redacted`、`secrets.` を含む行は除外され、`KEY=` の空代入も通る。誤検知で止まった場合は `git commit --no-verify` で回避できるが、その前に本当に値が入っていないかを確認する。

フックは bash スクリプトだが、Git for Windows に bash が同梱されるため Windows でも動作する。

## 有効化

クローン直後に1回だけ必要。設定しないとフックは動かない。

```
git config core.hooksPath githooks
```

このリポジトリだけ `githooks`（ドットなし）を指す。接続先プロジェクトでは `.githooks` になる。理由は [[llm-wiki-hook-distribution]]。

## 検証済み

AWS キー形式（`AKIA` + 16文字）を含むファイルをステージしてコミットを試行し、`exit=1` で中止されコミットが作成されないことを確認した。配布元リポジトリ・接続先プロジェクトの両方で確認している。

## 限界

- **フックはローカルでしか動かない。** クローンした人が `core.hooksPath` を設定しなければ素通りする。サーバ側の強制力は無い
- `--no-verify` で誰でも回避できる
- 内蔵パターンは既知の形式しか見ない。独自形式のトークンは検出できない
- 実際に鍵が漏れた場合、**フックの有無にかかわらず再発行が必要**。履歴書き換え（[[llm-wiki-history-rewrite]]）で消したとしても、漏れた事実は取り消せないため
