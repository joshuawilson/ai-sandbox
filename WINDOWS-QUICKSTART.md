# Windows Quick Start Guide

Complete setup in 6 steps. Total time: ~1 hour (mostly automated).

## Prerequisites

- Windows 10/11 **Pro, Enterprise, or Education** (not Home)
- 80+ GB free disk space
- Administrator access

## Step 1: Clone Repository

```powershell
cd $env:USERPROFILE
git clone <repo-url> ai-sandbox
cd ai-sandbox
```

## Step 2: Run Setup (Elevated PowerShell)

Right-click PowerShell → Run as Administrator

```powershell
cd $env:USERPROFILE\ai-sandbox
Set-ExecutionPolicy -Scope Process Bypass
.\setup-host.ps1
```

Answer `Y` when prompted to configure VM settings and password.

**If prompted to reboot:** Restart Windows, then run `.\setup-host.ps1 -CheckOnly`

## Step 3: Install ADK (One-Time)

Still in elevated PowerShell:

```powershell
.\host\install-adk-windows.ps1
```

This takes 5-10 minutes and provides tools for ISO creation.

## Step 4: Add SSH Key to GitHub/GitLab

```powershell
# View public key
Get-Content secrets\ssh\id_ed25519.pub

# Copy the output and add to:
# GitHub: Settings → SSH and GPG keys → New SSH key
# GitLab: Preferences → SSH Keys → Add new key
```

## Step 5: Create SMB Password

```powershell
.\host\write-smb-password-env.ps1
```

Enter your **Windows login password** (what you use to log into Windows).

## Step 6: Create and Start VM

```powershell
.\host\create-vm-windows-netinstall.ps1
```

**The VM starts automatically!**

## Step 7: Watch Installation (Hands-Off!)

1. **Open Hyper-V Manager** (search in Start menu)
2. **Find VM** named `ai-sandbox`
3. **Double-click** to open console
4. **Watch** the automated installation:
   - Kickstart auto-detects (~2 min)
   - Fedora installs (~20-30 min)
   - VM reboots
   - GNOME welcome screens (skip through)

5. **Login** when prompted:
   - Username: `ai`
   - Password: (in `secrets\vm-password.env`)

6. **Wait** for background setup (~10-20 min):
   - SMB share mounts
   - Podman, Cursor, Claude install
   - **Terminator opens** when complete ✅

**Total: 30-50 minutes (hands-off)**

## Step 8: Start Using It

Inside the VM (in Terminator):

```bash
# Start your first project
bash ~/ai-sandbox/config/start-day.sh

# This creates workspace/default and opens Cursor
```

## Daily Workflow

**Start VM:**
```powershell
.\start-vm.ps1
```

**Stop VM:**
```powershell
.\stop-vm.ps1
```

**In the VM** after login:
```bash
bash ~/ai-sandbox/config/start-day.sh
```

## Troubleshooting

**VM won't start?**
```powershell
Get-VM -Name ai-sandbox | Select-Object State
# Should show "Running" or "Off"
```

**Can't connect to VM?**
- Open Hyper-V Manager
- Right-click VM → Connect

**Installation seems stuck?**
- Wait - large downloads can take time
- Check progress in Hyper-V Manager console

**Forgot VM password?**
```powershell
Get-Content secrets\vm-password.env
```

**Need to start over?**
```powershell
.\stop-vm.ps1 -Remove
.\host\create-vm-windows-netinstall.ps1
```

## What's Installed

After setup completes, the VM has:
- ✅ Fedora Workstation (GNOME desktop)
- ✅ Podman (container runtime)
- ✅ Cursor IDE
- ✅ Claude Code CLI
- ✅ Terminator (terminal)
- ✅ Dev tools (git, node, python, go, etc.)
- ✅ Auto-mounted access to Windows `ai-sandbox` folder

## File Locations

| Location | What It Is |
|----------|-----------|
| `C:\Users\You\ai-sandbox\workspace\` | Your projects (shared with VM) |
| `C:\Users\You\ai-sandbox\secrets\` | API keys, SSH keys (shared with VM) |
| Inside VM: `~/ai-sandbox/workspace/` | Same as Windows workspace folder |

Work survives VM rebuilds!

## Next Steps

See main [README.md](README.md) for:
- Claude Code configuration
- MCP servers setup
- Container customization
- Advanced workflows
