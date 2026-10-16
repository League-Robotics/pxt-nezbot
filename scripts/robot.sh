#!/usr/bin/env bash
# robot.sh — build for a fleet robot and flash it through mbdeploy, wherever
# it is plugged in. A robot the console holds is unlocked first: the lock
# lives on the node that has the board (the HOST column of `mbregistry
# list`), so a remote one is released over ssh.
#
#   bash scripts/robot.sh gopiv
#
# MBTOOLS points at the mbtools checkout; `uv run` there finds the tools.
set -euo pipefail

ROBOT="${1:-}"
[ -n "$ROBOT" ] || { echo "usage: bash scripts/robot.sh <robot>" >&2; exit 1; }
MBTOOLS="${MBTOOLS:-/Volumes/Proj/proj/robot-projects/mbtools}"

cd "$(dirname "$0")/.."
bash scripts/build.sh --local --robot "$ROBOT"
HEX="$PWD/built/binary.hex"

cd "$MBTOOLS"
ROW=$(uv run mbregistry list | awk -v r="$ROBOT" '$3 == r')
[ -n "$ROW" ] || { echo "robot.sh: $ROBOT is not in the registry" >&2; exit 1; }
STATE=$(echo "$ROW" | awk '{print $1}')
UID_=$(echo "$ROW" | awk '{print $4}')
HOST=$(echo "$ROW" | awk '{print $(NF-1)}')

if [ "$STATE" = "locked" ]; then
    if [ "$HOST" = "local" ]; then
        uv run mbregistry unlock --force "$UID_"
    else
        USER_=eric
        [ "$HOST" = "zilch" ] && USER_=jtl
        ssh -o BatchMode=yes "$USER_@$HOST" "mbregistry unlock --force $UID_"
    fi
fi

uv run mbdeploy deploy "$ROBOT" --hex "$HEX"
