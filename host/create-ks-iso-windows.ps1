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
        # Try mkisofs/genisoimage from Git for Windows
        $mkisofs = $null
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

        if ($mkisofs) {
            Write-Host "Creating ISO using $(Split-Path -Leaf $mkisofs) with OEMDRV label..."
            Write-Host "(Anaconda automatically searches OEMDRV volumes for ks.cfg)"
            & $mkisofs -o $OutputISO -V "OEMDRV" -r -J $TempDir
            if ($LASTEXITCODE -ne 0) {
                throw "$(Split-Path -Leaf $mkisofs) failed with exit code $LASTEXITCODE"
            }
        } else {
            Write-Warning "Neither oscdimg (Windows ADK) nor genisoimage/mkisofs (Git) found."
            Write-Host ""
            Write-Host "Install one of:"
            Write-Host "  - Windows ADK: https://docs.microsoft.com/windows-hardware/get-started/adk-install"
            Write-Host "  - Git for Windows usually includes genisoimage"
            Write-Host "  - Or use manual kickstart: run tools\serve-kickstart.ps1 and type inst.ks=http://... at boot"
            throw "No ISO creation tool available"
        }
    }

    Write-Host "Kickstart ISO created: $OutputISO"

} finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
