#!/bin/zsh

# バージョン1: selectコマンドを使用（数字キーで選択）
function awsp() {
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
