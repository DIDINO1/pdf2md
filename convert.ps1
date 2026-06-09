# Document to Markdown Converter (MinerU)
# Supports: PDF, DOCX, PPTX, XLSX, PNG, JPG, BMP, TIFF, WebP
param(
    [string]$InputPath = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspace = Split-Path -Parent $scriptDir
$python = Join-Path $workspace "mineru-env\Scripts\python.exe"
$outputBase = Join-Path $scriptDir "output"
$logFile = Join-Path $scriptDir "mineru.log"
$backend = "pipeline"
$lang = "ch"

$env:MINERU_LOG_LEVEL = "WARNING"
$env:NO_COLOR = "1"
$env:FORCE_COLOR = "0"

$supportedExts = @(".pdf", ".docx", ".pptx", ".xlsx", ".png", ".jpg", ".jpeg", ".bmp", ".tiff", ".tif", ".gif", ".webp")

if (-not (Test-Path $python)) {
    Write-Host "[ERROR] MinerU not found: $python" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Clear-Host
Write-Host ""
Write-Host "=============================================="
Write-Host "  Document -> Markdown (MinerU)"
Write-Host "  PDF | DOCX | PPTX | XLSX | Images"
Write-Host "=============================================="
Write-Host ""

# Get input path
if ($InputPath -eq "") {
    $InputPath = Read-Host "Drag file/folder here and press Enter"
}

if ($InputPath -eq "") {
    Write-Host "No path entered. Exiting."
    Read-Host "Press Enter to exit"
    exit 1
}

# Strip quotes and convert Unix path to Windows
$InputPath = $InputPath.Trim('"').Trim()
if ($InputPath -match '^/([a-zA-Z])/(.*)') {
    $InputPath = "$($Matches[1].ToUpper()):\$($Matches[2])"
}
$InputPath = $InputPath.Replace('/', '\')

if (-not (Test-Path $InputPath)) {
    Write-Host "[ERROR] Path not found: $InputPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# ---- Convert single file ----
function Convert-File {
    param($FilePath, $OutputDir)
    $stem = [IO.Path]::GetFileNameWithoutExtension($FilePath)
    $dir = Join-Path $OutputDir $stem
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Host "  $stem"
    $mineruArgs = @("-c", "from mineru.cli.client import main; main()",
              "-p", $FilePath, "-o", $OutputDir,
              "-m", "auto", "-b", $backend, "-l", $lang,
              "-f", "true", "-t", "true", "--image-analysis", "true")
    & $python $mineruArgs 2>&1 | Out-File $logFile -Append -Encoding utf8
    return $LASTEXITCODE
}

# ---- Main logic ----
if (Test-Path $InputPath -PathType Container) {
    # Folder mode
    $folderName = Split-Path $InputPath -Leaf
    Write-Host "Scanning folder: $folderName"
    Write-Host ""

    $files = Get-ChildItem -Path $InputPath -Recurse -File |
        Where-Object { $supportedExts -contains $_.Extension.ToLower() } |
        ForEach-Object { $_.FullName }

    $total = @($files).Count
    if ($total -eq 0) {
        Write-Host "No supported files found." -ForegroundColor Yellow
        Write-Host "Supported: $($supportedExts -join ', ')"
        Read-Host "Press Enter to exit"
        exit 0
    }

    Write-Host "Found $total file(s). Converting..."
    Write-Host "(log: mineru.log)"
    Write-Host ""

    "" | Out-File $logFile
    $count = 0
    $failed = 0

    foreach ($f in $files) {
        $count++
        $relPath = $f.Substring($InputPath.Length).TrimStart('\')
        $relDir = Split-Path $relPath -Parent

        if ($relDir) {
            $outDir = Join-Path $outputBase $folderName $relDir
        } else {
            $outDir = Join-Path $outputBase $folderName
        }

        Write-Host -NoNewline "[$count/$total] "
        Convert-File -FilePath $f -OutputDir $outDir
        if ($LASTEXITCODE -ne 0) {
            $failed++
            Write-Host "  [FAIL] - see mineru.log" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "=============================================="
    Write-Host "  Done! $($total - $failed)/$total converted."
    if ($failed -gt 0) {
        Write-Host "  $failed failed - check mineru.log" -ForegroundColor Red
    }
    Write-Host "=============================================="

} else {
    # Single file mode
    $stem = [IO.Path]::GetFileNameWithoutExtension($InputPath)
    Write-Host "File: $(Split-Path $InputPath -Leaf)"
    Write-Host "Output: output\$stem\"
    Write-Host ""
    Write-Host "Converting..."
    Write-Host ""

    "" | Out-File $logFile
    $exitCode = Convert-File -FilePath $InputPath -OutputDir $outputBase

    Write-Host ""
    Write-Host "=============================================="
    if ($exitCode -eq 0) {
        Write-Host "  [OK] Conversion completed!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Error code: $exitCode" -ForegroundColor Red
    }
    Write-Host "=============================================="
}

Write-Host ""
Write-Host "Output: $outputBase"

# Open output folder
Start-Process explorer.exe -ArgumentList $outputBase

Write-Host ""
Read-Host "Press Enter to close"
