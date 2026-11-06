#!/bin/zsh
# kbd-off-agent をビルドし、LaunchAgent として登録(再登録)する。何度実行してもよい。
set -e
DIR=${0:A:h}
LABEL=jp.fei-yen.kbd-off
PLIST=~/Library/LaunchAgents/$LABEL.plist

swiftc -O -o $DIR/kbd-off-agent $DIR/agent.swift

mkdir -p ~/Library/LaunchAgents
cat > $PLIST <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$DIR/kbd-off-agent</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>/tmp/kbd-off.log</string>
  <key>StandardErrorPath</key><string>/tmp/kbd-off.log</string>
</dict></plist>
PLIST

launchctl bootout gui/$(id -u)/$LABEL 2>/dev/null || true
rm -f /tmp/kbd-off.state
launchctl bootstrap gui/$(id -u) $PLIST
echo "登録しました: $PLIST"
