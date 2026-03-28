@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo  Inventory Management System — Build ^& Package
echo ============================================================
echo.

:: ── Locate project root (one level up from installer\) ──────
set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
cd /d "%PROJECT_DIR%"

:: ── 1. Flutter release build ─────────────────────────────────
echo [1/3] Building Flutter release for Windows...
flutter build windows --release
if errorlevel 1 (
    echo.
    echo ERROR: Flutter build failed. Aborting.
    pause
    exit /b 1
)
echo       Build OK.
echo.

:: ── 2. Locate Inno Setup compiler ────────────────────────────
echo [2/3] Locating Inno Setup compiler...
set ISCC=
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set ISCC=C:\Program Files\Inno Setup 6\ISCC.exe
) else (
    echo ERROR: Inno Setup 6 not found.
    echo Download from: https://jrsoftware.org/isdl.php
    pause
    exit /b 1
)
echo       Found: !ISCC!
echo.

:: ── 3. Compile installer ─────────────────────────────────────
echo [3/3] Compiling installer...
if not exist "%SCRIPT_DIR%Output" mkdir "%SCRIPT_DIR%Output"
"!ISCC!" "%SCRIPT_DIR%inventory_setup.iss"
if errorlevel 1 (
    echo.
    echo ERROR: Inno Setup compilation failed.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  SUCCESS!
echo  Installer saved to:
echo  %SCRIPT_DIR%Output\
echo ============================================================
echo.
explorer "%SCRIPT_DIR%Output"
pause
