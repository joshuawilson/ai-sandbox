# How — architecture: host, VM, mounts, and projects

This document explains **how the pieces fit together**: what lives on the **physical host**, what runs **inside the Fedora VM**, how **virtiofs / CIFS** expose host directories to the guest, and how **Podman** containers see your **project code**.

For procedures (install order, kickstart, scripts), see [bootstrap.md](bootstrap.md). For day-to-day commands, see [runtime.md](runtime.md).

## Layers

```
Host OS (Fedora, macOS, or Windows)
  └─ Hypervisor: KVM, Hyper-V, or UTM
        Fedora Workstation guest (user `ai`)
              ├─ virtiofs / CIFS: host config, secrets, workspace (see below)
              ├─ Guest local disk: OS, packages, Cursor, Podman images, ~/.cache, …
              └─ Rootless Podman
                    └─ Container `ai-dev-<project>` bind-mounts project dir → /workspace
```

Each inner layer can be compromised without automatically compromising the outer one; the **main product goal** is keeping routine dev work and **sandbox SSH keys** off the bare-metal session. The **guest** is still a full dev machine (sudo, network).

## What lives on the host under `~/ai-sandbox/`

On the machine where you cloned this repo, the tree is usually:

| Path (host) | Role |
|-------------|------|
| **`config/`** | Shared automation (`Containerfile`, `ensure-sandbox-mounts.sh`, etc.). Mounted **read-only** into the guest (virtiofs). |
| **`secrets/`** | SSH keys, API key files, `vm-password.env`. Mounted **read-only** into the guest. **Do not commit** contents. |
| **`workspace/`** | Writable host share. **Per-project working trees** live at **`workspace/<name>/`** (git repos, clones, or copies). You may also keep host-only subtrees such as **`workspace/.ai-sandbox-private/`** (gitignored) for API fallbacks. |
| **`logs/`** | Optional; created by scripts; typically not virtiofs unless you put it there. |

Install scripts create **`workspace/`** on the host. Older layouts used **`workspace/projects/<name>/`**; **`ensure-sandbox-mounts.sh`** and host **`install-virt-*`** flatten those to **`workspace/<name>/`** when possible.

## How the guest sees the same tree (`~/ai-sandbox/`)

After **`config/ensure-sandbox-mounts.sh`** runs in the guest:

| Guest path | Resolves to |
|------------|-------------|
| **`~/ai-sandbox/config`** | `/mnt/host-config` → host **`config/`** (RO) |
| **`~/ai-sandbox/secrets`** | `/mnt/host-secrets` → host **`secrets/`** (RO) |
| **`~/ai-sandbox/workspace`** | `/mnt/host-workspace` → host **`workspace/`** (RW) |

So **`~/ai-sandbox/workspace/foo`** in the VM is the **same directory** as **`~/ai-sandbox/workspace/foo`** on the host. There is **no VM-specific format** inside project folders—normal files and **`.git`** directories.

**Linux (libvirt):** `host/create-vm-linux.sh` passes three virtiofs tags: `host-config`, `host-secrets`, `host-workspace` mapping to the host paths above. Exact tag names and env var conventions: **[conventions.md](conventions.md)**; full script list: **[inventory.md](inventory.md)**.

### Where the repo should live on the host (libvirt + virtiofs)

**The constraint:** QEMU runs as the system user **`qemu`**, not as you. A typical **`/home/$USER`** directory is mode **0700**, so **only you** can traverse it. That is correct for a home directory—but it means **qemu cannot open** `~/ai-sandbox/config` (or anything under your home) **unless** something grants access.

**There is no fundamental conflict** between “I want secrets and projects under my home” and “libvirt needs to read those paths.” You only need a **controlled** way for **qemu** to reach the three trees.

**Reasonable options (pick one):**

