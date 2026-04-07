#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
  Install Windows ADK (Assessment and Deployment Kit) Deployment Tools component.
  This provides oscdimg.exe for creating bootable ISOs for kickstart automation.

  Run from elevated PowerShell:
    .\host\install-adk-windows.ps1
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "=== Windows ADK Deployment Tools Installer ===" -ForegroundColor Cyan
Write-Host ""

# Check if oscdimg already exists
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

if ($oscdimg -and -not $Force) {
    Write-Host "oscdimg.exe already installed: $oscdimg" -ForegroundColor Green
    Write-Host "Use -Force to reinstall."
    exit 0
}

Write-Host "This will download and install Windows ADK Deployment Tools (~500 MB download)." -ForegroundColor Yellow
Write-Host "Only the Deployment Tools component will be installed (includes oscdimg.exe)."
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Continue? [Y/n]"
    if ($confirm -match '^[Nn]') {
        Write-Host "Installation cancelled."
        exit 0
    }
}

# Download ADK installer
$tempDir = Join-Path $env:TEMP "adk-installer"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$adkSetup = Join-Path $tempDir "adksetup.exe"

Write-Host ""
Write-Host "Downloading Windows ADK installer..." -ForegroundColor Cyan

try {
    # Use the web installer URL (small download, pulls components as needed)
    $adkUrl = "https://go.microsoft.com/fwlink/?linkid=2271337"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $adkUrl -OutFile $adkSetup -UseBasicParsing
    $ProgressPreference = 'Continue'

    Write-Host "Downloaded: $adkSetup" -ForegroundColor Green
} catch {
    Write-Error "Failed to download ADK installer: $_"
    Write-Host ""
    Write-Host "Manual download: https://learn.microsoft.com/windows-hardware/get-started/adk-install"
    exit 1
}

Write-Host ""
Write-Host "Installing Windows ADK Deployment Tools..." -ForegroundColor Cyan
Write-Host "This may take 5-10 minutes. A separate installer window will appear."
Write-Host ""

try {
    # Run silent install with only Deployment Tools feature
    # /quiet = silent mode
    # /features OptionId.DeploymentTools = only install deployment tools
    # /ceip off = disable telemetry prompt
    # /norestart = don't restart

    $installArgs = @(
        "/quiet"
        "/features"
        "OptionId.DeploymentTools"
        "/ceip"
        "off"
        "/norestart"
    )

    Write-Host "Running: $adkSetup $($installArgs -join ' ')" -ForegroundColor Gray

    $process = Start-Process -FilePath $adkSetup -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "Installation completed successfully!" -ForegroundColor Green

        # Verify installation
        $oscdimg = $null
        foreach ($path in $adkPaths) {
            if (Test-Path $path) {
                $oscdimg = $path
                break
            }
        }

        if ($oscdimg) {
            Write-Host "oscdimg.exe found: $oscdimg" -ForegroundColor Green
        } else {
            Write-Warning "Installation completed but oscdimg.exe not found at expected paths."
            Write-Host "ADK may have installed to a different location."
        }

    } elseif ($process.ExitCode -eq 3010) {
        Write-Host ""
        Write-Host "Installation completed (reboot required)." -ForegroundColor Yellow
        Write-Host "Reboot before creating VMs."
    } else {
        Write-Error "Installation failed with exit code: $($process.ExitCode)"
        Write-Host ""
        Write-Host "Try manual installation:"
        Write-Host "  1. Visit: https://learn.microsoft.com/windows-hardware/get-started/adk-install"
        Write-Host "  2. Download Windows ADK"
        Write-Host "  3. Run installer and select only 'Deployment Tools'"
        exit 1
    }

} catch {
    Write-Error "Installation failed: $_"
    exit 1
} finally {
    # Cleanup
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run: .\host\create-vm-windows.ps1"
Write-Host "  2. Kickstart ISO will be created automatically"
Write-Host "  3. Fedora will install unattended"
