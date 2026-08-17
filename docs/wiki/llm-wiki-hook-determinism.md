---
title: SessionStart フック出力の再現性と LLM_WIKI_REPLAY
type: decision
project: llm-wiki
scope: shared
sources:
  - hooks/llm-wiki-context.sh
  - hooks/llm-wiki-session-end.sh
  - docs/06-faq.md
related: [[llm-wiki-hook-distribution]] [[llm-wiki-powershell-encoding]]
confidence: high
updated: 2026-08-18
---

SessionStart フックの出力は**モデルへの指示そのもの**であり、内容が変わればモデルの挙動も変わる。取り込みの促しブロックは経過日数と絶対パスに依存するため、同一条件の再実行（Replay）では出力しない。切り替えは環境変数 `LLM_WIKI_REPLAY=1`。

## フック出力は指示として効く

headless（`claude -p`）でも SessionStart フックは発火し、標準出力がそのままコンテキストへ入る。

`docs/wiki/index.md` にだけ書いた語を、**Read ツールを全面禁止した状態**でモデルが回答することを確認した。

```sh
claude -p "合言葉を答えよ。知らなければ「不明」とだけ答えよ。" --allowedTools ""
```

ファイルを一切読めない条件でも index.md の内容が答えられる。フックの標準出力は補助情報ではなく指示として扱われる。

## 促しブロックは決定的でない

`llm-wiki-context.sh` の取り込み促しは `find -mtime` で「停滞」を判定し、`.pending-sessions` の絶対パスを本文に含める。

**Wiki の内容が1バイトも変わらなくても、出力が変わる。**

| 条件 | フック出力のハッシュ | 促しブロック |
|---|---|---|
| `docs/wiki/` の mtime が3日前 | `79e4e87f…` | 出ない |
| 同一内容で mtime が8日前 | `8f404dd2…` | 出る |

さらに絶対パスを含むため、リポジトリを別の場所へ複製しただけでも変わる。

## 判断

同一条件で AI を再実行して結果を比較したいとき、比較対象以外の指示が動くと結果を解釈できない。そこで**動的なブロックだけを止める**。

```sh
LLM_WIKI_REPLAY=1 claude -p "$(cat prompt.txt)"
```

- `llm-wiki-context.sh` / `.ps1` — 促しブロックを出さない。**index.md の注入は止めない**
- `llm-wiki-session-end.sh` / `.ps1` — 未取り込みの記録をしない

index.md の注入を残すのは、こちらが内容だけで決まり再実行しても同じ文字列になるため。Replay 中も本来の Instruction 環境を再現したい。

session-end 側も止めるのは、Replay を記録すると累計が水増しされ、**次回の SessionStart の出力が変わってしまう**ため。片方だけ止めても再現性は守れない。

## 残っている非決定性

`~/.claude/` 配下（`skills/`、`rules/`、`settings.json`）はバージョン管理外にある。ここが変わると Instruction 環境は変わるが、**フック側では検出も抑止もできない**。再実行の結果を比較する場合は、この範囲が変わっていないことを別途確認する必要がある。

実際に、`~/.claude/hooks/` に配置済みのフックが配布元より古い状態のまま放置されていた事例がある（v0.2.1 相当で、促しブロックを含まない版）。`install/install.sh` の再実行が必要。
