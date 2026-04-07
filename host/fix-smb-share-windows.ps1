#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
  Remove and recreate the SMB share with proper guest access settings.
#>

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir

$shareName = "ai-sandbox"

Write-Host "=== Checking SMB Share Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Check if share exists
$existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue

if ($existingShare) {
    Write-Host "Current share found:" -ForegroundColor Yellow
    Write-Host "  Name: $($existingShare.Name)"
    Write-Host "  Path: $($existingShare.Path)"
    Write-Host "  Description: $($existingShare.Description)"
    Write-Host ""

    # Check permissions
    Write-Host "Current permissions:" -ForegroundColor Yellow
    Get-SmbShareAccess -Name $shareName | Format-Table -AutoSize

    Write-Host ""
    $remove = Read-Host "Remove and recreate with guest access? [Y/n]"
    if ($remove -eq '' -or $remove -match '^[Yy]') {
        Write-Host "Removing old share..." -ForegroundColor Yellow
        Remove-SmbShare -Name $shareName -Force
        Write-Host "Share removed." -ForegroundColor Green
    } else {
        Write-Host "Keeping existing share. Exiting."
        exit 0
    }
}

Write-Host ""
Write-Host "Creating new SMB share with guest access..." -ForegroundColor Cyan

try {
    # Create the share with Everyone read access
    New-SmbShare -Name $shareName -Path $Base -ReadAccess "Everyone" -Description "AI Sandbox shared folders" -ErrorAction Stop
    Write-Host "Share created successfully!" -ForegroundColor Green

    # Grant full access to current user
    Write-Host "Granting full access to $env:USERNAME..." -ForegroundColor Cyan
    Grant-SmbShareAccess -Name $shareName -AccountName "$env:USERDOMAIN\$env:USERNAME" -AccessRight Full -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "=== Share Configuration ===" -ForegroundColor Green
    Get-SmbShare -Name $shareName | Format-List

    Write-Host "=== Share Permissions ===" -ForegroundColor Green
    Get-SmbShareAccess -Name $shareName | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Share ready: \\$env:COMPUTERNAME\$shareName" -ForegroundColor Green
    Write-Host "Guest access enabled - no password required from VM" -ForegroundColor Green

} catch {
    Write-Error "Failed to create SMB share: $_"
    exit 1
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Regenerate kickstart: .\host\generate-ks-windows.ps1"
Write-Host "2. Verify ks.cfg contains CIFS_GUEST=1 (not username/password)"
Write-Host "3. Stop VM if running: .\stop-vm.ps1 -Remove"
Write-Host "4. Recreate VM: .\host\create-vm-windows.ps1"
