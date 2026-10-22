#!/bin/zsh

# fzf-install-guide を探すため、このファイルの置き場所を覚えておく
_awsp_dir="${${(%):-%x}:A:h}"

# バージョン1: fzf があれば fzf で、なければ selectコマンドで選択
function awsp() {
    local config_file="${HOME}/.aws/config"
    
    case "$1" in
        -h|--help|help)
            awsp-help
            return 0
            ;;
        -n|--new|new)
            shift
            awsp-new "$@"
            return
            ;;
    esac
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: ~/.aws/config が見つかりません（'awsp new' で作成できます）"
        return 1
    fi
    
    # プロファイル名を抽出
    local profiles=($(grep -E '^\[profile ' "$config_file" | sed 's/\[profile \(.*\)\]/\1/' | sort))
    
    # defaultプロファイルも追加
    if grep -q '^\[default\]' "$config_file"; then
        profiles=(default $profiles)
    fi
    
    if [[ ${#profiles[@]} -eq 0 ]]; then
        echo "プロファイルが見つかりませんでした"
        return 1
    fi
    
    if (( $+commands[fzf] )); then
        # 選んでいるプロファイルの設定を ~/.aws/config から抜き出して表示する
        local preview='awk -v name={} '"'"'
            BEGIN { h = (name == "default") ? "[default]" : "[profile " name "]" }
            $0 == h { f = 1; print; next }
            /^\[/ { f = 0 }
            f
        '"'"' ~/.aws/config'
        local profile
        profile=$(printf '%s\n' $profiles | fzf --height 40% --reverse \
            --prompt 'AWS profile> ' \
            --header "現在: ${AWS_PROFILE:-なし}" \
            --preview "$preview") || return 0
        export AWS_PROFILE="$profile"
        echo "✓ AWS_PROFILE を '$profile' に設定しました"
        return 0
    fi
    
    # fzf がなければ入れ方を案内してから、select で選ぶ（案内はシェルごとに 1 回）
    if [[ -z "$_awsp_fzf_guided" ]]; then
        "$_awsp_dir/fzf-install-guide"
        echo
        _awsp_fzf_guided=1
    fi
    
    echo "AWSプロファイルを選択してください:"
    
    select profile in $profiles; do
        if [[ -n "$profile" ]]; then
            export AWS_PROFILE="$profile"
            echo "✓ AWS_PROFILE を '$profile' に設定しました"
            break
        else
            echo "無効な選択です"
        fi
    done
}

# バージョン2: カーソルキー対応版（より高機能）
function awsp-interactive() {
    local config_file="${HOME}/.aws/config"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: ~/.aws/config が見つかりません"
        return 1
    fi
    
    # プロファイル名を抽出
    local profiles=($(grep -E '^\[profile ' "$config_file" | sed 's/\[profile \(.*\)\]/\1/' | sort))
    
    # defaultプロファイルも追加
    if grep -q '^\[default\]' "$config_file"; then
        profiles=(default $profiles)
    fi
    
    if [[ ${#profiles[@]} -eq 0 ]]; then
        echo "プロファイルが見つかりませんでした"
        return 1
    fi
    
    local selected=1
    local total=${#profiles[@]}
    
    # カーソルを非表示にして画面をクリア
    echo -ne "\033[?25l"
    
    while true; do
        # 画面をクリア
        clear
        
        echo "AWSプロファイルを選択してください:"
        echo "(↑↓: 移動, Enter: 決定, q: キャンセル)"
        echo ""
        
        # 現在のプロファイルを表示
        if [[ -n "$AWS_PROFILE" ]]; then
            echo "現在のプロファイル: \033[36m$AWS_PROFILE\033[0m"
            echo ""
        fi
        
        # プロファイルリストを表示
        for i in {1..$total}; do
            if [[ $i -eq $selected ]]; then
                echo "\033[1;32m→ $i) ${profiles[$i]}\033[0m"
            else
                echo "  $i) ${profiles[$i]}"
            fi
        done
        
        # キー入力を読み取る
        read -k 1 key
        
        case "$key" in
            # 上矢印・下矢印
            $'\e')
                read -k 2 key
                if [[ "$key" == "[A" ]]; then
                    # 上矢印
                    ((selected--))
                    if [[ $selected -lt 1 ]]; then
                        selected=$total
                    fi
                elif [[ "$key" == "[B" ]]; then
                    # 下矢印
                    ((selected++))
                    if [[ $selected -gt $total ]]; then
                        selected=1
                    fi
                fi
                ;;
            # Enter (改行文字)
            $'\n')
                clear
                export AWS_PROFILE="${profiles[$selected]}"
                echo "✓ AWS_PROFILE を '\033[1;32m${profiles[$selected]}\033[0m' に設定しました"
                echo -ne "\033[?25h"
                return 0
                ;;
            # 数字キー
            [1-9])
                if [[ $key -le $total ]]; then
                    clear
                    export AWS_PROFILE="${profiles[$key]}"
                    echo "✓ AWS_PROFILE を '\033[1;32m${profiles[$key]}\033[0m' に設定しました"
                    echo -ne "\033[?25h"
                    return 0
                fi
                ;;
            # q でキャンセル
            q|Q)
                clear
                echo "キャンセルしました"
                echo -ne "\033[?25h"
                return 0
                ;;
        esac
    done
}

# プロファイルを解除する関数
function awsp-unset() {
    if [[ -n "$AWS_PROFILE" ]]; then
        echo "AWS_PROFILE '$AWS_PROFILE' を解除します"
        unset AWS_PROFILE
        echo "✓ AWS_PROFILE を解除しました"
    else
        echo "AWS_PROFILE は設定されていません"
    fi
}

# 現在のプロファイルを表示
function awsp-current() {
    if [[ -n "$AWS_PROFILE" ]]; then
        echo "現在のプロファイル: \033[1;32m$AWS_PROFILE\033[0m"
    else
        echo "AWS_PROFILE は設定されていません（defaultプロファイルを使用）"
    fi
}

# プロファイルを新規作成して切り替える
function awsp-new() {
    local config_file="${HOME}/.aws/config"
    local profile="$1"
    
    if ! command -v aws >/dev/null 2>&1; then
        echo "Error: aws コマンドが見つかりません"
        return 1
    fi
    
    if [[ -z "$profile" ]]; then
        read "profile?新しいプロファイル名: "
    fi
    
    if [[ -z "$profile" ]]; then
        echo "キャンセルしました"
        return 1
    fi
    
    # 一覧の取得が空白区切りなので、空白や [] を含む名前は受け付けない
    if [[ "$profile" == *[[:space:]]* || "$profile" == *\[* || "$profile" == *\]* ]]; then
        echo "Error: プロファイル名に空白や [ ] は使えません"
        return 1
    fi
    
    local section="[profile $profile]"
    [[ "$profile" == "default" ]] && section="[default]"
    
    if [[ -f "$config_file" ]] && grep -qxF "$section" "$config_file"; then
        echo "Error: プロファイル '$profile' は既に存在します"
        return 1
    fi
    
    # select は日本語の項目名が崩れることがあるので自前で表示する
    echo "認証方式を選択してください:"
    echo "  1) IAM Identity Center (SSO)"
    echo "  2) アクセスキー"

    local method
    while true; do
        read "method?番号: " || return 1
        case "$method" in
            1)
                aws configure sso --profile "$profile" || return 1
                break
                ;;
            2)
                aws configure --profile "$profile" || return 1
                break
                ;;
            *)
                echo "無効な選択です"
                ;;
        esac
    done
    
    if [[ -f "$config_file" ]] && grep -qxF "$section" "$config_file"; then
        export AWS_PROFILE="$profile"
        echo "✓ プロファイル '$profile' を作成し、AWS_PROFILE に設定しました"
    else
        echo "プロファイル '$profile' は作成されませんでした"
        return 1
    fi
}

