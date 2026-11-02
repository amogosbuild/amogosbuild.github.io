#!/bin/bash
set -euo pipefail
test "${AMOGOS_STORE_TEST_ROOT:-}" = bootstrap
test "${container:-}" = chocolatier
test -f /work/rootfs/etc/os-release
test "$(id -un)" = storetest
/usr/bin/amogos-appstore > /home/storetest/store-native.log 2>&1 &
store_pid=$!
trap 'kill "$store_pid" 2>/dev/null || true; wait "$store_pid" 2>/dev/null || true' EXIT
sleep 12
kill -0 "$store_pid"
python3 - <<'PY'
from PIL import ImageGrab
ImageGrab.grab().save('/home/storetest/store-linux.png')
print('Native Linux store window captured',flush=True)
PY
