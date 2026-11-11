#!/bin/sh
# 標準の機能をまとめてインストールする（何度実行しても大丈夫）
# 機能を選んでインストール・アンインストールしたいときは rcfiles-setup を使う
exec sh "$(cd "$(dirname "$0")" && pwd)/rcfiles-setup" defaults
