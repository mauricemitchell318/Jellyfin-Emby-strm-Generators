# Ensure script runs in its own directory
Set-Location $PSScriptRoot

Clear-Host
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "     Jellyfin VOD M3U Parser & STRM Generator        " -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Cyan

# Find the first .m3u file in the current directory
$m3uFile = Get-ChildItem -Filter *.m3u | Select-Object -First 1

if (-not $m3uFile) {
    Write-Host "[ERROR] No .m3u file found in this folder!" -ForegroundColor Red
    Write-Host "Please place your .m3u file in the same folder as this script." -ForegroundColor Yellow
    Pause
    exit
}

Write-Host "[INFO] Found M3U file: $($m3uFile.Name)" -ForegroundColor Green

# Define and create output directory compatible with Jellyfin
$outputDir = Join-Path $PSScriptRoot "VODMovies"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
Write-Host "[INFO] Jellyfin library root ready: VODMovies" -ForegroundColor Green
Write-Host "----------------------------------------------------" -ForegroundColor Cyan
Write-Host "Reading and parsing M3U file..." -ForegroundColor Yellow

# Read file lines efficiently using .NET IO for maximum speed
$lines = [System.IO.File]::ReadAllLines($m3uFile.FullName)
$entries = [System.Collections.Generic.List[PSCustomObject]]::new()

# Parse EXTINF lines and corresponding URLs
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].StartsWith("#EXTINF")) {
        $extinf = $lines[$i]
        $url = if ($i + 1 -lt $lines.Length) { $lines[$i + 1] } else { $null }

        if ($url -and -not $url.StartsWith("#")) {
            $titlePart = ""
            if ($extinf -match ',([^,]+)$') {
                $titlePart = $Matches[1].Trim()
            }

            if ($titlePart) {
                $entries.Add([PSCustomObject]@{
                    RawTitle = $titlePart
                    Url      = $url.Trim()
                })
            }
        }
    }
}

$total = $entries.Count
if ($total -eq 0) {
    Write-Host "[ERROR] No valid movie entries found in the M3U file." -ForegroundColor Red
    Pause
    exit
}

Write-Host "[SUCCESS] Found $total movie entries. Starting generation..." -ForegroundColor Green
Write-Host "----------------------------------------------------" -ForegroundColor Cyan

# Initialize Statistics Counters
$createdCount  = 0
$skippedCount  = 0
$failedCount   = 0

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$current = 0

foreach ($entry in $entries) {
    $current++
    $raw = $entry.RawTitle

    # Remove quality prefixes (e.g., "HD : ", "FHD : ", "SD : ")
    $cleanName = $raw -replace '^(?:[A-Za-z\s]+:\s*)', ''
    
    # Extract Title and 4-digit Year at the end
    if ($cleanName -match '^(.*?)\s+(\d{4})$') {
        $movieName = $Matches[1].Trim()
        $year = $Matches[2]
        $folderName = "$movieName ($year)"
    } else {
        $folderName = $cleanName # Fallback if year isn't detected
    }

    # Clean illegal characters for Windows/Jellyfin compatibility (<, >, :, ", /, \, |, ?, *)
    $folderName = $folderName -replace '[\\/:*?"<>|]', ''
    # Clean up any double spaces that might occur after removing punctuation
    $folderName = ($folderName -replace '\s+', ' ').Trim()

    $movieFolder = Join-Path $outputDir $folderName
    $strmFileName = "$folderName.strm"
    $strmFilePath = Join-Path $movieFolder $strmFileName

    # Calculate live progress and dynamic ETA
    $percent = [math]::Round(($current / $total) * 100, 1)
    $elapsed = $sw.Elapsed.TotalSeconds
    $avgTimePerItem = if ($current -gt 0) { $elapsed / $current } else { 0 }
    $remainingItems = $total - $current
    $etaSeconds = [math]::Round($avgTimePerItem * $remainingItems, 1)

    # Check if file already exists
    if (Test-Path $strmFilePath) {
        $skippedCount++
        Write-Host "[" -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,5}%" -f $percent) -NoNewline -ForegroundColor DarkGray
        Write-Host "] | " -NoNewline -ForegroundColor DarkGray
        Write-Host "[SKIPPED] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$folderName - $strmFileName already exists." -ForegroundColor Gray
        continue
    }

    try {
        # Create movie subfolder only if a new file needs to be created
        if (-not (Test-Path $movieFolder)) {
            New-Item -ItemType Directory -Path $movieFolder | Out-Null
        }

        # Write .strm file
        [System.IO.File]::WriteAllText($strmFilePath, $entry.Url)
        $createdCount++

        # Multi-colored real-time logging for newly processed files
        Write-Host "[" -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,5}%" -f $percent) -NoNewline -ForegroundColor Yellow
        Write-Host "] | Done: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$current/$total" -NoNewline -ForegroundColor Green
        Write-Host " | ETA: " -NoNewline -ForegroundColor DarkGray
        Write-Host "${etaSeconds}s" -NoNewline -ForegroundColor Magenta
        Write-Host " | Processing: " -NoNewline -ForegroundColor DarkGray
        Write-Host $folderName -ForegroundColor Cyan
    }
    catch {
        $failedCount++
        Write-Host "[ERROR] Failed to write $strmFileName : $_" -ForegroundColor Red
    }
}

$sw.Stop()
$totalTime = [math]::Round($sw.Elapsed.TotalSeconds, 2)

# Calculate rates and percentages
$createdPct = [math]::Round(($createdCount / $total) * 100, 1)
$skippedPct = [math]::Round(($skippedCount / $total) * 100, 1)
$failedPct  = [math]::Round(($failedCount / $total) * 100, 1)
$itemsPerSec = if ($totalTime -gt 0) { [math]::Round($total / $totalTime, 1) } else { $total }

Write-Host "----------------------------------------------------" -ForegroundColor Cyan
Write-Host "=== EXECUTION SUMMARY ===" -ForegroundColor Green
Write-Host " Total Entries Parsed : $total" -ForegroundColor White
Write-Host " New STRM Files Created: $createdCount ($createdPct%)" -ForegroundColor Green
Write-Host " Skipped (Already Exist): $skippedCount ($skippedPct%)" -ForegroundColor DarkGray
if ($failedCount -gt 0) {
    Write-Host " Failed Write Errors   : $failedCount ($failedPct%)" -ForegroundColor Red
} else {
    Write-Host " Failed Write Errors   : 0 (0%)" -ForegroundColor Green
}
Write-Host "----------------------------------------------------" -ForegroundColor Cyan
Write-Host " Total Execution Time  : $totalTime seconds ($itemsPerSec items/sec)" -ForegroundColor Yellow
Write-Host " Output Directory      : $outputDir" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Cyan
Pause