#!/bin/bash

for disk in $(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print $1}'); do
    points=$(lsblk -nlo MOUNTPOINT "/dev/$disk" | awk 'NF')
    [[ -z $points ]] && continue
    read -r u t < <(printf '%s' "$points" | xargs df -B1 --output=used,size 2>/dev/null | awk 'NR>1{u+=$1;t+=$2}END{print u,t}')
    ((t > 0)) && printf '%s:%s/%s ' "$disk" \
        "$(numfmt --to=iec --suffix=B "$u")" "$(numfmt --to=iec --suffix=B "$t")"
done
echo
