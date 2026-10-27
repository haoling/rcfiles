#!/bin/zsh

# fzf-install-guide を探すため、このファイルの置き場所を覚えておく
_awsp_dir="${${(%):-%x}:A:h}"

# プロファイルを選んで切り替える（fzf があれば fzf で、なければ selectコマンドで選択）
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

# 今のプロファイルの一時キーを、Coder ワークスペース用の k8s Secret に入れる
# Secret 名は aws-session-token-<プロファイル名>（k8s の名前は小文字・ハイフンしか使えないので変換する）
# Secret には config / credentials / expiration の 3 つのファイルが入る。
# テンプレートの AWS profile に同じ名前を入れたワークスペースが読み込み、
# 実行し直すと、動いているワークスペースにも 1 分ほどで反映される
# aws login の一時キーは 15 分で切れるので、使う間は --watch で書き直し続ける
# （ホスト側の aws login のセッションが続く最大 12 時間まで）
function awsp-coder() {
    setopt local_options pipe_fail
    local context="rancher-desktop"
    local namespace="coder"
    # --watch のときに Secret を書き直す間隔（秒）。aws login の一時キーは 15 分で切れるので、それより十分短くする
    local interval="${AWSP_CODER_INTERVAL:-300}"
    local watch=0

    case "$1" in
        -w|--watch) watch=1 ;;
        "") ;;
        *)
            echo "使い方: awsp-coder [-w|--watch]"
            return 1
            ;;
    esac

    if [[ -z "$AWS_PROFILE" ]]; then
        echo "Error: AWS_PROFILE が設定されていません（awsp で選べます）"
        return 1
    fi

    local cmd
    for cmd in aws kubectl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: $cmd コマンドが見つかりません"
            return 1
        fi
    done

    local secret="aws-session-token-${(L)${AWS_PROFILE//_/-}}"
    if [[ ! "$secret" =~ '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' ]]; then
        echo "Error: プロファイル名 '$AWS_PROFILE' から Secret 名を作れません（$secret）"
        return 1
    fi

    if ! kubectl config get-contexts "$context" >/dev/null 2>&1; then
        echo "Error: kubectl のコンテキスト '$context' がありません"
        return 1
    fi

    local region section="[profile $AWS_PROFILE]"
    region=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null)
    [[ "$AWS_PROFILE" == "default" ]] && section="[default]"

    if (( watch )); then
        echo "${interval} 秒ごとに $namespace/$secret を書き直します（Ctrl-C で終了）"
    fi

    # zsh では値の入った変数をもう一度 local 宣言すると中身が表示されるので、ループの外で宣言する
    local out line key_id secret_key session_token expiration tmp
    while :; do
        # aws login の一時キーと更新用トークンはホストの ~/.aws/login/cache に置いたまま、
        # CLI が更新した一時キーだけを取り出して渡す。ロールのプロファイルは CLI がロールを引き受ける
        key_id="" secret_key="" session_token="" expiration=""
        if ! out=$(aws configure export-credentials --profile "$AWS_PROFILE" --format env-no-export); then
            echo "Error: 一時キーを取得できませんでした（aws login でログインし直してください。ロールのプロファイルは source_profile 側でログインします）"
            return 1
        fi
        for line in ${(f)out}; do
            case "${line%%=*}" in
                AWS_ACCESS_KEY_ID) key_id="${line#*=}" ;;
                AWS_SECRET_ACCESS_KEY) secret_key="${line#*=}" ;;
                AWS_SESSION_TOKEN) session_token="${line#*=}" ;;
                AWS_CREDENTIAL_EXPIRATION) expiration="${line#*=}" ;;
            esac
        done

        if [[ -z "$key_id" || -z "$secret_key" || -z "$session_token" ]]; then
            echo "Error: 一時キーではないキーが返ってきたので中止します"
            return 1
        fi

        # ワークスペースではこのディレクトリの中身がファイルとしてマウントされ、
        # AWS_CONFIG_FILE / AWS_SHARED_CREDENTIALS_FILE で読まれる
        # キーは画面にもコマンドライン引数にも出さず、自分だけが読める一時ディレクトリ経由で渡す
        tmp=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/awsp-coder.XXXXXX") || return 1
        {
            printf '%s\n' \
                "[$AWS_PROFILE]" \
                "aws_access_key_id = $key_id" \
                "aws_secret_access_key = $secret_key" \
                "aws_session_token = $session_token" >"$tmp/credentials"
            printf '%s\n' "$section" >"$tmp/config"
            [[ -n "$region" ]] && printf 'region = %s\n' "$region" >>"$tmp/config"
            printf '%s\n' "$expiration" >"$tmp/expiration"

            kubectl --context "$context" -n "$namespace" create secret generic "$secret" \
                --from-file="$tmp" --dry-run=client -o yaml \
                | kubectl --context "$context" -n "$namespace" apply -f - >/dev/null \
                || { echo "Error: Secret を書き込めませんでした"; return 1; }

            echo "✓ $(date +%H:%M:%S) '$AWS_PROFILE' の一時キーを $namespace/$secret に格納しました（期限: ${expiration:-不明}）"
        } always {
            rm -rf "$tmp"
        }

        (( watch )) || return 0
        sleep "$interval"
    done
}

# 使い方を表示
function awsp-help() {
    cat <<'HELP'
使い方:
  awsp              プロファイルを選んで AWS_PROFILE に設定
                    （fzf があれば fzf で、なければ番号で選ぶ）
  awsp new [名前]   プロファイルを新規作成して切り替え（-n, --new でも可）
  awsp help         この使い方を表示（-h, --help でも可）
  awsp-current      現在のプロファイルを表示
  awsp-unset        AWS_PROFILE を解除
  awsp-coder        今のプロファイルの一時キーを rancher-desktop の
                    coder/aws-session-token-<プロファイル名> Secret に格納
                    （Coder テンプレートの AWS profile に同じ名前を入れると読み込まれる）
  awsp-coder -w     上を AWSP_CODER_INTERVAL 秒（既定 300 秒）ごとに繰り返す（--watch でも可）
                    aws login の一時キーは 15 分で切れるので、ワークスペースで使う間は動かしておく

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
