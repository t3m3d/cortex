#!/usr/bin/env sh
# Build cortex (pure-Krypton X11 file manager) to ./cortex.
#   ./build.sh            -> ./cortex
#   ./build.sh /tmp/cortex -> custom output path
#   ./build.sh --run      -> build to ./cortex and launch it
set -e
cd "$(dirname "$0")"

OUT=./cortex
RUN=0
case "$1" in
  --run) RUN=1 ;;
  "" ) ;;
  * ) OUT="$1" ;;
esac

# Locate the Krypton repo (for stdlib/x11.k) and a native driver.
KRYPTON_ROOT="${KRYPTON_ROOT:-$(cd ../krypton 2>/dev/null && pwd)}"
if [ -z "$KRYPTON_ROOT" ] || [ ! -d "$KRYPTON_ROOT" ]; then
  echo "build.sh: set KRYPTON_ROOT to your krypton checkout (stdlib/x11.k lives there)" >&2
  exit 1
fi

DRIVER="$KRYPTON_ROOT/bootstrap/kcc_driver_linux_x86_64"
if [ ! -x "$DRIVER" ]; then
  DRIVER="$(command -v kcc || command -v krypton || true)"
fi
if [ -z "$DRIVER" ]; then
  echo "build.sh: no Krypton driver found (looked for $KRYPTON_ROOT/bootstrap/kcc_driver_linux_x86_64, kcc, krypton)" >&2
  exit 1
fi

echo "build.sh: KRYPTON_ROOT=$KRYPTON_ROOT"
echo "build.sh: $DRIVER cortex.k -o $OUT"
KRYPTON_ROOT="$KRYPTON_ROOT" "$DRIVER" cortex.k -o "$OUT"

if [ "$RUN" = 1 ]; then
  exec "$OUT"
fi
