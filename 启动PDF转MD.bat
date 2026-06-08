@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: PDF to Markdown Launcher (MinerU)
:: Drag PDF file onto this bat icon, or double-click to run

title PDF -^> Markdown (MinerU)

cd /d "%~dp0"
set "PYTHON=%~dp0..\mineru-env\Scripts\python.exe"
set "OUTPUT_BASE=%~dp0output"
set "LOG_FILE=%~dp0mineru.log"

set "MINERU_LOG_LEVEL=WARNING"
set "NO_COLOR=1"
set "FORCE_COLOR=0"
set "BACKEND=pipeline"
set "LANG=ch"

if not exist "%PYTHON%" (
    echo [ERROR] MinerU not found: %PYTHON%
    pause
    exit /b 1
)

cls
echo.
echo ==============================================
echo   PDF to Markdown - MinerU
echo ==============================================
echo.

set "PDF_PATH=%~1"

if not "!PDF_PATH!"=="" goto :fix_path

:ask_path
echo Drag PDF file here and press Enter:
echo.
set /p "PDF_PATH=^> "

:fix_path
if "!PDF_PATH!"=="" (
    echo No file path entered. Exiting.
    pause
    exit /b 1
)

set "PDF_PATH=!PDF_PATH:"=!"
for /f "tokens=*" %%a in ("!PDF_PATH!") do set "PDF_PATH=%%a"

:: Convert Unix /c/xxx to Windows C:\xxx
set "TMP=!PDF_PATH!"
if "!TMP:~0,2!"=="/c" set "PDF_PATH=C:!TMP:~2!"
if "!TMP:~0,2!"=="/d" set "PDF_PATH=D:!TMP:~2!"
if "!TMP:~0,2!"=="/e" set "PDF_PATH=E:!TMP:~2!"
set "PDF_PATH=!PDF_PATH:/=\!"

if not exist "!PDF_PATH!" (
    echo.
    echo [ERROR] File not found:
    echo   !PDF_PATH!
    pause
    exit /b 1
)

for %%f in ("!PDF_PATH!") do set "PDF_NAME=%%~nf"
set "OUTPUT_DIR=!OUTPUT_BASE!\!PDF_NAME!"
if not exist "!OUTPUT_DIR!" mkdir "!OUTPUT_DIR!"

echo.
echo   File  : !PDF_NAME!.pdf
echo   Output: PDF2MD\output\!PDF_NAME!\
echo.
echo   Converting... Please wait.
echo.

echo --- %date% %time% --- > "%LOG_FILE%"
"%PYTHON%" -c "from mineru.cli.client import main; main()" -p "!PDF_PATH!" -o "!OUTPUT_DIR!" -m auto -b "!BACKEND!" -l "!LANG!" -f true -t true --image-analysis true >> "%LOG_FILE%" 2>&1

set "EXIT_CODE=!ERRORLEVEL!"

echo.
if !EXIT_CODE! equ 0 (
    echo ==============================================
    echo   [OK] Conversion completed!
    echo ==============================================
    echo.
    echo   MD file: output\!PDF_NAME!\!PDF_NAME!\auto\!PDF_NAME!.md
    echo.
    start "" "!OUTPUT_DIR!"
    echo   Output folder opened.
) else (
    echo ==============================================
    echo   [FAIL] Conversion error (code: !EXIT_CODE!)
    echo ==============================================
    echo.
    echo   Check log: mineru.log
)

echo.
echo Press any key to close...
pause >nul
