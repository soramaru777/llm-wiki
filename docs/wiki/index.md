---
title: llm-wiki Wiki インデックス
type: hub
project: llm-wiki
scope: shared
sources:
  - CLAUDE.md
  - README.md
related: [[llm-wiki-powershell-encoding]] [[llm-wiki-branch-flow]]
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

## 構成

- `install/` — セットアップスクリプト（`install.ps1` / `install.sh`）
- `skill/`、`rules/`、`hooks/` — Claude Code 側に配置される成果物
- `template/` — vault と接続先プロジェクトに配る雛形
- `githooks/pre-commit` — 秘密情報の混入を止めるフック（配布元。接続先では `.githooks/` に複製される）
- `docs/` — 利用者向けドキュメント（`01`〜`06` と README）
- `docs/raw/` — 生資料。**git 未追跡**、README のみ追跡
- `docs/wiki/` — このディレクトリ

## まだ書かれていないページ

リンク先が無いものは、次に書くべきページの印。

- 動作確認の手順（Windows / macOS / Linux でのインストール検証）
- `install.ps1` と `install.sh` の機能差
