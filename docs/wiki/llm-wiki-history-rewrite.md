---
title: 保護ブランチ下で履歴を書き換える手順
type: howto
project: llm-wiki
scope: shared
sources:
  - 2026-08-15 の作業セッション（コミット作者メールの一括置換）
  - https://github.com/soramaru777/llm-wiki/rules/20855265
related: [[llm-wiki-branch-flow]] [[llm-wiki-secret-hygiene]]
confidence: high
updated: 2026-08-15
---

`main` / `develop` は ruleset で force push が禁止されているため、履歴を書き換えるには**保護を一時的に外す**必要がある。2026-08-15 に全コミットの作者メールアドレスを GitHub の noreply アドレスへ置換した際の手順。

公開前に一度だけ行う類の作業で、日常的にやるものではない。ブランチ運用そのものは [[llm-wiki-branch-flow]] を参照。

## 手順

**1. 退避を取る**

```
git bundle create backup-before-rewrite.bundle --all
```

全 ref を含むため、失敗しても完全に戻せる。破壊的な操作の前に必ず取る。

**2. 書き換え前の tree ハッシュを記録する**

```
git rev-parse <branch>^{tree}
```

各ブランチについて記録しておく。**書き換え後に一致すれば、ファイル内容が1バイトも変わっていない証拠になる。** コミット SHA は必ず変わるので、内容が保たれたかの検証にはこちらを使う。

**3. `git filter-repo` で書き換える**

メールアドレスの置換は mailmap が簡潔。`<新> <旧>` の1行で、表示名を保ったままメールだけ置換できる。author・committer・タグの tagger すべてに適用される。

```
git filter-repo --mailmap mailmap.txt --force
```

**`filter-repo` は事故防止のため `origin` リモートを削除する。** 後で `git remote add origin <URL>` で戻す。

**4. 検証する**

```
git log --all --format='%ae %ce' | sort -u    # 旧アドレスが 0 件か
git rev-parse <branch>^{tree}                 # 手順2 と一致するか
git cat-file -t <tag>                         # 注釈付きタグが tag のままか
```

**5. ruleset を一時的に無効化する**

```
gh api -X PUT repos/<owner>/<repo>/rulesets/<id> -f enforcement=disabled
```

**6. force push する**

```
git push --force origin main develop <他のブランチ...>
git push --force origin <tag>
```

タグは指す先のコミットが変わるため貼り直しが必要。注釈付きタグは `--force` で更新できる。

**7. ruleset を戻す（必須）**

```
gh api -X PUT repos/<owner>/<repo>/rulesets/<id> -f enforcement=active
```

**この手順を忘れると保護が外れたままになる。** 戻したあと `gh api repos/<owner>/<repo>/rules/branches/main` でルールが適用されているか確認する。

**8. 後始末**

- `git branch --set-upstream-to=origin/<b> <b>` で追跡を復旧（`filter-repo` がリモートを消したため外れている）
- 今後のコミットに旧アドレスが混ざらないよう `git config --local user.email` を設定する。global を変えると他のリポジトリにも影響するため、まずローカルに入れる

## 避けられない副作用

- **マージ済み PR のページからコミットへのリンクが辿れなくなる。** 参照先の SHA が履歴から消えるため。マージ済みという記録自体は残る
- 他のマシンのクローンは pull では追従できない。**クローンし直しが必要**
- タグを打ち直すので、リリースを参照していた外部リンクは指す先が変わる

## 判断の目安

コミットメッセージやメールアドレスの修正は、**マージ済み・タグ付きの履歴を書き換えるほどの価値があるか**を先に考える。同じ 2026-08-15 に、セッション URL をコミットメッセージから除去する作業も行ったが、こちらはマージ済みの1件（`v0.1.0` に含まれる）を**あえて書き換えずに残した**。秘密情報ではなく、保護解除とタグ打ち直しの代償に見合わないと判断したため。

一方でメールアドレスは、公開後に取り消せない個人情報であり、書き換えの価値があると判断した。**実際に漏れた鍵の場合は書き換えでは不十分で、再発行が必要**（[[llm-wiki-secret-hygiene]]）。
