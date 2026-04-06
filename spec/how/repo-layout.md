# Repository layout — constraints, roots, and where to look

This document states **structural rules** and **where scripts live**. For a **complete file-by-file list**, see **[inventory.md](inventory.md)**. For **env vars and virtiofs tags**, see **[conventions.md](conventions.md)**.

---

## Hard constraint: keep these three directories at the sandbox root

Linux **`host/create-vm-linux.sh`** passes these host paths to the guest as virtiofs tags. **Renaming or relocating** `config/`, `secrets/`, or `workspace/` requires updating **`host/create-vm-linux.sh`**, **`config/ensure-sandbox-mounts.sh`**, and every path that assumes **`~/ai-sandbox/{config,secrets,workspace}`**.

| Path (host) | Virtiofs tag | Role |
|-------------|--------------|------|
| **`~/ai-sandbox/config`** | `host-config` | Automation, `Containerfile`, `install-inside-vm.sh`, … |
| **`~/ai-sandbox/secrets`** | `host-secrets` | SSH keys, API keys, `vm-password.env` (gitignored) |
| **`~/ai-sandbox/workspace`** | `host-workspace` | Per-project trees **`workspace/<name>/`** (and optional private subtrees under **`workspace/`**) |

---

## Repo root vs `host/` vs `config/`

| Location | Runs on | Purpose |
|----------|---------|---------|
| **Repo root** | Host | Thin wrappers: **`setup-host.sh`**, **`start-vm.sh`**, **`stop-vm.sh`** (and **`.ps1`**). |
| **`host/`** | Host (Fedora/macOS/Windows) | Hypervisor install, checks, **`configure-vm-host.*`**, **`vm-host.env`**, create/start/stop VM, kickstart generators, **`ks.template.cfg`**. |
| **`config/`** | Guest (files live on host disk) | Mounts, **`install-inside-vm.sh`**, Podman, Cursor/Claude merge, dashboard, **`Containerfile`**. |
| **`tools/`** | Host | HTTP kickstart server for macOS/Windows installer workflows. |
| **`tests/`** | CI / dev | **`tests/run.sh`** — syntax + integration tests. |
| **`spec/`** | — | **Canonical documentation** for the whole project (**[README.md](../README.md)** in **`spec/`**). |

---

## Generated artifacts (not committed)

| Artifact | Producer |
|----------|----------|
| **`ks.cfg`** (repo root) | **`host/generate-ks-*.sh`** / **`generate-ks-windows.ps1`** |
| **`host/vm-host.env`** | **`host/configure-vm-host.*`** or manual copy from **`vm-host.env.example`** |

---

## Quick “I want to…”

| Goal | Where to look |
|------|---------------|
| **Every script and its role** | **[inventory.md](inventory.md)** |
| Env vars, virtiofs tags, kickstart tokens | **[conventions.md](conventions.md)** |
| First-time vs daily overview | **[use-cases.md](use-cases.md)** |
| Install order by OS | **[bootstrap.md](bootstrap.md)** |
| Mounts and trust boundaries | **[architecture.md](architecture.md)** |
| Guest provisioning and containers | **[runtime.md](runtime.md)** |
| Snapshots, troubleshooting, tests | **[operations.md](operations.md)** |

---

## Related

- **[host/README.md](../../host/README.md)** — host script table (operator-focused).
- **[../README.md](../README.md)** — repository front door.
