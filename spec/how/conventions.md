# Conventions — environment variables, paths, and contracts

Cross-cutting rules for scripts and documentation. See **[inventory.md](inventory.md)** for the file list.

---

## Repository root resolution

| Mechanism | Used by |
|-----------|---------|
| **`SANDBOX`** or **`AI_SANDBOX_HOME`** | Bash `host/lib/sandbox-root.sh` → `sandbox_repo_root`; PowerShell `Get-SandboxRepoRoot` in `read-vm-host-env.ps1`. Must point at the **repo root** (parent of `host/`, `config/`, `secrets/`). |
| Default | Parent directory of **`host/`** containing the invoked script. |

---

## VM naming (libvirt / Hyper-V)

| Variable | Role |
|----------|------|
| **`VM_NAME`** | Preferred domain/VM name; set in **`host/vm-host.env`**. |
| **`VIRSH_DOMAIN`** | Linux **`virsh`** / Windows **`Get-VM`**: if set, overrides **`VM_NAME`** for start/stop scripts. |
| **`VIRSH_SNAPSHOT`** | **`reset-sandbox.sh`**: snapshot name (default **`clean`**). |

Disk files: Linux **`$VM_DIR/$VM_NAME.qcow2`**; Windows **`vm/$VMName.vhdx`**; macOS **`vm/$VM_NAME.qcow2`**.

---

## Virtiofs tags (Linux libvirt only)

`host/create-vm-linux.sh` passes **`--filesystem`** entries. Guest and **`ensure-sandbox-mounts.sh`** must stay aligned.

| Tag | Host path (repo) | Guest mount base used by ensure-sandbox-mounts |
|-----|------------------|--------------------------------------------------|
| **`host-config`** | `<repo>/config` | `/mnt/host-config` → `~/ai-sandbox/config` |
| **`host-secrets`** | `<repo>/secrets` | `/mnt/host-secrets` → `~/ai-sandbox/secrets` |
| **`host-workspace`** | `<repo>/workspace` | `/mnt/host-workspace` → `~/ai-sandbox/workspace` |

**libvirt requirement:** real virtiofs (not virtio-9p fallback) needs **`--memorybacking=source.type=memfd,access.mode=shared`** and **`driver.type=virtiofs`** on each **`--filesystem`** line — see [libvirt virtiofs](https://libvirt.org/kbase/virtiofs.html). Without that, the guest sees 9p and **`mount -t virtiofs`** fails.

First-boot **`ai-sandbox-firstboot.service`** expects **`host-config`** to be mountable; if not (e.g. Hyper-V without virtiofs), use **CIFS** per **`config/cifs.env.example`**.

---

## VM host tunables (`host/vm-host.env`)

Bash-sourceable **`KEY=value`** file (optional **`#`** comments). Loaded by **`host/lib/vm-host-env.sh`** on Linux/macOS; merged in PowerShell via **`Get-VmHostEnvMerged`**.

Common keys: **`VM_NAME`**, **`VM_DISK_GB`**, **`VM_MEMORY_MIB`**, **`VM_VCPUS`**, **`VM_CPU_MODE`**, **`FEDORA_VER`**, **`LOCATION_URL`**, **`VM_DIR`**, **`VM_LIBVIRT_NETWORK`**, **`VM_ISO_URL`**, **`VM_HYPERV_SWITCH`**.

---

## Container tunables (`config/container.env`)

| Variable | Default | Purpose |
|----------|---------|---------|
| **`CONTAINER_IMAGE`** | `ai-dev` | Podman image name built by **`build-container.sh`**. |
| **`CPU_LIMIT`** | `6` | **`--cpus`** for **`podman run`**. |
| **`MEMORY_LIMIT`** | `16g` | **`--memory`** for **`podman run`**. |
| **`PID_LIMIT`** | `512` | **`--pids-limit`** for **`podman run`**. |
| **`SECRETS_DIR`** | `/mnt/host-secrets` | Mounted host secrets path inside the VM. |
| **`WORKSPACE_ROOT`** | `$HOME/ai-sandbox/workspace` | Host-backed workspace root; **`start-container.sh`** mounts **`$WORKSPACE_ROOT/<name>`** → **`/workspace`**. |

---

## Kickstart template tokens

| Token in `host/ks.template.cfg` | Replaced by `generate-ks-*` |
|--------------------------------|------------------------------|
| **`__PASSWORD_HASH__`** | `openssl passwd -6` from **`VM_PASSWORD`** in **`secrets/vm-password.env`**. |
| **`__SSH_KEY__`** | Contents of **`secrets/ssh/id_ed25519.pub`** (single line). |
| **`__SANDBOX_OWNER_UID__`** | Numeric UID of **`secrets/`** on the host (**`stat`**) or **`id -u`**; kickstart **`user --uid=…`** for **`ai`** (virtiofs passthrough + **`chmod 700`** on **`secrets/`**). Windows: env **`AI_SANDBOX_OWNER_UID`** or **`1000`**. |

Output: **`ks.cfg`** at **repo root** (not under `host/`).

---

## Guest user and paths

- **User:** **`ai`** (kickstart); passwordless sudo via **`/etc/sudoers.d/90-ai-sandbox`**.
- **Home layout:** **`/home/ai/ai-sandbox`** symlinks to virtiofs/CIFS targets mirroring **`~/ai-sandbox`** on the host doc layout.
- **Projects:** **`~/ai-sandbox/workspace/<name>`** → host **`workspace/<name>`** (same path via virtiofs/CIFS).

---

## Container naming

- Image: **`ai-dev`** (from **`config/container.env`** / **`Containerfile`**).
- Per-project container: **`ai-dev-<name>`** where **`<name>`** is a single path segment (directory name under **`workspace/`**).

---

## Runtime env (guest / container / dashboard)

| Variable | Purpose |
|----------|---------|
| **`AI_SANDBOX_DASHBOARD_TOKEN`** | Bearer token for **`config/dashboard.py`** POST endpoints. |
| **`SKIP_VIRTIOFS_QEMU_ACL`** | Set to **`1`** to skip ACL/SELinux fix in **`virtiofs-qemu-access.sh`** if paths are already accessible. |
| **`AI_SANDBOX_PODMAN_LABEL_DISABLE`** | **`1`** = always add **`--security-opt label=disable`** (auto-detected for virtiofs). **`0`** = use **`:z`/`:Z`** volume suffixes. Unset = auto-detect via **`findmnt`**. Set in **`config/container.env`** or export before **`start-container.sh`**. |
| **`AI_SANDBOX_SKIP_CLAUDE_SETUP`** | **`1`** = skip interactive Claude Code wizard at the end of **`install-inside-vm.sh`** and suppress GNOME autostart registration. |
| **`AI_SANDBOX_SETUP_FROM_INSTALL`** | Set internally by **`install-inside-vm.sh`** when calling **`setup-claude.sh`** so the wizard knows it does not need to remind about **`install-inside-vm.sh`**. |
| **`CURSOR_RPM_URL`** | Override the Cursor RPM download URL in **`install-inside-vm.sh`** (default: latest from **`api2.cursor.sh`**). |
| **`DISABLE_AUTOUPDATER`** | **`1`** in **`config/Containerfile`** and **`podman run`**: prevents Claude Code self-update inside the read-only container. |
| **`SKIP_VM_CONFIGURE`** | **`1`** = skip the **`configure-vm-host`** wizard in **`setup-host.*`**. Equivalent to **`--skip-vm-config`**. |

---

## Related

- **[architecture.md](architecture.md)** — trust boundaries and persistence.
- **[inventory.md](inventory.md)** — which file implements each concern.
