# Host scripts (physical machine)

Run these on **Fedora**, **macOS**, or **Windows** before or while managing the VM.

**New users (first-time):** **`./setup-host.sh`** or **`.\setup-host.ps1`** at repo root — after host checks, you can run the **VM wizard** (**`host/configure-vm-host.sh`** / **`.ps1`**) for disk/RAM/CPUs and an **auto-generated** **`secrets/vm-password.env`**. Then use the scripts below. **`start-vm`** only boots an existing VM; it does not run that wizard.

**Returning users:** **`./start-vm.sh`** or **`.\start-vm.ps1`** to boot the VM; **`./stop-vm.sh`** or **`.\stop-vm.ps1`** to force-stop it (**`--remove`** / **`-Remove`** removes the VM + disk for a clean reinstall). In the guest run **`~/ai-sandbox/config/start-day.sh`**. See **[spec/how/use-cases.md](../spec/how/use-cases.md)**.

**Do not rename** **`../config/`**, **`../secrets/`**, or **`../workspace/`** — the Linux VM attaches them by path (virtiofs).

**Repo path (any machine):** scripts under **`host/`** find the checkout automatically (they live next to **`config/`**). To point at a different tree, set **`SANDBOX`** or **`AI_SANDBOX_HOME`** to the repo root. Shared logic: **`host/lib/sandbox-root.sh`**.

**VM sizing (disk, RAM, vCPUs, Fedora version, …):** copy **`host/vm-host.env.example`** to **`host/vm-host.env`** (gitignored) and edit, or run **`./host/configure-vm-host.sh`** for interactive prompts. **`host/create-vm-*`**, **`rebuild-all-*`**, and **`start-vm` / `stop-vm`** on Linux and Windows read **`VM_NAME`** and related settings from that file when present.

**VM disk (Fedora + libvirt):** default **`/var/lib/libvirt/images/ai-sandbox.qcow2`** — libvirt’s pool so **qemu** can access it. Override with **`VM_DIR`** in **`vm-host.env`**.

**virtiofs from `~/ai-sandbox`:** libvirt’s **qemu** process needs **DAC** (often **`setfacl`**, package **`acl`**) **and**, with **SELinux Enforcing**, **`virt_content_t`** on those paths ( **`semanage`/`restorecon`**, package **`policycoreutils-python-utils`**). **`host/install-virt-linux.sh`** installs both; **`./setup-host.sh`** runs that installer unless **`--check-only`**. **`host/check-host-fedora.sh`** warns if they are missing.

**Already ran setup but skipped these?** Install without re-running the full script:

```bash
sudo dnf install -y acl policycoreutils-python-utils
```

**`create-vm-linux.sh`** **sources** **`host/lib/virtiofs-qemu-access.sh`** (and other **`host/lib/*.sh`** libraries), so a missing **execute** bit on those files does **not** stop ACL/SELinux setup.

**Repos under `/home` (normal git clones):** **`host/install-virt-linux.sh`** runs the same virtiofs preparation automatically: POSIX ACLs for user **`qemu`**, then SELinux **`virt_content_t`** on **`config/`**, **`secrets/`**, and **`workspace/`**, then a **`sudo -u qemu`** probe. **SELinux runs before the probe** so Enforcing does not block **`qemu`** on **`user_home_t`** even when ACLs are correct (a common failure on **`secrets/`** with mode **`700`**). If checks fail, run **`./host/fix-virtiofs-qemu-access.sh`**. **`host/check-host-fedora.sh`** verifies **`qemu`** can access all three paths.

**Guest: `/mnt/host-config` empty?** On the **host**, run **`./host/fix-virtiofs-qemu-access.sh`**, then **start the VM** and in the guest (as **`ai`**) run **`sudo /mnt/host-config/ensure-sandbox-mounts.sh ai`** (or reboot so first-boot can retry). The VM does not need to be recreated if the domain already has virtiofs tags from **`create-vm-linux.sh`**—only host-side access to the files must be fixed.

| Order | Purpose | Scripts |
|-------|---------|---------|
| 0 | Optional: set VM disk / RAM / CPUs / name | `configure-vm-host.sh` or copy `vm-host.env.example` → `vm-host.env` |
| 1 | Install hypervisor deps + dirs + SSH key + **virtiofs prep (Fedora)** | `install-virt-*.sh` / `install-virt-windows.ps1` — Linux also runs QEMU ACL/SELinux for **`/home` clones** |
| 1b | If virtiofs checks fail later | **`fix-virtiofs-qemu-access.sh`** (Fedora host, repo root) |
| 2 | Verify the machine | `check-host-*.sh` / `check-host-windows.ps1` |
| 3 | VM user password for kickstart | `write-vm-password-env.*` |
| 4 | Create the VM + kickstart | **`create-vm-*`** — on **Fedora**, **`create-vm-linux.sh`** runs **`generate-ks-fedora.sh`** for you. Run **`generate-ks-*`** alone only to refresh **`ks.cfg`** without reinstalling. |
| 5 | Full rebuild | `rebuild-all-*` |
| 6 | Revert VM snapshot (Linux) | `reset-sandbox.sh` |
| — | Boot existing VM (host) | `start-vm-linux.sh`, `start-vm-mac.sh`, `start-vm-windows.ps1` (wrappers: **`../start-vm.sh`**, **`../start-vm.ps1`**) |
| — | Stop / kill VM; optional full cleanup | `stop-vm-linux.sh` (**`--shutdown`**, **`--remove`**), `stop-vm-mac.sh` (**`--remove`**), `stop-vm-windows.ps1` (**`-Shutdown`**, **`-Remove`**) — wrappers: **`../stop-vm.sh`**, **`../stop-vm.ps1`** |

Templates: **`ks.template.cfg`**. Generated artifact: **`../ks.cfg`** at repo root.

See [spec/how/repo-layout.md](../spec/how/repo-layout.md) and [spec/how/bootstrap.md](../spec/how/bootstrap.md).
