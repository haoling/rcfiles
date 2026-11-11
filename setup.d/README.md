# setup.d

`rcfiles-setup` で選べる機能を置くディレクトリです。
**`<名前>.yml` を1つ置くと、その名前（`.yml` を除いたファイル名）が一覧に出ます。** `rcfiles-setup` のコードを変える必要はありません。

```sh
rcfiles-setup list    # 置いたファイルが出る
```

一覧の並びはファイル名順です。名前に使えるのは英数字と `.` `_` `-` だけです。
この README のように、`.yml` で終わらないファイルは無視されます。

## 書き方

```yaml
description: ~/.vimrc をリンクする   # 一覧でカーソルを合わせたときに出る説明
default: true                         # true なら ln_rcfiles.sh（rcfiles-setup defaults）でも入れる

link:
  - .vimrc
```

### 使えるキー

| キー | 内容 |
|---|---|
| `description` | 説明（1行） |
| `default` | `true` にすると、`ln_rcfiles.sh` や `rcfiles-setup defaults` でインストールされる。省略すると入らない |
| `os` | `darwin` か `linux`。違う OS では「この環境では使えません」と出て、選べない |
| `requires_dir` | ホームからの相対パス。そのディレクトリがないと、使えない扱いになる（例: `.gnupg`） |
| `link` | ホームに作るシンボリックリンクのリスト（下記） |
| `file` `where` `marker` `text` | ホームのファイルに行を足す（下記） |
| `install` `uninstall` | インストール・アンインストールのときに、最後に実行するシェル（下記） |
| `status` | 状態を自分で答えるシェル（下記） |

`link` も `text` もない機能は、`status` を書きます。書かないと、いつも「未インストール」になります。

### link: シンボリックリンクを作る

```yaml
link:
  - .tmux.conf                                # ~/.tmux.conf -> リポジトリの .tmux.conf
  - ".gnupg/pinentry-notify.py: gnupg/pinentry-notify.py"   # 置き場所: リポジトリの中のパス
```

- インストールで、ホームに同じ名前の実体ファイルがあれば `<名前>.rcfiles-bak` に退避してからリンクします
- アンインストールで、rcfiles のリンクだけを消し、退避したファイルがあれば戻します
- 全部リンクできていれば「インストール済み」、一部だけなら「一部だけ」になります

### file / where / marker / text: ファイルに行を足す

`~/.zshrc` や `~/.gitconfig` のように、他のツールも書き込むファイルは、実体のまま残して行だけ足します。

```yaml
file: .zshrc                   # ホームからの相対パス
where: top                     # top: 先頭に足す（省略時） / bottom: 最後に足す
marker: .rcfiles/.zshrc_rcfiles
text: '[ -f ~/.rcfiles/.zshrc_rcfiles ] && source ~/.rcfiles/.zshrc_rcfiles'
```

- `marker` がファイルに含まれていれば、インストール済みとみなします（手で書いた行でも構いません）。省略すると `text` の1行目です
- `text` が複数行のときは、`"...\n..."` か `|` で書きます（下記）
- アンインストールでは、`text` と同じ行が並んでいるところだけを消します。`marker` を含む行が残ったときは、手で消すよう知らせます

### install / uninstall / status: シェルを書く

`|` の後ろに字下げして書きます。`link` や `text` の処理のあとに実行されます。

```yaml
install: |
  msg "メッセージを出す"
  warn "注意を出す"
  zsh "$RCDIR/kbd-off/install.sh"
```

- ホームがカレントディレクトリです。`$RCDIR` がリポジトリの場所です
- `msg`、`warn` が使えます
- `status` は `on`、`off`、`partial` のどれかを表示してください。ほかの出力は `off` になります
- 画面で選んだだけでは実行されません。決定して、確認で `y` を押したときだけ実行されます

## 書ける YAML の範囲

YAML のすべては読めません。`rcfiles-setup.awk` が読めるのは、次の形だけです。

```yaml
# コメント
key: 値                      # 1行の値。' ' や " " で囲んでもよい。" " の中では \n \t \" \\ が使える
key: |                       # 複数行の値（スペースで字下げ。タブは不可）
  1行目
  2行目
key:                         # リスト（各項目は1行の値）
  - 項目
  - 項目
```

アンカー、入れ子、`>` の折りたたみ、`[a, b]` の書き方は使えません。
読めない行や知らないキーは、`rcfiles-setup list` や画面の最初に警告が出ます（その行は無視されます）。
