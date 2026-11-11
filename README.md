# rcfiles

zsh・git・tmux・screen・vim などの設定ファイル（dotfiles）です。

## セットアップ

```sh
git clone https://github.com/haoling/rcfiles.git ~/.rcfiles
sh ~/.rcfiles/ln_rcfiles.sh
```

`ln_rcfiles.sh` は標準の機能（zsh・git・vim・tmux・screen・launcher・pinentry-notify）をまとめてインストールします。標準かどうかは、各機能の `setup.d/*.yml` の `default: true` で決まります。何度実行しても大丈夫です。

## 機能を選んでインストール・アンインストールする

`rcfiles-setup` を実行すると、機能の一覧が出ます。今の状態を見ながら、入れるもの・外すものを選べます。
（zsh の設定を読み込んだあとは `rcfiles-setup` だけで動きます）

```sh
sh ~/.rcfiles/rcfiles-setup
```

```
 rcfiles の機能を選んでください

   1 [x] zsh               インストール済み
   2 [x] git               インストール済み
 - 3 [ ] vim               インストール済み
   4 [x] tmux              インストール済み
   ...
 + 7 [x] awsp              未インストール
   9     kbd-off           この環境では使えません
```

- **↑↓**（または `j` `k`）で移動、**Space** か数字キーで切り替え、**Enter** で決定します
- `+` の付いた機能をインストールし、`-` の付いた機能をアンインストールします。決定のあと、変更の一覧を出して確認します
- `a` で全部選ぶ、`n` で全部外す、`r` で今の状態に戻す、`q` か Escape で何もせずに終わります

画面を使わずに、コマンドで指定することもできます。

```sh
rcfiles-setup list                  # 各機能の状態を表示
rcfiles-setup install awsp          # 指定した機能をインストール
rcfiles-setup uninstall screen vim  # 指定した機能をアンインストール
```

機能は `setup.d/<名前>.yml` に1ファイルずつ書いてあり、ファイル名がそのまま一覧に出ます。

| 機能 | 内容 |
|---|---|
| `zsh` | `~/.zshrc` の先頭で `.zshrc_rcfiles` を読み込む |
| `git` | `~/.gitconfig` の先頭で `.gitconfig_rcfiles` を `[include]` する |
| `vim` | `~/.vimrc` をリンクする |
| `tmux` | `~/.tmux.conf`、`.mytmux`、`.mytmux2`、`.mytmux3`、`.tmuxssh` をリンクする |
| `screen` | `~/.screenrc`、`.myscreen`、`.myscreen2` をリンクする |
| `launcher` | `~/.mylauncher` をリンクする |
| `awsp` | `shell_functions/aws_profile_switcher.zsh` を読み込む行を `~/.zshrc` の最後に追加する（`aws` コマンドがあるときだけ。標準では入れない） |
| `prompt-2line` | 2行のプロンプト（`.zshrc.bash_prompt` と `.zshrc.2line_prompt_1`）を読み込む行を `~/.zshrc` の最後に追加する（標準では入れない） |
| `pinentry-notify` | `~/.gnupg/pinentry-notify.py` をリンクする（`~/.gnupg` があるときだけ） |
| `kbd-off` | `kbd-off/install.sh` で常駐させる。アンインストールで常駐を止める（macOS のみ。標準では入れない） |

### 機能を足す

`setup.d/` に `.yml` を1つ置くだけで、一覧に出ます。例えば `setup.d/ripgrep.yml` を作ります。

```yaml
description: ~/.ripgreprc をリンクする
default: true
link:
  - .ripgreprc
```

リンクの作り方のほか、`~/.zshrc` などに行を足す書き方や、実行するシェルを書く方法は [setup.d/README.md](setup.d/README.md) にあります。

アンインストールで消すのは、rcfiles が作ったリンクと、rcfiles が追加した行だけです。

- インストールのとき、ホームに同じ名前の実体ファイルがあれば `<ファイル名>.rcfiles-bak` に退避します。アンインストールすると、退避したファイルを元に戻します
- 手で書いた読み込みの行や、rcfiles のものではないファイルは消さずに、残っていることを知らせます
- pinentry-notify をアンインストールしても、`gpg-agent.conf` は書き換えません。表示される案内に沿って戻してください

## 仕組み

ファイルの種類によって、ホームディレクトリへの置き方を変えています。

### シンボリックリンクで置くもの

`.vimrc`、`.tmux.conf`、`.screenrc` など、他のツールが書き換えないファイルです。
`ln_rcfiles.sh` が `~/.vimrc -> .rcfiles/.vimrc` のようにリンクを作ります。
ホームに同じ名前のファイルがあると、`<ファイル名>.rcfiles-bak` に退避してからリンクに置き換えます。

