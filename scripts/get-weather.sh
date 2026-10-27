#!/bin/bash
file="$HOME/.cache/.region"
if [ -f "$file" ];then
  region=$(cat "$file")
  json=$(curl -s -L --compressed "https://weather.cma.cn/api/now/$region" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36" \
  -H "Accept: application/json, text/plain, */*" \
  -H "Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8" \
  -H "Referer: https://weather.cma.cn/" \
  -H "Connection: keep-alive")

  city=$(echo "$json" | grep -o '"name":[^,]*' | sed 's/"name"://'| sed 's/"//g')
  temp=$(echo "$json" | grep -o '"temperature":[^,]*' | sed 's/"temperature"://')
  humi=$(echo "$json" | grep -o '"humidity":[^,]*' | sed 's/"humidity"://')

  echo "$city 气温: $temp°C 湿度: $humi%"
fi

