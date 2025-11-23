@echo off
REM Build script for Inventory Management System
REM This script builds the Windows release version

echo ============================================
echo   Inventory Management System - Build
echo ============================================
echo.

echo Cleaning previous builds...
flutter clean

echo.
echo Getting dependencies...
flutter pub get

echo.
echo Running build...
flutter build windows --release

echo.
echo ============================================
echo Build Complete!
echo ============================================
echo.
echo Output location: build\windows\x64\runner\Release\
echo.
echo Next steps:
echo 1. Test the executable in build\windows\x64\runner\Release\inventory.exe
echo 2. Create installer using NSIS (run create_installer.bat)
echo.

pause
