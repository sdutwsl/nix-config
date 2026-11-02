#!/usr/bin/env bash
set -euo pipefail
umask 077
display_file="$XDG_RUNTIME_DIR/display"
rm -f "$display_file"
Xvfb -displayfd 3 -screen 0 1280x800x24 -nolisten tcp \
  3>"$display_file" >"$XDG_CACHE_HOME/xvfb.log" 2>&1 &
for attempt in {1..100}; do
  [[ -s "$display_file" ]] && break
  sleep .1
done
[[ -s "$display_file" ]] || { echo 'Private X server failed to start' >&2; exit 1; }
export DISPLAY=":$(cat "$display_file")"
unset XAUTHORITY
mkdir -p "$XDG_CONFIG_HOME/fcitx"
if [[ ! -f "$XDG_CONFIG_HOME/fcitx/profile" ]]; then
  cat > "$XDG_CONFIG_HOME/fcitx/profile" <<'EOF'
[Profile]
CurrentIM=sogoupinyin
EnabledIMList=fcitx-keyboard-us:True,sogoupinyin:True
EOF
fi
# Only this private D-Bus session is published to the bridge.
display_number=${DISPLAY##*:}
display_number=${display_number%%.*}
printf '%s\norg.fcitx.Fcitx-%s\n' "$DBUS_SESSION_BUS_ADDRESS" "$display_number" > "$SOGOU_BUS_ADDRESS_FILE.tmp"
mv "$SOGOU_BUS_ADDRESS_FILE.tmp" "$SOGOU_BUS_ADDRESS_FILE"
exec fcitx -D -s 0 --disable fcitx-xim,fcitx-remote-module,fcitx-sogoupinyinhxm
