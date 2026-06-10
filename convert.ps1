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

function Wait-Exit {
    Write-Host ""
    Read-Host "Press Enter to close"
    exit
}

function Invoke-MinerU {
    param($SourcePath, $OutputDir)

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Build argument string with proper quoting for paths with CJK/special chars
    $escapedSource = $SourcePath -replace '"', '""'
    $escapedOutput = $OutputDir -replace '"', '""'
    $allArgs = "-c ""from mineru.cli.client import main; main()"" -p ""$escapedSource"" -o ""$escapedOutput"" -m auto -b $backend -l $lang -f true -t true --image-analysis true"

    Add-Content -Path $logFile -Value "" -Encoding utf8
    Add-Content -Path $logFile -Value "--- $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---" -Encoding utf8
    Add-Content -Path $logFile -Value "Source: $SourcePath" -Encoding utf8
    Add-Content -Path $logFile -Value "Output: $OutputDir" -Encoding utf8

    $proc = Start-Process -FilePath $python -ArgumentList $allArgs `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput "$env:TEMP\mineru_out.tmp" `
        -RedirectStandardError "$env:TEMP\mineru_err.tmp"

    Get-Content "$env:TEMP\mineru_out.tmp" -ErrorAction SilentlyContinue | Add-Content -Path $logFile -Encoding utf8
    Get-Content "$env:TEMP\mineru_err.tmp" -ErrorAction SilentlyContinue | Add-Content -Path $logFile -Encoding utf8
    Remove-Item "$env:TEMP\mineru_out.tmp", "$env:TEMP\mineru_err.tmp" -ErrorAction SilentlyContinue

    Add-Content -Path $logFile -Value "Exit code: $($proc.ExitCode)" -Encoding utf8
    return $proc.ExitCode
}

# ---- MAIN ----
try {
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

    if ($InputPath -eq "") {
        $InputPath = Read-Host "Drag file/folder here and press Enter"
    }
    if ($InputPath -eq "") {
        Write-Host "No path entered."
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

    "" | Out-File $logFile -Encoding utf8

    if (Test-Path $InputPath -PathType Container) {
        # ============ FOLDER MODE ============
        $folderName = Split-Path $InputPath -Leaf
        Write-Host "Scanning: $folderName"

        $allFiles = @(Get-ChildItem -LiteralPath $InputPath -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -and ($supportedExts -contains $_.Extension.ToLower()) })

        if ($allFiles.Count -eq 0) {
            Write-Host "No supported files found." -ForegroundColor Yellow
            Write-Host "Supported: PDF, DOCX, PPTX, XLSX, images"
            Wait-Exit
        }

        # Group files by parent directory (one MinerU call per directory)
        $groups = $allFiles | Group-Object DirectoryName
        $totalDirs = @($groups).Count
        $totalFiles = $allFiles.Count

        Write-Host "Found $totalFiles file(s) in $totalDirs folder(s)."
        Write-Host "Converting..."
        Write-Host "(log: logs/mineru_$logStamp.log)"
        Write-Host ""

        $dirNum = 0
        $failedFiles = 0

        foreach ($group in $groups) {
            $dirNum++
            $dirPath = $group.Name
            $dirCount = $group.Count
            $dirName = if ($dirPath -eq $InputPath) { "(root)" } else { $dirPath.Substring($InputPath.Length).TrimStart('\') }

            Write-Host -NoNewline "[$dirNum/$totalDirs] $dirName ($dirCount files) ... "

            # Output directory preserves sub-folder structure
            if ($dirPath -eq $InputPath) {
                $outDir = Join-Path $outputBase $folderName
            } else {
                $relDir = $dirPath.Substring($InputPath.Length).TrimStart('\')
                $outDir = Join-Path (Join-Path $outputBase $folderName) $relDir
            }

            $ec = Invoke-MinerU -SourcePath $dirPath -OutputDir $outDir
            if ($ec -eq 0) {
                Write-Host "OK" -ForegroundColor Green
            } else {
                Write-Host "FAILED ($dirCount files)" -ForegroundColor Red
                $failedFiles += $dirCount
            }
        }

        Write-Host ""
        Write-Host "=============================================="
        $ok = $totalFiles - $failedFiles
        if ($failedFiles -eq 0) {
            Write-Host "  All $ok file(s) converted!" -ForegroundColor Green
        } else {
            Write-Host "  Done! $ok / $totalFiles converted" -ForegroundColor Yellow
            Write-Host "  $failedFiles failed - see logs/mineru_$logStamp.log" -ForegroundColor Red
        }
        Write-Host "=============================================="

    } else {
        # ============ SINGLE FILE MODE ============
        $stem = [IO.Path]::GetFileNameWithoutExtension($InputPath)
        $fileName = Split-Path $InputPath -Leaf

        Write-Host "File  : $fileName"
        Write-Host "Output: output\$stem\"
        Write-Host ""
        Write-Host "Converting..."
        Write-Host ""

        $exitCode = Invoke-MinerU -SourcePath $InputPath -OutputDir $outputBase

        Write-Host ""
        Write-Host "=============================================="
        if ($exitCode -eq 0) {
            Write-Host "  [OK] Conversion completed!" -ForegroundColor Green
            Write-Host "  output\$stem\$stem\auto\$stem.md"
        } else {
            Write-Host "  [FAILED] Error code: $exitCode" -ForegroundColor Red
            Write-Host "  Check logs/mineru_$logStamp.log"
        }
        Write-Host "=============================================="
    }

    Write-Host ""
    Start-Process explorer.exe -ArgumentList $outputBase
    Write-Host "(Output folder opened)"

} catch {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "  UNEXPECTED ERROR" -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
}

Wait-Exit