### 実体ファイルから読み込むもの

`~/.zshrc` と `~/.gitconfig` は、インストーラーや `git config --global` などが追記します。
そのため、この2つはシンボリックリンクにせず、各マシンの実体ファイルにしています。
共通の設定はリポジトリ側の `*_rcfiles` に置き、実体ファイルの先頭で読み込みます。

| ホームのファイル | 先頭に入る行 | 読み込む共通設定 |
|---|---|---|
| `~/.zshrc` | `[ -f ~/.rcfiles/.zshrc_rcfiles ] && source ~/.rcfiles/.zshrc_rcfiles` | `.zshrc_rcfiles` |
| `~/.gitconfig` | `[include]`<br>`path = ~/.rcfiles/.gitconfig_rcfiles` | `.gitconfig_rcfiles` |

`ln_rcfiles.sh` は、この行がまだなければ先頭に追加します。それより後ろにある既存の内容は残します。
ツールが書き込むのはホームの実体ファイルだけなので、リポジトリにマシン固有の設定が入りません。

マシン固有の設定（PATH、認証ヘルパー、各種ツールの補完など）は、ホームの `~/.zshrc` と `~/.gitconfig` に書いてください。
互換性のため、`~/.zshrc.local` があればそれも読み込みます。

### コマンドの補完

`kubectl` と `docker` の補完は、各コマンドが出力するものを `~/.cache/zsh/completion` に生成して使います。

- 生成は最初のプロンプト表示時に1回だけ行います（`~/.zshrc` の後半で PATH が追加されるコマンドにも対応するため）
- 補完ファイルがないとき、またはコマンドの方が新しいときだけ作り直します
- コマンドが入っていないマシンでは何もしません

Homebrew で入れたコマンドの補完は Homebrew が用意するので、ここでは扱いません。

## GPG 鍵の使用確認ダイアログ（macOS）

