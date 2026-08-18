#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m unittest discover -s "$ROOT/tests" -p 'test_*.py' -v
find "$ROOT/scripts" -maxdepth 1 -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 -m py_compile "$ROOT/tools/port_product.py" "$ROOT/tools/make_rock960_android_dts.py"
grep -q 'mkupdate_rk3399.sh' "$ROOT/scripts/in-tree-build.sh"
! grep -R --line-number 'sdboot.sh' "$ROOT/scripts" >/dev/null
printf '%s\n' 'All controller tests passed.'
