#Requires -Version 5.1
<#
  Create a small ISO containing ks.cfg for automated kickstart installation.
  Uses oscdimg.exe from Windows ADK or creates using PowerShell + mkisofs from Git.
#>
param(
    [string]$OutputISO
)

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir

if ([string]::IsNullOrEmpty($OutputISO)) {
    $OutputISO = Join-Path $Base "vm\kickstart.iso"
}

$KsFile = Join-Path $Base "ks.cfg"
if (-not (Test-Path $KsFile)) {
    Write-Error "Missing $KsFile - run host\generate-ks-windows.ps1 first"
}

$TempDir = Join-Path $env:TEMP "ks-iso-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    # Copy ks.cfg to temp directory
    Copy-Item -Path $KsFile -Destination (Join-Path $TempDir "ks.cfg")

    # Try oscdimg from Windows ADK first (most reliable)
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

    if ($oscdimg) {
        Write-Host "Creating ISO using oscdimg with OEMDRV label..."
        Write-Host "(Anaconda automatically searches OEMDRV volumes for ks.cfg)"
        & $oscdimg -n -m -lOEMDRV $TempDir $OutputISO | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "oscdimg failed with exit code $LASTEXITCODE"
        }
    } else {
        # Try mkisofs/genisoimage from Git for Windows or PATH
        $mkisofs = $null

        # Check if it's in PATH first
        $mkisofs = Get-Command mkisofs -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if (-not $mkisofs) {
            $mkisofs = Get-Command genisoimage -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        }

        # Check Git for Windows locations
        if (-not $mkisofs) {
            $gitPaths = @(
                "${env:ProgramFiles}\Git\usr\bin\genisoimage.exe",
                "${env:ProgramFiles(x86)}\Git\usr\bin\genisoimage.exe",
                "${env:ProgramFiles}\Git\usr\bin\mkisofs.exe",
                "${env:ProgramFiles(x86)}\Git\usr\bin\mkisofs.exe"
            )
            foreach ($path in $gitPaths) {
                if (Test-Path $path) {
                    $mkisofs = $path
                    break
                }
            }
        }

        if ($mkisofs) {
            Write-Host "Creating ISO using $(Split-Path -Leaf $mkisofs) with OEMDRV label..."
            Write-Host "(Anaconda automatically searches OEMDRV volumes for ks.cfg)"
            & $mkisofs -o $OutputISO -V "OEMDRV" -r -J $TempDir
            if ($LASTEXITCODE -ne 0) {
                throw "$(Split-Path -Leaf $mkisofs) failed with exit code $LASTEXITCODE"
            }
        } else {
            # Try to download portable mkisofs
            Write-Host "No ISO creation tool found locally. Attempting to download portable mkisofs..." -ForegroundColor Yellow

            $portableDir = Join-Path $Base "tools\mkisofs"
            $mkisofsExe = Join-Path $portableDir "mkisofs.exe"

            if (-not (Test-Path $mkisofsExe)) {
                Write-Warning "No portable mkisofs.exe download available (mirrors offline)."
                Write-Host ""
                Write-Host "SOLUTION 1 - Install Windows ADK (Recommended):" -ForegroundColor Yellow
                Write-Host "  Run: .\host\install-adk-windows.ps1"
                Write-Host "  This will automatically download and install oscdimg.exe"
                Write-Host ""
                Write-Host "SOLUTION 2 - Use manual kickstart (Works immediately):" -ForegroundColor Cyan
                Write-Host "  1. Run: tools\serve-kickstart.ps1"
                Write-Host "  2. At VM boot, press Tab/e and add: inst.ks=http://<your-ip>:8000/ks.cfg"
                Write-Host "  3. Find your IP with: ipconfig"
                Write-Host ""
                throw "No ISO creation tool available"
            }

            if (Test-Path $mkisofsExe) {
                Write-Host "Creating ISO using downloaded mkisofs with OEMDRV label..."
                Write-Host "(Anaconda automatically searches OEMDRV volumes for ks.cfg)"
                & $mkisofsExe -o $OutputISO -V "OEMDRV" -r -J $TempDir
                if ($LASTEXITCODE -ne 0) {
                    throw "mkisofs failed with exit code $LASTEXITCODE"
                }
            } else {
                throw "No ISO creation tool available"
            }
        }
    }

    Write-Host "Kickstart ISO created: $OutputISO"

} finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
