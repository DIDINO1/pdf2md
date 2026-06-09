@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0convert.ps1" "%~1"
