#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
  Cleanup script to undo all changes made during AI Sandbox Windows setup.

  Run this to return your Windows system to its original state.

  WARNING: This will:
  - Remove the VM and all its data
  - Remove SMB shares
  - Remove firewall rules
  - Revert registry changes
  - Optionally remove installed software (ADK, Git)
  - Optionally remove the ai-sandbox folder
#>

param(
    [switch]$RemoveGit,
    [switch]$RemoveADK,
    [switch]$RemoveRepo,
    [switch]$Help
)

$ErrorActionPreference = "Continue"

if ($Help) {
    Write-Host @"
Usage: .\host\cleanup-windows-host.ps1 [options]

Removes AI Sandbox configuration from Windows host.

Options:
  -RemoveGit    Also uninstall Git for Windows
  -RemoveADK    Also uninstall Windows ADK
  -RemoveRepo   Also delete the ai-sandbox repository folder

Without options, only removes:
  - Hyper-V VM
  - SMB shares
  - Firewall rules
  - Registry changes

Examples:
  .\host\cleanup-windows-host.ps1                    # Keep software, just remove config
  .\host\cleanup-windows-host.ps1 -RemoveRepo        # Also delete the repo
  .\host\cleanup-windows-host.ps1 -RemoveGit -RemoveADK -RemoveRepo  # Full removal
"@
    exit 0
}

Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  AI Sandbox Windows Cleanup" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will remove AI Sandbox configuration from your system." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue? [y/N]"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "Cancelled."
    exit 0
}

Write-Host ""
Write-Host "=== Removing Hyper-V VM ===" -ForegroundColor Cyan

# Stop and remove VM
$vmName = "ai-sandbox"
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm) {
    Write-Host "Stopping VM: $vmName"
    Stop-VM -Name $vmName -TurnOff -Force -ErrorAction SilentlyContinue
    Write-Host "Removing VM: $vmName"
    Remove-VM -Name $vmName -Force -ErrorAction SilentlyContinue
    Write-Host "VM removed" -ForegroundColor Green
} else {
    Write-Host "VM not found (already removed)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Removing SMB Share ===" -ForegroundColor Cyan

$shareName = "ai-sandbox"
$share = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
if ($share) {
    Write-Host "Removing SMB share: $shareName"
    Remove-SmbShare -Name $shareName -Force
    Write-Host "SMB share removed" -ForegroundColor Green
} else {
    Write-Host "SMB share not found (already removed)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Removing Firewall Rules ===" -ForegroundColor Cyan

$rules = @("ai-sandbox-http", "ai-sandbox-kickstart", "SMB ai-sandbox")
foreach ($ruleName in $rules) {
    $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($rule) {
        Write-Host "Removing firewall rule: $ruleName"
        Remove-NetFirewallRule -DisplayName $ruleName
    }
}
Write-Host "Firewall rules cleaned up" -ForegroundColor Green

Write-Host ""
Write-Host "=== Reverting Registry Changes ===" -ForegroundColor Cyan

# Revert AllowInsecureGuestAuth
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    $regName = "AllowInsecureGuestAuth"

    if (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue) {
        Write-Host "Removing AllowInsecureGuestAuth registry value"
        Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        Restart-Service LanmanWorkstation -Force
        Write-Host "Registry cleaned up (service restarted)" -ForegroundColor Green
    } else {
        Write-Host "Registry value not found (already removed)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not revert registry: $_"
}

Write-Host ""
Write-Host "=== Cleaning VM Files ===" -ForegroundColor Cyan

# Remove vm directory if it exists
$repoBase = $env:USERPROFILE
if ($PSScriptRoot) {
    $repoBase = Split-Path (Split-Path $PSScriptRoot)
}

$vmDir = Join-Path $repoBase "ai-sandbox\vm"
if (Test-Path $vmDir) {
    Write-Host "Removing VM files: $vmDir"
    Remove-Item -Path $vmDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "VM files removed" -ForegroundColor Green
} else {
    Write-Host "VM directory not found" -ForegroundColor Gray
}

if ($RemoveGit) {
    Write-Host ""
    Write-Host "=== Uninstalling Git for Windows ===" -ForegroundColor Cyan

    $gitUninstall = Get-ChildItem "C:\Program Files\Git\unins*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gitUninstall) {
        Write-Host "Running Git uninstaller..."
        Start-Process -FilePath $gitUninstall.FullName -ArgumentList "/SILENT" -Wait
        Write-Host "Git uninstalled" -ForegroundColor Green
    } else {
        Write-Host "Git uninstaller not found" -ForegroundColor Gray
    }
}

if ($RemoveADK) {
    Write-Host ""
    Write-Host "=== Uninstalling Windows ADK ===" -ForegroundColor Cyan

    # ADK uninstall is complex, just point user to Control Panel
    Write-Host "Please uninstall Windows ADK manually:" -ForegroundColor Yellow
    Write-Host "  1. Open Settings -> Apps -> Installed apps"
    Write-Host "  2. Search for 'Windows Assessment'"
    Write-Host "  3. Uninstall 'Windows Assessment and Deployment Kit'"
}

if ($RemoveRepo) {
    Write-Host ""
    Write-Host "=== Removing Repository ===" -ForegroundColor Cyan

    $repoPath = Join-Path $repoBase "ai-sandbox"
    if (Test-Path $repoPath) {
        Write-Host "This will delete: $repoPath" -ForegroundColor Yellow
        $confirmRepo = Read-Host "Are you sure? [y/N]"
        if ($confirmRepo -match '^[Yy]') {
            Remove-Item -Path $repoPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Repository removed" -ForegroundColor Green
        } else {
            Write-Host "Repository kept" -ForegroundColor Gray
        }
    } else {
        Write-Host "Repository not found" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Cleanup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "What was removed:" -ForegroundColor White
Write-Host "  ✓ Hyper-V VM and disk files"
Write-Host "  ✓ SMB share 'ai-sandbox'"
Write-Host "  ✓ Firewall rules"
Write-Host "  ✓ Registry changes"
if ($RemoveGit) { Write-Host "  ✓ Git for Windows" }
if ($RemoveADK) { Write-Host "  ! Windows ADK (manual uninstall required)" }
if ($RemoveRepo) { Write-Host "  ✓ ai-sandbox repository" }
Write-Host ""
Write-Host "What was NOT changed:" -ForegroundColor White
Write-Host "  - Hyper-V feature (still enabled)"
Write-Host "  - Windows user accounts"
Write-Host "  - Network configuration"
if (-not $RemoveGit) { Write-Host "  - Git for Windows (still installed)" }
if (-not $RemoveADK) { Write-Host "  - Windows ADK (still installed)" }
if (-not $RemoveRepo) { Write-Host "  - ai-sandbox repository folder (still exists)" }
Write-Host ""
Write-Host "To fully remove Hyper-V:" -ForegroundColor Cyan
Write-Host "  Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All"
Write-Host "  (requires reboot)"
Write-Host ""
