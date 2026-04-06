# How — host bootstrap and VM creation

## Repository location

**Recommended:** clone to **`~/ai-sandbox`** (or **`%USERPROFILE%\ai-sandbox`** on Windows) so guest paths in docs match your tree. **Host scripts** under **`host/`** resolve the repo root automatically from their location (or use **`SANDBOX`** / **`AI_SANDBOX_HOME`** if the checkout lives elsewhere and you run scripts outside the tree).

## Unified host setup (fewer steps)

| Host | One-shot | Re-check after reboot / group change |
|------|----------|--------------------------------------|
| **Fedora + macOS** | **`./setup-host.sh`** — **`host/install-virt-*.sh`**, **`host/check-host-*.sh`**, then optional **`host/configure-vm-host.sh`** (interactive **`host/vm-host.env`** + auto-generated **`secrets/vm-password.env`** by default) | **`./setup-host.sh --check-only`** |
| **Windows** (elevated PowerShell) | **`.\setup-host.ps1`** — same optional configure step (**`configure-vm-host.ps1`**, or **`configure-vm-host.sh`** if Git Bash **`bash`** is on `PATH`) | **`.\setup-host.ps1 -CheckOnly`** |

Skip the wizard with **`--skip-vm-config`** / **`-SkipVmConfig`** or **`SKIP_VM_CONFIGURE=1`**. **`start-vm`** does not run this; it only boots an existing VM.

**Kickstart VM user password file:** **`secrets/vm-password.env`**. The configure wizard creates it with a random **`VM_PASSWORD`** unless you skip that step or keep an existing file. Standalone helpers: **`host/write-vm-password-env.sh`** or **`.\host\write-vm-password-env.ps1`** — bash-style quoting, UTF-8 **without BOM** on Windows so guest **`source`** works.

The per-OS sections below still describe what each underlying script does; use **`setup-host.*`** when you want the default **install → check** sequence without chaining commands by hand.

## Automation level by host

| Host | Guest install | Host `config/` / `secrets/` in guest | First-boot `install-inside-vm.sh` |
|------|----------------|--------------------------------------|-------------------------------------|
| **Fedora + libvirt** | **Full:** `host/create-vm-linux.sh` netinst + kickstart + virtiofs tags | **Automatic** virtiofs | **Automatic** via `ai-sandbox-firstboot.service` when kickstart applies |
| **macOS + UTM** | **Partial:** ISO + disk; UTM UI for VM | **Manual** shared folder, rsync, or see **Kickstart over HTTP** + optional virtio-9p in UTM | **Manual** unless kickstart + virtiofs share is configured to match `host-config` |
| **Windows + Hyper-V** | **Partial:** `host/create-vm-windows.ps1` | **Optional SMB:** `-CreateSmbShare` exposes `\\hostname\ai-sandbox`; guest uses **`config/cifs.env.example`** + **`ensure-sandbox-mounts.sh`** | **Manual** unless kickstart succeeds **and** virtiofs-equivalent exists (uncommon on Hyper-V) |

**Kickstart over HTTP (macOS / Windows):** With `ks.cfg` generated, run **`tools/serve-kickstart.sh`** (Mac/Linux/Git Bash) or **`tools/serve-kickstart.ps1`** (Windows with Python). At the Anaconda screen, add **`inst.ks=http://<host-LAN-ip>:8000/ks.cfg`**. Open the host firewall for TCP **8000** if needed. That satisfies **unattended Workstation install** with the same **`ks.template.cfg`** as Linux, including first-boot—**but** first-boot still **requires** virtiofs tag **`host-config`** unless you later switch to **CIFS** (see `config/ensure-sandbox-mounts.sh` and **`config/cifs.env.example`**).

**SMB/CIFS path:** On the guest, install **`/etc/ai-sandbox/cifs.env`** with **`USE_CIFS=1`**, **`CIFS_URL`**, and credentials; run **`sudo config/ensure-sandbox-mounts.sh ai`**. This mounts the whole host **`ai-sandbox`** tree so **`config/`**, **`secrets/`**, **`workspace/`** align with the Linux virtiofs layout.

