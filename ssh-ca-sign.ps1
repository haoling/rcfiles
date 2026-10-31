# ssh-ca-sign.ps1 — step を使わずに step-ca から SSH ユーザー証明書をもらう (Windows)
#
# 使い方:
#   .\ssh-ca-sign.ps1 -PublicKey $env:USERPROFILE\.ssh\card.pub [-OutFile <証明書ファイル>]
#   → 既定では card-cert.pub が同じフォルダにできる
#
# 必要なもの: curl.exe, ssh-keygen.exe (Windows 10/11 標準), PowerShell 5.1 以上
param(
  [Parameter(Mandatory = $true)][string]$PublicKey,
  [string]$OutFile
)
$ErrorActionPreference = 'Stop'

# ==== 設定 ====
$Auth0Domain = 'dev-yylac0nb1wj2gbav.jp.auth0.com'
$ClientId    = 'nvOYR8glGfbvv154bb6LRUykBS4Yyh1C'
$CaUrl       = 'https://ssh-ca.fei-yen.jp'
$CaRoot      = Join-Path $env:USERPROFILE '.ssh\ssh-ca-root.pem'
$RootFp      = 'f6370d96bcc0abf8357e8f703eb539c752229a9a90066e585d1fa34aae1d3892'
$Principal   = 'haoling'
# ==============

$PublicKey = (Resolve-Path $PublicKey).Path
# 秘密鍵を渡されたら、隣にある .pub を使う
if ((Get-Content $PublicKey -TotalCount 1) -match '-----BEGIN') {
  if (-not (Test-Path "$PublicKey.pub")) {
    Write-Host "公開鍵 $PublicKey.pub が無いので、秘密鍵から作成します(パスフレーズ付きなら入力を求められます)"
    $pubText = & ssh-keygen.exe -y -f $PublicKey
    if ($LASTEXITCODE -ne 0 -or -not $pubText) { throw "公開鍵の作成に失敗しました" }
    [IO.File]::WriteAllText("$PublicKey.pub", (($pubText -join "`n").Trim() + "`n"), (New-Object System.Text.UTF8Encoding $false))
    Write-Host "保存しました: $PublicKey.pub"
  } else {
    Write-Host "秘密鍵が指定されたので、公開鍵 $PublicKey.pub を使います"
  }
  $PublicKey = "$PublicKey.pub"
}
if (((Get-Content $PublicKey -Raw).Trim() -split '\s+')[0] -notmatch '^(ssh-|ecdsa-|sk-)') {
  throw "OpenSSH 形式の公開鍵ではありません: $PublicKey"
}
if (-not $OutFile) { $OutFile = ($PublicKey -replace '\.pub$', '') + '-cert.pub' }

# --- 1. CA のルート証明書(初回のみ取得して、フィンガープリントで検証) ---
if (-not (Test-Path $CaRoot)) {
  $tmpRoot = [IO.Path]::GetTempFileName()
  & curl.exe -sS -k -o $tmpRoot "$CaUrl/roots.pem"
  if ($LASTEXITCODE -ne 0) { throw "roots.pem の取得に失敗しました" }
  $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $tmpRoot
  $sha  = [System.Security.Cryptography.SHA256]::Create()
  $fp   = (($sha.ComputeHash($cert.RawData) | ForEach-Object { $_.ToString('x2') }) -join '')
  if ($fp -ne $RootFp) {
    Remove-Item $tmpRoot -Force
    throw "ルート証明書のフィンガープリントが一致しません!`n  期待値: $RootFp`n  取得値: $fp"
  }
  New-Item -ItemType Directory -Force -Path (Split-Path $CaRoot) | Out-Null
  Move-Item $tmpRoot $CaRoot -Force
  Write-Host "ルート証明書を検証して保存しました: $CaRoot"
}

# --- 2. Auth0 Device Code フローで ID トークンを取得 ---
$dc = Invoke-RestMethod -Method Post -Uri "https://$Auth0Domain/oauth/device/code" `
        -Body @{ client_id = $ClientId; scope = 'openid email' }

Write-Host ''
Write-Host '  このURLを開いて承認してください(スマホでもOK):'
Write-Host "    $($dc.verification_uri_complete)"
Write-Host "  確認コード: $($dc.user_code)   ← 画面のコードと一致するか必ず確認"
Write-Host ''
try { Start-Process $dc.verification_uri_complete } catch {}

$interval = if ($dc.interval) { [int]$dc.interval } else { 5 }
$deadline = (Get-Date).AddSeconds([int]$dc.expires_in)
$idToken  = $null
while (-not $idToken) {
  Start-Sleep -Seconds $interval
  try {
    $tok = Invoke-RestMethod -Method Post -Uri "https://$Auth0Domain/oauth/token" -Body @{
      grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
      device_code = $dc.device_code
      client_id   = $ClientId
    }
    $idToken = $tok.id_token
  } catch {
    $e = $null
    try { $e = $_.ErrorDetails.Message | ConvertFrom-Json } catch {}
    if ($e -and $e.error -eq 'authorization_pending') {
    } elseif ($e -and $e.error -eq 'slow_down') {
      $interval += 5
    } else {
      $msg = if ($e) { "$($e.error) $($e.error_description)" } else { $_.Exception.Message }
      throw "認証失敗: $msg"
    }
  }
  if (-not $idToken -and (Get-Date) -gt $deadline) { throw '時間切れです。' }
}
Write-Host '認証OK。証明書を発行します…'

# --- 3. step-ca に公開鍵と ID トークンを送って署名してもらう ---
$parts   = ((Get-Content $PublicKey -Raw).Trim()) -split '\s+'
$keyType = $parts[0]
$body = @{
  publicKey  = $parts[1]
  ott        = $idToken
  certType   = 'user'
  principals = @($Principal)
} | ConvertTo-Json -Compress
$idToken = $null

# トークンをコマンドライン引数に載せないよう、本文は一時ファイル経由で渡してすぐ消す
$tmpBody = [IO.Path]::GetTempFileName()
try {
  [IO.File]::WriteAllText($tmpBody, $body)
  $respText = & curl.exe -sS --ssl-no-revoke --cacert $CaRoot `
                -H 'Content-Type: application/json' `
                --data-binary "@$tmpBody" "$CaUrl/1.0/ssh/sign"
} finally {
  Remove-Item $tmpBody -Force -ErrorAction SilentlyContinue
  $body = $null
}
if ($LASTEXITCODE -ne 0) { throw "step-ca への接続に失敗しました" }
$resp = ($respText -join "`n") | ConvertFrom-Json
if (-not $resp.crt) { throw "発行に失敗: $($resp.message)" }

switch ($keyType) {
  'sk-ecdsa-sha2-nistp256@openssh.com' { $certType = 'sk-ecdsa-sha2-nistp256-cert-v01@openssh.com' }
  'sk-ssh-ed25519@openssh.com'         { $certType = 'sk-ssh-ed25519-cert-v01@openssh.com' }
  default                              { $certType = "$keyType-cert-v01@openssh.com" }
}

[IO.File]::WriteAllText($OutFile, "$certType $($resp.crt)`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host "保存しました: $OutFile"
Write-Host ''
& ssh-keygen.exe -L -f $OutFile | Select-Object -First 12
