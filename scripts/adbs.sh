#!/usr/bin/env bash

IP="10.42.0.42" # vivo-S50-Pro-mini @ NixWiFi
WAIT=10         # 等 mDNS 发现的上限（秒）

run_scrcpy() {
  exec scrcpy -s "$1" --render-driver vulkan --no-audio --stay-awake -S
}

# adb devices 里属于 $IP 且状态为 device 的 serial
connected_serial() {
  adb devices | awk -v ip="$IP:" '$2=="device" && index($1, ip)==1 { print $1; exit }'
}

# 向 mDNS 问 $IP 上的无线调试端口。安卓开着无线调试时会广播
# _adb-tls-connect._tcp，端口每次开关都会变，所以只能问、不能猜。
# avahi-browse -p 的字段: 8=地址 9=端口
mdns_endpoint() {
  avahi-browse -rpt _adb-tls-connect._tcp 2>/dev/null |
    awk -F';' -v ip="$IP" '$1=="=" && $3=="IPv4" && $8==ip { print $8 ":" $9; exit }'
}

# 已经连上了就直接投屏
serial=$(connected_serial)
if [ -n "$serial" ]; then
  run_scrcpy "$serial"
fi

# mDNS 发现是异步的，重试到超时为止（avahi-browse -t 本身约 1s 返回）
deadline=$((SECONDS + WAIT))
while :; do
  endpoint=$(mdns_endpoint)
  [ -n "$endpoint" ] && break
  [ "$SECONDS" -ge "$deadline" ] && break
  sleep 1
done

if [ -z "$endpoint" ]; then
  echo "未在 $IP 上发现 adb 服务（等了 ${WAIT}s）"
  echo "请确认手机连在 NixWiFi 上，且 开发者选项 → 无线调试 已打开"
  exit 1
fi

echo "发现 $endpoint"
adb connect "$endpoint" >/dev/null 2>&1

serial=$(connected_serial)
if [ -z "$serial" ]; then
  adb disconnect "$endpoint" >/dev/null 2>&1
  echo "连接 $endpoint 失败"
  echo "若从未配对过，在手机「无线调试 → 使用配对码配对设备」里取配对端口和配对码，然后："
  echo "  adb pair $IP:<配对端口> <配对码>"
  exit 1
fi

run_scrcpy "$serial"
