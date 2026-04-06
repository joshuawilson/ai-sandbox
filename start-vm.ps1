# Boot an existing Hyper-V VM. First-time: .\setup-host.ps1 then host\create-vm-windows.ps1
$RepoRoot = $PSScriptRoot
& (Join-Path $RepoRoot "host\start-vm-windows.ps1") @args
exit $LASTEXITCODE
