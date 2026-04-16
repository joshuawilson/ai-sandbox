# How — operations, snapshots, troubleshooting, pins

## Project image snapshots (Podman)

- **`config/snapshot-project.sh`** — `podman commit ai-dev-<name> ai-dev-<name>-snapshot`. This captures **container filesystem layers only**, **not** bind-mounted **`/workspace`**.
- **`config/restore-project.sh`** — Runs a new container from the snapshot image with the **same** workspace and SSH bind mounts as **`start-container.sh`**.

## VM snapshot reset (Linux / libvirt)

- **`host/reset-sandbox.sh`** — Destroys running domain, **`virsh snapshot-revert <domain> clean`**, starts VM. Defaults: **`VIRSH_DOMAIN`** or **`VM_NAME`** from **`host/vm-host.env`** (else **`ai-sandbox`**), **`VIRSH_SNAPSHOT=clean`**. Requires snapshot **`clean`** to exist (created at end of **`host/create-vm-linux.sh`** when **`virsh snapshot-create-as`** succeeds).

## Stop or remove the VM (host)

- **`stop-vm.sh`** / **`stop-vm.ps1`** (repo root) dispatch to **`host/stop-vm-linux.sh`**, **`host/stop-vm-mac.sh`**, **`host/stop-vm-windows.ps1`**.
- **Linux:** **`virsh destroy`** by default; **`--shutdown`** tries ACPI first; **`--remove`** runs **`undefine --remove-all-storage`** and deletes **`$VM_DIR/<domain>.qcow2`** (default **`/var/lib/libvirt/images`**).
- **macOS:** **`utmctl stop`** when UTM 4+ is installed; **`--remove`** deletes **`vm/<VM_NAME>.qcow2`** (default name **`ai-sandbox`**; set in **`host/vm-host.env`**). Remove the VM in UTM’s UI separately.
- **Windows:** **`Stop-VM -TurnOff -Force`** by default; **`-Shutdown`** tries a graceful stop; **`-Remove`** runs **`Remove-VM`** and deletes **`vm\<name>.vhdx`**.

## Kickstart and SSH key mechanics

- **`host/generate-ks-*.sh`** inject **`__PASSWORD_HASH__`**, **`__SSH_KEY__`**, and **`__SANDBOX_OWNER_UID__`** into **`host/ks.template.cfg`** (guest **`ai`** UID = owner of **`secrets/`** on the host so virtiofs can traverse mode-**700** dirs).
- VM user **`ai`** receives the SSH public key via kickstart **`sshkey`** line.
- First-boot runs **`install-inside-vm.sh`**; see [runtime.md](runtime.md).

## Version and URL pins

