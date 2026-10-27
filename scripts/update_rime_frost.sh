#!/usr/bin/env bash
set -euo pipefail

repo_url="https://github.com/gaboolic/rime-frost.git"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
rime_dir="$data_home/fcitx5/rime"
rime_parent="$(dirname "$rime_dir")"

mkdir -p "$rime_parent"

if [ -d "$rime_dir/.git" ]; then
  git -C "$rime_dir" remote set-url origin "$repo_url" || true
  if git -C "$rime_dir" pull --ff-only --depth=1; then
    echo "Updated rime-frost in $rime_dir"
    exit 0
  fi
fi

tmp_dir="$(mktemp -d "$rime_parent/rime-frost.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

git clone --depth=1 "$repo_url" "$tmp_dir"

if [ -e "$rime_dir" ]; then
  rm -rf "$rime_dir.bak"
  mv "$rime_dir" "$rime_dir.bak"
fi

mv "$tmp_dir" "$rime_dir"
trap - EXIT

echo "Installed rime-frost to $rime_dir"
