# What — overview

## Purpose

Provide an **isolated development environment** for AI-assisted coding: **Cursor** and **Claude** (and their LLM backends) run **inside a Fedora Workstation VM**, not on the physical host, so routine automation—shell commands, package installs, repo edits—does not directly use the operator’s bare-metal OS or personal default SSH keys.

The operator accepts **full capability inside the guest** in exchange for a **clear boundary**: secrets and Git credentials used for sandbox work are **dedicated keys** living **on the host**, exposed to workloads **read-only** where designed.

## Why Fedora Workstation (not Server)

The guest is a **desktop-class dev VM**: graphical session expectations for **Cursor**, Workstation package sets, and typical developer ergonomics. **Fedora Server** omits that stack by default. Kickstart uses **`@workstation-product-environment`** (see **`host/ks.template.cfg`**).

## Scope

- **In scope:** Fedora Workstation–style VM; **rootless Podman**; one **dev container image** (`ai-dev`) reused across projects; per-project workspaces; **sandbox SSH keys** for Git forges; **internet** from the guest; automation for **Fedora Linux, macOS, and Windows** hosts.
- **Out of scope:** Protection against a compromised hypervisor or hardware attacker; enterprise SSO; shipping a **custom remastered Fedora ISO** (see [requirements.md](requirements.md#installation-media-and-configuration-mounts)); **safe execution of malware or untrusted binaries for security research** (see below).

## Malware analysis and untrusted code

This environment is **not** intended as a **malware lab** or a guarantee that running viruses, trojans, or other malicious samples is safe for you or adjacent systems.

The design targets **trusted developer workflows**: AI tooling and your own code. The guest uses **host-backed** trees (**`workspace/`**, **`config/`**, **`secrets/`** via virtiofs or CIFS), and the VM may reach the **internet**. A malicious or compromised workload could try to damage or exfiltrate data on those mounts, abuse the network, or attack the **hypervisor** stack—none of which this project hardens to research-grade malware containment.

For deliberate malware or exploit analysis, use a **dedicated** setup (isolated hardware or throwaway VMs, **no** shared folders to important data, **no** production credentials, controlled networking, and procedures that match your **legal and organizational** requirements).

## Layered architecture

```
Host OS (Fedora, macOS, or Windows)
  └─ Fedora Workstation VM
        virtiofs: host config, secrets (read-only), workspace (per-project dirs workspace/<name>/)
      └─ Rootless Podman
            └─ ai-dev container (hardened run flags, /workspace per project)
```

Each layer reduces blast radius: compromising the inner container still requires breaking out of Podman, then the VM, then the hypervisor, before reaching the host filesystem. **Mount and path details:** [../how/architecture.md](../how/architecture.md).

## Security goals (summary)

| Layer | Intent |
|--------|--------|
| Host | Store `~/ai-sandbox/secrets/` (keys, tokens); **never commit**; register **only** the sandbox public key with Git hosts. |
| VM | `firewalld` default zone **block** with explicit allows; `auditd`; kickstart grants user **`ai`** passwordless **sudo** for automation—**only inside this VM**. |
| Container | `cap-drop=all`, `no-new-privileges`, read-only root, **SSH private keys read-only** under `/home/dev/.ssh`. |
| Dashboard | Optional; **no** remote control without `AI_SANDBOX_DASHBOARD_TOKEN`; **127.0.0.1** only. |

## Key concepts

- **Sandbox SSH key:** Ed25519 under `secrets/ssh/` on the **host**, injected for VM user **`ai`** and mounted read-only into containers—**not** your personal `~/.ssh` unless you choose to unify them.
- **Config in the repo:** `config/` on the host is the **source of truth** for automation and is shared into the VM (virtiofs on Linux).
- **First-boot provisioning:** Heavy setup runs **after** install via **systemd**, not during unreliable Anaconda `%post` virtiofs mounts.

See [requirements.md](requirements.md) for numbered requirements and [../how/runtime.md](../how/runtime.md) for Cursor/Claude placement in the guest.

## Specifications for implementers (including AI)

The **`spec/`** directory is the **authoritative narrative** for how this repository fits together: workflows, trust boundaries, and a **full inventory** of scripts in **[../how/inventory.md](../how/inventory.md)**. **[../how/conventions.md](../how/conventions.md)** documents environment variables, virtiofs tag names, and kickstart placeholder contracts.

**Regenerating or extending the project:** Start from **`spec/README.md`**, then **`inventory.md`** and **`conventions.md`**. Implementation details for the guest OS package set and kickstart **`%post`** live in **`config/install-inside-vm.sh`** and **`host/ks.template.cfg`**—read those files when matching behavior exactly; the specs describe **what** they must accomplish, not every line of shell.
