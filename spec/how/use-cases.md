# Use cases: first-time setup vs returning to work

Script names and paths: **[inventory.md](inventory.md)**. Env and mount contracts: **[conventions.md](conventions.md)**.

## 1. Starting from nothing (greenfield)

Goal: physical machine → working dev VM with Cursor, Podman, and host-backed projects.

| Step | Where | What |
|------|-------|------|
| a | **Host** | Clone repo to **`~/ai-sandbox`** (or Windows profile path). |
| b | **Host** | **`./setup-host.sh`** or **`.\setup-host.ps1`** — hypervisor deps, dirs, sandbox SSH key, host check. After checks, optional **`host/configure-vm-host.*`** — **`host/vm-host.env`** (disk, RAM, vCPUs, …) and default **auto-generated** **`secrets/vm-password.env`**. Skip with **`--skip-vm-config`** / **`-SkipVmConfig`** or **`SKIP_VM_CONFIGURE=1`**. |
| c | **Host** | If you skipped the wizard: **`host/write-vm-password-env.*`** and/or **`host/vm-host.env`** from **`vm-host.env.example`**. Then **`host/create-vm-*`** — builds **`ks.cfg`** (via **`generate-ks-*`**) and creates the VM (see [bootstrap.md](bootstrap.md)). Run **`generate-ks-*`** alone only to refresh **`ks.cfg`**. |
| d | **Guest** (first boot) | **`ai-sandbox-firstboot.service`** runs **`config/install-inside-vm.sh`**. If that failed, fix mounts then run it manually. |
| e | **Guest** | Log in as **`ai`**, then **`~/ai-sandbox/config/start-dev.sh`** to open Cursor and the default project container. |

You only do **(b)→(e)** once per new machine or new VM disk.

---

## 2. Everything already installed — start the day

Goal: VM and guest tooling exist; you just need to work.

| Step | Where | What |
|------|-------|------|
| a | **Host** | Power on the VM: **`./start-vm.sh`** (Linux/macOS) or **`.\start-vm.ps1`** (Windows Hyper-V). On macOS with UTM, the script opens **UTM** — start/resume the VM in the app if needed. |
| b | **Guest** | Log in (graphical or SSH). |
| c | **Guest** | **`~/ai-sandbox/config/start-dev.sh`** — starts the default project’s container (detached) and launches **Cursor** on that workspace. For a specific project: **`~/ai-sandbox/config/start-container.sh <name>`**. To shell into a running container: **`~/ai-sandbox/config/shell-into-container.sh <name>`**. |

Optional: **`git pull`** on the **host** repo so **`config/`** updates in the guest; optional **`git pull`** inside **`workspace/<name>/`** on the host.

---

## Script map

| Use case | Host (repo root) | Host (`host/`) | Guest (`~/ai-sandbox/config/`) |
|----------|------------------|----------------|----------------------------------|
| First-time | **`setup-host.sh`**, **`setup-host.ps1`** (optional **`configure-vm-host.*`**) | **`vm-host.env`** + **`create-vm-*`** (calls **`generate-ks-*`** on Fedora/macOS/Windows) | **`install-inside-vm.sh`** (first boot or manual) |
| Returning | **`start-vm.sh`**, **`start-vm.ps1`**; **`stop-vm.sh`**, **`stop-vm.ps1`** | `start-vm-*`, `stop-vm-*` | **`start-dev.sh`**, **`start-container.sh`**, **`shell-into-container.sh`** |

Details: [repo-layout.md](repo-layout.md), [runtime.md](runtime.md#repeatable-workflows), [bootstrap.md](bootstrap.md).
