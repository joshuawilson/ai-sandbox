#Requires -Version 5.1
<#
  Create Hyper-V VM using Fedora netinstall ISO for TRUE automatic kickstart.

  The netinstall ISO properly auto-detects OEMDRV kickstart volumes,
  unlike the Live ISO which requires manual boot parameter entry.

  This is the fully automatic option for Windows.
#>
param(
    [switch]$SkipSmbShare
)

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

# Create SMB share
if (-not $SkipSmbShare) {
    try {
        $shareName = "ai-sandbox"
        $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
        if ($existingShare) {
            Write-Host "SMB share already exists: \\$env:COMPUTERNAME\$shareName"
        } else {
            Write-Host "Creating SMB share: \\$env:COMPUTERNAME\$shareName"
            $SmbPasswordFile = Join-Path $Base "secrets\smb-password.env"
            if (Test-Path $SmbPasswordFile) {
                New-SmbShare -Name $shareName -Path $Base -FullAccess "$env:USERDOMAIN\$env:USERNAME" -Description "AI Sandbox (authenticated)" -ErrorAction Stop
                Write-Host "SMB share created (authenticated)"
            } else {
                New-SmbShare -Name $shareName -Path $Base -ReadAccess "Everyone" -Description "AI Sandbox (guest)" -ErrorAction Stop
                Grant-SmbShareAccess -Name $shareName -AccountName "$env:USERDOMAIN\$env:USERNAME" -AccessRight Full -Force -ErrorAction SilentlyContinue
                Write-Host "SMB share created (guest access)"
            }
        }
    } catch {
        Write-Warning "SMB share creation failed: $_"
    }
}

Start-VM -VMName $VMName
Write-Host ""
Write-Host "=== VM Started - FULLY AUTOMATIC INSTALLATION ===" -ForegroundColor Green
Write-Host ""
Write-Host "The netinstall ISO will:" -ForegroundColor White
Write-Host "  1. Boot and auto-detect the OEMDRV kickstart volume" -ForegroundColor Green
Write-Host "  2. Install Fedora Workstation automatically (~20-40 minutes)" -ForegroundColor Green
Write-Host "  3. Reboot into the desktop" -ForegroundColor Green
Write-Host "  4. Auto-mount SMB share" -ForegroundColor Green
Write-Host "  5. Auto-install Podman, Cursor, Claude" -ForegroundColor Green
Write-Host ""
Write-Host "NO MANUAL INTERVENTION NEEDED!" -ForegroundColor Green -BackgroundColor DarkGreen
Write-Host ""
Write-Host "Username: ai" -ForegroundColor Cyan
Write-Host "Password: (see secrets\vm-password.env)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Monitor progress in Hyper-V Manager console."
Write-Host "Total time: ~30-50 minutes depending on network speed."
