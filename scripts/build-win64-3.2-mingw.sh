#!/usr/bin/env bash
# Cross-compile MSPhysics msp_lib.so for SketchUp 2024-2026 (Ruby 3.2.2, Win x64)
# using MinGW-w64 on Linux. This is a fallback path: the supported build is
# GitHub Actions windows-2022 + MSVC (see .github/workflows/build.yml).
# Mirrors Projects/VS/*.vcxproj Release (3.2)|x64 configs:
#   C++17, /MD equivalent, _WIN32_WINNT 0x0A00, RUBY_VERSION32.
# Outputs (all under build/mingw-win64-3.2/):
#   newton.dll (+ libnewton.dll.a import lib), msp_lib.so (PE32+ DLL)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/mingw-win64-3.2"
mkdir -p "$BUILD/obj"
# Toolchain: prefer the persistent copy extracted from the apt cache into
# ~/workspace/mingw-w64 (survives VM resets; /usr/bin does not). Fall back
# to a system-installed MinGW if present. Override with MINGW_PREFIX.
if [ -x "$HOME/workspace/mingw-w64/usr/bin/x86_64-w64-mingw32-g++" ]; then
  MINGW_PREFIX="${MINGW_PREFIX:-$HOME/workspace/mingw-w64/usr}"
elif command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1; then
  MINGW_PREFIX="${MINGW_PREFIX:-/usr}"
else
  echo "ERROR: no MinGW-w64 toolchain. Install g++-mingw-w64-x86-64, or extract" >&2
  echo "the cached .debs into ~/workspace/mingw-w64 (see PORTING.md)." >&2
  exit 1
fi
CXX="$MINGW_PREFIX/bin/x86_64-w64-mingw32-g++"
AR="$MINGW_PREFIX/bin/x86_64-w64-mingw32-ar"
OBJDUMP="$MINGW_PREFIX/bin/x86_64-w64-mingw32-objdump"
TP="$ROOT/C++Extension/ThirdParty"
SRC="$ROOT/C++Extension/Source"

CXXFLAGS="-std=c++17 -O2 -DWIN32 -DNDEBUG -D_CRT_SECURE_NO_WARNINGS \
  -D_WIN32_WINNT=0x0A00 -D_WIN_64_VER -m64 -msse3 -mfpmath=sse -fpermissive"
# NOTE: do NOT define _MSC_VER for MinGW. It was tried and breaks MinGW's
# own headers (unknwnbase.h/servprov.h parse errors, EM_* macros missing
# from MinGW float.h). Instead, the few Newton sources that gate Windows
# branches on _MSC_VER carry targeted `|| defined(__MINGW32__)` patches
# (see PORTING.md "MinGW 交叉编译" and the patches in ThirdParty/).
# NOTE: -fpermissive is a MinGW tolerance knob for MSVC-era code; if the
# build passes without it, drop it (see build log).

if [ ! -f "$BUILD/libdMath.a" ]; then
echo "== dMath (static) =="
$CXX $CXXFLAGS -I"$TP/NewtonDynamics/dMath" -c \
  "$TP"/NewtonDynamics/dMath/*.cpp -o /dev/null 2>/dev/null || true
# compile one by one (glob in -c is not allowed)
rm -f "$BUILD"/obj/dmath_*.o
i=0; for f in "$TP"/NewtonDynamics/dMath/*.cpp; do
  $CXX $CXXFLAGS -I"$TP/NewtonDynamics/dMath" -c "$f" -o "$BUILD/obj/dmath_$i.o"; i=$((i+1))
done
$AR rcs "$BUILD/libdMath.a" "$BUILD"/obj/dmath_*.o
fi

if [ ! -f "$BUILD/libdgCore.a" ]; then
echo "== dgCore (static) =="
rm -f "$BUILD"/obj/dgcore_*.o
i=0; for f in "$TP"/NewtonDynamics/dgCore/*.cpp; do
  $CXX $CXXFLAGS -I"$TP/NewtonDynamics/dgCore" -I"$TP/NewtonDynamics/dMath" \
    -c "$f" -o "$BUILD/obj/dgcore_$i.o"; i=$((i+1))
done
$AR rcs "$BUILD/libdgCore.a" "$BUILD"/obj/dgcore_*.o
fi

if [ ! -f "$BUILD/libdgPhysics.a" ]; then
echo "== dgPhysics (static) =="
rm -f "$BUILD"/obj/dgphys_*.o
i=0; for f in "$TP"/NewtonDynamics/dgPhysics/*.cpp "$TP"/NewtonDynamics/dgMeshUtil/*.cpp; do
  $CXX $CXXFLAGS -I"$TP/NewtonDynamics/dgCore" -I"$TP/NewtonDynamics/dgPhysics" \
    -I"$TP/NewtonDynamics/dgMeshUtil" -I"$TP/NewtonDynamics/dMath" \
    -c "$f" -o "$BUILD/obj/dgphys_$i.o"; i=$((i+1))
done
$AR rcs "$BUILD/libdgPhysics.a" "$BUILD"/obj/dgphys_*.o
fi

echo "== newton.dll =="
# -static-libgcc -static-libstdc++: the .so/.dll must load inside SketchUp,
# which does not ship MinGW runtime DLLs, and Windows does not search the
# extension's own folder for dependencies. Static linking makes both DLLs
# self-contained. (Newton's API is C-only; no std:: objects cross the
# newton.dll boundary, so separate static runtimes are safe here.)
$CXX $CXXFLAGS -static-libgcc -static-libstdc++ -D_USRDLL -D_NEWTON_BUILD_DLL \
  -I"$TP/NewtonDynamics/dgNewton" -I"$TP/NewtonDynamics/dgCore" \
  -I"$TP/NewtonDynamics/dgPhysics" -I"$TP/NewtonDynamics/dgMeshUtil" \
  -I"$TP/NewtonDynamics/dMath" \
  -shared "$TP/NewtonDynamics/dgNewton/Newton.cpp" \
          "$TP/NewtonDynamics/dgNewton/NewtonClass.cpp" \
  -Wl,--start-group "$BUILD/libdgPhysics.a" "$BUILD/libdgCore.a" \
  "$BUILD/libdMath.a" -Wl,--end-group \
  -Wl,--out-implib,"$BUILD/libnewton.dll.a" -o "$BUILD/newton.dll"

echo "== msp_lib.so =="
MSP_DEFS="-D_USRDLL -DRUBY_VERSION32"
MSP_INC="-I$TP/Ruby/include/3.2/win32_x64 \
  -I$TP/NewtonDynamics/dgNewton -I$TP/NewtonDynamics/dMath \
  -I$TP/SDL2/include -I$TP/SDL2_mixer/include \
  -I$SRC/main -I$SRC/win"
$CXX $CXXFLAGS -static-libgcc -static-libstdc++ $MSP_DEFS $MSP_INC \
  -shared "$SRC"/main/*.cpp "$SRC/win/msp_lib.cpp" \
  "$BUILD/libnewton.dll.a" "$BUILD/libdMath.a" \
  "$TP/Ruby/lib/win32/x64-ucrt-ruby320.lib" \
  "$TP/SDL2/lib/x64/SDL2.lib" "$TP/SDL2_mixer/lib/x64/SDL2_mixer.lib" \
  -o "$BUILD/msp_lib.so"

echo "== checks =="
file "$BUILD/msp_lib.so" "$BUILD/newton.dll"
"$OBJDUMP" -p "$BUILD/msp_lib.so" | grep -i "Init_msp_lib" \
  && echo "OK: Init_msp_lib exported"
echo "BUILD OK: $BUILD/msp_lib.so"
