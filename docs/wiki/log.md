# Operation Log

追記のみ。先頭に `YYYY-MM-DD` を付けて、新しいものを下に足す。

書式の例:

```
2026-01-15 ingest — <ソース> を取り込み。<ページA> を更新、<ページB> を新規作成。
2026-01-18 lint   — 矛盾2件を修正。孤立ページ <名前> を削除。
2026-01-20 doc    — <ファイル> を追加。index.md に登録。
```

---

2026-08-15 doc — docs/wiki を開設。index.md、llm-wiki-powershell-encoding.md、llm-wiki-branch-flow.md を新規作成。CLAUDE.md を追跡対象に追加し、docs/raw/README.md と .gitignore の docs/raw 除外を PR #3 の方針に合わせた。

2026-08-15 ingest — v0.2.0 リリースまでの作業セッションを取り込み。llm-wiki-secret-hygiene.md（PR #3 の方針と pre-commit の中身）、llm-wiki-hook-distribution.md（PR #5 の自己接続判定、2種類のフックの違い）、llm-wiki-history-rewrite.md（保護ブランチ下での履歴書き換え手順）を新規作成。llm-wiki-branch-flow.md に v0.2.0 の経緯とタグ貼り直しの注記を追加、llm-wiki-powershell-encoding.md の「未確認」に CLAUDE.md の BOM 除去（install 側は未修正）を追記。index.md にページ3件を登録し、未着手ページを更新。昇格候補として .ps1 の BOM 問題と履歴書き換え手順を認識しているが、いずれもこのリポジトリ1件でしか出ていないため ~/wiki/knowledge/ には移していない。
