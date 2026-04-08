#Requires -Version 5.1
<#
  Create a modified Fedora ISO with kickstart parameter pre-configured in boot menu.
  This makes kickstart automatic - no manual intervention needed.

  This script:
  1. Extracts the original Fedora ISO
  2. Modifies GRUB config to add inst.ks parameter to default boot entry
  3. Repacks as a new bootable ISO with kickstart enabled

  Requires oscdimg from Windows ADK.
#>
param(
    [string]$SourceISO,
    [string]$OutputISO,
    [string]$KickstartLabel = "OEMDRV"
)

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir

if ([string]::IsNullOrEmpty($SourceISO)) {
    $SourceISO = Join-Path $Base "vm\fedora.iso"
}

if ([string]::IsNullOrEmpty($OutputISO)) {
    $OutputISO = Join-Path $Base "vm\fedora-auto-ks.iso"
}

if (-not (Test-Path $SourceISO)) {
    Write-Error "Source ISO not found: $SourceISO"
}

Write-Host "=== Creating Auto-Kickstart Fedora ISO ===" -ForegroundColor Cyan
Write-Host "Source: $SourceISO"
Write-Host "Output: $OutputISO"
Write-Host ""

# Find oscdimg
$oscdimg = $null
$adkPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
)
foreach ($path in $adkPaths) {
    if (Test-Path $path) {
        $oscdimg = $path
        break
    }
}

if (-not $oscdimg) {
    Write-Error @"
oscdimg.exe not found. Install Windows ADK:
  .\host\install-adk-windows.ps1

Or manually: https://learn.microsoft.com/windows-hardware/get-started/adk-install
"@
}

# Check for 7-Zip (needed to extract ISO)
$7z = $null
$7zPaths = @(
    "${env:ProgramFiles}\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
)
foreach ($path in $7zPaths) {
    if (Test-Path $path) {
        $7z = $path
        break
    }
}

if (-not $7z) {
    Write-Error @"
7-Zip not found. Install from: https://www.7-zip.org/

After installing, run this script again.

Alternative: Use HTTP kickstart (.\tools\serve-kickstart.ps1) - no ISO modification needed.
"@
}

# Create temp directory for extraction
$extractDir = Join-Path $env:TEMP "fedora-iso-$(Get-Random)"
$bootDir = Join-Path $extractDir "boot"

try {
    Write-Host "Extracting ISO (this may take a few minutes)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    & $7z x "-o$extractDir" $SourceISO -y | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to extract ISO"
    }

    Write-Host "ISO extracted to: $extractDir" -ForegroundColor Green
    Write-Host ""

    # Find and modify GRUB config
    $grubCfg = Join-Path $extractDir "boot\grub2\grub.cfg"
    if (-not (Test-Path $grubCfg)) {
        $grubCfg = Join-Path $extractDir "EFI\BOOT\grub.cfg"
    }

    if (Test-Path $grubCfg) {
        Write-Host "Modifying GRUB config: $grubCfg" -ForegroundColor Cyan

        $content = Get-Content $grubCfg -Raw

        # Add inst.ks parameter to the first/default linux boot entry
        # Pattern: look for the first 'linux' line and add our parameter
        $ksParam = "inst.ks=hd:LABEL=${KickstartLabel}:/ks.cfg"

        # Match the first linux command and add kickstart param
        $content = $content -replace '(linux\s+[^\n]+?)\s*$', "`$1 $ksParam"

        [System.IO.File]::WriteAllText($grubCfg, $content)
        Write-Host "Added kickstart parameter to boot menu" -ForegroundColor Green
    } else {
        Write-Warning "GRUB config not found - ISO structure may be different"
    }

    # Also modify isolinux if present (BIOS boot)
    $isolinuxCfg = Join-Path $extractDir "isolinux\isolinux.cfg"
    if (Test-Path $isolinuxCfg) {
        Write-Host "Modifying isolinux config: $isolinuxCfg" -ForegroundColor Cyan

        $content = Get-Content $isolinuxCfg -Raw
        $ksParam = "inst.ks=hd:LABEL=${KickstartLabel}:/ks.cfg"

        # Add to append lines
        $content = $content -replace '(append\s+[^\n]+?)\s*$', "`$1 $ksParam"

        [System.IO.File]::WriteAllText($isolinuxCfg, $content)
        Write-Host "Added kickstart parameter to BIOS boot menu" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Creating new bootable ISO..." -ForegroundColor Cyan

    # Get boot sector info from original ISO
    $bootSector = Join-Path $extractDir "isolinux\isolinux.bin"
    $efiImg = Join-Path $extractDir "images\efiboot.img"

    # Build oscdimg command for UEFI + BIOS boot
    $oscdimgArgs = @(
        "-m"           # Ignore max size
        "-o"           # Optimize
        "-u2"          # UDF
        "-udfver102"   # UDF version
        "-l`"Fedora-Auto-KS`""  # Volume label
    )

    if (Test-Path $bootSector) {
        $oscdimgArgs += "-b$bootSector"
    }

    if (Test-Path $efiImg) {
        $oscdimgArgs += "-pEF"
        $oscdimgArgs += "-e$efiImg"
    }

    $oscdimgArgs += $extractDir
    $oscdimgArgs += $OutputISO

    & $oscdimg @oscdimgArgs

    if ($LASTEXITCODE -ne 0) {
        throw "oscdimg failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Success!" -ForegroundColor Green
    Write-Host "Auto-kickstart ISO created: $OutputISO" -ForegroundColor Green
    Write-Host ""
    Write-Host "This ISO will automatically use kickstart from the OEMDRV volume."
    Write-Host "No manual boot parameter entry needed!"

} finally {
    # Cleanup
    if (Test-Path $extractDir) {
        Write-Host ""
        Write-Host "Cleaning up..." -ForegroundColor Gray
        Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Update create-vm-windows.ps1 to use: $OutputISO"
Write-Host "2. Or manually: Set-VMDvdDrive -VMName ai-sandbox -Path '$OutputISO'"
Write-Host "3. Boot the VM - kickstart will run automatically!"
