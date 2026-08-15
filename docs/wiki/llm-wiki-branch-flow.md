---
title: ブランチ運用とリリース手順
type: howto
project: llm-wiki
scope: shared
sources:
  - https://github.com/soramaru777/llm-wiki/rules/20855265
  - https://github.com/soramaru777/llm-wiki/pull/1
  - https://github.com/soramaru777/llm-wiki/pull/2
related: [[llm-wiki-powershell-encoding]] [[llm-wiki-history-rewrite]] [[llm-wiki-secret-hygiene]]
confidence: high
updated: 2026-08-15
---

feature ブランチ → `develop` → `main` の2段階で変更を入れる。`main` と `develop` へは**直接 push できない**。

## 流れ

```
feature ブランチ ──PR──> develop ──PR──> main ──> タグ (vX.Y.Z)
```

1. `develop` から feature ブランチを切る（`fix/...`、`docs/...`、`chore/...`）
2. feature → `develop` の PR を作成、マージ
3. リリース時に `develop` → `main` の PR を作成、マージ
4. `main` のマージコミットに注釈付きタグを打つ

`main` は「利用者がチェックアウトしてよい状態」を表す。このリポジトリは clone して `install` を実行する配布形態なので、タグは実際に意味を持つ。

## 保護設定

ruleset `protect-main-develop`（ID 20855265）が `refs/heads/main` と `refs/heads/develop` に適用されている。

| ルール | 効果 |
|---|---|
| `pull_request` | 変更は PR 経由必須（＝直接 push 不可）。必要承認数は **0** |
| `deletion` | ブランチ削除の禁止 |
| `non_fast_forward` | force push の禁止 |

bypass 対象者は設定していない（`current_user_can_bypass: "never"`）。**オーナーも例外にならない。**

必要承認数を 0 にしているのは、1人リポジトリで1件以上を必須にすると自分の PR を自分で承認できずマージ不能になるため。「PR を作らないと入らない」制約は 0 でも効く。レビュアーが増えたら引き上げる。

タグの push は branch ruleset の対象外なので、保護下でもそのまま実行できる。ただしタグを**貼り直す**場合は、指す先のコミットが履歴書き換えで変わっているケースが多い。その手順は [[llm-wiki-history-rewrite]] にまとめてある。

## タグ

`main` へのマージ後、`main` 上のマージコミットに対して打つ。`develop` や feature ブランチには打たない（squash / rebase でコミットが差し替わると、どのブランチからも辿れないコミットを指すことになるため）。

```
git switch main
git pull
git tag -a v0.1.0 -m "初回リリース: LLM Wiki セットアップ一式"
git push origin v0.1.0
```

軽量タグではなく注釈付きタグ（`-a`）を使う。作成者・日時・メッセージが残り、`git describe` でも正しく扱われる。

バージョンは `install` スクリプトや `SKILL.md` の破壊的変更で MINOR、ドキュメント修正やバグ修正で PATCH。

## Windows で作業する場合の注意

`powershell.exe`（Windows PowerShell 5.1）は `&&` を**ステートメント区切りとして解釈できない**。

```
git switch main && git pull
→ トークン '&&' は、このバージョンでは有効なステートメント区切りではありません。
```

1行ずつ実行するか、`pwsh`（PowerShell 7）を使う。`;` で繋ぐ方法もあるが、前のコマンドが失敗しても次が動くため、`git pull` の失敗に気づかず古いコミットにタグを打つ事故が起きる。分けて実行するのが安全。

## 経緯

- v0.1.0（2026-08-14）— 初回リリース。[[llm-wiki-powershell-encoding]] の修正を含む。修正前の `main` は Windows で `install.ps1` が動かない状態だったため、修正を `main` に入れてから最初のタグを打った
- v0.2.0（2026-08-15）— [[llm-wiki-secret-hygiene]]（生資料の非追跡と pre-commit 検査）、[[llm-wiki-hook-distribution]]（自己接続時はフックを複製しない）、`docs/wiki` の開設。`install` の挙動が追加・変更されたため PATCH ではなく MINOR

> 2026-08-15 更新: v0.1.0 のタグは同日の履歴書き換え（[[llm-wiki-history-rewrite]]）により指す先のコミットが変わっている。内容は同一。
