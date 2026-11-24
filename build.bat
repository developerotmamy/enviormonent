@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  build.bat - compiles the entire DX11 dashboard into an .exe
REM  Target:   MSYS2 UCRT64 (x86_64-w64-mingw32-g++) + Windows SDK fxc.exe
REM  Usage:    build.bat            (release build)
REM            build.bat debug      (debug build, -Zi / -Od)
REM ============================================================

cd /d "%~dp0"

set "CFG=Release"
set "CXXFLAGS=-O2 -DNDEBUG"
set "FXCFLAGS=/O2"
if /I "%~1"=="debug" (
    set "CFG=Debug"
    set "CXXFLAGS=-O0 -g -DDEBUG"
    set "FXCFLAGS=/Zi /Od"
)

set "CXX=x86_64-w64-mingw32-g++"
set "OUT_DIR=build"
set "EXE=%OUT_DIR%\dashboard.exe"
set "SRC_DIR=src"
set "SHADER_DIR=%SRC_DIR%\shaders"

echo ============================================================
echo  Dashboard build [!CFG!]  (MSYS2 UCRT64 / DirectX 11)
echo ============================================================

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

REM ------------------------------------------------------------
REM 0. Locate toolchain
REM ------------------------------------------------------------
where %CXX% >nul 2>nul
if errorlevel 1 (
    echo ERROR: %CXX% not found on PATH.
    echo        Run this from the "MSYS2 UCRT64" shell environment, or install:
    echo        pacman -S mingw-w64-ucrt-x86_64-gcc
    exit /b 1
)

REM Locate fxc.exe (Windows SDK). Try PATH first, then known SDK locations.
set "FXC="
where fxc.exe >nul 2>nul && set "FXC=fxc.exe"
if not defined FXC (
    for %%V in (11 10) do (
        if not defined FXC (
            for /d %%P in ("C:\Program Files (x86)\Windows Kits\%%V\bin\10.*") do (
                if exist "%%P\x64\fxc.exe" set "FXC=%%P\x64\fxc.exe"
            )
            if exist "C:\Program Files (x86)\Windows Kits\%%V\bin\x64\fxc.exe" set "FXC=C:\Program Files (x86)\Windows Kits\%%V\bin\x64\fxc.exe"
        )
    )
)
if not defined FXC (
    echo ERROR: fxc.exe not found on PATH or in the Windows SDK directories.
    exit /b 1
)
echo Using compiler : %CXX%
echo Using shader c : !FXC!

REM ------------------------------------------------------------
REM 1. Compile HLSL shaders to byte-code C++ headers (fxc /Fh)
REM    Each entry point lives in its own .hlsl; dashboard.hlsli is
REM    shared and pulled in by the preprocessor automatically.
REM ------------------------------------------------------------
echo.
echo [1/3] Compiling shaders...

"!FXC!" /nologo %FXCFLAGS% /T vs_5_0 /E VSFullscreen /Fh "%OUT_DIR%\vs_fullscreen.h" "%SHADER_DIR%\dashboard.hlsli"
if errorlevel 1 goto :shader_fail

"!FXC!" /nologo %FXCFLAGS% /T ps_5_0 /E PSBackground /Fh "%OUT_DIR%\ps_background.h" "%SHADER_DIR%\background.hlsl"
if errorlevel 1 goto :shader_fail

"!FXC!" /nologo %FXCFLAGS% /T ps_5_0 /E PSPanels /Fh "%OUT_DIR%\ps_panels.h" "%SHADER_DIR%\panels.hlsl"
if errorlevel 1 goto :shader_fail

"!FXC!" /nologo %FXCFLAGS% /T ps_5_0 /E PSWidgets /Fh "%OUT_DIR%\ps_widgets.h" "%SHADER_DIR%\widgets.hlsl"
if errorlevel 1 goto :shader_fail

"!FXC!" /nologo %FXCFLAGS% /T ps_5_0 /E PSText /Fh "%OUT_DIR%\ps_text.h" "%SHADER_DIR%\text.hlsl"
if errorlevel 1 goto :shader_fail

echo       shaders OK

REM ------------------------------------------------------------
REM 2. Compile + link the host application
REM ------------------------------------------------------------
echo.
echo [2/3] Compiling C++ sources...

%CXX% -std=c++20 !CXXFLAGS! -Wall -Wextra ^
    -I"%OUT_DIR%" -I"%SRC_DIR%" ^
    "%SRC_DIR%\dashboard.cpp" ^
    -o "%EXE%" ^
    -mwindows ^
    -ld3d11 -ldxgi -ld3dcompiler ^
    -lpdh -liphlpapi -lpsapi ^
    -luser32 -lgdi32 -lkernel32 -lwinmm ^
    -static-libgcc -static-libstdc++
if errorlevel 1 (
    echo.
    echo ERROR: C++ compilation/link failed.
    exit /b 1
)
echo       link OK

REM ------------------------------------------------------------
REM 3. Done
REM ------------------------------------------------------------
echo.
echo [3/3] Build complete: %EXE%
echo.
pause
exit /b 0

:shader_fail
echo.
echo ERROR: Shader compilation failed.
exit /b 1
