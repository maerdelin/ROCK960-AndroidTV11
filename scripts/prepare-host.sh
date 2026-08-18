#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then
  echo "run with sudo: sudo $0" >&2
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  git git-core gnupg flex bison gperf build-essential zip curl zlib1g-dev \
  gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev \
  libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip python2 \
  python3 python3-dev bc liblz4-tool lz4 m4 xz-utils kmod fontconfig libssl-dev \
  parted gawk cpio rsync dosfstools wget sudo device-tree-compiler openjdk-8-jdk \
  fakeroot file ca-certificates ccache
update-alternatives --install /usr/bin/python python /usr/bin/python2 10 || true
