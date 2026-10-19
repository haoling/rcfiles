# rcfiles

zsh・git・tmux・screen・vim などの設定ファイル（dotfiles）です。

## セットアップ

```sh
git clone https://github.com/haoling/rcfiles.git ~/.rcfiles
sh ~/.rcfiles/ln_rcfiles.sh
```

`ln_rcfiles.sh` は何度実行しても大丈夫です。

## 仕組み

ファイルの種類によって、ホームディレクトリへの置き方を変えています。

### シンボリックリンクで置くもの

`.vimrc`、`.tmux.conf`、`.screenrc` など、他のツールが書き換えないファイルです。
`ln_rcfiles.sh` が `~/.vimrc -> .rcfiles/.vimrc` のようにリンクを作ります。
ホームに同じ名前のファイルがあると、削除してリンクに置き換えるので注意してください。

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
| `shell_functions/aws_profile_switcher.zsh` | `AWS_PROFILE` を選んで切り替える関数（`awsp` など）。`~/.zshrc` から `source` して使う |
| `shell_functions/middle`, `middle.php` | ファイルの指定行の前後を表示する `middle` コマンド |
| `ln_rcfiles.sh` | セットアップ用のスクリプト |
