#!/bin/bash
# build.sh ARES_DIR : build the headless ares runner (main.cpp -> build-headless/headless/ares-headless)
# in an ares source tree (github.com/ares-emulator/ares) for speed/compatibility tests of the 2 MB
# ROMs (make shareware, make demo).  ares maps a Super FX ROM of at most 2 MB ($00-$3F/$40-$5F),
# so the 4 MB builds do not run in it.  Applies ares-probes.patch (probe hooks, no timing change)
# and leaves the GUI (ruby, hiro, desktop-ui) out of the build.
set -e
A=$(cd "$1" && pwd); HERE=$(cd "$(dirname "$0")" && pwd)
cd "$A"
git apply --check "$HERE/ares-probes.patch" 2>/dev/null && git apply "$HERE/ares-probes.patch" || echo "(patch already applied?)"
mkdir -p headless && cp "$HERE/main.cpp" "$HERE/CMakeLists.txt" headless/
sed -e '/add_subdirectory(ruby)/d' -e '/add_subdirectory(hiro)/d' -e 's/add_subdirectory(desktop-ui)/add_subdirectory(headless)/' \
    -e '/add_subdirectory(.github)/d' CMakeLists.txt > CMakeLists.headless.txt
cp CMakeLists.txt CMakeLists.gui.txt; cp CMakeLists.headless.txt CMakeLists.txt
cmake -S . -B build-headless -G Ninja -DARES_CORES=sfc -DARES_SKIP_DEPS=ON -DENABLE_CCACHE=OFF -DENABLE_IPO=OFF \
      -DARES_ENABLE_CHD=OFF -DCMAKE_BUILD_TYPE=Release -Wno-dev
ninja -C build-headless ares-headless
cp CMakeLists.gui.txt CMakeLists.txt
mkdir -p build-headless/headless/Database && cp mia/Database/* build-headless/headless/Database/
echo "built $A/build-headless/headless/ares-headless"
