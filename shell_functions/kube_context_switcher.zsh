#!/bin/zsh

# fzf-install-guide を探すため、このファイルの置き場所を覚えておく
_kubep_dir="${${(%):-%x}:A:h}"

# kubectl の context を選んで切り替える（fzf があれば fzf で、なければ selectコマンドで選択）
# kubectl config use-context で切り替えるので、AWS_PROFILE と違って他のシェルにも効く
function kubep() {
    case "$1" in
        -h|--help|help)
            kubep-help
            return 0
            ;;
    esac

    if ! command -v kubectl >/dev/null 2>&1; then
        echo "Error: kubectl コマンドが見つかりません"
        return 1
    fi

    # 名前を指定されたらそのまま切り替える
    if [[ -n "$1" ]]; then
        _kubep_use "$1"
        return
    fi

    local contexts=(${(f)"$(kubectl config get-contexts -o name 2>/dev/null | sort)"})

    if [[ ${#contexts[@]} -eq 0 ]]; then
        echo "context が見つかりませんでした（kubeconfig: ${KUBECONFIG:-~/.kube/config}）"
        return 1
    fi

    local current
    current=$(kubectl config current-context 2>/dev/null)

    if (( $+commands[fzf] )); then
        # 選んでいる context の cluster / user / namespace を表示する（認証情報は出さない）
        local preview='kubectl config get-contexts {}'
        # 今の context が一覧にあれば、最初からそこにカーソルを当てる
        local -a pos_opt
        local current_index=${contexts[(Ie)$current]}
        if [[ -n "$current" ]] && (( current_index > 0 )); then
            pos_opt=(--bind "load:pos($current_index)")
        fi
        local context
        context=$(printf '%s\n' $contexts | fzf --height 40% --reverse \
            --prompt 'kube context> ' \
            --header "現在: ${current:-なし}" \
            $pos_opt \
            --preview "$preview" \
            --preview-window down:3) || return 0
        _kubep_use "$context"
        return
    fi

    # fzf がなければ入れ方を案内してから、select で選ぶ（案内はシェルごとに 1 回）
    if [[ -z "$_kubep_fzf_guided" ]]; then
        "$_kubep_dir/fzf-install-guide"
        echo
        _kubep_fzf_guided=1
    fi

    echo "kubectl の context を選択してください（現在: ${current:-なし}）:"

    select context in $contexts; do
        if [[ -n "$context" ]]; then
            _kubep_use "$context"
            break
        else
            echo "無効な選択です"
        fi
    done
}

function _kubep_use() {
    kubectl config use-context "$1" >/dev/null || return 1
    echo "✓ kubectl の context を '$1' に切り替えました"
}

# 現在の context を表示
function kubep-current() {
    local current
    current=$(kubectl config current-context 2>/dev/null)
    if [[ -n "$current" ]]; then
        echo "現在の context: \033[1;32m$current\033[0m"
    else
        echo "kubectl の context は設定されていません"
    fi
}

# 使い方を表示
function kubep-help() {
    cat <<'HELP'
使い方:
  kubep             context を選んで kubectl config use-context で切り替え
                    （fzf があれば fzf で、なければ番号で選ぶ）
  kubep <名前>      指定した context にそのまま切り替え
  kubep help        この使い方を表示（-h, --help でも可）
  kubep-current     現在の context を表示

kubeconfig（~/.kube/config または KUBECONFIG）の current-context を書き換えるので、
切り替えは開いている他のシェルにも反映される。

fzf の入れ方は ~/.rcfiles/shell_functions/fzf-install-guide で確認できる。
HELP
}
