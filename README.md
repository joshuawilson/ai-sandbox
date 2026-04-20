# AI Sandbox

Give Cursor and Claude Code full sudo and internet access — without risking your host OS, credentials, or personal files.

AI agents want to run shell commands, install packages, and edit your filesystem. AI Sandbox puts all of that inside a Fedora VM with Podman dev containers, so your real machine stays clean. Repos and secrets live on the host, mounted into the VM — your work survives full VM rebuilds.

```
Host OS (Linux, macOS, or Windows)
  └─ VM: Fedora Workstation (KVM / Hyper-V / UTM)
        ├─ virtiofs/SMB: config (read-only), secrets (read-only), workspace (read-write)
        └─ Rootless Podman
              └─ ai-dev container → /workspace (your project)
```

- **Sandboxed AI autonomy** — agents run with full capability inside the VM, not on your host
- **Survives rebuilds** — repos and secrets are host-backed, not on the VM disk
- **Dedicated credentials** — sandbox-specific SSH keys; your personal keys are never exposed
- **Three-platform support** — Linux (KVM/libvirt), macOS (UTM), Windows (Hyper-V)
- **Per-project containers** — each project gets its own Podman container with isolated `/workspace`
- **One-command daily start** — `start-dev.sh` launches your container and opens Cursor

**You'll need:** A machine with CPU virtualization (VT-x / AMD-V), ~80 GB free disk space, and 30-50 minutes for first-time setup. Windows requires Pro/Enterprise/Education (Hyper-V).

---

## Setup

*Instructions below are organized by platform — click to expand yours.*

### Requirements

All platforms need CPU virtualization enabled in firmware (VT-x / AMD-V) and ~80 GB free disk space.

<details open>
<summary><strong>Linux (Fedora)</strong></summary>

- `setup-host.sh` installs libvirt/KVM automatically
- After setup, **log out and back in** for `libvirt` group membership to take effect

</details>

<details>
<summary><strong>macOS</strong></summary>

