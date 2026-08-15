# llm-wiki

Karpathy の LLM Wiki パターンを Claude Code に導入するためのセットアップ一式。vault の雛形、スキル・ルール・フック、Windows / macOS / Linux 向けのインストールスクリプトを配布する。

## LLM Wiki

このプロジェクトは LLM Wiki パターンで知識を管理している。**スキーマの定義は `~/wiki/SCHEMA.md`**（このファイルには複製しない）。`docs/wiki/` や `docs/raw/` に触れると `~/.claude/rules/llm-wiki.md` 経由で自動的に読み込まれる。

- `docs/raw/` — 不変のソース置き場。LLM は読むだけ。**git 未追跡**（README のみ追跡）
- `docs/wiki/` — LLM が保守するページ。エントリポイントは `docs/wiki/index.md`
- `docs/wiki/log.md` — 操作ログ（追記のみ）
- ハブページ: `~/wiki/projects/llm-wiki.md`、横断知識: `~/wiki/knowledge/`

**作業を始める前に `docs/wiki/index.md` を読むこと。** 実装や課題の背景はそこに集約されている。

設計判断・既知の課題・運用手順が変わったら、コードと一緒に `docs/wiki/` を更新する。他プロジェクトでも通用する知見は `~/wiki/knowledge/` に昇格させる。

## このリポジトリ固有の注意

- `docs/raw/` は git 未追跡。**Issue・PR・コミットメッセージで言及しない**
- API キー・トークンは `.env` にのみ置き、Wiki やコミットに書かない
- コミット前に pre-commit フックが秘密情報を検査する。クローン直後に1回だけ実行すること:

  ```
  git config core.hooksPath githooks
  ```

  **このリポジトリだけ `.githooks` ではなく `githooks` を指す。** ここはフックの配布元であり `githooks/pre-commit` が実体だからである。接続先のプロジェクトでは `install` がこれを `.githooks/` に複製し、そちらを指すよう設定する。

- **日本語を含む `.ps1` は BOM 付き UTF-8 で保存する。** BOM が無いと Windows PowerShell 5.1 がシステムの ANSI コードページ（日本語環境では CP932）として読み、文字化けしてパースエラーになる。詳細は `docs/wiki/llm-wiki-powershell-encoding.md`
- `main` と `develop` は ruleset で保護されている。直接 push・force push・ブランチ削除はできない。変更は feature ブランチ → `develop` → `main` の PR 経由で入れる。詳細は `docs/wiki/llm-wiki-branch-flow.md`

<!-- 以下、プロジェクト固有の注意を追記する -->