| Item | Override / note |
|------|------------------|
| VM sizing, name, Fedora, ISO URL, libvirt network, Hyper-V switch | **`host/vm-host.env`** (see **`host/vm-host.env.example`**) or **`host/configure-vm-host.*`** |
| Fedora release (env / shell) | **`FEDORA_VER`**, **`LOCATION_URL`** — set in **`vm-host.env`** or exported before **`create-vm-linux.sh`** |
| Fedora ISO (Mac/Windows) | **`VM_ISO_URL`** in **`vm-host.env`** |
| Cursor RPM | **`CURSOR_RPM_URL`** when running **`install-inside-vm.sh`** |
| Claude default model | **`config/.claude/config.json`** and heredoc in **`install-inside-vm.sh`** |
| Claude Code permission mode | **`config/claude-code.settings.json`** → guest **`~/.claude/settings.json`** (**`bypassPermissions`**); optional host override **`secrets/claude-settings.json`** (must be **non-empty** or install skips it). Repair: **`bash ~/ai-sandbox/config/ensure-claude-settings.sh`** (**`--force`** to overwrite). |
| Claude MCP + skills from host | **`config/merge-claude-bootstrap.sh`** — **`config/claude-bootstrap/`**, **`workspace/.ai-sandbox-private/claude-bootstrap/`**, **`secrets/claude-mcp.json`** |
| Default project for **`start-dev.sh`** | **`config/first-project-name.sh`** — first non-hidden directory under **`~/ai-sandbox/workspace/`** (lexicographic), else **`default`** |
| Cursor Agent auto-run | In-app only; see [runtime.md — Non-interactive defaults](runtime.md#non-interactive-defaults-do-it-without-asking) |

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| **`host/generate-ks-fedora.sh` fails** | **`secrets/ssh/id_ed25519.pub`** exists; run **`host/install-virt-linux.sh`** first. |
| **`virt-install` / netinst fails** | HTTPS to Fedora mirrors; **`libvirtd`**; **`virsh net-list`** shows **default** active. |
| **First-boot service fails** | **`journalctl -u ai-sandbox-firstboot.service -b`**; virtiofs tag names match **`host/create-vm-linux.sh`**. |
| **Firewall blocks something** | Rules are on zone **`block`**; add services/ports with **`--zone=block`**. |
| **`host/generate-ks-windows.ps1` fails** | Git for Windows installed (**`host/install-virt-windows.ps1`**); **`openssl.exe`** under **`Git\usr\bin`**; **`vm-password.env`** is bash-style **`VM_PASSWORD=...`**. |
| **`start-container` says container exists** | **`podman rm -f ai-dev-<name>`** or **`stop-container.sh`**, then start again. |
| **Guest: `Permission denied` on `/home/dev/.bashrc`, `.`, or `ls` in `/workspace` inside the container** | **`--user "$(id -u):$(id -g)"`** (not image UID 1000). **`/home/dev`** is **`~/.local/share/ai-sandbox/container-home/<name>/`**. For **`ls` in `/workspace` only** on virtiofs: **`start-container.sh`** auto adds **`--security-opt label=disable`** when **`findmnt`** reports **`virtiofs`** (SELinux cannot relabel that share). Override via **`AI_SANDBOX_PODMAN_LABEL_DISABLE`** in **`config/container.env`** (**`0`** = **`:z`/`:Z`**). If the guest cannot list the directory **outside** the container, fix DAC with **`chown -R "$(id -u):$(id -g)" ~/ai-sandbox/workspace/<name>`**. |
| **Domain already exists (`virt-install`)** | Undefine/remove old VM (**`host/rebuild-all-fedora.sh`** path) or pick a new name. |
| **First-boot fails (no virtiofs)** | Guest not created with **`host/create-vm-linux.sh`** virtiofs tags; use **SMB** + **`config/cifs.env.example`**, then **`ensure-sandbox-mounts.sh`** and **`install-inside-vm.sh`** manually. |
| **Claude CLI / `~/.claude` missing after rebuild** | **API path:** **`secrets/claude_api_key`** or **`workspace/.ai-sandbox-private/claude_api_key`**, then **`install-inside-vm.sh`**. **Vertex:** edit host **`claude-vertex.env`**, then on the guest **`bash ~/ai-sandbox/config/sync-claude-vertex-env.sh`** (or **`install-inside-vm.sh`** / **`setup-claude.sh`**). |
| **Guest: `syntax error near unexpected token` sourcing `claude-vertex.env`** | The **`ANTHROPIC_VERTEX_PROJECT_ID`** value was not a real project ID (e.g. pasted prose). Fix or remove **`~/.config/ai-sandbox/claude-vertex.env`** and host **`secrets/claude-vertex.env`** / **`workspace/.ai-sandbox-private/claude-vertex.env`**, then re-run **`setup-claude.sh`**. Newer **`setup-claude.sh`** validates the ID and writes the value shell-quoted. |
| **Cursor asks to sign in every time** | Session is in the **guest** profile, not **`secrets/`**. After a **new disk**, sign in again; or back up **`~/.config/Cursor`** (and related) to the host manually if you need continuity. |
| **Guest: Permission denied on `/mnt/host-secrets` or `secrets/ssh`** | With virtiofs **passthrough**, **`secrets/`** is mode **700** for the **host** owner’s UID; guest **`ai`** must use that same numeric UID. Regenerate **`ks.cfg`** (**`host/generate-ks-fedora.sh`**) and **reinstall the VM** so kickstart applies **`user --uid=…`**. Compare **`id -u`** on the host with **`id -u ai`** in the guest. |
| **Guest: black screen, no GDM (hang at boot)** | **`ai-sandbox-virtiofs-mounts.service`** used **`Before=display-manager.service`**, so a **hung** virtiofs **`mount`** could block **GDM** indefinitely. Current template **removes** that ordering and adds **`TimeoutStartSec`** + **`timeout`** on the first mount. Regenerate **`ks.cfg`** and reinstall, or edit **`/etc/systemd/system/ai-sandbox-virtiofs-mounts.service`** on the guest and **`systemctl daemon-reload`**. |

## Tests

- **`tests/run.sh`** — **`bash -n`** on all repo **`*.sh`** files; integration tests for **`config/merge-claude-bootstrap.sh`** (temp **`HOME`** / fake sandbox tree); tests for **`config/first-project-name.sh`**. No extra packages required (**`python3`** for assertions). Optional: **`SHELLCHECK=1 ./tests/test_syntax.sh`** with ShellCheck installed.
- **CI:** **`.github/workflows/tests.yml`** runs **`./tests/run.sh`** on **`ubuntu-latest`** for pushes/PRs to **`main`** / **`master`**.
- Full script index: **[inventory.md](inventory.md#tests)**.

## Auxiliary scripts (reference)

- **`config/ai-kill-switch.sh`** — Optional crude network spike detector; **`INTERFACE`**, **`THRESHOLD_MB`** env vars.
- **`config/ai-recorder.sh`** — Logging experiment.
- **New project directory:** **`mkdir -p ~/ai-sandbox/workspace/<name>`** on the guest (host-backed), or use **`config/start-container.sh --detach <name>`**, which creates **`$WORKSPACE_ROOT/<name>`** if needed.
