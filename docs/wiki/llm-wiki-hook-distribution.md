---
title: 2種類のフックと配布方法
type: decision
project: llm-wiki
scope: shared
sources:
  - https://github.com/soramaru777/llm-wiki/pull/5
  - install/install.ps1
  - install/install.sh
  - README.md
related: [[llm-wiki-secret-hygiene]] [[llm-wiki-powershell-encoding]] [[llm-wiki-branch-flow]]
confidence: high
updated: 2026-08-15
---

このリポジトリには**名前の似た別物のフックが2種類**ある。`hooks/` と `githooks/` を混同しないこと。

| ディレクトリ | 何のフックか | いつ動くか | 配置先 |
|---|---|---|---|
| `hooks/` | **Claude Code** のライフサイクルフック | セッション開始時に `docs/wiki/index.md` を注入 | `~/.claude/hooks/` |
| `githooks/` | **git** の pre-commit フック | コミット前に秘密情報を検査 | 接続先プロジェクト（後述） |

`hooks/` は OS ごとに実体が分かれる（`.sh` / `.ps1`）。`githooks/pre-commit` は bash スクリプト1本で全 OS 共通。Git for Windows に bash が同梱されるため Windows でも動く。

## git フックの配布先

`install --connect` は接続先によって挙動を変える。v0.2.0 で追加した分岐。

| 接続先 | フックの実体 | `core.hooksPath` |
|---|---|---|
| **配布元リポジトリ自身** | `githooks/`（複製しない） | `githooks` |
| それ以外のプロジェクト | `.githooks/`（複製する） | `.githooks` |

配布元を自己接続したときに複製すると、**同じフックが `githooks/` と `.githooks/` の2箇所に置かれ、片方だけ古くなる**。llm-wiki は自分自身をこのパターンで管理しているため、この状況が実際に発生する。

判定は install スクリプトの位置から求めた配布元パスと接続先パスの比較で行う。

- PowerShell — `[System.IO.Path]::GetFullPath()` で正規化し、末尾の `\` を落として比較
- bash — `-ef` で同一の実体かを判定（シンボリックリンク経由でも一致する）

`次の手順` の案内に出る `git add` の対象と、`core.hooksPath` が別の値で設定済みだった場合の警告文も、この判定に追従する。

## 既存設定を壊さない

`core.hooksPath` が既に別の値で設定されている場合、install は**自動で切り替えない**。フックの配置だけ行い、警告と手動で有効化するコマンドを表示する。他のフック管理ツールを使っているリポジトリを壊さないため。

## 検証済み

Windows PowerShell 5.1 で、配布元のコピーと別プロジェクトを用意して両方に `--connect` を実行した。

- 自己接続 → `.githooks/` は作られず `core.hooksPath = githooks`
- 別接続 → `.githooks/pre-commit` を配置し `core.hooksPath = .githooks`
- 両方で pre-commit が発火し、秘密情報を検出してコミットを中止（`exit=1`、コミットは作られない）
- `core.hooksPath` は相対パスだが、git は worktree のトップレベル基準で解決するため、作業ディレクトリを変えても結果は同じ

## 関連する注意

`hooks/llm-wiki-context.ps1` は BOM 付き UTF-8 で保存する必要がある。SessionStart フックとして `shell: 'powershell'` で実行されるため、BOM が無いとセッション開始のたびにパースエラーになる。詳細は [[llm-wiki-powershell-encoding]]。

pre-commit が何を検査するかは [[llm-wiki-secret-hygiene]] を参照。
