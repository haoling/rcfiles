# kbd-off

外付けキーボード（iClever DK02）がつながっている間だけ、MacBook の内蔵キーボードを無効にします（macOS）。

- DK02 が接続されると内蔵キーボードを無効にし、通知を出します
- DK02 が切断されると元に戻し、通知を出します
- 内蔵トラックパッドはそのまま使えます

## 仕組み

macOS 標準の `hidutil` で、内蔵キーボードの全キーを「何もしないキー」に割り当て直しています。
ドライバーやカーネル拡張は使いません。割り当ては再起動すると消えるので、壊れても再起動すれば元に戻ります。

| ファイル | 役割 |
|---|---|
| `agent.swift` | 常駐プログラムのソース。5 秒ごとに `check.sh` を実行します |
| `check.sh` | DK02 の接続を調べ、必要なときだけ `off.sh` / `on.sh` を実行します |
| `off.sh` | 内蔵キーボードを無効にします（`map.json` の割り当てを適用） |
| `on.sh` | 内蔵キーボードを元に戻します（割り当てを空にする） |
| `map.json` | 無効化に使うキー割り当て（全キー → 何もしないキー） |
| `install.sh` | `kbd-off-agent` をビルドし、LaunchAgent に登録します |

`check.sh` は次のときに割り当てを掛け直します。スリープ復帰などで割り当てが外れることがあるためです。

- DK02 の接続状態が変わったとき
- スリープから復帰したとき
- DK02 接続中に 5 分たったとき

状態は `/tmp/kbd-off.state`、ログは `/tmp/kbd-off.log` に出ます。

## インストール

Xcode Command Line Tools（`swiftc`）が必要です。

```sh
~/.rcfiles/kbd-off/install.sh
```

ビルドした `kbd-off-agent` を `~/Library/LaunchAgents/jp.fei-yen.kbd-off.plist` に登録して起動します。
ログイン時にも自動で起動します。何度実行しても大丈夫です。`agent.swift` を変えたときも、これを実行し直してください。

初回やビルドし直したあとに「入力監視」の許可を求められたら、許可してください。
（システム設定 → プライバシーとセキュリティ → 入力監視 に `kbd-off-agent` が出ます）

## 手動で切り替える

```sh
~/.rcfiles/kbd-off/off.sh   # 内蔵キーボードを無効にする
~/.rcfiles/kbd-off/on.sh    # 元に戻す
```

常駐中は 5 秒以内に `check.sh` が DK02 の接続状態に合わせ直します。
ずっと手動で切り替えたいときは、下の「アンインストール」で常駐を止めてください。

## 別のキーボードを使う

`check.sh` の `EXTERNALS` に、キーボードの VendorID と ProductID を追加します。
値は `hidutil list` で調べられます。

```sh
hidutil list | grep -i keyboard
```

`check.sh` は、一致したデバイスの行に `iclever` または `0x25a7` が含まれるかで接続を判定しています。
別メーカーのキーボードを足すときは、この `grep` の条件も合わせて変えてください。

## 困ったとき

内蔵キーボードが効かないまま戻らないときは、外付けキーボードかターミナルから `on.sh` を実行してください。
それもできないときは、Mac を再起動すれば元に戻ります。

## アンインストール

```sh
launchctl bootout gui/$(id -u)/jp.fei-yen.kbd-off
rm ~/Library/LaunchAgents/jp.fei-yen.kbd-off.plist
~/.rcfiles/kbd-off/on.sh
```

不要になったら、システム設定の「入力監視」から `kbd-off-agent` を削除してください。
