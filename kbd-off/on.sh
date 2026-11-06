#!/bin/zsh
M='{"Product":"Apple Internal Keyboard / Trackpad","PrimaryUsagePage":1,"PrimaryUsage":6}'
hidutil property --matching "$M" --set '{"UserKeyMapping":[]}' >/dev/null && echo "内蔵キーボード on"
