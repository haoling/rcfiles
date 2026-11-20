#!/bin/zsh

# awsl-browser などを探すため、このファイルの置き場所を覚えておく
_awsl_dir="${${(%):-%x}:A:h}"

# aws login を、選んでおいた Chrome のプロファイルで開く（macOS）
#   awsl choice … fzf で Chrome のプロファイルを選び、~/.config/awsl/chrome-profile に保存する
#   awsl [引数] … aws login [引数] を実行する。ブラウザは保存したプロファイルで開く
function awsl() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/awsl/chrome-profile"

    case "$1" in
        -h|--help|help)
            echo "使い方:"
            echo "  awsl choice   aws login で使う Chrome のプロファイルを選ぶ（最初に1回）"
            echo "  awsl [引数]   aws login [引数] を実行し、選んだプロファイルでブラウザを開く"
            echo "                先に awsp で AWS_PROFILE を設定しておく（--profile を渡すときは不要）"
            echo "保存先: $conf"
            return 0
            ;;
        choice)
            if ! command -v fzf >/dev/null 2>&1; then
                "$_awsl_dir/fzf-install-guide"
                return 1
            fi
            local current="" sel
            [[ -s "$conf" ]] && current="$(head -n1 "$conf")"
            sel="$("$_awsl_dir/awsl-list-chrome-profiles" \
                | fzf --delimiter='\t' --with-nth=2 --height=40% --reverse \
                      --prompt='Chrome profile> ' --header="現在: ${current:-未設定}")" || return 1
            mkdir -p "${conf:h}"
            print -r -- "${sel%%$'\t'*}" > "$conf"
            echo "保存しました: ${sel#*$'\t'} (${sel%%$'\t'*}) -> $conf"
            return 0
            ;;
    esac

    if [[ ! -s "$conf" ]]; then
        echo "awsl: 使用する Chrome プロファイルが未設定です。先に 'awsl choice' を実行してください。" >&2
        return 1
    fi
    # --profile を直接渡したときは AWS_PROFILE がなくてもよい
    if [[ -z "$AWS_PROFILE" && ! " $* " =~ ' --profile[ =]' ]]; then
        echo "awsl: AWS_PROFILE が設定されていません。先に 'awsp' でプロファイルを選んでください。" >&2
        return 1
    fi
    BROWSER="$_awsl_dir/awsl-browser" aws login "$@"
}
