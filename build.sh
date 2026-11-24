#!/bin/sh
# build.sh - dashboard for MSYS2 UCRT64 (x86_64-w64-mingw32 toolchain)
# Run from the repo root inside the "MSYS2 UCRT64" shell:  ./build.sh
set -e

CXX=${CXX:-x86_64-w64-mingw32-g++}
FXC=${FXC:-fxc}          # ships with the Windows SDK; on PATH in a dev shell.
                        # Fallback if not on PATH:
if ! command -v "$FXC" >/dev/null 2>&1; then
    FXC="/c/Program Files (x86)/Windows Kits/10/bin/x64/fxc.exe"
fi

mkdir -p build

# ---- 1. shaders -> byte-code C headers (debug info only in Debug builds) ----
D=-Od
case "${1:-release}" in
    debug) D=-Zi ;;
esac

"$FXC" /nologo $D /T vs_5_0 /E VSFullscreen /Fh build/vs_fullscreen.h src/shaders/dashboard.hlsli
"$FXC" /nologo $D /T ps_5_0 /E PSBackground /Fh build/ps_background.h src/shaders/background.hlsl
"$FXC" /nologo $D /T ps_5_0 /E PSPanels     /Fh build/ps_panels.h     src/shaders/panels.hlsl
"$FXC" /nologo $D /T ps_5_0 /E PSWidgets    /Fh build/ps_widgets.h    src/shaders/widgets.hlsl
"$FXC" /nologo $D /T ps_5_0 /E PSText       /Fh build/ps_text.h       src/shaders/text.hlsl

# ---- 2. app -------------------------------------------------------------
"$CXX" -std=c++20 -O2 -DNDEBUG -mwindows \
    -Ibuild -Isrc \
    src/dashboard.cpp \
    -o build/dashboard.exe \
    -ld3d11 -ldxgi -ld3dcompiler \
    -lpdh -liphlpapi -lpsapi -luser32 -lgdi32 -lkernel32 -lwinmm

echo "OK -> build/dashboard.exe"
