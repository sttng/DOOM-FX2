#!/bin/bash
# build.sh MESENCE_DIR : build the headless test runner tools/mesenrun/mesenrun in a MesenCE
# source tree (github.com/nesdev-org/MesenCE, the continuation of the archived Mesen 2), after
# applying tools/mesence-doomfx.patch: the 4 MB DOOM-FX cartridge map (CPU $E0-$FF) and the
# GSU probes below.
# Environment of mesenrun:
#   MESEN_GSU_CLOCK=<%>            GSU clock speed
#   MESEN_HOME=<dir>               Mesen's home folder (battery saves in Saves/; default /tmp/mesenhome)
#   MESEN_RAM=random|ones          power-on RAM (default zeros)
#   MESEN_HIDE=<1234s>             layers not drawn (BG1-BG4, sprites)
#   MESEN_PORT1_MOUSE, MESEN_PORT2_MOUSE, MESEN_PORT2_PAD   controllers (default: a joypad in port 1)
#   MESEN_GSU_PROF=<file>          GSU cycles per instruction address (tools/test/gsuprof.py)
#   MESEN_GSU_STATS=<file>         GSU cycles and pixel cache flushes (JSON)
#   MESEN_GSU_IDLE=<file>          GSU time running / stopped / waiting for ROM / for RAM, in master
#                                  clocks: total, per frame and per GSU address
#   MESEN_GSU_IDLE_FROM=<frame>    per-address counts and the trace from that frame on
#   MESEN_GSU_TRACE=<file>         with MESEN_GSU_IDLE: each idle interval (master clock, length,
#                                  reason, GSU PC) for MESEN_GSU_TRACE_FRAMES (default 60) frames
set -e
M=$(cd "$1" && pwd); HERE=$(cd "$(dirname "$0")" && pwd)
cd "$M"
grep -q isFx3 Core/SNES/Coprocessors/GSU/Gsu.h || { echo "$M: not a MesenCE source tree"; exit 1; }
P="$HERE/../mesence-doomfx.patch"
git apply --check "$P" 2>/dev/null && git apply "$P" || echo "(patch already applied?)"
make -j"$(nproc)" core
clang++ -O2 -fPIC --std=c++17 -I . -I Core -I Utilities -c "$HERE/mesenrun.cpp" -o "$HERE/mesenrun.o"
clang++ -flto=thin -O3 -fuse-ld=lld -o "$HERE/mesenrun" "$HERE/mesenrun.o" $(find Core Utilities -name '*.o') $(find Lua SevenZip -name '*.o') -pthread
echo "built $HERE/mesenrun"
