# AI Sandbox

Fedora VM + Podman dev containers for **Cursor** and **Claude Code**. Your editor and agents run **inside the VM**; repos and secrets live in **host-backed** directories so work survives VM disk rebuilds.

---

## Requirements

- **CPU virtualization** enabled in firmware (VT-x / AMD-V).
- **Fedora Linux:** `./setup-host.sh` installs libvirt/KVM; you must **log out and back in** after being added to the `libvirt` group, then `./setup-host.sh --check-only` until it passes.
- **macOS:** UTM (see [spec/how/bootstrap.md](spec/how/bootstrap.md)).
- **Windows:** Windows Pro, Enterprise, or Education (Hyper-V not available on Home edition); elevated PowerShell for `.\setup-host.ps1`.
  - Python 3.x (for kickstart server)
  - At least 80 GB free disk space (default VM size)

---

## First-time setup

Do these in order. Paths assume the repo is at **`~/ai-sandbox`** on the host (recommended). Other locations work if you set **`SANDBOX`** / **`AI_SANDBOX_HOME`** to the repo root.

**Note for Windows users:** See the [Windows Setup Guide](#windows-setup-guide) below for detailed Windows-specific instructions.

### 1. Host: hypervisor and repo layout

```bash
cd ~/ai-sandbox
./setup-host.sh
```

On Fedora, after a **new** `libvirt` group membership: **log out, log in**, then:

```bash
./setup-host.sh --check-only
```

### 2. Host: VM settings and guest password

When `setup-host` finishes, run the optional wizard, or configure by hand:

- **`host/configure-vm-host.sh`** (or **`.\host\configure-vm-host.ps1`** on Windows) → writes **`host/vm-host.env`** and usually **`secrets/vm-password.env`** (password for guest user **`ai`**).
- Or copy **`host/vm-host.env.example`** → **`host/vm-host.env`** and create **`secrets/vm-password.env`** with **`host/write-vm-password-env.sh`** / **`.\host\write-vm-password-env.ps1`**.

Skip the wizard during setup: **`--skip-vm-config`**, **`-SkipVmConfig`**, or **`SKIP_VM_CONFIGURE=1`**.

### 3. Host: create the VM

- **Fedora:** `host/create-vm-linux.sh` (generates **`ks.cfg`** and installs the guest).
- **macOS / Windows:** follow the output of **`setup-host`** and **[spec/how/bootstrap.md](spec/how/bootstrap.md)** (kickstart over HTTP, UTM, Hyper-V).

Wait for the install to finish and the guest to reboot into the desktop.

### 4. Guest: provisioning

First boot runs **`~/ai-sandbox/config/install-inside-vm.sh`** automatically (Podman, **`ai-dev`** image, Cursor RPM, firewall, Claude wiring). If that did not run:

```bash
sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai
~/ai-sandbox/config/install-inside-vm.sh
```

**How to tell it finished:** The first-boot service only creates **`/var/lib/ai-sandbox-firstboot.done`** after **`install-inside-vm.sh`** exits successfully. In the guest, run:

```bash
test -f /var/lib/ai-sandbox-firstboot.done && echo "First-boot provisioning completed."
systemctl status ai-sandbox-firstboot.service
journalctl -u ai-sandbox-firstboot.service -b --no-pager
```

If the marker file is missing, read the journal for errors (often mounts or missing **`secrets/ssh`** on the host). Quick sanity checks: **`podman images | grep ai-dev`**, **`command -v cursor`**.

### 5. Guest: Claude and Cursor

- **Cursor:** sign in inside the app (guest only; not stored in this repo).
- **Claude Code:** after graphical login, a terminal may open for **`setup-claude.sh`**; or run **`bash ~/ai-sandbox/config/setup-claude.sh`** yourself. Put API or Vertex secrets on the **host** under **`secrets/`** (see **[spec/how/runtime.md](spec/how/runtime.md)**).

### 6. Guest: project directory and dev container

Each project is a folder **`~/ai-sandbox/workspace/<name>/`** (same as **`workspace/<name>/`** on the host). Clone or create your repo there, or let the next step create **`default`**.

Start the **default** project’s container (detached) and open **Cursor** on that folder:

```bash
bash ~/ai-sandbox/config/start-day.sh
```

(`start-dev.sh` is the same.)

- **Shell inside the container:** `bash ~/ai-sandbox/config/start-container.sh <name>` — same tree as **`/workspace`** and as **`~/ai-sandbox/workspace/<name>`** (**`HOME`** is **`/home/dev`**; that path is bind-mounted for you).
- **Another project:** `bash ~/ai-sandbox/config/create-project.sh <name>` or `start-container.sh <name>`

`podman run -d` prints a long container ID when **`start-day.sh`** succeeds—that is normal. Check with **`podman ps`** (**`ai-dev-<name>`**).

---

## Windows Setup Guide

Complete step-by-step instructions for setting up the AI Sandbox on Windows.

### Prerequisites

Before starting, ensure you have:

1. **Windows Edition:** Windows 10/11 Pro, Enterprise, or Education
   - Windows Home does **not** support Hyper-V
   - To check: Press `Win+R`, type `winver`, and check your edition
2. **Virtualization enabled** in BIOS/UEFI:
   - Restart and enter BIOS/UEFI setup (usually `F2`, `Del`, or `F10` during boot)
   - Enable Intel VT-x or AMD-V
   - Save and reboot
3. **Python 3.x** installed and on PATH:
   - Download from [python.org](https://python.org)
   - During install, check **"Add Python to PATH"**
   - Verify: Open PowerShell and run `python --version`
4. **At least 80 GB free disk space** (for the default VM configuration)

### Step 1: Clone the Repository

Open PowerShell and clone the repository to your preferred location:

```powershell
# Recommended location: C:\Users\<YourUsername>\ai-sandbox
cd $env:USERPROFILE
git clone https://github.com/your-org/ai-sandbox.git
cd ai-sandbox
```

**Custom location:** If cloning elsewhere, set the environment variable:
```powershell
$env:AI_SANDBOX_HOME = "C:\path\to\ai-sandbox"
```

### Step 2: Run Host Setup

Open an **elevated** (Administrator) PowerShell window:

1. Right-click **Start** → **Windows PowerShell (Admin)** or **Terminal (Admin)**
2. Navigate to your repo:
   ```powershell
   cd $env:USERPROFILE\ai-sandbox
   ```
3. Allow script execution for this session:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   ```
4. Run the setup script:
   ```powershell
   .\setup-host.ps1
   ```

This script will:
- Enable Hyper-V (may require a reboot)
- Install Git for Windows (if missing)
- Generate an SSH key at `secrets\ssh\id_ed25519`
- Create necessary directories

**If prompted to reboot:** Restart your computer, then re-run with the `-CheckOnly` flag:
```powershell
.\setup-host.ps1 -CheckOnly
```

### Step 3: Configure VM Settings

The setup script will prompt you to configure VM settings. If you skipped it, run:

```powershell
.\host\configure-vm-host.ps1
```

This interactive wizard configures:
- VM name (default: `ai-sandbox`)
- Disk size (default: 80 GB)
- RAM allocation (default: 32 GB / 32768 MiB)
- vCPU count (default: 8)
- Guest user password (auto-generated or manual)

Files created:
- `host\vm-host.env` — VM sizing parameters
- `secrets\vm-password.env` — Password for the `ai` user in the Fedora guest

### Step 4: Add SSH Key to Git Host

1. View your public key:
   ```powershell
   Get-Content secrets\ssh\id_ed25519.pub
   ```
2. Copy the output and add it to your Git hosting service:
   - **GitHub:** Settings → SSH and GPG keys → New SSH key
   - **GitLab:** Preferences → SSH Keys → Add new key

### Step 5: Create the VM

```powershell
.\host\create-vm-windows.ps1
```

This script will:
- Download the Fedora Workstation Live ISO (~2-3 GB)
- Create a virtual disk
- Generate kickstart configuration (`ks.cfg`)
- Create and start the Hyper-V VM

**Optional SMB sharing:**
```powershell
.\host\create-vm-windows.ps1 -CreateSmbShare
```
This creates a `\\COMPUTERNAME\ai-sandbox` SMB share for the guest.

### Step 6: Install Fedora (Kickstart)

For automated installation via kickstart:

1. **In a separate PowerShell window** (does not need to be elevated), start the kickstart server:
   ```powershell
   cd $env:USERPROFILE\ai-sandbox
   .\tools\serve-kickstart.ps1
   ```

2. **Find your Windows PC's LAN IP address:**
   ```powershell
   ipconfig
   # Look for IPv4 Address under your active network adapter
   # Example: 192.168.1.100
   ```

3. **Allow firewall access** (if prompted, or manually):
   ```powershell
   # Run in elevated PowerShell:
   New-NetFirewallRule -DisplayName "ai-sandbox-kickstart" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```

4. **In the Hyper-V VM console** (Anaconda boot screen):
   - Press `Tab` or `E` to edit boot options
   - Add to the boot line:
     ```
     inst.ks=http://<YOUR-WINDOWS-IP>:8000/ks.cfg
     ```
     Example: `inst.ks=http://192.168.1.100:8000/ks.cfg`
   - Press `Enter` to boot

5. Wait for the installation to complete (~15-30 minutes). The VM will automatically reboot into the Fedora desktop.

**Alternative - Manual Installation:**

If kickstart doesn't work, install Fedora manually:
1. Follow the graphical installer
2. Create a user named `ai` with the password from `secrets\vm-password.env`
3. After installation, in the VM terminal:
   ```bash
   sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai
   ~/ai-sandbox/config/install-inside-vm.sh
   ```

### Step 7: Verify Guest Provisioning

After the VM reboots, log in as user `ai` and verify the first-boot provisioning:

```bash
# Check if provisioning completed
test -f /var/lib/ai-sandbox-firstboot.done && echo "Provisioning complete"

# Check service status
systemctl status ai-sandbox-firstboot.service

# View logs if there were issues
journalctl -u ai-sandbox-firstboot.service -b --no-pager
```

Successful provisioning installs:
- Podman and the `ai-dev` container image
- Cursor IDE
- Claude Code CLI
- Firewall rules

### Step 8: Configure Claude Code (in Guest)

Inside the Fedora VM:

```bash
bash ~/ai-sandbox/config/setup-claude.sh
```

This sets up Claude Code authentication. Place your API credentials on the **host** under `secrets/`:
- `secrets/claude-api-key.env` — for Anthropic API
- `secrets/claude-vertex.env` — for Google Cloud Vertex AI

See [spec/how/runtime.md](spec/how/runtime.md) for credential format details.

### Step 9: Start Your First Project

Inside the Fedora VM:

```bash
bash ~/ai-sandbox/config/start-day.sh
```

This:
- Creates a default project at `~/ai-sandbox/workspace/default/`
- Starts the Podman dev container
- Opens Cursor IDE

### Daily Workflow on Windows

| Action | Command (PowerShell) |
|--------|---------------------|
| Start VM | `.\start-vm.ps1` |
| Stop VM | `.\stop-vm.ps1` |
| Stop and delete VM | `.\stop-vm.ps1 -Remove` |

Inside the VM, run:
```bash
bash ~/ai-sandbox/config/start-day.sh
```

### Troubleshooting Windows Issues

**Hyper-V not available:**
- Verify Windows edition: `winver`
- Windows Home users: Consider WSL2 or upgrade to Pro
- Check virtualization in Task Manager → Performance → CPU → Virtualization: Enabled

**Virtual switch missing:**
- Open Hyper-V Manager
- Actions → Virtual Switch Manager → Create "Default Switch" or External switch

**Git/OpenSSL not found:**
- Install Git for Windows: https://git-scm.com/
- Re-open PowerShell after installation

**Python not found:**
- Install Python 3: https://python.org
- Ensure "Add to PATH" was checked during install
- Alternative: Use Git Bash with `./tools/serve-kickstart.sh`

**Permission denied running scripts:**
```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

**VM creation fails:**
- Check available disk space (need 80+ GB)
- Ensure `secrets\vm-password.env` exists (run `.\host\write-vm-password-env.ps1`)
- Verify `secrets\ssh\id_ed25519.pub` exists (run `.\setup-host.ps1` again)

**Kickstart connection refused:**
- Verify firewall allows TCP 8000: `New-NetFirewallRule -DisplayName "ai-sandbox-ks" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow`
- Use correct Windows LAN IP (from `ipconfig`)
- Ensure kickstart server is running: `.\tools\serve-kickstart.ps1`

**Boot loader did not load an operating system:**
This happens if the VM boot order isn't set correctly. Fix it with PowerShell (elevated):

```powershell
# Stop the VM first
Stop-VM -Name ai-sandbox -Force

# Get the DVD drive and hard disk
$dvd = Get-VMDvdDrive -VMName ai-sandbox
$hdd = Get-VMHardDiskDrive -VMName ai-sandbox

# Disable Secure Boot (required for Fedora)
Set-VMFirmware -VMName ai-sandbox -EnableSecureBoot Off

# Set boot order: DVD first, then hard drive
Set-VMFirmware -VMName ai-sandbox -BootOrder $dvd,$hdd

# Start the VM
Start-VM -Name ai-sandbox
```

If you already installed Fedora but it won't boot, the ISO should remain as the first boot device until installation completes. After installation, you can optionally remove the ISO and reboot.

---

## Daily workflow

| Where | Linux/macOS | Windows |
|-------|------------|---------|
| Host — Start VM | `./start-vm.sh` | `.\start-vm.ps1` |
| Guest — Start project | `bash ~/ai-sandbox/config/start-day.sh` | Same |
| Host — Stop VM | `./stop-vm.sh` | `.\stop-vm.ps1` |
| Host — Delete VM | `./stop-vm.sh --remove` | `.\stop-vm.ps1 -Remove` |

---

## Where things live

| Path | Role |
|------|------|
| **`workspace/<name>/`** | Your Git repos and project files (host ↔ guest) |
| **`secrets/`** | SSH keys, API tokens — **do not commit**; mounted read-only in the guest where designed |
| **`config/`** | Automation used inside the guest (mounted from the host) |

Register **`secrets/ssh/id_ed25519.pub`** with your Git host.

---

## Claude MCP servers and skills (survive VM disk rebuilds)

They live on the **host** (virtiofs) and are merged into the guest **`~/.claude.json`** and **`~/.claude/skills/`**:

| Location | Purpose |
|----------|---------|
| **`config/claude-bootstrap/mcp.json`** | Team MCP defaults (copy from **`config/claude-bootstrap/mcp.json.example`**) |
| **`secrets/claude-mcp.json`** | Private MCP + tokens (copy from **`secrets/claude-mcp.json.example`**) — **gitignored** |
| **`workspace/.ai-sandbox-private/claude-bootstrap/`** | Extra **`mcp.json`** and **`skills/`** when **`secrets/`** is read-only from the VM or you want machine-local data — **gitignored** |

On the **guest**, after editing those files on the host:

```bash
bash ~/ai-sandbox/config/merge-claude-bootstrap.sh ~/ai-sandbox
```

Then **recreate** dev containers (**`podman rm -f ai-dev-<name>`** + **`start-container.sh`**) so Podman picks up **`~/.claude.json`** and skills. Per-repo **`.mcp.json`** is still supported by Claude Code in project trees.

Details: **[spec/how/runtime.md](spec/how/runtime.md)** (host-backed MCP and skills).

---

## Optional

- **VM / kickstart details, macOS & Windows:** **[spec/how/bootstrap.md](spec/how/bootstrap.md)**
- **Full script index, architecture, troubleshooting, pins:** **[spec/README.md](spec/README.md)** → **[spec/how/inventory.md](spec/how/inventory.md)**, **[spec/how/architecture.md](spec/how/architecture.md)**, **[spec/how/operations.md](spec/how/operations.md)**

---

## Tests

```bash
./tests/run.sh
```

Optional: `SHELLCHECK=1 ./tests/test_syntax.sh` with ShellCheck installed.
