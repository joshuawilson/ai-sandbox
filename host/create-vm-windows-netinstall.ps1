#Requires -Version 5.1
<#
  Create Hyper-V VM using Fedora netinstall ISO for TRUE automatic kickstart.

  Uses HTTP file delivery instead of SMB to avoid Windows Home authentication issues.
  The netinstall ISO properly auto-detects OEMDRV kickstart volumes.

  This is the fully automatic option for Windows.
#>
param()

$ErrorActionPreference = "Stop"

Write-Host "=== AI Sandbox - Automated Fedora Install (Windows/Hyper-V) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Using Fedora Server netinstall ISO for TRUE automatic kickstart." -ForegroundColor Green
Write-Host "(Will still install Workstation desktop via kickstart config)" -ForegroundColor Gray
Write-Host ""

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$VmEnv = Get-VmHostEnvMerged -RepoRoot $Base

$VMName = $VmEnv['VM_NAME']
$VMPath = Join-Path $Base "vm"
$VHD = Join-Path $VMPath "$VMName.vhdx"
$ISO = Join-Path $VMPath "fedora-netinstall.iso"
$ISOURL = if ($VmEnv['VM_NETINSTALL_URL']) { $VmEnv['VM_NETINSTALL_URL'] } else {
    "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Server/x86_64/iso/Fedora-Server-netinst-x86_64-43-1.6.iso"
}
$DiskGb = [int64]$VmEnv['VM_DISK_GB']
$MemBytes = [uint64]$VmEnv['VM_MEMORY_MIB'] * 1MB
$ProcCount = [int]$VmEnv['VM_VCPUS']
$SwitchName = $VmEnv['VM_HYPERV_SWITCH']

New-Item -ItemType Directory -Force -Path $VMPath | Out-Null

# Generate kickstart and ISO
$useKickstart = $false
if ((Test-Path (Join-Path $Base "secrets\ssh\id_ed25519.pub")) -and (Test-Path (Join-Path $Base "secrets\vm-password.env"))) {
    Write-Host "Generating ks.cfg..."
    & (Join-Path $Base "host\generate-ks-windows.ps1")
    $useKickstart = $true

    # Create kickstart ISO
    try {
        $ksISO = Join-Path $VMPath "kickstart.iso"
        Write-Host "Creating kickstart ISO..."
        & (Join-Path $Base "host\create-ks-iso-windows.ps1") -OutputISO $ksISO
        if (Test-Path $ksISO) {
            Write-Host "Kickstart ISO created successfully" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to create kickstart ISO: $_"
        $useKickstart = $false
    }
} else {
    Write-Host "Skipping kickstart (create secrets\ssh and secrets\vm-password.env first)."
}

Write-Host "Downloading Fedora netinstall ISO (~700 MB, smaller than Live ISO)..."
if (-not (Test-Path $ISO)) {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $ISOURL -OutFile $ISO
    $ProgressPreference = 'Continue'
} else {
    Write-Host "ISO already exists: $ISO"
}

Write-Host "Creating disk..."
if (-not (Test-Path $VHD)) {
    New-VHD -Path $VHD -SizeBytes ($DiskGb * 1GB) -Dynamic
} else {
    Write-Host "Disk already exists: $VHD"
}

Write-Host "Creating VM..."
$switch = $SwitchName
if (-not (Get-VMSwitch -Name $switch -ErrorAction SilentlyContinue)) {
    $sw = Get-VMSwitch -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sw) {
        Write-Error "No Hyper-V virtual switch found. Create one in Hyper-V Manager."
    }
    $switch = $sw.Name
    Write-Host "Using virtual switch: $switch"
}

# Remove existing VM if present
if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing VM: $VMName"
    Stop-VM -Name $VMName -TurnOff -Force -ErrorAction SilentlyContinue
    Remove-VM -Name $VMName -Force
}

New-VM -Name $VMName -MemoryStartupBytes $MemBytes -VHDPath $VHD -Generation 2 -SwitchName $switch
Set-VMProcessor -VMName $VMName -Count $ProcCount

# Add netinstall ISO
$dvd = Add-VMDvdDrive -VMName $VMName -Path $ISO -Passthru

# Add kickstart ISO if created
if ($useKickstart) {
    $ksISO = Join-Path $VMPath "kickstart.iso"
    if (Test-Path $ksISO) {
        Add-VMDvdDrive -VMName $VMName -Path $ksISO
        Write-Host "Kickstart ISO attached - installation will be FULLY AUTOMATIC" -ForegroundColor Green
    }
}

# Configure firmware
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
$hdd = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $dvd,$hdd
Write-Host "Boot order configured: DVD (netinstall ISO) first"

# Configure Windows Firewall for HTTP (port 8000)
Write-Host "Configuring Windows Firewall for HTTP file server..."
$fwRule = Get-NetFirewallRule -DisplayName "ai-sandbox-http" -ErrorAction SilentlyContinue
if (-not $fwRule) {
    New-NetFirewallRule -DisplayName "ai-sandbox-http" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Firewall rule created for HTTP (port 8000)" -ForegroundColor Green
} else {
    Write-Host "Firewall rule already exists for HTTP"
}

# Start HTTP server in background
Write-Host ""
Write-Host "Starting HTTP file server for VM installation..."
$serverScript = Join-Path $Base "tools\serve-kickstart.ps1"

# Start PowerShell in a new window to run the HTTP server
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$Base'; & '$serverScript'" -WindowStyle Normal

Write-Host "HTTP server started in separate window (keep it running!)" -ForegroundColor Green
Start-Sleep -Seconds 2

Start-VM -VMName $VMName
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  VM STARTED - FULLY AUTOMATIC INSTALL" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "CRITICAL: HTTP server window must stay open!" -ForegroundColor Yellow -BackgroundColor Red
Write-Host "The VM downloads files from: http://<your-ip>:8000/" -ForegroundColor Yellow
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open Hyper-V Manager" -ForegroundColor White
Write-Host "   (Search 'Hyper-V Manager' in Start menu)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Connect to VM '$VMName'" -ForegroundColor White
Write-Host "   (Double-click or Right-click -> Connect)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Watch automated installation:" -ForegroundColor White
Write-Host "   - Kickstart auto-detects (~2 min)" -ForegroundColor Gray
Write-Host "   - Fedora installs (~20-30 min)" -ForegroundColor Gray
Write-Host "   - VM reboots" -ForegroundColor Gray
Write-Host "   - GNOME welcome (skip through)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Login:" -ForegroundColor White
Write-Host "   - Username: ai" -ForegroundColor Cyan
Write-Host "   - Password: (see secrets\vm-password.env)" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Background setup runs automatically:" -ForegroundColor White
Write-Host "   - Downloads config from HTTP server" -ForegroundColor Gray
Write-Host "   - Installs Podman, Cursor, Claude (~10-20 min)" -ForegroundColor Gray
Write-Host "   - Terminator opens when complete" -ForegroundColor Gray
Write-Host ""
Write-Host "TOTAL TIME: 30-50 minutes" -ForegroundColor Yellow
Write-Host ""
Write-Host "You can close the HTTP server after Terminator opens." -ForegroundColor Cyan
Write-Host ""