`gnupg/pinentry-notify.py` は、gpg-agent と [pinentry-touchid](https://github.com/jorgelbg/pinentry-touchid) の間に入る中継スクリプトです。
GPG 鍵（gpg-agent 経由の SSH 鍵を含む）が使われるとき、Touch ID の前に確認ダイアログを出し、どのプロセスが鍵を要求したかを表示します。

```
要求元: gpg (PID 12345) ← git ← zsh ← login ← iTerm2

Touch ID 認証に進みますか？        [キャンセル] [OK]
```

- **Enter（OK）** で Touch ID 認証に進み、**Escape（キャンセル）** で中止します
- 60 秒操作がないとき、ダイアログを出せなかったときも中止します
- gpg-agent と pinentry の通信はそのまま中継します。パスフレーズはどこにも記録しません

### 必要なもの

- macOS（`/usr/bin/python3` と `/usr/bin/osascript` を使います）
- Homebrew で入れた pinentry-touchid（`/opt/homebrew/opt/pinentry-touchid/bin/pinentry-touchid`。場所が違うときはスクリプト冒頭の `REAL_PINENTRY` を書き換えてください）

### インストール

1. pinentry-touchid を入れて、単体で Touch ID 認証できるようにしておきます

   ```sh
   brew install pinentry-touchid
   ```

2. `ln_rcfiles.sh` を実行すると、`~/.gnupg/pinentry-notify.py` にシンボリックリンクができます（`~/.gnupg` があるときだけ）

   ```sh
   sh ~/.rcfiles/ln_rcfiles.sh
   ```

3. `~/.gnupg/gpg-agent.conf` の `pinentry-program` をこのスクリプトに向けます。パスは絶対パスで書いてください

   ```
   pinentry-program /Users/<ユーザー名>/.gnupg/pinentry-notify.py
   ```

4. gpg-agent を再起動して、署名を試します

   ```sh
   gpgconf --kill gpg-agent
   echo test | gpg --clearsign > /dev/null
   ```

   確認ダイアログが出て、OK のあとに Touch ID 認証ができれば完了です。

### webhook で結果を送る（任意）

`~/.gnupg/pinentry-notify-webhook` に URL を 1 行書いておくと、ダイアログの結果と要求元を JSON で POST します。
URL は秘密情報として扱い、このリポジトリには入れないでください。

```sh
echo 'https://hooks.slack.com/services/...' > ~/.gnupg/pinentry-notify-webhook
chmod 600 ~/.gnupg/pinentry-notify-webhook
```

```json
{
  "text": "🔐 GPG鍵の使用要求: ok\n要求元: gpg (PID 12345) ← git ← zsh\nホスト: my-mac.local",
  "status": "ok",
  "requester": {
    "summary": "gpg (PID 12345) ← git ← zsh",
    "chain": [
      {"pid": 12345, "name": "gpg", "path": "/opt/homebrew/bin/gpg", "argv": ["gpg", "--status-fd=2", "-bsau", "..."]},
      {"pid": 12340, "name": "git", "path": "/opt/homebrew/bin/git", "argv": ["git", "commit", "-m", "..."]},
      {"pid": 12000, "name": "zsh", "path": "-zsh", "argv": ["-zsh"]}
    ]
  },
  "host": "my-mac.local"
}
```

- `status` は `ok`（OK）、`cancel`（キャンセル）、`timeout`（60 秒操作なし）、`error`（ダイアログを出せなかった）のいずれかです
- `text` があるので、Slack の Incoming Webhook にそのまま送れます
- `text` と確認ダイアログには `requester.summary`（プロセス名と PID だけ）を出します。実行ファイルのパスと引数は `requester.chain` にだけ入れます
- `requester.chain` は要求元から親方向に最大 6 個までのプロセスで、`path` は実行ファイルのパス、`argv` は引数の配列です。引数 1 つは 200 文字までで切り詰め、root など他ユーザーのプロセスで取得できないときは `null` になります。環境変数は送りません
- `git commit -m` のメッセージなど、コマンドラインの引数はそのまま送られます。コマンドラインにトークンなどを書く使い方をしている場合は、送り先に注意してください
- 送信は別スレッドで行い、失敗しても無視します（Touch ID 認証は待たせません）

### うまく動かないとき

Touch ID を使わずに、要求元の取得と中継だけを確かめられます。

```sh
printf 'OPTION owner=%d/%d %s\nGETINFO version\nBYE\n' $$ $(id -u) $(hostname) \
  | PINENTRY_NOTIFY_DEBUG=1 ~/.gnupg/pinentry-notify.py
```

`[pinentry-notify] zsh (PID ...) ← ...` と `OK` で始まる行が出れば正常です。

### 元に戻す

`gpg-agent.conf` の `pinentry-program` を pinentry-touchid に戻して、`gpgconf --kill gpg-agent` を実行します。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| `.zshrc_rcfiles` | zsh の共通設定（履歴、キーバインド、補完、エイリアスなど） |
| `.zshrc.bash_prompt`<br>`.zshrc.bash_prompt_traditional`<br>`.zshrc.2line_prompt_1` | プロンプトの見た目の切り替え用。`~/.zshrc` から必要なものを読み込む |
| `.gitconfig_rcfiles` | git の共通設定（エイリアス、GPG 署名など） |
| `.tmux.conf` | tmux の設定（prefix は `Ctrl-Z`） |
| `.tmux29.conf` | tmux 2.9 以降向けの設定 |
| `.screenrc`, `.screenrc.local` | GNU screen の設定（エスケープキーは `Ctrl-Z`） |
| `.vimrc` | vim の設定 |
| `.mytmux`, `.mytmux2`, `.mytmux3` | tmux のセッションを選んで接続・作成するスクリプト |
| `.myscreen`, `.myscreen2` | screen のセッションを選んで接続・作成するスクリプト |
| `.tmuxssh` | ssh 接続ごとに tmux セッションを作るスクリプト |
| `.mylauncher` | `~/.mylaunchers` に置いたコマンドを選んで実行するランチャー |
| `.myfunc` | 上のスクリプトが使う bash の関数 |
| `shell_functions/aws_profile_switcher.zsh` | `AWS_PROFILE` を選んで切り替える関数（`awsp` など）。fzf があれば fzf で選べる。`awsp new` でプロファイルの新規作成、`awsp help` で使い方を表示。`~/.zshrc` から `source` して使う |
| `shell_functions/kube_context_switcher.zsh` | kubectl の context を選んで切り替える関数（`kubep` など）。fzf があれば fzf で選べる。`kubep help` で使い方を表示。`~/.zshrc` から `source` して使う |
| `shell_functions/fzf-install-guide` | fzf を現在のユーザーに入れる手順を、環境に合わせて表示するスクリプト。fzf がないときは `awsp` や `kubep` からも呼ばれる |
| `shell_functions/middle`, `middle.php` | ファイルの指定行の前後を表示する `middle` コマンド |
| `gnupg/pinentry-notify.py` | GPG 鍵の使用前に要求元を表示して確認する pinentry の中継スクリプト（macOS） |
| `rcfiles-setup` | 機能を選んでインストール・アンインストールするスクリプト |
| `rcfiles-setup.awk` | `setup.d/*.yml` を読むための awk スクリプト（`rcfiles-setup` が使う） |
| `setup.d/*.yml` | `rcfiles-setup` で選べる機能の定義。1ファイルが1機能 |
| `ln_rcfiles.sh` | 標準（`default: true`）の機能をまとめてインストールするスクリプト（`rcfiles-setup defaults` を実行） |
