# Merge host/vm-host.env (if present) with defaults for Hyper-V / shared scripts.
# Dot-source from host/*.ps1:  . "$PSScriptRoot\lib\read-vm-host-env.ps1"

function Get-SandboxRepoRoot {
    param([string]$HostScriptDirectory)
    if ($env:AI_SANDBOX_HOME) { return $env:AI_SANDBOX_HOME }
    if ($env:SANDBOX) { return $env:SANDBOX }
    return (Resolve-Path -LiteralPath (Join-Path $HostScriptDirectory "..")).Path
}

function Get-VmHostEnvMerged {
    param([string]$RepoRoot)

    $merged = [ordered]@{
        VM_NAME               = "ai-sandbox"
        VM_DISK_GB            = "80"
        VM_MEMORY_MIB         = "32768"
        VM_VCPUS              = "8"
        VM_CPU_MODE           = "host-model"
        FEDORA_VER            = "43"
        VM_DIR                = "/var/lib/libvirt/images"
        VM_LIBVIRT_NETWORK    = "default"
        VM_ISO_URL            = "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-43-1.6.iso"
        VM_NETINSTALL_URL     = "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Server/x86_64/iso/Fedora-Server-netinst-x86_64-43-1.6.iso"
        VM_HYPERV_SWITCH      = "Default Switch"
    }

    $path = Join-Path $RepoRoot "host\vm-host.env"
    if (-not (Test-Path -LiteralPath $path)) {
        return $merged
    }

    Get-Content -LiteralPath $path | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\s*#' -or $line -eq '') { return }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { return }
        $key = $line.Substring(0, $eq).Trim()
        $val = $line.Substring($eq + 1).Trim()
        if ($val.Length -ge 2 -and $val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Substring(1, $val.Length - 2)
        } elseif ($val.Length -ge 2 -and $val.StartsWith("'") -and $val.EndsWith("'")) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        $merged[$key] = $val
    }

    return $merged
}
