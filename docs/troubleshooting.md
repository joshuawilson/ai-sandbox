# Troubleshooting

Common issues and fixes for AI Sandbox on all platforms.

---

## All Platforms

| Symptom | What to check |
|---------|---------------|
| **First-boot service fails** | `journalctl -u ai-sandbox-firstboot.service -b`; virtiofs tag names match `host/create-vm-linux.sh`. |
| **`start-container` says container exists** | `podman rm -f ai-dev-<name>` or `stop-container.sh`, then start again. |
| **Guest: `Permission denied` on `/workspace` inside container** | Ensure `start-container.sh` runs with `--user "$(id -u):$(id -g)"` (not image UID 1000). On virtiofs, `start-container.sh` auto-adds `--security-opt label=disable`. Override via `AI_SANDBOX_PODMAN_LABEL_DISABLE` in `config/container.env`. |
| **Guest: `Permission denied` on workspace outside container** | Fix ownership: `chown -R "$(id -u):$(id -g)" ~/ai-sandbox/workspace/<name>` |
| **Guest: Permission denied on `/mnt/host-secrets` or `secrets/ssh`** | With virtiofs passthrough, `secrets/` is mode 700 for the host owner's UID. Guest user `ai` must have that same numeric UID. Regenerate `ks.cfg` (`host/generate-ks-fedora.sh`) and reinstall the VM. Compare `id -u` on the host with `id -u ai` in the guest. |
| **Claude CLI / `~/.claude` missing after rebuild** | **API path:** `secrets/claude_api_key` or `workspace/.ai-sandbox-private/claude_api_key`, then `install-inside-vm.sh`. **Vertex:** edit host `claude-vertex.env`, then `bash ~/ai-sandbox/config/sync-claude-vertex-env.sh` in the guest. |
| **Guest: `syntax error near unexpected token` sourcing `claude-vertex.env`** | The `ANTHROPIC_VERTEX_PROJECT_ID` value was not a real project ID. Fix or remove `~/.config/ai-sandbox/claude-vertex.env` and host `secrets/claude-vertex.env`, then re-run `setup-claude.sh`. |
| **Cursor asks to sign in every time** | Session is in the guest profile, not `secrets/`. After a new disk, sign in again. |
| **Guest: black screen, no GDM (hang at boot)** | The virtiofs mount service may block GDM. Regenerate `ks.cfg` and reinstall, or edit `/etc/systemd/system/ai-sandbox-virtiofs-mounts.service` and `systemctl daemon-reload`. |
| **Firewall blocks something** | Rules are on zone `block`; add services/ports with `--zone=block`. |
| **Domain already exists (`virt-install`)** | Undefine/remove old VM or pick a new name. |
| **First-boot fails (no virtiofs)** | Guest not created with `host/create-vm-linux.sh` virtiofs tags. Use SMB + `config/cifs.env.example`, then `ensure-sandbox-mounts.sh` and `install-inside-vm.sh` manually. |

---

## Linux

| Symptom | What to check |
|---------|---------------|
| **`host/generate-ks-fedora.sh` fails** | `secrets/ssh/id_ed25519.pub` must exist. Run `host/install-virt-linux.sh` first. |
| **`virt-install` / netinst fails** | Check HTTPS access to Fedora mirrors. Verify `libvirtd` is running and `virsh net-list` shows **default** active. |

---

## macOS

| Symptom | What to check |
|---------|---------------|
| **UTM not detected** | Install UTM 4+ from the App Store or [mac.getutm.app](https://mac.getutm.app). `host/check-host-mac.sh` verifies `/Applications/UTM.app` exists. |
| **Apple Silicon: wrong ISO** | Use the **aarch64** Fedora media, not x86_64. |

---

## Windows

| Symptom | What to check |
|---------|---------------|
| **Hyper-V not available** | Verify edition with `winver` — Windows Home does not support Hyper-V. Check Task Manager > Performance > CPU > Virtualization: Enabled. |
| **Virtual switch missing** | Open Hyper-V Manager > Actions > Virtual Switch Manager. Create a "Default Switch" or External switch. |
| **Git/OpenSSL not found** | Install [Git for Windows](https://git-scm.com/). Re-open PowerShell after installation. |
| **Python not found** | Install [Python 3](https://python.org). Ensure "Add to PATH" was checked during install. |
| **Permission denied running scripts** | Run: `Set-ExecutionPolicy -Scope Process Bypass` |
| **`host/generate-ks-windows.ps1` fails** | Git for Windows installed (`host/install-virt-windows.ps1`); `openssl.exe` under `Git\usr\bin`; `vm-password.env` is bash-style `VM_PASSWORD=...`. |
| **VM creation fails** | Check 80+ GB free disk. Ensure `secrets\vm-password.env` exists (`.\host\write-vm-password-env.ps1`). Verify `secrets\ssh\id_ed25519.pub` exists (`.\setup-host.ps1`). |
| **SMB share creation failed** | Windows Home doesn't support SMB sharing. Check file sharing is enabled in Settings > Network > Advanced sharing settings. Ensure your user account has a password set. Run as Administrator. |
| **Guest can't mount SMB share** | Verify share exists: `Get-SmbShare -Name ai-sandbox`. Check Windows Firewall allows SMB (port 445). Try from guest: `smbclient -L //HOSTNAME -U username`. Check `/etc/ai-sandbox/cifs.env` in guest. |
| **Kickstart ISO not created** | Run `.\host\install-adk-windows.ps1` to install Windows ADK. Fallback: use manual HTTP kickstart (see below). |
| **Boot loader did not load an operating system** | VM boot order is wrong. See fix below. |

### Windows: Manual HTTP Kickstart (No ADK)

If the kickstart ISO wasn't created, serve `ks.cfg` over HTTP instead:

1. **Terminal 1** (keep running):
   ```powershell
   .\tools\serve-kickstart.ps1
   ```

2. **Get your IP:**
   ```powershell
   ipconfig | Select-String "IPv4"
   ```

3. **In the VM console** when Fedora boots, press `e` to edit boot options. Find the `linuxefi` or `linux` line and append:
   ```
   inst.ks=http://YOUR-IP:8000/ks.cfg
   ```
   Press `Ctrl+X` to boot.

4. **If the firewall blocks it:**
   ```powershell
   New-NetFirewallRule -DisplayName "ai-sandbox-kickstart" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```

### Windows: Fix Boot Order

If you see "Boot loader did not load an operating system":

```powershell
Stop-VM -Name ai-sandbox -Force

$dvd = Get-VMDvdDrive -VMName ai-sandbox
$hdd = Get-VMHardDiskDrive -VMName ai-sandbox

Set-VMFirmware -VMName ai-sandbox -EnableSecureBoot Off
Set-VMFirmware -VMName ai-sandbox -BootOrder $dvd,$hdd

Start-VM -Name ai-sandbox
```

---

For architecture details, script inventory, and advanced operations, see the [spec index](../spec/README.md).
