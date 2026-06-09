@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
::  Document to Markdown Launcher (MinerU)
::  Supports: PDF, DOCX, PPTX, XLSX, PNG, JPG, BMP, TIFF ...
::  - Drag a file/folder onto this bat icon -> auto convert
::  - Double-click -> enter path -> auto convert
:: ============================================================

title Document -^> Markdown (MinerU)

cd /d "%~dp0"
set "PYTHON=%~dp0..\mineru-env\Scripts\python.exe"
set "OUTPUT_BASE=%~dp0output"
set "LOG_FILE=%~dp0mineru.log"
set "FILELIST=%TEMP%\mineru_filelist.txt"

set "MINERU_LOG_LEVEL=WARNING"
set "NO_COLOR=1"
set "FORCE_COLOR=0"
set "BACKEND=pipeline"
set "LANG=ch"
set "SUPPORTED_EXT=.pdf .docx .pptx .xlsx .png .jpg .jpeg .bmp .tiff .tif .gif .webp"

if not exist "%PYTHON%" (
    echo [ERROR] MinerU not found: %PYTHON%
    pause
    exit /b 1
)

cls
echo.
echo ==============================================
echo   Document -^> Markdown (MinerU)
echo   PDF ^| DOCX ^| PPTX ^| XLSX ^| Images
echo ==============================================
echo.

:: ---- Get input path ----
set "INPUT_PATH=%~1"

:: Convert Unix /c/xxx to Windows C:\xxx
set "TMP=!INPUT_PATH!"
if "!TMP:~0,2!"=="/c" set "INPUT_PATH=C:!TMP:~2!"
if "!TMP:~0,2!"=="/d" set "INPUT_PATH=D:!TMP:~2!"
if "!TMP:~0,2!"=="/e" set "INPUT_PATH=E:!TMP:~2!"
set "INPUT_PATH=!INPUT_PATH:/=\!"

if not "!INPUT_PATH!"=="" goto :check_input

:ask_path
echo Drag a file or folder here, then press Enter:
echo.
set /p "INPUT_PATH=^> "

:: Convert Unix /c/xxx to Windows C:\xxx
set "TMP=!INPUT_PATH!"
if "!TMP:~0,2!"=="/c" set "INPUT_PATH=C:!TMP:~2!"
if "!TMP:~0,2!"=="/d" set "INPUT_PATH=D:!TMP:~2!"
if "!TMP:~0,2!"=="/e" set "INPUT_PATH=E:!TMP:~2!"
set "INPUT_PATH=!INPUT_PATH:/=\!"

:check_input
if "!INPUT_PATH!"=="" (
    echo No path entered. Exiting.
    pause
    exit /b 1
)

:: Strip quotes and trailing backslash
set "INPUT_PATH=!INPUT_PATH:"=!"
for /f "tokens=*" %%a in ("!INPUT_PATH!") do set "INPUT_PATH=%%a"
if "!INPUT_PATH:~-1!"=="\" set "INPUT_PATH=!INPUT_PATH:~0,-1!"

if exist "!INPUT_PATH!\*" (
    set "IS_DIR=1"
    set "SCAN_ROOT=!INPUT_PATH!"
    for %%f in ("!INPUT_PATH!") do set "SCAN_NAME=%%~nxf"
    set "TOTAL=0"
    set "COUNT=0"

    echo.
    echo   Scanning folder: !SCAN_NAME!
    echo.

    :: Find all supported files
    del "!FILELIST!" 2>nul
    for %%e in (pdf docx pptx xlsx png jpg jpeg bmp tiff tif gif webp) do (
        dir /s /b /a-d "!SCAN_ROOT!\*.%%e" 2>nul >> "!FILELIST!"
    )

    :: Count files
    for /f "tokens=*" %%a in ('type "!FILELIST!" 2^>nul ^| find /c /v ""') do set "TOTAL=%%a"

    if "!TOTAL!"=="0" (
        echo   No supported files found in this folder.
        echo   Supported: PDF, DOCX, PPTX, XLSX, images
        pause
        exit /b 1
    )

    echo   Found !TOTAL! file(s) to convert.
    echo.
    echo   Converting...
    echo   (log: mineru.log)
    echo.

    echo --- %date% %time% --- > "%LOG_FILE%"

    for /f "usebackq delims=" %%f in ("!FILELIST!") do (
        set /a COUNT+=1
        set "FULL_PATH=%%f"
        for %%g in ("!FULL_PATH!") do set "FILE_STEM=%%~ng"

        :: Compute relative path from SCAN_ROOT
        set "REL=!FULL_PATH:%SCAN_ROOT%\=!"
        for %%g in ("!REL!") do set "REL_DIR=%%~dpg"
        if not "!REL_DIR!"=="" set "REL_DIR=!REL_DIR:~0,-1!"

        if "!REL_DIR!"=="" (
            set "OUT_DIR=!OUTPUT_BASE!\!SCAN_NAME!"
        ) else (
            set "OUT_DIR=!OUTPUT_BASE!\!SCAN_NAME!\!REL_DIR!"
        )

        if not exist "!OUT_DIR!" mkdir "!OUT_DIR!"

        echo [!COUNT!/!TOTAL!] !FILE_STEM!
        echo [!COUNT!/!TOTAL!] !FILE_STEM! >> "%LOG_FILE%"

        "%PYTHON%" -c "from mineru.cli.client import main; main()" -p "!FULL_PATH!" -o "!OUT_DIR!" -m auto -b "!BACKEND!" -l "!LANG!" -f true -t true --image-analysis true >> "%LOG_FILE%" 2>&1

        if !ERRORLEVEL! neq 0 (
            echo   [FAIL] !FILE_STEM! - see mineru.log
        )
    )

    del "!FILELIST!" 2>nul

) else if exist "!INPUT_PATH!" (

    :: Single file mode
    set "IS_DIR=0"
    for %%f in ("!INPUT_PATH!") do set "FILE_EXT=%%~xf"
    for %%f in ("!INPUT_PATH!") do set "FILE_NAME=%%~nf"

    echo.
    echo   File: !FILE_NAME!!FILE_EXT!
    echo   Output: output\!FILE_NAME!\
    echo.
    echo   Converting...
    echo.

    set "OUT_DIR=!OUTPUT_BASE!\!FILE_NAME!"
    if not exist "!OUT_DIR!" mkdir "!OUT_DIR!"

    echo --- %date% %time% --- > "%LOG_FILE%"
    "%PYTHON%" -c "from mineru.cli.client import main; main()" -p "!INPUT_PATH!" -o "!OUT_DIR!" -m auto -b "!BACKEND!" -l "!LANG!" -f true -t true --image-analysis true >> "%LOG_FILE%" 2>&1

    set "EXIT_CODE=!ERRORLEVEL!"

) else (
    echo.
    echo [ERROR] Path not found:
    echo   !INPUT_PATH!
    pause
    exit /b 1
)

:: ---- Done ----
echo.
echo ==============================================
if "!IS_DIR!"=="1" (
    echo   Done! !COUNT!/!TOTAL! file(s) converted.
) else (
    if !EXIT_CODE! equ 0 (
        echo   [OK] Conversion completed!
    ) else (
        echo   [FAIL] Error code: !EXIT_CODE!
    )
)
echo ==============================================
echo.
echo   Output: !OUTPUT_BASE!
echo.
start "" "!OUTPUT_BASE!"
echo   (output folder opened)

if "!IS_DIR!"=="1" (
    echo.
    echo   Log: mineru.log
)

echo.
echo Press any key to close...
pause >nul
