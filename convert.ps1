# Document to Markdown Converter (MinerU)
# Supports: PDF, DOCX, PPTX, XLSX, PNG, JPG, BMP, TIFF, WebP
param([string]$InputPath = "")

$scriptDir = $PSScriptRoot
$workspace = Split-Path -Parent $scriptDir
$python = Join-Path $workspace "mineru-env\Scripts\python.exe"
$outputBase = Join-Path $scriptDir "output"
$logStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $scriptDir "logs\mineru_$logStamp.log"
$null = New-Item -ItemType Directory -Path (Join-Path $scriptDir "logs") -Force
$backend = "pipeline"
$lang = "ch"

$env:MINERU_LOG_LEVEL = "WARNING"
$env:NO_COLOR = "1"
$env:FORCE_COLOR = "0"

$supportedExts = @(".pdf", ".docx", ".pptx", ".xlsx", ".png", ".jpg", ".jpeg", ".bmp", ".tiff", ".tif", ".gif", ".webp")

# ---- Pause helper (always keeps window open) ----
function Wait-Exit {
    Write-Host ""
    Read-Host "Press Enter to close"
    exit
}

# ---- Convert a single file ----
function Convert-File {
    param($FilePath, $OutputDir)
    $stem = [IO.Path]::GetFileNameWithoutExtension($FilePath)
    Write-Host "  $stem"

    try {
        if (-not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }

        # Run MinerU and log output
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logHeader = [Environment]::NewLine + "--- $timestamp ---" + [Environment]::NewLine + "File: $FilePath" + [Environment]::NewLine
        Add-Content -Path $logFile -Value $logHeader -Encoding utf8

        # Build single argument string (avoids PowerShell array parsing issues)
        $escapedPath = $FilePath -replace '"', '""'
        $escapedOutput = $OutputDir -replace '"', '""'
        $allArgs = "-c ""from mineru.cli.client import main; main()"" -p ""$escapedPath"" -o ""$escapedOutput"" -m auto -b $backend -l $lang -f true -t true --image-analysis true"

        $guid = [Guid]::NewGuid().ToString('N').Substring(0, 8)
        $stdoutTmp = "$env:TEMP\mineru_out_${guid}.tmp"
        $stderrTmp = "$env:TEMP\mineru_err_${guid}.tmp"

        $exitCode = -1
        try {
            $proc = Start-Process -FilePath $python -ArgumentList $allArgs `
                -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput $stdoutTmp `
                -RedirectStandardError $stderrTmp `
                -ErrorAction Stop

            $exitCode = $proc.ExitCode
        }
        catch {
            Write-Host "  [ERR] Failed to launch MinerU: $_" -ForegroundColor Red
        }

        # Collect output
        try { Get-Content $stdoutTmp -ErrorAction Stop | Add-Content -Path $logFile -Encoding utf8 } catch {}
        try { Get-Content $stderrTmp -ErrorAction Stop | Add-Content -Path $logFile -Encoding utf8 } catch {}
        try { Remove-Item $stdoutTmp, $stderrTmp -ErrorAction Stop } catch {}

        "Exit code: $exitCode" | Add-Content -Path $logFile -Encoding utf8
        return $exitCode
    }
    catch {
        Write-Host "  [ERROR] $_" -ForegroundColor Red
        return 1
    }
}

# ---- MAIN ----
try {
    # Check Python
    if (-not (Test-Path $python)) {
        Write-Host "[ERROR] MinerU Python not found:" -ForegroundColor Red
        Write-Host "  $python"
        Wait-Exit
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
        Wait-Exit
    }

    # Clean path
    $InputPath = $InputPath.Trim('"').Trim()
    if ($InputPath -match '^/([a-zA-Z])/(.*)') {
        $InputPath = "$($Matches[1].ToUpper()):\$($Matches[2])"
    }
    $InputPath = $InputPath.Replace('/', '\')

    if (-not (Test-Path $InputPath)) {
        Write-Host "[ERROR] Path not found:" -ForegroundColor Red
        Write-Host "  $InputPath"
        Wait-Exit
    }

    if (Test-Path $InputPath -PathType Container) {
        # ============ FOLDER MODE ============
        $folderName = Split-Path $InputPath -Leaf
        Write-Host "Scanning: $folderName"

        try {
            $files = @(Get-ChildItem -LiteralPath $InputPath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -and ($supportedExts -contains $_.Extension.ToLower()) })
        } catch {
            Write-Host "Scan error: $_" -ForegroundColor Red
            $files = @()
        }

        Write-Host "Found $($files.Count) file(s)."
        if ($files.Count -eq 0) {
            Write-Host "No supported files found." -ForegroundColor Yellow
            Write-Host "Supported: PDF, DOCX, PPTX, XLSX, images"
            Wait-Exit
        }

        Write-Host "Converting... (log: logs/mineru_$logStamp.log)"
        Write-Host ""

        "" | Out-File $logFile -Encoding utf8
        $count = 0
        $failed = 0
        $inputLen = $InputPath.TrimEnd('\').Length

        foreach ($f in $files) {
            $count++
            $fullPath = $f.FullName
            if ($fullPath.Length -gt $inputLen) {
                $relPath = $fullPath.Substring($inputLen).TrimStart('\')
            } else {
                $relPath = Split-Path $fullPath -Leaf
            }
            $relDir = Split-Path $relPath -Parent

            if ($relDir) {
                $outDir = Join-Path $outputBase $folderName $relDir
            } else {
                $outDir = Join-Path $outputBase $folderName
            }

            Write-Host -NoNewline "[$count/$($files.Count)] "
            $ec = Convert-File -FilePath $fullPath -OutputDir $outDir
            if ($ec -ne 0) {
                $failed++
                Write-Host "  [FAILED]" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "=============================================="
        $ok = $files.Count - $failed
        Write-Host "  Done! $ok / $($files.Count) converted"
        if ($failed -gt 0) {
            Write-Host "  $failed failed - see logs/mineru_$logStamp.log" -ForegroundColor Red
        }
        Write-Host "=============================================="

    } else {
        # ============ SINGLE FILE MODE ============
        $stem = [IO.Path]::GetFileNameWithoutExtension($InputPath)
        $fileName = Split-Path $InputPath -Leaf

        Write-Host "File  : $fileName"
        Write-Host "Output: output\$stem\"
        Write-Host ""
        Write-Host "Converting... (log: logs/mineru_$logStamp.log)"
        Write-Host ""

        $exitCode = Convert-File -FilePath $InputPath -OutputDir $outputBase

        Write-Host ""
        Write-Host "=============================================="
        if ($exitCode -eq 0) {
            Write-Host "  [OK] Conversion completed!" -ForegroundColor Green
            Write-Host "  output\$stem\$stem\auto\$stem.md"
        } else {
            Write-Host "  [FAILED] Error code: $exitCode" -ForegroundColor Red
            Write-Host "  Check logs/mineru_$logStamp.log for details"
        }
        Write-Host "=============================================="
    }

    # Open output folder
    Write-Host ""
    Start-Process explorer.exe -ArgumentList $outputBase
    Write-Host "(Output folder opened)"

}
catch {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "  UNEXPECTED ERROR" -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}

# Always keep window open
Wait-Exit
