# flash.ps1 -- download the latest Cornix NICOLA firmware release and flash it (Windows).
#
# No prerequisites: no GitHub account, no gh CLI. Windows PowerShell 5+.
#
# Run directly (paste this one line into PowerShell):
#   iex (New-Object Net.WebClient).DownloadString('https://autofor.github.io/cornix-oyayubi/flash.ps1')
#
# Or download this file and run with options:
#   powershell -ExecutionPolicy Bypass -File flash.ps1 -Side left
#   powershell -ExecutionPolicy Bypass -File flash.ps1 -Repo you/your-fork
#
# Before writing, the current firmware (CURRENT.UF2) is backed up automatically.
# Copying is done by command (not Explorer), so the harmless-but-scary
# "error 0x800701B1" dialog of drag-and-drop flashing never appears.
#
# ASCII-only source on purpose, so cross-platform transfer never corrupts it.

param(
    [ValidateSet("both", "left", "right")]
    [string]$Side = "both",
    [string]$Repo = "AutoFor/cornix-oyayubi"
)

$ErrorActionPreference = "Stop"
$base = "https://github.com/$Repo/releases/latest/download"
$names = @{ left = "cornix_left_default_nosd.uf2"; right = "cornix_right_nosd.uf2" }
$dest = Join-Path $env:TEMP "cornix-flash"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

function Find-CornixDrive {
    Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 } | ForEach-Object {
        # The drive can vanish mid-enumeration (the device reboots right after
        # the UF2 copy finishes), so treat any error here as "drive not present".
        try {
            $info = "$($_.DeviceID)\INFO_UF2.TXT"
            if ((Test-Path $info -ErrorAction SilentlyContinue) -and
                (Select-String -Path $info -Pattern "Model: cornix" -Quiet -ErrorAction SilentlyContinue)) {
                $_.DeviceID
            }
        } catch { }
    } | Select-Object -First 1
}

function Wait-CornixDrive([string]$Label) {
    Write-Host ""
    Write-Host "== Put the $Label half into bootloader mode (double-tap the reset button) ==" -ForegroundColor Yellow
    Write-Host "   waiting for the UF2 drive to appear... (Ctrl+C to abort)"
    while ($true) {
        $drive = Find-CornixDrive
        if ($drive) { return $drive }
        Start-Sleep -Seconds 1
    }
}

function Flash-Uf2([string]$Label, [string]$Uf2Path) {
    $drive = Wait-CornixDrive $Label
    Write-Host "   found: $drive"
    # back up the firmware currently on the device (best effort)
    $bak = Join-Path $dest ("backup-{0}-{1}.uf2" -f $Label, (Get-Date -Format "yyyyMMdd-HHmmss"))
    try {
        Copy-Item "$drive\CURRENT.UF2" $bak -ErrorAction Stop
        Write-Host "   backup saved: $bak"
    } catch {
        Write-Host "   (backup skipped: CURRENT.UF2 not readable)"
    }
    Write-Host "   copying $(Split-Path $Uf2Path -Leaf) ..."
    Copy-Item $Uf2Path "$drive\" -ErrorAction SilentlyContinue
    # The device reboots as soon as the copy finishes and the drive disappears,
    # so a copy error here is expected and can be ignored.
    Write-Host "   writing... waiting for the drive to disappear"
    while (Find-CornixDrive) { Start-Sleep -Seconds 1 }
    Write-Host "   [OK] $Label done (rebooted automatically)" -ForegroundColor Green
}

foreach ($s in @("left", "right")) {
    if ($Side -ne "both" -and $Side -ne $s) { continue }
    $file = $names[$s]
    $path = Join-Path $dest $file
    Write-Host "Downloading $file ..."
    Invoke-WebRequest -UseBasicParsing "$base/$file" -OutFile $path
    Flash-Uf2 $s.ToUpper() $path
}

Write-Host ""
Write-Host "[DONE] Flashing complete. Verify the keyboard works." -ForegroundColor Green
Write-Host "   Firmware backups (if any) are in: $dest"