| Approach | Idea | Tradeoff |
|----------|------|----------|
| **DAC + SELinux** (`host/lib/virtiofs-qemu-access.sh`) | **ACLs** for **`u:qemu`** on the path and trees (see above). With **SELinux Enforcing**, paths under **`/home`** are **`user_home_t`**; libvirt’s QEMU cannot use them for virtiofs until labeled **`virt_content_t`** (`semanage` + **`restorecon`**, or **`chcon`**). A plain **`sudo -u qemu test`** is **not** enough to validate the real QEMU process (different SELinux context). | Same virtiofs exposure class as above. **`virt_content_t`** is the usual label for host content shared into guests. |
| **Repo outside `$HOME`** (e.g. **`/opt/ai-sandbox`**, **`/srv/ai-sandbox`**) with **0755** (or root-owned + group) | No ACLs on home; **qemu** can traverse standard paths. | Secrets are **not** under your home on disk; you can still **back** them up to home or sync—operationally, many people are fine with **`/opt`** for “shared tooling” and keep secrets there with tight permissions. |
| **Split tree** | Keep **`config/`** in the repo under `/opt`, but put **`secrets/`** and **`workspace/`** on separate paths under **`$HOME`** and pass **three** `--filesystem` sources (each path must still be reachable by **qemu**—so home subtrees still need ACLs or looser permissions). | More moving parts; only worth it if you have a strict policy. |

**What is usually “best”:** For a **single-user** Linux workstation, **ACLs for `qemu`** plus **`virt_content_t`** when SELinux is on is the **standard** fix for a repo under **`$HOME`**. Putting the **whole repo** under **`/opt`** or **`/srv`** is the **cleanest** if you want to avoid home-specific SELinux relabeling (paths there are often not **`user_home_t`**).

**What to avoid:** **`chmod o+x $HOME`** or **`chmod 755 $HOME`** so “everyone” can traverse—**wider** exposure than ACLs for **qemu** only.

**CIFS / SMB:** With **`config/cifs.env.example`**, the whole host **`ai-sandbox`** tree can be mounted and bind-split so **paths match** the virtiofs layout.

## Podman and “project”

- **`config/container.env`** sets **`WORKSPACE_ROOT="$HOME/ai-sandbox/workspace"`**.
- **`config/start-container.sh`** runs a container named **`ai-dev-<name>`** with **`-v "$WORKSPACE_ROOT/<name>:/workspace"`**.
- **`<name>`** is a single path segment: the folder name under **`workspace/`** on the host.

You can populate **`workspace/myapp/`** on the **host** (clone, copy, or unpack); after mounts, **`start-container.sh myapp`** uses that tree as **`/workspace`** in the container. There is no separate “repo list” config—only what you place under **`workspace/`**.

## Config vs workspace (trust and persistence)

- **`config/`** and **`secrets/`** are **read-only** in the guest so automation and keys are harder to accidentally rewrite from the VM.
- **`workspace/`** is **writable** from the guest so editors and tools can save work; that data **persists on the host** and survives **replacing the VM disk** as long as you keep the host directory.
- **Pushing to a remote Git host** still protects against **host** disk loss and is the standard off-site backup.

## Cursor and SSH in the container

- **Cursor** runs in the **guest** graphical session and opens directories under **`~/ai-sandbox/workspace/<name>/`** like any editor.
- **Containers** receive **`secrets/ssh`** read-only for Git; they do not automatically see all of **`workspace/`**—only the bound **`workspace/<name>`** as **`/workspace`**.

## Related documents

| Topic | Document |
|-------|----------|
| **Every script / file** | [inventory.md](inventory.md) |
| Env vars, virtiofs tags, kickstart tokens | [conventions.md](conventions.md) |
| Automation level by host (UTM, Hyper-V, virtiofs) | [bootstrap.md](bootstrap.md#automation-level-by-host) |
| First boot, daily workflow, `install-inside-vm.sh`, firewall | [runtime.md](runtime.md) (see [repeatable workflows](runtime.md#repeatable-workflows)) |
| Snapshots, reset, tests | [operations.md](operations.md) |
| Product requirements (mounts, PRs) | [../what/requirements.md](../what/requirements.md) |
| Which files run on host vs guest | [repo-layout.md](repo-layout.md) |
| First-time setup vs daily start | [use-cases.md](use-cases.md) |
