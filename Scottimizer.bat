@echo off
rem  Launches Scottimizer 2. It asks for Administrator permission itself.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Scottimizer.ps1"
