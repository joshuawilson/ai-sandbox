# Project inventory — files, scripts, and roles

This document is the **machine-oriented map** of the repository: what exists, where it runs (host OS vs guest VM), and what it does. Use it with **[conventions.md](conventions.md)** (environment variables, virtiofs tags, kickstart placeholders) and **[architecture.md](architecture.md)** (data flow).

**Regeneration note:** An AI can use this inventory plus the other **`spec/`** docs to **reimplement behavior** (new scripts with the same contracts). It cannot replace reading **`host/ks.template.cfg`**, **`config/Containerfile`**, and **`config/install-inside-vm.sh`** for exact package lists, firewall rules, and kickstart `%post` details—those files remain the **authoritative implementation** for those concerns. This spec describes their **role** and **relationships**.

---

## Directory tree (conceptual)

```
ai-sandbox/
├── setup-host.sh, setup-host.ps1     # thin wrappers → host/setup-host.*
├── start-vm.sh, start-vm.ps1          # thin wrappers → host/start-vm-*
├── stop-vm.sh, stop-vm.ps1            # thin wrappers → host/stop-vm-*
├── ks.cfg                             # generated; gitignored
├── README.md                          # human quickstart
├── .gitignore                         # secrets, ks.cfg, host/vm-host.env, …
├── .github/workflows/tests.yml        # CI: ./tests/run.sh
├── host/                              # physical host only (Fedora/macOS/Windows)
├── config/                            # mounted into guest (virtiofs/CIFS); automation
├── secrets/                           # host-only; gitignored content; mounted RO in guest
├── workspace/                         # host-backed writable share; per-project dirs workspace/<name>/
├── tools/                             # kickstart HTTP server (macOS/Windows path)
├── tests/                             # bash -n + integration tests
└── spec/                              # this documentation set
```

---

## Repo root wrappers

| File | Invokes |
|------|---------|
| **`setup-host.sh`** | **`host/setup-host.sh`** |
| **`setup-host.ps1`** | **`host/setup-host.ps1`** |
| **`start-vm.sh`** | **`host/start-vm-linux.sh`** \| **`host/start-vm-mac.sh`** by OS |
| **`start-vm.ps1`** | **`host/start-vm-windows.ps1`** |
| **`stop-vm.sh`** | **`host/stop-vm-linux.sh`** \| **`host/stop-vm-mac.sh`** |
| **`stop-vm.ps1`** | **`host/stop-vm-windows.ps1`** |

---

## `host/` — physical machine (not the guest)

### Entrypoints and setup

| Script | Purpose |
|--------|---------|
| **`setup-host.sh`** | Fedora: `install-virt-linux.sh` → `check-host-fedora.sh` → optional `configure-vm-host.sh`. macOS: `install-virt-mac.sh` → `check-host-mac.sh` → optional configure. Flags: `--check-only`, `--skip-vm-config`. Env: `SKIP_VM_CONFIGURE`. |
| **`setup-host.ps1`** | Windows (admin): `install-virt-windows.ps1` → `check-host-windows.ps1` → optional configure (`configure-vm-host.ps1` or `bash configure-vm-host.sh`). `-CheckOnly`, `-SkipVmConfig`. |
| **`configure-vm-host.sh`** | Interactive **`host/vm-host.env`** + optional **`secrets/vm-password.env`** (auto-generate default). `--skip-password`, `--help`. |
| **`configure-vm-host.ps1`** | Windows equivalent; `-SkipPassword`. |

### VM host configuration (shared)

| File | Purpose |
|------|---------|
| **`vm-host.env.example`** | Documented defaults: `VM_NAME`, `VM_DISK_GB`, `VM_MEMORY_MIB`, `VM_VCPUS`, `VM_CPU_MODE`, `FEDORA_VER`, `LOCATION_URL`, `VM_DIR`, `VM_LIBVIRT_NETWORK`, `VM_ISO_URL`, `VM_HYPERV_SWITCH`. |
| **`vm-host.env`** | Operator copy (gitignored). Sourced by bash scripts; parsed by PowerShell helpers. |

