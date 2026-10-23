param(
    [string]$M3UFileName = "TVVOD.m3u",
    [string]$OutputDirectory = "TVVOD",
    [switch]$CreateStreamFiles =$true
)

# Start execution timer
$startTime = [datetime]::Now

# ---------------------------------------------------------------------------
# 1. Automatic Directory & Path Resolution (.NET Native Pathing)
# ---------------------------------------------------------------------------
$scriptPath =$MyInvocation.MyCommand.Path
if (-not [string]::IsNullOrWhiteSpace($scriptPath)) {
    $currentDir = Split-Path -Parent$scriptPath
} else {
    $currentDir =$PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($currentDir)) {$currentDir = (Get-Location).Path 
}

# Shift location to script directory
Set-Location -Path $currentDir

Clear-Host

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "                     Jellyfin/Emby                  " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Fallback defaults
if ([string]::IsNullOrWhiteSpace($M3UFileName)) {$M3UFileName = "TVVOD.m3u" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {$OutputDirectory = "TVVOD" }

# Safe .NET Path Combine
$M3UPath = [System.IO.Path]::Combine($currentDir,$M3UFileName)

if (-not (Test-Path -Path $M3UPath)) {
    # Fallback search for any .m3u file in current script directory
    $m3uFile = Get-ChildItem -Path$currentDir -Filter "*.m3u" | Select-Object -First 1
    if (-not $m3uFile) {
        Write-Host "[ERROR] No .m3u file found in: $currentDir" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }
    $M3UPath =$m3uFile.FullName
    Write-Host "[INFO] Detected M3U: $($m3uFile.Name)" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Using M3U: $M3UFileName" -ForegroundColor Yellow
}

$OutputDirectoryClean =$OutputDirectory.TrimStart(".\").TrimStart("\")
$OutputDirectoryPath = [System.IO.Path]::Combine($currentDir,$OutputDirectoryClean)

Write-Host "[INFO] Reading M3U file streams (Fast StreamReader)..." -ForegroundColor DarkCyan

# ---------------------------------------------------------------------------
# 2. Fast High-Performance M3U Streaming
# ---------------------------------------------------------------------------
$playlistItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$reader = [System.IO.StreamReader]::new($M3UPath, [System.Text.Encoding]::UTF8)

$extinf =$null
while (($line = $reader.ReadLine()) -ne$null) {
    if ($line.StartsWith("#EXTINF:")) {
        $extinf =$line
    } elseif ($extinf -and -not$line.StartsWith("#") -and -not [string]::IsNullOrWhiteSpace($line)) {$title = ""
        if ($extinf -match 'tvg-name="([^"]*)"') {
            $title =$Matches[1]
        }
        if ([string]::IsNullOrWhiteSpace($title) -and$extinf -like "*,*") {
            $title = $extinf.Substring($extinf.LastIndexOf(",") + 1).Trim()
        }

        # Clean prefix metadata tags
        $title =$title -replace '^(HD|SD|4K|FHD|UHD|US|UK|CA)\s*[:\-]\s*', ''

        $playlistItems.Add([PSCustomObject]@{
            RawTitle = $title
            Url      = $line.Trim()
        })
        $extinf =$null
    }
}
$reader.Dispose()

$total =$playlistItems.Count
if ($total -eq 0) {
    Write-Host "[ERROR] No valid stream entries found in the M3U file." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "[SUCCESS] Loaded $total items! Processing TV shows...`n" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Processing & File Generation
# ---------------------------------------------------------------------------
$counter = 1
$createdCount = 0
$skippedCount = 0
$failedCount  = 0
$foldersCreatedCount = 0

foreach ($item in $playlistItems) {
    $cleanTitle = $item.RawTitle
    
    # Pre-clean generic video quality noise
    $cleanTitle = $cleanTitle -replace '(?i)\b(1080p|720p|4k|2160p|HEVC|x265|H264|WEB-DL|WEBRip|AAC|MULTi)\b', ''
    $cleanTitle = $cleanTitle.Trim(' -_')

    $targetShowName = ""
    $seasonFolder = ""
    $fileName = ""
    $typeIndicator = ""

    # Pattern 1: Fixed SxxExx or 1x01 matching
    if ($cleanTitle -match '(?i)(.*?)\s+[S\.]?(\d{1,2})[ExX\.-](\d{1,3})') {
        $targetShowName = $Matches[1].Trim(' -_')
        $seasonNum = [int]$Matches[2]
        $episodeNum = [int]$Matches[3]

        $seasonFolder = "Season " + $seasonNum.ToString("00")
        $fileName = "$targetShowName - S" + $seasonNum.ToString("00") + "E" + $episodeNum.ToString("00")
        $typeIndicator = "SERIES"
    }
    # Pattern 2: Date-based TV Shows
    elseif ($cleanTitle -match '(?i)^(.*?)\s+((?:19|20)\d{2})[\s\.-](\d{2})[\s\.-](\d{2})') {
        $targetShowName = $Matches[1].Trim(' -_')
        $year = $Matches[2]
        $month = $Matches[3]
        $day = $Matches[4]

        $seasonFolder = "Season $year"
        $fileName = "$targetShowName - $year-$month-$day"
        $typeIndicator = "DATE"
    }
    # Pattern 3: Fallback for unmatched TV items
    else {
        $targetShowName = "Unsorted Shows"
        $seasonFolder = "Season 01"
        $fileName = $cleanTitle
        $typeIndicator = "OTHER"
    }

    # Sanitize invalid Windows path characters
    $targetShowName = $targetShowName -replace '[\\/:*?"<>|]', ''
    $fileName = $fileName -replace '[\\/:*?"<>|]', ''

    # Guarantees no empty strings reach the path builder
    if ([string]::IsNullOrWhiteSpace($targetShowName)) { $targetShowName = "Unsorted Shows" }
    if ([string]::IsNullOrWhiteSpace($seasonFolder)) { $seasonFolder = "Season 01" }
    if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = "Episode_$counter" }

    # Safe .NET Path Builders
    $seasonDirPath = [System.IO.Path]::Combine($OutputDirectoryPath, $targetShowName, $seasonFolder)
    $strmFilePath  = [System.IO.Path]::Combine($seasonDirPath, "$fileName.strm")
    
    $percent = [Math]::Round(($counter / $total) * 100)

    # Check if stream file already exists (Skip duplicate work)
    if (Test-Path -Path $strmFilePath) {
        $skippedCount++
        Write-Host "[$percent%] " -NoNewline -ForegroundColor DarkGray
        Write-Host "[SKIPPED] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$targetShowName -> $seasonFolder -> $fileName.strm" -ForegroundColor Gray
        $counter++
        continue
    }

    try {
        if (-not (Test-Path -Path $seasonDirPath)) {
            New-Item -ItemType Directory -Path $seasonDirPath -Force | Out-Null
            $foldersCreatedCount++
        }

        Write-Host "[$percent%] " -NoNewline -ForegroundColor DarkYellow
        Write-Host "[$typeIndicator] " -NoNewline -ForegroundColor Magenta
        Write-Host "$targetShowName " -NoNewline -ForegroundColor Cyan
        Write-Host "-> " -NoNewline -ForegroundColor DarkGray
        Write-Host "$seasonFolder " -NoNewline -ForegroundColor Yellow
        Write-Host "-> $fileName" -ForegroundColor White

        if ($CreateStreamFiles) {
            Set-Content -Path $strmFilePath -Value $item.Url -Encoding UTF8
        }
        $createdCount++
    }
    catch {
        $failedCount++
        Write-Host "[$percent%] [ERROR] Failed to write file: $_" -ForegroundColor Red
    }

    $counter++
}

# Calculate elapsed time and percentages
$elapsedTime = [datetime]::Now - $startTime
$createdPct = if ($total -gt 0) { [Math]::Round(($createdCount / $total) * 100, 1) } else { 0 }
$skippedPct = if ($total -gt 0) { [Math]::Round(($skippedCount / $total) * 100, 1) } else { 0 }
$failedPct  = if ($total -gt 0) { [Math]::Round(($failedCount / $total) * 100, 1) } else { 0 }

# Format elapsed time cleanly (Hours:Minutes:Seconds.Milliseconds or similar)
$timeFormatted = "{0:hh\:mm\:ss\.fff}" -f $elapsedTime
if ($elapsedTime.TotalHours -ge 1) {
    $timeFormatted = "$(([int]$elapsedTime.TotalHours))h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s"
} else {
    $timeFormatted = "$($elapsedTime.Minutes)m $($elapsedTime.Seconds)s $($elapsedTime.Milliseconds)ms"
}

# ---------------------------------------------------------------------------
# 4. Execution Summary Block
# ---------------------------------------------------------------------------
Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "                 === EXECUTION SUMMARY ===          " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " Total Entries Parsed      : $total" -ForegroundColor White
Write-Host " New Folders Created       : $foldersCreatedCount" -ForegroundColor White
Write-Host " New STRM Files Created    : $createdCount ($createdPct%)" -ForegroundColor Green
Write-Host " Skipped (Already Exist)   : $skippedCount ($skippedPct%)" -ForegroundColor DarkGray
Write-Host " Failed Write Errors       : $failedCount ($failedPct%)" -ForegroundColor $(if($failedCount -gt 0){"Red"}else{"White"})
Write-Host "----------------------------------------------------" -ForegroundColor Cyan
Write-Host " Total Execution Time      : $timeFormatted" -ForegroundColor Yellow
Write-Host " Output Directory          : $OutputDirectoryPath" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Cyan

Read-Host "Press Enter to exit"