# 使い方を表示
function awsp-help() {
    cat <<'HELP'
使い方:
  awsp              プロファイルを選んで AWS_PROFILE に設定
                    （fzf があれば fzf で、なければ番号で選ぶ）
  awsp new [名前]   プロファイルを新規作成して切り替え（-n, --new でも可）
  awsp help         この使い方を表示（-h, --help でも可）
  awsp-interactive  カーソルキーでプロファイルを選んで設定
  awsp-current      現在のプロファイルを表示
  awsp-unset        AWS_PROFILE を解除

プロファイルを手作業で作る場合:
  IAM Identity Center (SSO) を使う:
    aws configure sso --profile <名前>
    （SSO start URL と SSO region を聞かれ、ブラウザで認証したあと
      アカウントとロールを選ぶ。セッションが切れたら
      aws sso login --profile <名前> で再ログインする）

  アクセスキーを使う:
    aws configure --profile <名前>
    （Access Key ID / Secret Access Key / region / output を入力する。
      キーは ~/.aws/credentials に、それ以外は ~/.aws/config に保存される）

  ~/.aws/config を直接編集する場合（例: 既存プロファイルからロールを引き受ける）:
    [profile <名前>]
    role_arn = arn:aws:iam::123456789012:role/<ロール名>
    source_profile = <元のプロファイル名>
    region = ap-northeast-1

作ったあとは awsp で選ぶと切り替わる。

fzf の入れ方は ~/.rcfiles/shell_functions/fzf-install-guide で確認できる。
HELP
}
