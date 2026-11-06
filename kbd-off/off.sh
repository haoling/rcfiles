#!/bin/zsh
M='{"Product":"Apple Internal Keyboard / Trackpad","PrimaryUsagePage":1,"PrimaryUsage":6}'
n=$(hidutil list --matching "$M" | sed -n '/^Services:/,/^Devices:/p' | grep -c 'Apple Internal Keyboard')
[[ $n -eq 1 ]] || { echo "matching ${n}件 → 中止"; exit 1; }
hidutil property --matching "$M" --set '{"UserKeyMapping":[]}' >/dev/null
hidutil property --matching "$M" --set "$(cat ${0:A:h}/map.json)" >/dev/null && echo "内蔵キーボード off"
