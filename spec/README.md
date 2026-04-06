# Specification index

This **`spec/`** tree is the **canonical description of the AI Sandbox project** for **humans and AI assistants**. The repository **[README.md](../README.md)** is the short front door; **`spec/`** is the **manual**: intent, requirements, architecture, every major script’s role, and conventions for regenerating or extending the system.

---

## Purpose (especially for AI)

When implementing features, debugging, or **reconstructing the project from documentation**:

1. Read **`what/`** for **intent and constraints** (what must never break).
2. Read **`how/use-cases.md`** for **workflow** (first-time vs daily).
3. Read **`how/inventory.md`** for **what file does what** (complete map).
4. Read **`how/conventions.md`** for **virtiofs tags, env vars, kickstart tokens**.
5. Read **`how/architecture.md`** and **`how/bootstrap.md`** for **data flow and host-specific procedures**.
6. Read **`how/runtime.md`** and **`how/operations.md`** for **guest provisioning, containers, CI, troubleshooting**.

**Implementation source of truth:** The specs describe **behavior and contracts**. Exact **line-level** behavior (full kickstart `%post`, every `dnf install`, firewall rules, `Containerfile` layers) lives in **`host/ks.template.cfg`**, **`config/install-inside-vm.sh`**, and **`config/Containerfile`**. An AI should **read those files** when reproducing installs or changing packages—**`inventory.md`** names them and **`requirements.md`** states the product goals they satisfy.

**What you can regenerate from spec alone:** Architecture, script graph, env var contracts, virtiofs layout, kickstart flow, test expectations, and new scripts that **call the same helpers** and **honor the same paths**. **What still requires reading code:** Verbatim kickstart/post-install snippets, full package/version lists, and dashboard code.

**To recreate the project from scratch:** Read the specs in the order above. Then read these three implementation files for exact package lists and kickstart `%post` details that the spec deliberately does not duplicate: **`config/Containerfile`** (image layers), **`config/install-inside-vm.sh`** (guest provisioning + firewall), and **`host/ks.template.cfg`** (Anaconda template + systemd first-boot units). Every other script can be re-derived from **`inventory.md`** (contracts) + **`conventions.md`** (env vars and paths).

---

## Document map

| Kind | Document | Contents |
|------|----------|----------|
| What | [what/overview.md](what/overview.md) | Purpose, trust model, Workstation vs Server, layered security, **out of scope** (malware lab) |
| What | [what/requirements.md](what/requirements.md) | PR / FR / NFR, installation media policy, constraints |
| How | [how/use-cases.md](how/use-cases.md) | Greenfield vs daily workflow; script map |
| How | [how/inventory.md](how/inventory.md) | **Full file/script inventory** (host, config, tools, tests, CI) |
| How | [how/conventions.md](how/conventions.md) | Repo root, **`VM_NAME`**, virtiofs tags, kickstart tokens, container names |
| How | [how/bootstrap.md](how/bootstrap.md) | Host prep, **`vm-host.env`**, VM creation per OS, kickstart artifacts |
| How | [how/architecture.md](how/architecture.md) | Host vs guest vs Podman; mounts; qemu/SELinux; projects |
| How | [how/repo-layout.md](how/repo-layout.md) | **Do not rename** `config/` / `secrets/` / `workspace/`; root vs `host/` |
| How | [how/runtime.md](how/runtime.md) | Cursor/Claude, first boot, Podman, Claude MCP merge, dashboard |
| How | [how/operations.md](how/operations.md) | Snapshots, reset, stop/remove VM, pins, troubleshooting, **tests** |

---

## Suggested reading order

1. **`what/overview`** → **`what/requirements`**
2. **`how/use-cases`**
3. **`how/inventory`** + **`how/conventions`**
4. **`how/bootstrap`** → **`how/architecture`**
5. **`how/runtime`** → **`how/operations`**
6. **`how/repo-layout`** as needed for path constraints

The repository **[README.md](../README.md)** remains the entry point for clone-and-run quickstart.
