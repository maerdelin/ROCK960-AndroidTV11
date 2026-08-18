#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

ensure_workspace
BIN_DIR="$WORKSPACE/bin"
REPO_BIN="$BIN_DIR/repo"
mkdir -p "$BIN_DIR"
if [[ -x "$REPO_BIN" ]]; then
  printf '%s\n' "$REPO_BIN"
  exit 0
fi

URL1="https://storage.googleapis.com/git-repo-downloads/repo"
URL2="https://raw.githubusercontent.com/GerritCodeReview/git-repo/master/repo"
if curl -fL --retry 4 --connect-timeout 15 "$URL1" -o "$REPO_BIN"; then
  :
elif curl -fL --retry 4 --connect-timeout 15 "$URL2" -o "$REPO_BIN"; then
  :
elif command -v repo >/dev/null 2>&1; then
  command -v repo
  exit 0
else
  die "unable to download repo launcher and no system repo command exists"
fi
chmod +x "$REPO_BIN"
printf '%s\n' "$REPO_BIN"
