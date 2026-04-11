#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$Template = Join-Path $Base "host\ks.template-windows-http.cfg"
$Output = Join-Path $Base "ks.cfg"
$EnvFile = Join-Path $Base "secrets\vm-password.env"

Write-Host "Generating Kickstart (Windows with HTTP file delivery)..."

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing $EnvFile (create VM_PASSWORD=... in bash env format)."
}

$VM_PASSWORD = $null
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*VM_PASSWORD\s*=\s*(.+)\s*$') {
        $val = $Matches[1].Trim()
        if (($val.StartsWith("'") -and $val.EndsWith("'")) -or ($val.StartsWith('"') -and $val.EndsWith('"'))) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        $VM_PASSWORD = $val
    }
}

if ([string]::IsNullOrEmpty($VM_PASSWORD)) {
    Write-Error "VM_PASSWORD not set in $EnvFile"
}

$pfx86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
$candidates = @(
    (Join-Path $env:ProgramFiles "Git\usr\bin\openssl.exe")
)
if ($pfx86) {
    $candidates += (Join-Path $pfx86 "Git\usr\bin\openssl.exe")
}
$openssl = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $openssl) {
    Write-Error "OpenSSL not found under Git for Windows. Run install-virt-windows.ps1 first."
}

# openssl passwd -6 prints "Password:" to stderr (cosmetic prompt)
# Use -stdin flag and suppress all error streams
$Hash = (echo $VM_PASSWORD | & $openssl passwd -6 -stdin 2>&1 | Where-Object { $_ -notmatch '^Password:' })
if ([string]::IsNullOrWhiteSpace($Hash)) {
    Write-Error "openssl passwd failed"
}
$Hash = $Hash.Trim()

$PubPath = Join-Path $Base "secrets\ssh\id_ed25519.pub"
if (-not (Test-Path $PubPath)) {
    Write-Error "Missing $PubPath. Run install-virt-windows.ps1 first."
}
$SshKey = (Get-Content $PubPath -Raw).Trim()

# Avoid PowerShell -replace: password hashes contain $ which breaks double-quoted expansion
# Linux guest must match secrets/ owner UID for SMB uid mapping.
$OwnerUid = $env:AI_SANDBOX_OWNER_UID
if ([string]::IsNullOrWhiteSpace($OwnerUid)) { $OwnerUid = "1000" }

# HTTP configuration for Windows host - get primary IP
$WindowsIP = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -First 1).IPAddress

if (-not $WindowsIP) {
    Write-Warning "Could not detect Windows IP address - using 192.168.1.1 as placeholder"
    $WindowsIP = "192.168.1.1"
}

$Content = [System.IO.File]::ReadAllText($Template)
$Content = $Content.Replace("__PASSWORD_HASH__", $Hash)
$Content = $Content.Replace("__SSH_KEY__", $SshKey)
$Content = $Content.Replace("__SANDBOX_OWNER_UID__", $OwnerUid)
$Content = $Content.Replace("__WINDOWS_HOST_IP__", $WindowsIP)
[System.IO.File]::WriteAllText($Output, $Content)

Write-Host "ks.cfg written: $Output"
Write-Host "Windows host IP: $WindowsIP (VM will download files via HTTP)"
Write-Host ""
Write-Host "IMPORTANT: Keep HTTP server running during installation:"
Write-Host "  .\tools\serve-kickstart.ps1"
