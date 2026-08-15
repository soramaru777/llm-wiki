---
title: llm-wiki Wiki インデックス
type: hub
project: llm-wiki
scope: shared
sources:
  - CLAUDE.md
  - README.md
related: [[llm-wiki-powershell-encoding]] [[llm-wiki-branch-flow]] [[llm-wiki-secret-hygiene]] [[llm-wiki-hook-distribution]] [[llm-wiki-history-rewrite]]
confidence: high
updated: 2026-08-15
---

このリポジトリの Wiki のエントリポイント。**作業を始める前にここを読む。** ページを追加したら必ず1行足すこと。

llm-wiki は Karpathy の LLM Wiki パターンを Claude Code に導入するためのセットアップ一式を配布するリポジトリ。ツールそのものであると同時に、**自分自身をこのパターンで管理している**（`install -Connect .` を自リポジトリに適用した状態）。

## ページ一覧

| ページ | 種別 | 概要 |
|---|---|---|
| [[llm-wiki-powershell-encoding]] | issue | 日本語を含む `.ps1` は BOM 付き UTF-8 必須。Windows PowerShell 5.1 が CP932 として読むため |
| [[llm-wiki-branch-flow]] | howto | feature → develop → main のブランチ運用、保護設定、タグの打ち方 |
| [[llm-wiki-secret-hygiene]] | decision | `docs/raw/` を追跡しない理由と、pre-commit による秘密情報の検査 |
| [[llm-wiki-hook-distribution]] | decision | `hooks/` と `githooks/` の違い、自己接続時にフックを複製しない判断 |
| [[llm-wiki-history-rewrite]] | howto | 保護ブランチ下で履歴を書き換える手順（ruleset の一時無効化と復旧） |

## 構成

- `install/` — セットアップスクリプト（`install.ps1` / `install.sh`）
- `skill/`、`rules/`、`hooks/` — Claude Code 側に配置される成果物
- `template/` — vault と接続先プロジェクトに配る雛形
- `githooks/pre-commit` — 秘密情報の混入を止めるフック。配布元では複製せずここを直接指す。接続先では `.githooks/` に複製される（[[llm-wiki-hook-distribution]]）
- `docs/` — 利用者向けドキュメント（`01`〜`06` と README）
- `docs/raw/` — 生資料。**git 未追跡**、README のみ追跡
- `docs/wiki/` — このディレクトリ

## まだ書かれていないページ

リンク先が無いものは、次に書くべきページの印。

- 動作確認の手順（Windows / macOS / Linux でのインストール検証）
- `install.ps1` と `install.sh` の機能差
- public 化の手順と、公開前に確認すること
- `install.ps1` が生成する `CLAUDE.md` の BOM 問題（[[llm-wiki-powershell-encoding]] の「未確認」に記載。未修正）
