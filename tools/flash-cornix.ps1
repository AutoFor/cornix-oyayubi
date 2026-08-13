# flash-cornix.ps1 -- download the latest CI build and flash it to Cornix.
#
# Prereqs (first time only):
#   1. install gh CLI:  winget install GitHub.cli
#   2. authenticate:     gh auth login
#
# Usage (PowerShell):
#   .\flash-cornix.ps1               # flash both halves in order
#   .\flash-cornix.ps1 -Side left    # left half only
#   .\flash-cornix.ps1 -Side right   # right half only
#   .\flash-cornix.ps1 -Branch xxx   # target branch (default: main)
#   .\flash-cornix.ps1 -DownloadOnly # download only, no flashing
#   .\flash-cornix.ps1 -DebugFw      # use the USB-logging debug build for the left half
#
# The UF2 bootloader drive is auto-detected via INFO_UF2.TXT "Model: cornix",
# so it works regardless of the assigned drive letter (D:/E:/F: ...).
#
# ASCII-only source on purpose, so cross-platform transfer never corrupts it.

param(
    [ValidateSet("both", "left", "right")]
    [string]$Side = "both",
    [string]$Branch = "main",
    [string]$Repo = "AutoFor/cornix-oyayubi",
    [switch]$DownloadOnly,
    [switch]$DebugFw
)

$ErrorActionPreference = "Stop"

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
    Write-Host "== Put $Label into bootloader mode (double-tap the reset button) ==" -ForegroundColor Yellow
    Write-Host "   waiting for the UF2 drive to appear... (Ctrl+C to abort)"
    while ($true) {
        $drive = Find-CornixDrive
        if ($drive) { return $drive }
        Start-Sleep -Seconds 1
    }
}

function Flash-Uf2([string]$Label, [string]$Uf2Path) {
    $drive = Wait-CornixDrive $Label
    Write-Host "   found: $drive -> copying $(Split-Path $Uf2Path -Leaf)"
    Copy-Item $Uf2Path "$drive\" -ErrorAction SilentlyContinue
    # The device reboots as soon as the copy finishes and the drive disappears,
    # so a copy error here is expected and can be ignored.
    Write-Host "   writing... waiting for the drive to disappear"
    while (Find-CornixDrive) { Start-Sleep -Seconds 1 }
    Write-Host "   [OK] $Label done (rebooted automatically)" -ForegroundColor Green
}

# --- 1. find the latest successful build ---
Write-Host "Searching latest successful build of $Repo ($Branch)..."
$runId = gh run list -R $Repo -b $Branch -w "Build ZMK firmware" -s success -L 1 --json databaseId -q ".[0].databaseId"
if ([string]::IsNullOrWhiteSpace($runId)) {
    Write-Error "No successful 'Build ZMK firmware' run found on branch '$Branch'. Check GitHub Actions (and 'gh auth status')."
}
$runId = $runId.Trim()
Write-Host "   run: https://github.com/$Repo/actions/runs/$runId"

# --- 2. download the firmware artifact ---
$dest = Join-Path $env:TEMP "cornix-fw-$runId"
if (-not (Test-Path (Join-Path $dest "_done"))) {
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Write-Host "Downloading firmware artifact... -> $dest"
    # -n firmware: only the firmware artifact (the repo also produces a github-pages
    # artifact; without -n, gh would drop into an interactive picker).
    gh run download $runId -R $Repo -n firmware -D $dest
    New-Item (Join-Path $dest "_done") -ItemType File | Out-Null
} else {
    Write-Host "   using cached download: $dest"
}

# left half: normally exclude debug; with -DebugFw pick the debug build
$leftUf2 = Get-ChildItem $dest -Recurse -Filter "*.uf2" |
    Where-Object {
        $_.Name -match "left" -and $_.Name -notmatch "dongle" -and
        ((-not $DebugFw -and $_.Name -notmatch "debug") -or ($DebugFw -and $_.Name -match "debug"))
    } | Select-Object -First 1
$rightUf2 = Get-ChildItem $dest -Recurse -Filter "*.uf2" |
    Where-Object { $_.Name -match "right" -and $_.Name -notmatch "dongle|debug" } | Select-Object -First 1
if ($DebugFw) { Write-Host "Using the debug (USB-logging) left-half UF2" -ForegroundColor Magenta }

Write-Host "   left : $($leftUf2.FullName)"
Write-Host "   right: $($rightUf2.FullName)"
if ($DownloadOnly) { Write-Host "[OK] download only"; exit 0 }

# --- 3. flash ---
if ($Side -in @("both", "left")) {
    if (-not $leftUf2) { Write-Error "left UF2 not found" }
    Flash-Uf2 "LEFT" $leftUf2.FullName
}
if ($Side -in @("both", "right")) {
    if (-not $rightUf2) { Write-Error "right UF2 not found" }
    Flash-Uf2 "RIGHT" $rightUf2.FullName
}

Write-Host ""
Write-Host "[DONE] Flashing complete. Verify the keyboard works." -ForegroundColor Green
Write-Host "   To roll back, flash the stock UF2 under firmware/stock/."
