@echo off
rem  Build Scottimizer.exe from the current source.
rem  Needs internet once (downloads the free ps2exe module).
echo Building Scottimizer.exe ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-EXE.ps1"
echo.
if exist "%~dp0Scottimizer.exe" (echo Done: Scottimizer.exe is in this folder.) else (echo Build failed - see messages above.)
pause
