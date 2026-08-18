#!/usr/bin/env bash
set -euo pipefail
SIZE="${1:-32G}"
FILE="${2:-/swapfile}"
if [[ $EUID -ne 0 ]]; then
  echo "run as root: sudo $0 $SIZE $FILE" >&2
  exit 1
fi
if swapon --show=NAME --noheadings | grep -Fxq "$FILE"; then
  echo "$FILE is already active"
  exit 0
fi
if [[ ! -f "$FILE" ]]; then
  fallocate -l "$SIZE" "$FILE" || dd if=/dev/zero of="$FILE" bs=1M count=$(( ${SIZE%G} * 1024 )) status=progress
  chmod 600 "$FILE"
  mkswap "$FILE"
fi
swapon "$FILE"
if ! grep -Fq "$FILE none swap" /etc/fstab; then
  printf '%s none swap sw 0 0\n' "$FILE" >> /etc/fstab
fi
swapon --show
