---
title: .ps1 は BOM 付き UTF-8 で保存する
type: issue
project: llm-wiki
scope: shared
sources:
  - install/install.ps1
  - hooks/llm-wiki-context.ps1
  - https://github.com/soramaru777/llm-wiki/pull/1
  - https://github.com/soramaru777/llm-wiki/pull/2
related: [[llm-wiki-branch-flow]] [[llm-wiki-hook-distribution]]
confidence: high
updated: 2026-08-15
---

日本語を含む `.ps1` を **BOM なし UTF-8** で保存すると、Windows PowerShell 5.1 でパースエラーになる。このリポジトリの `.ps1` は必ず **BOM 付き UTF-8** で保存すること。

## 症状

```
PS C:\...\llm-wiki> powershell -ExecutionPolicy Bypass -File .\install\install.ps1
発生場所 ...\install\install.ps1:122 文字:46
+ Write-Info "  3. 菴ｿ縺・婿縺ｯ $Repo\docs\README.md"
+                                              ~
文字列に終端記号 " がありません。
発生場所 ...\install\install.ps1:25 文字:15
+ if ($Connect) {
ステートメント ブロックまたは型定義に終わりの '}' が存在しません。
```

エラー箇所（122 行目）と実際の原因（ファイル全体のエンコーディング）が一致しないため、そのまま読むと誤診しやすい。2つ目の「`}` が存在しない」は1つ目の巻き添えで、修正すべき箇所ではない。

## 原因

`powershell.exe`（Windows PowerShell 5.1）は、**BOM の無い `.ps1` をシステムの ANSI コードページとして読む**。日本語環境では CP932 になるため、UTF-8 のマルチバイト文字が化ける。

化けたバイト列に CP932 の2バイト文字の先頭バイトが混ざると、それが直後の文字と結合して閉じ引用符 `"` を食い潰す。結果、文字列が閉じられないまま行末に到達し、以降のブロック構造が総崩れになる。

`pwsh`（PowerShell 7）は BOM が無くても UTF-8 と解釈するため、**この問題は 5.1 でのみ再現する**。7 でしか動作確認していないと見落とす。

## 対処

対象ファイルの先頭に BOM（`EF BB BF`）を付けて保存する。内容と改行コードは変更しない。

```powershell
$enc = New-Object System.Text.UTF8Encoding($true)
$bytes = [System.IO.File]::ReadAllBytes($path)
$text  = [System.Text.Encoding]::UTF8.GetString($bytes)
[System.IO.File]::WriteAllText($path, $text, $enc)
```

確認は先頭3バイトを見る。

```
$ head -c 3 install/install.ps1 | xxd -p
efbbbf
```

## 適用範囲

`hooks/llm-wiki-context.ps1` も対象。このファイルは `settings.json` の SessionStart フックに `shell: 'powershell'` で登録されるため、BOM が無いと**セッション開始のたびに同じパースエラーが出る**。install が配布する `.ps1` は例外なく BOM 付きにする。フックの種類と配布方法は [[llm-wiki-hook-distribution]] を参照。

`.md` や `.json` に BOM は不要。付けるのは `.ps1` だけ。

## 検証済みの事実

- Windows PowerShell 5.1 のパーサ（`[System.Management.Automation.Language.Parser]::ParseFile`）で構文エラーなし
- `install.ps1` が完走し、vault・スキル・ルール・フックを配置
- `/hooks` で SessionStart フックが発火し、エラーなし
- コマンドライン引数経由の日本語（`git tag -m "..."` など）は 5.1 でも化けない。**問題はファイル読み込み時のみ**

## 未確認

- 英語環境（CP1252）での挙動。理屈の上では同じ現象が起きるが、実機では確認していない
- `install.ps1` が `Set-Content -Encoding UTF8` で生成する `CLAUDE.md` には BOM が付く（5.1 の場合）。7 では付かない。生成物の BOM 有無が実行環境で変わる点は未整理

  > 2026-08-15 更新: このリポジトリが追跡している `CLAUDE.md` からは BOM を除去した（`.md` に BOM は不要で、他の `.md` と不揃いになるため）。ただし **`install.ps1` の生成処理は直していない**ので、5.1 で接続したプロジェクトの `CLAUDE.md` には引き続き BOM が付く。
