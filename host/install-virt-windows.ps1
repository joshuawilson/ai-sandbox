#Requires -RunAsAdministrator
<#
  Host bootstrap for the AI sandbox on Windows: Hyper-V, directories, Git + OpenSSH, sandbox SSH key.
  Run from an elevated PowerShell:  Set-ExecutionPolicy -Scope Process Bypass; .\host\install-virt-windows.ps1
  (Or use .\setup-host.ps1 from repo root.)
#>

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir

$dirs = @(
    (Join-Path $Base "config"),
    (Join-Path $Base "secrets\ssh"),
    (Join-Path $Base "workspace"),
    (Join-Path $Base "logs")
)
New-Item -ItemType Directory -Force -Path $dirs | Out-Null

$ws = Join-Path $Base "workspace"
$wpLegacy = Join-Path $Base "workspace\projects"
if (Test-Path $wpLegacy) {
    Get-ChildItem -Path $wpLegacy -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = Join-Path $ws $_.Name
        if (-not (Test-Path $dest)) { Move-Item -Path $_.FullName -Destination $dest -Force }
    }
    Remove-Item -Path $wpLegacy -Recurse -Force -ErrorAction SilentlyContinue
}

$legacyProjects = Join-Path $Base "projects"
if (Test-Path $legacyProjects) {
    if ((Get-ChildItem -Path $legacyProjects -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
        Copy-Item -Path (Join-Path $legacyProjects "*") -Destination $ws -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $legacyProjects -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Enabling Hyper-V (reboot may be required)..."
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart

$gitSshCheck = "C:\Program Files\Git\usr\bin\ssh-keygen.exe"
if (Test-Path $gitSshCheck) {
    Write-Host "Git already installed, skipping download."
} else {
    Write-Host "Installing Git (includes Git Bash and ssh-keygen)..."
    $gitInstaller = Join-Path $env:TEMP "git-installer.exe"
    Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-64-bit.exe" -OutFile $gitInstaller -UseBasicParsing
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
    Remove-Item -Force $gitInstaller -ErrorAction SilentlyContinue
}

$gitSsh = "C:\Program Files\Git\usr\bin\ssh-keygen.exe"
$key = Join-Path $Base "secrets\ssh\id_ed25519"
if (-not (Test-Path $key)) {
    Write-Host "Generating sandbox SSH key..."
    if (-not (Test-Path $gitSsh)) {
        Write-Error "ssh-keygen not found at $gitSsh. Re-open PowerShell after Git install or add Git usr\bin to PATH."
    }
    & $gitSsh -t ed25519 -f $key -N ""
    Write-Host ""
}

if (Test-Path "$key.pub") {
    Write-Host "Add this public key to GitHub/GitLab:"
    Get-Content "$key.pub"
} elseif (Test-Path "$env:USERPROFILE\.ssh\id_ed25519.pub") {
    Write-Host "Sandbox key not found at $key.pub, but found a key at the default location:"
    Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
} else {
    Write-Host "SSH key already exists: $key"
    Write-Host "Public key (.pub) not found. Copy your existing public key to: $key.pub"
}

Write-Host ""
Write-Host "Install complete. Log out and back in if Hyper-V asked for a reboot."
Write-Host "Verify:  .\setup-host.ps1 -CheckOnly   (same as .\host\check-host-windows.ps1)"
Write-Host "Use Git Bash for tools/serve-kickstart.sh, or PowerShell: tools/serve-kickstart.ps1 (needs Python)."
Write-Host "Create a VM: .\host\create-vm-windows.ps1  (optional: -CreateSmbShare for \\hostname\ai-sandbox)."
