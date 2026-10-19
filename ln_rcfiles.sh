#!/bin/sh

cd `dirname $0`
cd ..


for f in .myscreen .myscreen2 .mylauncher .mytmux .mytmux2 .mytmux3 .screenrc .tmux.conf .vimrc .gitconfig .tmuxssh
do
	if [ -e $f ]; then rm $f; fi
	if [ -L $f ]; then rm $f; fi
	ln -s .rcfiles/$f $f
done

# .zshrc はインストーラー等が追記するため、実体ファイルの先頭で .zshrc_rcfiles を読み込む
if [ -L .zshrc ]; then rm .zshrc; fi
if ! grep -qsF '.rcfiles/.zshrc_rcfiles' .zshrc; then
	{
		echo '[ -f ~/.rcfiles/.zshrc_rcfiles ] && source ~/.rcfiles/.zshrc_rcfiles'
		if [ -f .zshrc ]; then cat .zshrc; fi
	} > .zshrc.tmp && mv .zshrc.tmp .zshrc
fi
