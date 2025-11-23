@echo off
REM License Generator Tool
REM Run this batch file to generate licenses

cd /d "%~dp0"
dart run license_generator.dart

pause
