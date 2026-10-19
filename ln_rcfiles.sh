#!/bin/sh

cd `dirname $0`
cd ..


for f in .myscreen .myscreen2 .mylauncher .mytmux .mytmux2 .mytmux3 .screenrc .tmux.conf .vimrc .tmuxssh
do
	if [ -e $f ]; then rm $f; fi
	if [ -L $f ]; then rm $f; fi
	ln -s .rcfiles/$f $f
done

# インストーラー等が追記するファイルは実体ファイルにして、先頭で .rcfiles 側を読み込む
# usage: prepend_loader <file> <marker> <text>
prepend_loader() {
	if [ -L "$1" ]; then rm "$1"; fi
	if ! grep -qsF "$2" "$1"; then
		{
			printf '%s\n' "$3"
			if [ -f "$1" ]; then cat "$1"; fi
		} > "$1.tmp" && mv "$1.tmp" "$1"
	fi
}

prepend_loader .zshrc '.rcfiles/.zshrc_rcfiles' \
	'[ -f ~/.rcfiles/.zshrc_rcfiles ] && source ~/.rcfiles/.zshrc_rcfiles'
prepend_loader .gitconfig '.rcfiles/.gitconfig_rcfiles' \
	"$(printf '[include]\n\tpath = ~/.rcfiles/.gitconfig_rcfiles')"
