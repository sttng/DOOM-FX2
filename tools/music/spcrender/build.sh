#!/bin/sh
# build.sh [GME_SOURCE] -- build tools/music/spcrender/spcrender from libgme's SPC emulator
# (git clone https://github.com/libgme/game-music-emu; default: game-music-emu; a relative
# GME_SOURCE is taken from tools/music/spcrender/, where the script runs)
set -e
cd "$(dirname "$0")"
G=${1:-game-music-emu}/gme
c++ -O2 -std=c++11 -DBLARGG_LITTLE_ENDIAN=1 -I"$G" -o spcrender spcrender.cpp \
    "$G/Snes_Spc.cpp" "$G/Spc_Cpu.cpp" "$G/Spc_Dsp.cpp"
echo "built $(pwd)/spcrender"
