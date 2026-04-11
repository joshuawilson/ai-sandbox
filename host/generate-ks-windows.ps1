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

        # Parse bash-style single-quoted string: 'value' or 'val'\''ue' for apostrophes
        if ($val -match "^'.*'$") {
            # Handle bash '\'' escape sequence (end quote, escaped quote, start quote)
            # Replace '\'' with just ' then remove outer quotes
            $val = $val -replace "'\\''", "'"
            if ($val.Length -ge 2) {
                $val = $val.Substring(1, $val.Length - 2)
            }
        }
        # Also handle double-quoted strings
        elseif ($val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Substring(1, $val.Length - 2)
        }

        $VM_PASSWORD = $val
    }
}

if ([string]::IsNullOrEmpty($VM_PASSWORD)) {
    Write-Error "VM_PASSWORD not set in $EnvFile"
}

Write-Host "Password read from file: [length=$($VM_PASSWORD.Length)]" -ForegroundColor Gray

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

# Generate password hash (same method as Linux: pass as argument)
# OpenSSL from Git for Windows handles arguments the same as Unix
Write-Host "Generating password hash..." -ForegroundColor Gray
$HashOutput = (& $openssl passwd -6 $VM_PASSWORD 2>&1)

# Filter to only the hash line (starts with $6$)
$Hash = ($HashOutput | Where-Object { $_ -match '^\$6\$' } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($Hash)) {
    Write-Host "OpenSSL output:" -ForegroundColor Yellow
    $HashOutput | ForEach-Object { Write-Host "  $_" }
    Write-Error "openssl passwd failed to generate hash"
}
$Hash = $Hash.Trim()

# Verify the hash works with the password
Write-Host "Verifying password hash..." -ForegroundColor Gray
$tempFile = [System.IO.Path]::GetTempFileName()
try {
    # Save hash to temp file for verification
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tempFile, $Hash, $utf8NoBom)

    # Test if password matches hash (openssl exits 0 if match)
    $verifyOutput = (echo $VM_PASSWORD | & $openssl passwd -6 -salt (($Hash -split '\$')[2]) 2>&1)
    if ($verifyOutput -match '^\$6\$') {
        $generatedHash = ($verifyOutput | Where-Object { $_ -match '^\$6\$' } | Select-Object -First 1).Trim()
        if ($generatedHash -eq $Hash) {
            Write-Host "✓ Password hash verified successfully" -ForegroundColor Green
        } else {
            Write-Warning "Password hash verification failed - hash mismatch"
        }
    }
} catch {
    Write-Warning "Could not verify hash: $_"
} finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

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

Write-Host "ks.cfg written: $Output" -ForegroundColor Green
Write-Host "Password hash: $($Hash.Substring(0,20))..." -ForegroundColor Gray
Write-Host "SSH key: $($SshKey.Substring(0,30))..." -ForegroundColor Gray
Write-Host "Guest UID: $OwnerUid" -ForegroundColor Gray
Write-Host "Windows host IP: $WindowsIP (VM will download files via HTTP)" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Keep HTTP server running during installation:"
Write-Host '  .\tools\serve-kickstart.ps1'
