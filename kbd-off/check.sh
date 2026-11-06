#!/bin/zsh
DIR=${0:A:h}
STATE=/tmp/kbd-off.state      # 中身: 状態 waketime 最終適用時刻
REFRESH=300                   # 接続中の定期掛け直し(秒)
EXTERNALS=(
  '{"VendorID":0x25a7,"ProductID":0xfaa2}'   # DK02 Bluetooth
  # '{"VendorID":0x????,"ProductID":0x????}' # DK02 2.4GHzドングル(調べたら追加)
)

want=on
for m in $EXTERNALS; do
  hidutil list --matching "$m" 2>/dev/null \
    | sed -n '/^Services:/,/^Devices:/p' \
    | grep -qi 'iclever\|0x25a7' && want=off && break
done

wake=$(sysctl -n kern.waketime | tr -dc '0-9')
now=$(date +%s)
[[ -f $STATE ]] && read prev pwake plast < $STATE

changed=0; [[ $want != $prev ]] && changed=1

if [[ $want == off ]]; then
  # 状態変化・スリープ復帰・定期のどれかで掛け直す
  [[ $changed == 1 || $wake != $pwake || $(( now - ${plast:-0} )) -ge $REFRESH ]] || exit 0
else
  [[ $changed == 1 ]] || exit 0
fi

$DIR/$want.sh >/dev/null || exit 1
echo "$want $wake $now" > $STATE

if [[ $changed == 1 ]]; then
  if [[ $want == off ]]; then
    osascript -e 'display notification "DK02 接続中のため無効化しました" with title "内蔵キーボード OFF"'
  else
    osascript -e 'display notification "DK02 が切断されたので有効に戻しました" with title "内蔵キーボード ON" sound name "Pop"'
  fi
fi
