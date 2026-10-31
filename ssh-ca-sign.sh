#!/bin/bash
# ssh-ca-sign.sh — step を使わずに step-ca から SSH ユーザー証明書をもらう (macOS / Linux)
#
# 使い方:
#   ./ssh-ca-sign.sh <公開鍵ファイル.pub> [出力する証明書ファイル]
#   例) ./ssh-ca-sign.sh ~/.ssh/mac-se.pub
#       → ~/.ssh/mac-se-cert.pub ができる
#
# 必要なもの: curl, openssl, ssh-keygen (macOS 標準), JSON 処理は jq があれば jq、無ければ osascript
set -euo pipefail

# ==== 設定 ====
AUTH0_DOMAIN="dev-yylac0nb1wj2gbav.jp.auth0.com"
CLIENT_ID="nvOYR8glGfbvv154bb6LRUykBS4Yyh1C"
CA_URL="https://ssh-ca.fei-yen.jp"
CA_ROOT="$HOME/.ssh/ssh-ca-root.pem"
ROOT_FP="f6370d96bcc0abf8357e8f703eb539c752229a9a90066e585d1fa34aae1d3892"
PRINCIPAL="haoling"
# ==============

PUBKEY="${1:?usage: $0 <public key .pub> [output cert file]}"
[ -r "$PUBKEY" ] || { echo "公開鍵が読めません: $PUBKEY" >&2; exit 1; }
# 秘密鍵を渡されたら、隣にある .pub を使う
if head -n 1 "$PUBKEY" | grep -q -- '-----BEGIN'; then
  if [ ! -e "$PUBKEY.pub" ]; then
    echo "公開鍵 $PUBKEY.pub が無いので、秘密鍵から作成します(パスフレーズ付きなら入力を求められます)"
    tmp_pub="$(mktemp)"
    if ! ssh-keygen -y -f "$PUBKEY" > "$tmp_pub"; then
      rm -f "$tmp_pub"; echo "公開鍵の作成に失敗しました" >&2; exit 1
    fi
    mv "$tmp_pub" "$PUBKEY.pub"
    chmod 644 "$PUBKEY.pub"
    echo "保存しました: $PUBKEY.pub"
  else
    echo "秘密鍵が指定されたので、公開鍵 $PUBKEY.pub を使います"
  fi
  PUBKEY="$PUBKEY.pub"
fi
case "$(awk '{print $1; exit}' "$PUBKEY")" in
  ssh-*|ecdsa-*|sk-*) ;;
  *) echo "OpenSSH 形式の公開鍵ではありません: $PUBKEY" >&2; exit 1 ;;
esac
OUT="${2:-${PUBKEY%.pub}-cert.pub}"

json_get() { # json_get <json> <key>
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -r --arg k "$2" '.[$k] // empty'
  else
    osascript -l JavaScript -e 'function run(a){var v=JSON.parse(a[0])[a[1]];return (v===undefined||v===null)?"":String(v)}' "$1" "$2"
  fi
}

# --- 1. CA のルート証明書(初回のみ取得して、フィンガープリントで検証) ---
if [ ! -s "$CA_ROOT" ]; then
  tmp_root="$(mktemp)"
  curl -sS -k -o "$tmp_root" "$CA_URL/roots.pem"
  fp="$(openssl x509 -in "$tmp_root" -noout -fingerprint -sha256 | sed 's/.*=//; s/://g' | tr 'A-F' 'a-f')"
  if [ "$fp" != "$ROOT_FP" ]; then
    rm -f "$tmp_root"
    echo "ルート証明書のフィンガープリントが一致しません!中断します。" >&2
    echo "  期待値: $ROOT_FP" >&2
    echo "  取得値: $fp" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$CA_ROOT")"
  mv "$tmp_root" "$CA_ROOT"
  chmod 644 "$CA_ROOT"
  echo "ルート証明書を検証して保存しました: $CA_ROOT"
fi

# --- 2. Auth0 Device Code フローで ID トークンを取得 ---
dc="$(curl -sS -X POST "https://$AUTH0_DOMAIN/oauth/device/code" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "scope=openid email")"
device_code="$(json_get "$dc" device_code)"
user_code="$(json_get "$dc" user_code)"
verify_uri="$(json_get "$dc" verification_uri_complete)"
interval="$(json_get "$dc" interval)"; interval="${interval:-5}"
expires_in="$(json_get "$dc" expires_in)"; expires_in="${expires_in:-900}"
if [ -z "$device_code" ]; then
  echo "Device Code の取得に失敗: $(json_get "$dc" error) $(json_get "$dc" error_description)" >&2
  exit 1
fi

echo
echo "  このURLを開いて承認してください(スマホでもOK):"
echo "    $verify_uri"
echo "  確認コード: $user_code   ← 画面のコードと一致するか必ず確認"
echo
if command -v open >/dev/null 2>&1; then open "$verify_uri" 2>/dev/null || true
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$verify_uri" >/dev/null 2>&1 || true
fi

deadline=$(( $(date +%s) + expires_in ))
id_token=""
while :; do
  sleep "$interval"
  tok="$(curl -sS -X POST "https://$AUTH0_DOMAIN/oauth/token" \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    --data-urlencode "device_code=$device_code" \
    --data-urlencode "client_id=$CLIENT_ID")"
  id_token="$(json_get "$tok" id_token)"
  [ -n "$id_token" ] && break
  err="$(json_get "$tok" error)"
  case "$err" in
    authorization_pending) ;;
    slow_down) interval=$(( interval + 5 )) ;;
    *) echo "認証失敗: $err $(json_get "$tok" error_description)" >&2; exit 1 ;;
  esac
  if [ "$(date +%s)" -ge "$deadline" ]; then echo "時間切れです。" >&2; exit 1; fi
done
echo "認証OK。証明書を発行します…"

# --- 3. step-ca に公開鍵と ID トークンを送って署名してもらう ---
keytype="$(awk '{print $1}' "$PUBKEY")"
pub_b64="$(awk '{print $2}' "$PUBKEY")"
# トークンをコマンドライン引数に載せないよう、本文は標準入力で渡す
resp="$(printf '{"publicKey":"%s","ott":"%s","certType":"user","principals":["%s"]}' \
          "$pub_b64" "$id_token" "$PRINCIPAL" \
        | curl -sS --cacert "$CA_ROOT" -H 'Content-Type: application/json' \
            --data-binary @- "$CA_URL/1.0/ssh/sign")"
unset id_token
crt="$(json_get "$resp" crt)"
if [ -z "$crt" ]; then
  echo "発行に失敗: $(json_get "$resp" message)" >&2
  exit 1
fi

case "$keytype" in
  sk-ecdsa-sha2-nistp256@openssh.com) certtype="sk-ecdsa-sha2-nistp256-cert-v01@openssh.com" ;;
  sk-ssh-ed25519@openssh.com)         certtype="sk-ssh-ed25519-cert-v01@openssh.com" ;;
  *)                                  certtype="${keytype}-cert-v01@openssh.com" ;;
esac

printf '%s %s\n' "$certtype" "$crt" > "$OUT"
chmod 644 "$OUT"
echo "保存しました: $OUT"
echo
ssh-keygen -L -f "$OUT" | sed -n '1,12p'