## Official Fedora media and configuration mounts

Per [requirements.md](../what/requirements.md#installation-media-and-configuration-mounts):

- This repo **does not** ship a **custom remastered Fedora ISO**.
- **Official Fedora Workstation** install bits: **netinstall `os/` tree** (Linux) or **live ISO** (macOS/Windows scripts).
- **`config/`**, **`secrets/`**, and **`workspace/`** stay on the **host** and are attached to the guest with **virtiofs** on Linux (`host/create-vm-linux.sh` `--filesystem`), or **SMB** / **manual share** elsewhere.

## Fedora Linux host

0. **Prerequisites** — Enable **CPU virtualization** in firmware (VT-x / AMD-V); see repository **README** (cannot be scripted). Avoid mixing **`qemu:///session`** with system VMs; use **`qemu:///system`** (see **`host/check-host-fedora.sh`**).
0b. **Shortcut** — **`./setup-host.sh`** runs **`host/install-virt-linux.sh`** then **`host/check-host-fedora.sh`** (or **`./setup-host.sh --check-only`** after a reboot / new login).
1. **`host/check-host-fedora.sh`** — Read-only check: `/dev/kvm`, **`@virtualization`** RPMs, **`libvirtd`**, user in **`libvirt`** group, **`virsh -c qemu:///system`**, and **default** NAT network **active** + **autostart** (`virbr0`). Run before **`host/create-vm-linux.sh`**.
2. **`host/install-virt-linux.sh`** — Installs `@virtualization`, libvirt, `virt-install`, creates `~/ai-sandbox/{config,secrets/ssh,workspace,logs}`, generates **`secrets/ssh/id_ed25519`** if missing. If an older tree has **`workspace/projects/`**, the script flattens those dirs to **`workspace/<name>/`**. Adds the user to the `libvirt` group (log out/in). Runs **`ensure_qemu_access_for_virtiofs`** (ACLs + SELinux **`virt_content_t`**) so a checkout under **`/home`** is readable by QEMU for virtiofs—no need to move the repo to **`/opt`** for a typical clone. If that step was skipped or failed later, run **`./host/fix-virtiofs-qemu-access.sh`** on the host.
3. Register **`secrets/ssh/id_ed25519.pub`** with GitHub/GitLab as you prefer.
4. **`secrets/vm-password.env`** — `VM_PASSWORD='...'` (bash-style). Used only to build the **hashed** password for kickstart user **`ai`**. Optional: **`host/write-vm-password-env.sh`** or **`.\host\write-vm-password-env.ps1`** generates a random password.
4b. **(Optional)** **`host/vm-host.env`** — copy **`host/vm-host.env.example`** to **`host/vm-host.env`** and set **disk size**, **RAM (MiB)**, **vCPUs**, **VM name**, **Fedora version**, **libvirt network**, **Hyper-V switch**, etc., or run **`host/configure-vm-host.sh`** to generate the file interactively. **`create-vm-*`**, **`rebuild-all-*`**, **`start-vm`**, and **`stop-vm`** read these settings when the file exists.
5. **`host/create-vm-linux.sh`** — **Run this for a normal install** (after steps 1–4). It runs **`host/generate-ks-fedora.sh`** first (writes **`ks.cfg`** from **`vm-password.env`** and the sandbox SSH public key), then **`virt-install`**. The guest disk defaults to **`/var/lib/libvirt/images/ai-sandbox.qcow2`** (libvirt’s pool so **qemu** can read it; disks under **`~/vms`** often fail with permission denied). Override with **`VM_DIR`** in **`vm-host.env`**. **`virt-install`** with:
   - **`--location`** pointing at the Fedora **Everything** netinstall **`os/`** tree on the mirror (HTTPS); kickstart selects **Workstation** packages.
   - **`--initrd-inject`** of `ks.cfg` and **`inst.ks=file:/ks.cfg`** in kernel args.
   - **virtiofs** mounts: `config` → `host-config`, `secrets` → `host-secrets`, `workspace` → `host-workspace`.
   - Overrides: **`host/vm-host.env`** (or env vars) for **`FEDORA_VER`**, **`LOCATION_URL`**, **`VM_MEMORY_MIB`**, **`VM_VCPUS`**, **`VM_CPU_MODE`**, **`VM_LIBVIRT_NETWORK`**, etc.
6. **(Optional)** **`host/generate-ks-fedora.sh`** alone — Only if you need to **refresh `ks.cfg`** without running **`create-vm-linux.sh`** again (for example to inspect or reuse the file).
7. After install completes, **`virsh snapshot-create-as ai-sandbox clean`** when possible (for **`host/reset-sandbox.sh`**).

**What you see in the VM window:** Kickstart **does** automate disk layout, package selection, and user **`ai`**. You may still see **Anaconda** in the SPICE window (progress or a short hub)—that is expected with **`--graphics`**. The template includes **`eula --agreed`** so the license screen should not block automation; after editing **`ks.template.cfg`**, run **`host/generate-ks-fedora.sh`** again before reinstalling. After the first reboot, **GNOME’s initial welcome / privacy** flow is **not** controlled by kickstart; complete or skip it. Then **`ai-sandbox-firstboot.service`** runs **`install-inside-vm.sh`** once virtiofs mounts succeed.

**Second reboot in the guest?** Not required as soon as you reach the desktop after kickstart’s reboot—first-boot provisioning is meant to run on that same boot. After **`install-inside-vm.sh`** completes, an optional **`sudo reboot`** in the guest is reasonable if **`dnf upgrade`** installed a **new kernel** (boot into it when convenient). The installer does not force an automatic guest reboot at first login (would disrupt GNOME welcome and user timing). **Host** **log out / in** after the **`libvirt`** group change is a separate requirement (see README prerequisites).

**Interactive prompts on first boot:** **`install-inside-vm.sh`** under **systemd** has **no TTY**, so it cannot ask questions in that session. After **GNOME login**, an **autostart** entry opens a terminal for **`setup-claude.sh`** (see [runtime.md](runtime.md)). For SSH-with-TTY or manual terminal, run **`setup-claude.sh`** yourself.

**Login password for user `ai`:** Kickstart must use **`--iscrypted`** with the **`openssl passwd -6`** hash in **`host/ks.template.cfg`**. Without it, the guest’s password is the **hash string**, not **`VM_PASSWORD`** from **`secrets/vm-password.env`**. Fix the template, regenerate **`ks.cfg`**, reinstall—or reset with **`passwd`** from a root shell (e.g. recovery).

**“Kickstart insufficient” under Installation Destination:** The kickstart must define storage clearly. **`host/ks.template.cfg`** uses **`zerombr`**, **`clearpart --all --initlabel`**, then **`autopart`** ( **`autopart` alone is not enough** ). Regenerate **`ks.cfg`** and reinstall. If it still appears with multiple disks visible to the guest, add **`ignoredisk --only-use=vda`** (libvirt virtio disk is usually **`vda`**) before **`clearpart`** in the template.

## macOS host

0. **Prerequisites** — Install **UTM** manually; on **Apple Silicon** consider **aarch64** Fedora media (see README). **`host/check-host-mac.sh`** verifies **Homebrew**, **qemu-img**, **git**, **curl**, **jq**, **python3**, **`/Applications/UTM.app`**, and repo paths.
0b. **Shortcut** — **`./setup-host.sh`** runs **`host/install-virt-mac.sh`** then **`host/check-host-mac.sh`** (requires **Homebrew** first).
1. **`host/install-virt-mac.sh`** — Requires **Homebrew**; installs `qemu`, `git`, `curl`, `jq`; creates directories; generates sandbox SSH key; chmods `secrets`.
2. **`host/check-host-mac.sh`** — Run after install; fix **MISS** before **`host/create-vm-mac.sh`**.
3. **`host/create-vm-mac.sh`** — Generates **`ks.cfg`** when secrets exist; downloads Fedora **Workstation ISO**; creates qcow2; prints **UTM**, **HTTP kickstart**, and **post-install** steps.
4. **`host/generate-ks-mac.sh`** — Same template as Linux; uses **`openssl passwd -6`** and sandbox pubkey (also invoked by **`host/create-vm-mac.sh`** when secrets exist).
5. **`host/rebuild-all-mac.sh`** — Regenerates kickstart, removes disk, re-runs `host/create-vm-mac.sh`.

**Note:** Default ISO URLs are **x86_64**. On **Apple Silicon**, use an **aarch64** Fedora image and adjust URLs, or run under emulation.

## Windows host

0. **Prerequisites** — **Hyper-V** requires **Pro/Enterprise/Education** (not Home); enable **virtualization** in firmware. **`host/check-host-windows.ps1`** checks **Hyper-V** state, **virtual switches**, **Git**/**OpenSSL**, **python**, and repo layout (run **as Administrator** for full Hyper-V queries). See README.
0b. **Shortcut** — **`.\setup-host.ps1`** (elevated) runs **`host/install-virt-windows.ps1`** then **`host/check-host-windows.ps1`** (or **`-CheckOnly`** after reboot).
1. **`host/install-virt-windows.ps1`** — **Elevated** PowerShell (`#Requires -RunAsAdministrator`). Creates directories, enables **Hyper-V**, installs **Git for Windows** silently, generates **`secrets/ssh/id_ed25519`** via **`Git\usr\bin\ssh-keygen.exe`**.
2. **`host/check-host-windows.ps1`** — After reboot if needed; fix **MISS** before **`host/create-vm-windows.ps1`**.
3. Create **`secrets/vm-password.env`** (same bash-style `VM_PASSWORD=...` as Linux; the Windows kickstart generator parses this text). Optional: **`.\host\write-vm-password-env.ps1`**.
4. **`host/generate-ks-windows.ps1`** — Uses **`Git\usr\bin\openssl.exe`** to hash the password and **`.Replace()`** on **`host/ks.template.cfg`**. Requires Git install first.
5. **`host/create-vm-windows.ps1`** — Optional **`-CreateSmbShare`**: creates **`\\COMPUTERNAME\ai-sandbox`** pointing at the repo for CIFS mount in the guest. Picks a **virtual switch** (Default Switch or first available). Generates **`ks.cfg`** when secrets exist. Prints **HTTP kickstart** and post-install instructions.

## Kickstart artifacts

| Script | Output |
|--------|--------|
| `host/generate-ks-fedora.sh` | `~/ai-sandbox/ks.cfg` |
| `host/generate-ks-mac.sh` | same |
| `host/generate-ks-windows.ps1` | same |

Template: **`host/ks.template.cfg`**. It installs **`ai-sandbox-firstboot.service`** and sudoers for user **`ai`**; see [runtime.md](runtime.md) for first-boot behavior. First-boot **expects** virtiofs **`host-config`**; if missing, configure **CIFS** and run **`ensure-sandbox-mounts.sh`** manually.

## Full rebuild helpers

| Host | Script |
|------|--------|
| Linux | `host/rebuild-all-fedora.sh` |
| macOS | `host/rebuild-all-mac.sh` |
| Windows | `host/rebuild-all-windows.ps1` |

| Host | Pre-flight check |
|------|-------------------|
| Fedora | `host/check-host-fedora.sh` |
| macOS | `host/check-host-mac.sh` |
| Windows | `host/check-host-windows.ps1` |

---

## Related

- **[inventory.md](inventory.md)** — every `host/` and `config/` script in one place.
- **[conventions.md](conventions.md)** — virtiofs tags, `vm-host.env` keys, kickstart tokens.