### Install and check (per OS)

| Script | Purpose |
|--------|---------|
| **`install-virt-linux.sh`** | `@virtualization`, libvirt, `virt-install`, dirs under repo, `secrets/ssh` keygen, user → `libvirt` group; runs **`ensure_qemu_access_for_virtiofs`** so clones under **`/home`** work with virtiofs. |
| **`fix-virtiofs-qemu-access.sh`** | Re-runs virtiofs ACL + SELinux prep; use if checks fail or repo was cloned before that automation existed. |
| **`install-virt-mac.sh`** | Homebrew deps: qemu, git, curl, jq; dirs; SSH key. |
| **`install-virt-windows.ps1`** | Hyper-V, Git for Windows, dirs, SSH key via `ssh-keygen`. |
| **`check-host-fedora.sh`** | kvm, RPMs, libvirtd, group, `virsh`, default network. |
| **`check-host-mac.sh`** | UTM, brew tools, paths. |
| **`check-host-windows.ps1`** | Hyper-V, switch, Git, openssl, layout. |

### Kickstart generation

| Script | Output |
|--------|--------|
| **`ks.template.cfg`** | Anaconda template: `__PASSWORD_HASH__`, `__SSH_KEY__`; user `ai`; `%post` installs first-boot unit. |
| **`generate-ks-fedora.sh`** | **`ks.cfg`** at repo root (openssl hash + pubkey). |
| **`generate-ks-mac.sh`** | Same. |
| **`generate-ks-windows.ps1`** | Same; uses Git’s openssl; **`Get-SandboxRepoRoot`**. |

### VM create / lifecycle

| Script | Purpose |
|--------|---------|
| **`create-vm-linux.sh`** | Load `vm-host-env.sh`; `virt-install` netinst + initrd-inject `ks.cfg`; virtiofs tags `host-config`, `host-secrets`, `host-workspace`; snapshot `clean`. |
| **`create-vm-mac.sh`** | Download ISO; `qemu-img` disk; UTM instructions; optional `generate-ks-mac.sh`. |
| **`create-vm-windows.ps1`** | VHD, Hyper-V VM, DVD; optional SMB share `-CreateSmbShare`. |
| **`start-vm-linux.sh`** | `virsh start`; domain from `vm-host.env` / `VIRSH_DOMAIN`. |
| **`start-vm-mac.sh`** | UTM / instructions. |
| **`start-vm-windows.ps1`** | `Start-VM`. |
| **`stop-vm-linux.sh`** | destroy / optional shutdown / `--remove`. |
| **`stop-vm-mac.sh`** | `utmctl` / disk remove. |
| **`stop-vm-windows.ps1`** | `Stop-VM`; `-Remove`. |
| **`reset-sandbox.sh`** | Revert libvirt snapshot `clean`. |
| **`rebuild-all-fedora.sh`** | destroy VM, remove disk, `create-vm-linux.sh`. |
| **`rebuild-all-mac.sh`** | remove `vm/${VM_NAME}.qcow2`, `create-vm-mac.sh`. |
| **`rebuild-all-windows.ps1`** | remove VM + VHD, `create-vm-windows.ps1`. |

### Secrets helpers (host)

| Script | Purpose |
|--------|---------|
| **`write-vm-password-env.sh`** | **`secrets/vm-password.env`** with `VM_PASSWORD=` (random or `--force`). |
| **`write-vm-password-env.ps1`** | Same; UTF-8 no BOM. |

### `host/lib/`

| File | Purpose |
|------|---------|
| **`sandbox-root.sh`** | `sandbox_repo_root` — `SANDBOX`, `AI_SANDBOX_HOME`, or parent of `host/`. |
| **`virtiofs-qemu-access.sh`** | ACL + SELinux `virt_content_t` for qemu reading repo paths. |
| **`vm-host-env.sh`** | `vm_host_env_load`, `vm_host_apply_defaults_linux`, `vm_host_apply_defaults_mac`. |
| **`read-vm-host-env.ps1`** | `Get-SandboxRepoRoot`, `Get-VmHostEnvMerged` for PowerShell scripts. |