- [UTM 4+](https://mac.getutm.app) installed
- On Apple Silicon, use **aarch64** Fedora media

</details>

<details>
<summary><strong>Windows</strong></summary>

- Windows 10/11 **Pro, Enterprise, or Education** (Home does not support Hyper-V)
- [Python 3.x](https://python.org) on PATH (for kickstart server)
- To check your edition: press `Win+R`, type `winver`

</details>

### 1. Clone and run host setup

Clone the repo and run the host setup script. This installs your platform's hypervisor and generates a sandbox SSH key.

<details open>
<summary><strong>Linux</strong></summary>

```bash
cd ~/ai-sandbox
./setup-host.sh
```

After a new `libvirt` group membership, **log out, log back in**, then verify:

```bash
./setup-host.sh --check-only
```

</details>

<details>
<summary><strong>macOS</strong></summary>

```bash
cd ~/ai-sandbox
./setup-host.sh
```

Requires [Homebrew](https://brew.sh). Installs `qemu`, `git`, `curl`, `jq`. Verify:

```bash
./setup-host.sh --check-only
```

</details>

<details>
<summary><strong>Windows</strong></summary>

Open an **elevated** (Administrator) PowerShell:

```powershell
cd $env:USERPROFILE\ai-sandbox
Set-ExecutionPolicy -Scope Process Bypass
.\setup-host.ps1
```

This enables Hyper-V (may require a reboot), installs Git for Windows if missing, and generates SSH keys. If prompted to reboot, restart and re-run:

```powershell
.\setup-host.ps1 -CheckOnly
```

</details>

### 2. Configure VM settings

Set VM sizing (disk, RAM, CPUs) and guest password. Usually done automatically by `setup-host`. To reconfigure or if files are missing:

<details open>
<summary><strong>Linux / macOS</strong></summary>

```bash
./host/configure-vm-host.sh
```

Or configure manually: copy `host/vm-host.env.example` to `host/vm-host.env`, then run `./host/write-vm-password-env.sh`.

</details>

<details>
<summary><strong>Windows</strong></summary>

```powershell
.\host\configure-vm-host.ps1
```

Or configure manually: copy `host\vm-host.env.example` to `host\vm-host.env`, then run `.\host\write-vm-password-env.ps1`.

</details>

### 3. Register your SSH key

Copy the generated public key and add it to your Git host (GitHub, GitLab, etc.).

<details open>
<summary><strong>Linux / macOS</strong></summary>

```bash
cat secrets/ssh/id_ed25519.pub
```

</details>

<details>
<summary><strong>Windows</strong></summary>

```powershell
Get-Content secrets\ssh\id_ed25519.pub
```

</details>

Add the key at: **GitHub** > Settings > SSH and GPG keys > New SSH key, or **GitLab** > Preferences > SSH Keys.

### 4. Create the VM

Build and start the Fedora VM. This is the longest step (~30-50 minutes). Wait for the install to finish and the guest to reboot into the desktop.

<details open>
<summary><strong>Linux</strong></summary>

```bash
host/create-vm-linux.sh
```

This generates `ks.cfg`, runs `virt-install` with virtiofs filesystem shares, and installs the guest automatically.

</details>

<details>
<summary><strong>macOS</strong></summary>

```bash
host/create-vm-mac.sh
```

This downloads the Fedora ISO and creates a qcow2 disk. Follow the printed instructions to create the VM in UTM and configure shared folders.

For the full UTM walkthrough, see [spec/how/bootstrap.md](spec/how/bootstrap.md#macos-host).

</details>

<details>
<summary><strong>Windows</strong></summary>

**Recommended (fully automatic):**

First, install the ISO creation tool (one-time):

```powershell
.\host\install-adk-windows.ps1
```

Then create the VM:

```powershell
.\host\create-vm-windows-netinstall.ps1
```

This downloads the Fedora netinstall ISO, creates a kickstart ISO, sets up an SMB share for host filesystem access, and starts the Hyper-V VM. Installation proceeds automatically.

**Watch progress:** Open Hyper-V Manager, find your VM, right-click > Connect.

If the kickstart ISO wasn't created, see [manual HTTP kickstart](docs/troubleshooting.md#windows-manual-http-kickstart-no-adk) in the troubleshooting guide.

</details>

### 5. Verify and configure the guest

Log in as user `ai` (password is in `secrets/vm-password.env`). First-boot provisioning installs Podman, the `ai-dev` container image, Cursor, Claude Code, and firewall rules automatically.

<details open>
<summary><strong>All platforms</strong></summary>

Verify provisioning completed:

```bash
test -f /var/lib/ai-sandbox-firstboot.done && echo "Provisioning complete"
```

If the marker file is missing, check the logs:

```bash
journalctl -u ai-sandbox-firstboot.service -b --no-pager
```

Set up Claude Code:

```bash
bash ~/ai-sandbox/config/setup-claude.sh
```

Place API credentials on the **host** under `secrets/` — see [spec/how/runtime.md](spec/how/runtime.md) for details.

</details>

### 6. Start your first project

<details open>
<summary><strong>All platforms</strong></summary>

Inside the VM:

```bash
bash ~/ai-sandbox/config/start-dev.sh
```

This creates a default project directory under `workspace/`, starts a Podman dev container, and opens Cursor.

</details>

---

## Daily workflow

| | Linux / macOS | Windows |
|---|---|---|
| **Start VM** | `./start-vm.sh` | `.\start-vm.ps1` |
| **Start project** | `bash ~/ai-sandbox/config/start-dev.sh` | *(same, inside VM)* |
| **Stop VM** | `./stop-vm.sh` | `.\stop-vm.ps1` |
| **Delete VM** | `./stop-vm.sh --remove` | `.\stop-vm.ps1 -Remove` |

For VM snapshots, save/restore state, and pause/resume: see [VM-USAGE.md](VM-USAGE.md).

---

## Where things live

| Path | Role |
|------|------|
| **`workspace/<name>/`** | Your Git repos and project files (host ↔ guest) |
| **`secrets/`** | SSH keys, API tokens — **do not commit**; mounted read-only in the guest |
| **`config/`** | Automation used inside the guest (mounted from host) |

Clone or create repos in `workspace/` on either the host or the guest — they're the same directory via virtiofs/SMB.

---

## Claude MCP servers and skills

MCP config and skills live on the **host** so they survive VM rebuilds. After editing them, run in the guest:

```bash
bash ~/ai-sandbox/config/merge-claude-bootstrap.sh ~/ai-sandbox
```

Then recreate dev containers (`podman rm -f ai-dev-<name>` + `start-container.sh`) to pick up changes.

| Location | Purpose |
|----------|---------|
| **`config/claude-bootstrap/mcp.json`** | Team MCP defaults |
| **`secrets/claude-mcp.json`** | Private MCP + tokens (gitignored) |
| **`workspace/.ai-sandbox-private/claude-bootstrap/`** | Machine-local overrides (gitignored) |

Details: [spec/how/runtime.md](spec/how/runtime.md)

---

## Useful commands

| Action | Command (inside VM) |
|--------|---------------------|
| Shell into running container | `bash ~/ai-sandbox/config/shell-into-container.sh <name>` |
| Start new project container | `bash ~/ai-sandbox/config/start-container.sh --detach <name>` |
| Interactive container session | `bash ~/ai-sandbox/config/start-container.sh <name>` |

---

## Learn more

| Topic | Link |
|-------|------|
| Troubleshooting | [docs/troubleshooting.md](docs/troubleshooting.md) |
| VM management (snapshots, save/restore) | [VM-USAGE.md](VM-USAGE.md) |
| Architecture and mounts | [spec/how/architecture.md](spec/how/architecture.md) |
| Full script inventory | [spec/how/inventory.md](spec/how/inventory.md) |
| Spec index | [spec/README.md](spec/README.md) |

## Tests

```bash
./tests/run.sh
```
