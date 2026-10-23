# Jellyfin / Emby STRM Generator

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-7%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell" />
  <img src="https://img.shields.io/badge/Jellyfin-Ready-00A4EF?style=for-the-badge" alt="Jellyfin Ready" />
  <img src="https://img.shields.io/badge/Emby-Ready-7A4DFF?style=for-the-badge" alt="Emby Ready" />
  <img src="https://img.shields.io/badge/M3U-Playlist-FF8C00?style=for-the-badge" alt="M3U Playlist" />
</p>

A high-performance PowerShell script for parsing IPTV and VOD M3U playlists and automatically generating organized `.strm` files for Jellyfin and Emby.

It scans your playlist, detects TV show episodes, cleans noisy metadata, creates season folders, and writes `.strm` files that point directly to the original stream URLs—making large media libraries easy to organize and maintain.

## Why use this?

If you have a large IPTV or VOD playlist, this script helps you:

- Convert raw M3U entries into a familiar library structure
- Automatically organize shows by series and season
- Create `.strm` files compatible with Jellyfin / Emby
- Skip duplicate entries that already exist
- Handle both standard `SxxExx` naming and date-based show formats

---

## Features

- Fast `.NET StreamReader` processing for large playlist files
- Smart regex matching for:
  - Standard episodes like `S01E02`
  - Alternate formats like `1x02`
  - Date-based titles like `Show Name 2024-01-15`
- Metadata cleanup to remove noisy labels like `HD`, `1080p`, `HEVC`, etc.
- Duplicate skipping to prevent unnecessary file rewrites
- Automatic creation of show and season folders
- Output summary with created, skipped, failed, and timing stats
- Works with Jellyfin and Emby media server layouts

---

## Requirements

Before running the script, make sure you have:

- PowerShell 7+ recommended (or Windows PowerShell 5.1 on older Windows systems)
- A valid `.m3u` playlist file
- Read access to the playlist
- Write permission to the output folder
- A Jellyfin or Emby-compatible library setup

---

## Installation

### Windows

If PowerShell is not installed:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Then verify:

```powershell
pwsh -v
```

### macOS

Using Homebrew:

```bash
brew install --cask powershell
```

Then verify:

```bash
pwsh -v
```

### Linux

On Ubuntu/Debian:

```bash
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
sudo dpkg -i /tmp/packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

Verify:

```bash
pwsh -v
```

---

## Quick Start

1. Download the script (for example, `Generate-STRM.ps1`)
2. Place it in the same folder as your `.m3u` file
3. Open PowerShell
4. Run the script

### Default usage

```powershell
.\Generate-STRM.ps1
```

This uses:

- `-M3UFileName = "TVVOD.m3u"`
- `-OutputDirectory = "TVVOD"`

---

## Custom Parameters

### Use a different M3U file

```powershell
.\Generate-STRM.ps1 -M3UFileName "MyPlaylist.m3u"
```

### Use a custom output folder

```powershell
.\Generate-STRM.ps1 -OutputDirectory "GeneratedStreams"
```

### Use both together

```powershell
.\Generate-STRM.ps1 -M3UFileName "MyPlaylist.m3u" -OutputDirectory "GeneratedStreams"
```

### Disable `.strm` creation

```powershell
.\Generate-STRM.ps1 -CreateStreamFiles:$false
```

---

## Parameter Reference

| Parameter | Default | Description |
|---|---:|---|
| `-M3UFileName` | `"TVVOD.m3u"` | Name or path of the input M3U playlist |
| `-OutputDirectory` | `"TVVOD"` | Output folder used to store generated show/season folders |
| `-CreateStreamFiles` | `True` | Whether or not `.strm` files are written |

---

## Example Output

```text
[INFO] Using M3U: TVVOD.m3u
[SUCCESS] Loaded 245 items! Processing TV shows...

[75%] [SERIES] Some Show -> Season 01 -> Some Show - S01E15
[80%] [DATE] Another Show -> Season 2024 -> Another Show - 2024-01-15
...

====================================================
                    === EXECUTION SUMMARY ===
====================================================
 Total Entries Parsed      : 245
 New Folders Created       : 18
 New STRM Files Created    : 220 (89.8%)
 Skipped (Already Exist)   : 25 (10.2%)
 Failed Write Errors       : 0 (0.0%)
 Total Execution Time      : 00m 12s 345ms
 Output Directory          : C:\path\to\script\TVVOD
====================================================
```

---

## Folder Structure Example

The script creates output in a format similar to this:

```text
TVVOD/
├── Show One/
│   ├── Season 01/
│   │   ├── Show One - S01E01.strm
│   │   ├── Show One - S01E02.strm
│   │   └── ...
│   └── Season 2024/
│       ├── Show One - 2024-01-10.strm
│       └── ...
├── Show Two/
│   ├── Season 01/
│   │   └── ...
└── Unsorted Shows/
    └── Season 01/
        └── Some Episode.strm
```

---

## How It Works

The script performs the following steps:

1. Reads the `.m3u` file using a fast .NET `StreamReader`
2. Extracts stream URLs and metadata from `#EXTINF` entries
3. Detects series naming patterns such as:
   - `Show Name S01E02`
   - `Show Name 1x02`
4. Detects date-based titles such as:
   - `Show Name 2024-01-15`
5. Cleans irrelevant metadata like resolution and codec tags
6. Creates the folder structure
7. Writes `.strm` files containing the original URL
8. Skips existing files to avoid duplicate work

---

## Notes and Tips

- Keep the script and M3U file in the same directory for the simplest workflow
- Use a fresh output folder if you want a clean library layout
- If a title does not match the supported patterns, it will be grouped under `Unsorted Shows`
- Ensure the output directory is writable before running
- For very large playlists, run the script on a machine with enough disk space and local read/write speed

---

## License

This project is provided as-is for personal and community use. Please check the repository for the specific license terms before using it in commercial or redistributed contexts.

---

## Contributing

Contributions are welcome. You can help by:

- Improving episode detection patterns
- Supporting additional naming conventions
- Improving performance on very large playlist files
- Adding better logging or output options

If you want to improve the script, fork the repository and submit a pull request with a clear description of the change.

---

## Support

If the script does not run as expected, verify:

- PowerShell is installed and working
- The M3U file exists and is valid
- The file is UTF-8 compatible
- The output directory can be created
- Stream URLs in the playlist are properly formatted

If you need help modifying the script for your playlist format, open an issue or provide a sample of the M3U entries you are working with.

---

<p align="center">
  <sub>Built for Jellyfin and Emby users who want a faster, cleaner way to organize IPTV and VOD libraries.</sub>
</p>