---

## `config/` — guest-facing automation (on host disk, shared into VM)

| Script / file | Purpose |
|---------------|---------|
| **`ensure-sandbox-mounts.sh`** | virtiofs or CIFS; fstab; symlinks **`~/ai-sandbox/{config,secrets,workspace}`**. Migrates legacy **`workspace/projects/<name>/`** → **`workspace/<name>/`** and removes obsolete **`~/ai-sandbox/projects`** symlink. Run as root with username arg. |
| **`install-inside-vm.sh`** | Main guest provisioning: dnf (includes **Terminator** + GNOME autostart), podman, firewall, audit, build `ai-dev` image, Cursor RPM, `merge-claude-bootstrap.sh`, Claude config, Vertex env sync. **`setup-claude.sh`** runs at the end only with a **TTY** (not when systemd runs this script on first boot); then installs **`@anthropic-ai/claude-code`** if **`claude`** is still missing. Skip wizard: **`AI_SANDBOX_SKIP_CLAUDE_SETUP=1`**. |
| **`setup-claude.sh`** | Interactive Claude Code setup: Red Hat (Vertex, gcloud, internal links) vs standard (API key + Anthropic install). |
| **`run-claude-setup-once.sh`** | GNOME autostart helper: opens **`gnome-terminal`** for **`setup-claude.sh`** when first boot had no TTY. |
| **`claude-setup-gui-session.sh`** | Inner session run inside that terminal; marks **`~/.config/ai-sandbox/claude-setup-autorun.done`** and removes autostart **`.desktop`**. |
| **`install-google-cloud-cli-fedora.sh`** | Adds Google DNF repo and installs `google-cloud-cli` (see [Google’s RPM guide](https://cloud.google.com/sdk/docs/install-sdk#rpm)). Run with **sudo**. |
| **`lib/claude-login-env.sh`** | Idempotent **`~/.bashrc`** hook; copy Vertex env from **`secrets/`** or **`workspace/.ai-sandbox-private/`** → **`~/.config/ai-sandbox/claude-vertex.env`**. |
| **`sync-claude-vertex-env.sh`** | Guest: copies host-backed **`claude-vertex.env`** into **`~/.config/ai-sandbox/`** (wrapper around **`ai_sandbox_sync_claude_vertex_env_from_sandbox`**). Run: **`bash ~/ai-sandbox/config/sync-claude-vertex-env.sh`**. |
| **`ensure-claude-settings.sh`** | Guest: if **`~/.claude/settings.json`** is missing or empty, copy **`config/claude-code.settings.json`** (**`bypassPermissions`**). **`--force`** overwrites. **`bash ~/ai-sandbox/config/ensure-claude-settings.sh`**. |
| **`lib/podman-claude-devhome.sh`** | **`start-container.sh`**: copy guest **`~/.claude/settings.json`**, **`~/.claude.json`**, **`~/.claude/skills/`** into **`container-home/<name>/`** for Podman **`/home/dev`**. |
| **`lib/podman-workspace-volumes.sh`** | Sets up volume mount arrays for podman; handles virtiofs vs SELinux labeling. Sourced by **`start-container.sh`** and **`restore-project.sh`**. |
| **`lib/podman-vertex-container-opts.sh`** | Prepares Vertex AI + gcloud environment and volumes for containers. Sets **`PODMAN_VERTEX_ENV_FILE`** and **`PODMAN_VERTEX_VOLS`**. |
| **`lib/podman-run-common.sh`** | Shared function **`ai_sandbox_run_dev_container`** — eliminates duplicated `podman run` logic between **`start-container.sh`** and **`restore-project.sh`**. |
| **`merge-claude-bootstrap.sh`** | Merge MCP JSON from **`config/claude-bootstrap/mcp.json`**, **`workspace/.ai-sandbox-private/claude-bootstrap/mcp.json`**, **`secrets/claude-mcp.json`**; copy skills from **`config/claude-bootstrap/skills/`** and workspace-private skills. |
| **`Containerfile`** | `ai-dev` image: dev user, toolchains, hardened defaults. |
| **`container.env`** | Image name, CPU/memory/pid limits, `WORKSPACE_ROOT`, `SECRETS_DIR`. |
| **`build-container.sh`** | `podman build` → `ai-dev`. |
| **`start-container.sh`** | Run `ai-dev-<name>` with hardened flags; bind project + SSH RO. Use **`--detach`** for background mode. |
| **`stop-container.sh`** | Stop/remove project container. |
| **`shell-into-container.sh`** | Open interactive shell in running `ai-dev-<name>` container. |
| **`start-dev.sh`** | First project + detached container + Cursor. |
| **`first-project-name.sh`** | Lexicographic first non-hidden dir under `~/ai-sandbox/workspace/` or `default`. |
| **`rebuild-container.sh`** | Rebuild image using `container.env`. |
| **`reset-project.sh`** | Reset project container state. |
| **`snapshot-project.sh`** | `podman commit` snapshot image. |
| **`restore-project.sh`** | Run container from snapshot. |
| **`run-dashboard.sh`** | uvicorn dashboard localhost. |
| **`dashboard.py`** | FastAPI start/stop with bearer token. |
| **`index.html`** | Dashboard UI. |
| **`claude-code.settings.json`** | Template → `~/.claude/settings.json`. |
| **`.claude/config.json`** | Claude API template (empty key in repo). |
| **`claude-bootstrap/mcp.json.example`** | Example MCP fragment; copy to **`mcp.json`** to enable. |
| **`claude-bootstrap/skills/`** | Optional committed skills tree (`SKILL.md` files). |
| **`cifs.env.example`** | CIFS credentials template for guest **`/etc/ai-sandbox/cifs.env`**. |
| **`ai-kill-switch.sh`** | Optional network monitor experiment. |
| **`ai-recorder.sh`** | Optional logging experiment. |

---

## `tools/`

| File | Purpose |
|------|---------|
| **`serve-kickstart.sh`** | HTTP server for `ks.cfg` (port 8000) — macOS / Windows / Git Bash path. |
| **`serve-kickstart.ps1`** | Windows variant (Python). |

---

## `tests/`

| File | Purpose |
|------|---------|
| **`run.sh`** | Orchestrates all tests. |
| **`test_syntax.sh`** | `bash -n` on `*.sh`; optional `SHELLCHECK=1`. |
| **`test_merge_claude_bootstrap.sh`** | Integration test for `merge-claude-bootstrap.sh`. |
| **`test_first_project_name.sh`** | Tests `first-project-name.sh`. |
| **`lib.sh`** | Shared test helpers. |

---

## `secrets/` (content gitignored)

Expected paths (see **`.gitignore`**): `ssh/*`, `vm-password.env`, `ai-secrets.env`, API keys, tokens, `claude-settings.json`, `claude-mcp.json`, etc. **`secrets/ssh/.gitkeep`** preserves the directory.

| File | Purpose |
|------|---------|
| **`secrets/gen-ssh-key.sh`** | Standalone **`ssh-keygen`** for **`secrets/ssh/id_ed25519`** (install scripts usually create the key if missing). |
| **`secrets/claude-mcp.json.example`** | Example gitignored **`secrets/claude-mcp.json`** (tokens); duplicate server names override bootstrap. |
| **`secrets/claude-vertex.env.example`** | Example **`secrets/claude-vertex.env`** for Vertex (Red Hat) users. |

---

## Generated and ignored artifacts

| Artifact | Produced by | Notes |
|----------|-------------|--------|
| **`ks.cfg`** | `generate-ks-*` | Repo root; gitignored. |
| **`host/vm-host.env`** | `configure-vm-host.*` or manual | gitignored. |

---

## CI

**`.github/workflows/tests.yml`**: on push/PR to `main`/`master`, runs **`./tests/run.sh`** on `ubuntu-latest`.

---

## Related

- **[conventions.md](conventions.md)** — virtiofs tags, env vars, kickstart tokens.
- **[bootstrap.md](bootstrap.md)** — human procedure order.
- **[repo-layout.md](repo-layout.md)** — constraints on moving directories.
