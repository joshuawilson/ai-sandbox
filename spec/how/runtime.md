# How — VM runtime: mounts, first boot, containers

For a **conceptual map** of host → VM → Podman, **`workspace/<name>/`**, and persistence, read **[architecture.md](architecture.md)** first. For a **list of every `config/` script**, see **[inventory.md](inventory.md)**.

## Repeatable workflows

| Situation | What to do |
|-----------|------------|
| **New host or first VM** | See **[use-cases.md](use-cases.md)** §1. On the **host**: **`./setup-host.sh`** or **`.\setup-host.ps1`** (optional **`host/configure-vm-host.*`** for **`vm-host.env`** + **`secrets/vm-password.env`**), then **`host/create-vm-*`** per [bootstrap.md](bootstrap.md). In the **guest**: first-boot runs **`install-inside-vm.sh`**; if mounts failed, run **`sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai`** then **`~/ai-sandbox/config/install-inside-vm.sh`**. |
| **Typical day** | See **[use-cases.md](use-cases.md)** §2. **Host:** **`./start-vm.sh`** or **`.\start-vm.ps1`**. **Guest:** **`~/ai-sandbox/config/start-dev.sh`** or **`start-container.sh <name>`**. Shell into running container: **`shell-into-container.sh <name>`**. Optionally **`git pull`** the host repo copy so **`config/`** updates in the guest. |
| **New guest disk (VM reset)** | Run **`~/ai-sandbox/config/install-inside-vm.sh`** again. **Host** **`secrets/`** and **`workspace/`** (including each **`workspace/<name>/`**) are unchanged if the host tree is intact. |
| **Reproducible environment** | Guest OS comes from the same **kickstart** + **`install-inside-vm.sh`**; pin tool URLs in [operations.md](operations.md). **Project code** is reproducible via normal **Git** in **`workspace/<name>/`** trees (and your remotes). |

**Security reminder:** The **guest** is intentionally a **full-trust dev machine** (sudo, outbound network, agents with broad permissions). The main boundary is **host vs VM**—keep **non-sandbox keys and personal data** off the shared **`workspace/`** if you treat the VM as untrusted. See [overview.md](../what/overview.md#security-goals-summary).

## Cursor and Claude in the same trust boundary

Both **Cursor** (IDE in the guest) and **Claude**-driven tooling are intended to run **inside the Fedora VM**, not on the host. Each can invoke an **LLM** according to its product; that traffic originates from the **guest**. The isolation promise is **host vs guest**: the **physical machine’s** filesystem and **non-sandbox** SSH keys are outside the VM’s normal reach. **Inside** the VM, the operator should assume **full local power** (sudo, network, arbitrary processes), with containment at the **hypervisor** layer—appropriate for **low-supervision** agent use when the goal is to protect the **host**, not to sandbox the operator from their own guest.

## Host-stored credentials (Cursor and Claude)

**Design:** Durable secrets live on the **host** under **`~/ai-sandbox/secrets/`** (see [requirements PR-8](../what/requirements.md)). In the guest, **`~/ai-sandbox/secrets`** is a symlink to the read-only virtiofs (or CIFS bind) mount **`/mnt/host-secrets`**, so the same files survive **VM rebuilds** as long as you keep them on the host checkout.

### Claude Code: interactive setup (Red Hat vs standard)

**`config/install-inside-vm.sh`** runs **`setup-claude.sh`** at the end when **stdin and stdout are a TTY** (you launched the script from an interactive shell). On **first boot**, **systemd** runs **`install-inside-vm.sh`** without a TTY, so the wizard is **not** run in that process—but the script registers **GNOME autostart** (`~/.config/autostart/ai-sandbox-claude-setup.desktop`) so **`run-claude-setup-once.sh`** opens **`gnome-terminal`** after graphical login and runs **`setup-claude.sh`** in a **real interactive terminal**. Without GNOME / **`gnome-terminal`**, run **`bash ~/ai-sandbox/config/setup-claude.sh`** manually. **Pure systemd** could attach **`StandardInput=tty`** to a virtual console (e.g. **`TTYPath=/dev/tty12`**), but that is brittle with GDM and easy to miss; autostart matches Workstation’s expected flow. Set **`AI_SANDBOX_SKIP_CLAUDE_SETUP=1`** to skip both inline wizard and autostart registration.

**Red Hat path** (Vertex / internal process): Asks whether you **already submitted** the internal confirmation form; only if **not**, it opens the form and waits for **Enter**. Collects **GCP project ID next** (optional browser open for the spreadsheet), then on Fedora/RHEL/CentOS installs **`google-cloud-cli`** via **`install-google-cloud-cli-fedora.sh`** when **`gcloud`** is missing (sudo, no extra yes/no). It does **not** run **`gcloud init`** (avoids slow project lists); it runs **`gcloud auth login`** if needed, **`gcloud config set project`**, **`gcloud auth application-default login`**, and **`gcloud auth application-default set-quota-project cloudability-it-gemini`**. Writes **`~/.config/ai-sandbox/claude-vertex.env`** and **`secrets/claude-vertex.env`** or **`workspace/.ai-sandbox-private/claude-vertex.env`**, login hooks, and the Claude **install menu**. Non-Linux: opens Google’s [RPM](https://cloud.google.com/sdk/docs/install-sdk#rpm) / [macOS](https://cloud.google.com/sdk/docs/install-sdk#mac) install docs. Template: **`secrets/claude-vertex.env.example`**.

**Standard path** (non–Red Hat): Asks if you already reviewed the docs; if not, opens [Claude Code overview](https://code.claude.com/docs/en/overview) and [Anthropic’s usage policy](https://www.anthropic.com/legal/aup). Prompts for a hidden **API key** when missing and saves **`secrets/claude_api_key`** or **`workspace/.ai-sandbox-private/claude_api_key`**, then the same **install menu** as above.

If you run **`setup-claude.sh` by itself** (not from the end of **`install-inside-vm.sh`**), run **`install-inside-vm.sh`** first (or rely on first-boot) so **`merge-claude-bootstrap.sh`** and **`~/.claude/settings.json`** apply. When **`install-inside-vm.sh`** already completed and then started **`setup-claude.sh`**, you can skip that.

### Claude (Anthropic API — standard path)

1. On the **host**, create **`~/ai-sandbox/secrets/claude_api_key`** containing **only** the API key string (one line, no `KEY=` prefix unless you change the script). **Skip this** if you use **Vertex** via **`secrets/claude-vertex.env`** (Red Hat path)—**`install-inside-vm.sh`** will not write **`apiKey`** into **`~/.claude/config.json`** when **`secrets/claude-vertex.env`** is present.
2. In the **guest**, run **`~/ai-sandbox/config/install-inside-vm.sh`** (or rely on kickstart **first-boot**, which runs it). The script installs **`~/.claude/settings.json`** from **`config/claude-code.settings.json`** or **`secrets/claude-settings.json`** (see [Non-interactive defaults](#non-interactive-defaults-do-it-without-asking)) and, when an API key file exists and Vertex env is absent, writes **`~/.claude/config.json`** for the **`ai`** user (key from **`secrets/claude_api_key`** or **`workspace/.ai-sandbox-private/claude_api_key`**). It copies **`secrets/claude-vertex.env`** or **`workspace/.ai-sandbox-private/claude-vertex.env`** into **`~/.config/ai-sandbox/claude-vertex.env`** when present and installs the **`~/.bashrc`** hook via **`config/lib/claude-login-env.sh`**.
3. If you **recreate the VM disk** and the guest home is empty, run **`install-inside-vm.sh`** again so **`~/.claude`** is recreated from the **unchanged** host files.

The **`config/.claude/config.json`** in the repo is a template only (empty **`apiKey`**); real keys are **not** committed.

### Cursor (IDE)

- **Install** is automated (**RPM** URL in **`install-inside-vm.sh`** via **`CURSOR_RPM_URL`**).
- **Authentication** is **not** stored in this repository. After install, open **Cursor** in the guest and complete **sign-in** (or license flow) in the app. That state is kept under the guest user’s config (e.g. **`~/.config/Cursor`**) until the disk is replaced.
- To avoid re-sign-in after a full disk wipe, you would need to **back up** those guest directories to the host manually; this project does not automate that path.

### Non-interactive defaults (“do it without asking”)

**Claude Code** uses **`~/.claude/settings.json`** (see [permission modes](https://code.claude.com/docs/en/permissions)). This repository ships **`config/claude-code.settings.json`** with **`permissions.defaultMode`** set to **`bypassPermissions`**, which skips permission prompts except for writes to a few **protected directories** (e.g. **`.git`**, **`.claude`**, **`.vscode`**, **`.idea`** — see Anthropic’s docs). That matches a **low-supervision** workflow inside an **isolated VM**; do **not** use **`bypassPermissions`** on your bare-metal OS unless you accept the risk.

**Install behavior:** **`install-inside-vm.sh`** copies **`config/claude-code.settings.json`** to **`~/.claude/settings.json`** when **`secrets/claude-settings.json`** is **missing or empty** (an **empty** override file no longer wins over the template). If you create a **non-empty** **`secrets/claude-settings.json`** on the **host** (gitignored), that file is used instead. To repair a blank **`~/.claude/settings.json`** on the guest: **`bash ~/ai-sandbox/config/ensure-claude-settings.sh`** (or **`--force`** to reset from the template).

**Cursor** does not expose a single stable, documented **`settings.json`** key in this repo. Use the in-app control: **Cursor Settings → Agents → Auto-Run** and choose **Run Everything** (fully automatic; weakest guardrails) or **Run in Sandbox** (auto-run inside Cursor’s sandbox where supported) — see [Terminal / Agent](https://cursor.com/docs/agent/terminal). **New Cursor projects** inherit **user** (and optionally **workspace**) settings in the guest; you do not need extra files under **`~/ai-sandbox/workspace/<name>/`** for that beyond normal editor project data. To duplicate behavior after replacing the guest disk, re-open **User Settings (JSON)** after configuring once and save a private copy, or back up **`~/.config/Cursor`**.

### Podman containers vs guest

**`start-container.sh`** bind-mounts **`secrets/ssh`** for Git. For **Vertex** (Red Hat path), it also injects env from **`~/.config/ai-sandbox/claude-vertex.env`** and mounts **`~/.config/gcloud`** read-only at **`/home/dev/.config/gcloud`** so **ADC** works inside the container. It still does **not** mount **`claude_api_key`** or **`ANTHROPIC_API_KEY`** for the direct-API path—use the guest shell or extend **`start-container.sh`** if you need that inside Podman. The image uses a **read-only** root and a global **`npm -g`** install of **`@anthropic-ai/claude-code`**, so **self-update cannot work**; **`DISABLE_AUTOUPDATER=1`** is set in **`config/Containerfile`** and **`podman run`**. To refresh the CLI in the container, **`podman build`** the **`ai-dev`** image again (e.g. **`config/rebuild-container.sh`**) or run **`npm i -g @anthropic-ai/claude-code`** on the **guest** if you use Claude outside Podman. Guest **`~/.claude/settings.json`** (or template), **`~/.claude.json`**, and **`~/.claude/skills/`** are copied into **`~/.local/share/ai-sandbox/container-home/<name>/`** each **`start-container.sh`** run—recreate the container after changing them (see [Host-backed Claude MCP and skills](#host-backed-claude-mcp-and-skills)).

### Host-backed Claude MCP and skills

Claude Code stores **user-scoped** MCP servers in **`~/.claude.json`** under **`mcpServers`** ([MCP docs](https://code.claude.com/docs/en/mcp)). **Personal** skills live under **`~/.claude/skills/<name>/SKILL.md`** ([skills](https://code.claude.com/docs/en/skills)).

To keep definitions on the **host** (survives guest disk replacement) and apply them at setup:

| Host path | Purpose |
|-----------|---------|
| **`config/claude-bootstrap/mcp.json`** | Optional JSON fragment with a top-level **`mcpServers`** object (same shape as a project **`.mcp.json`**). Copy from **`mcp.json.example`**; commit team defaults here if you want. |
| **`workspace/.ai-sandbox-private/claude-bootstrap/mcp.json`** | Optional **host-backed, gitignored** MCP fragment (writable from the guest when **`secrets/`** is read-only). Merged **after** **`config/`** bootstrap; **`secrets/claude-mcp.json`** still merges **last** and wins on duplicate server names. |
| **`secrets/claude-mcp.json`** | Optional **gitignored** fragment with **`mcpServers`**. Merged **last**; use for tokens or private endpoints. See **`secrets/claude-mcp.json.example`**. |
| **`config/claude-bootstrap/skills/`** | Optional committed skills tree (**`SKILL.md`** in subdirs). Copied into **`~/.claude/skills/`** in the guest. |
| **`workspace/.ai-sandbox-private/claude-bootstrap/skills/`** | Optional **gitignored** skills overlay; copied **after** **`config/`** skills (same layout). |

**`config/merge-claude-bootstrap.sh`** performs the merge and copy. **`config/install-inside-vm.sh`** runs it automatically. After you change files on the host, run **`~/ai-sandbox/config/merge-claude-bootstrap.sh ~/ai-sandbox`** again in the guest (or re-run **`install-inside-vm.sh`**) to refresh **`~/.claude.json`** and skills. **`start-container.sh`** copies the merged **`~/.claude.json`** and **`~/.claude/skills/`** into the container **`/home/dev`** tree so Claude Code in Podman sees the same MCP and skills.

Copy **`config/claude-bootstrap/mcp.json.example`** to **`mcp.json`** and edit; the **`.example`** file is not read by the script.

**Cursor** has its own MCP configuration (not merged by these scripts). Configure Cursor’s MCP in the guest if you use it there.

## virtiofs / CIFS and `~/ai-sandbox` layout

**Linux (libvirt):** **`config/ensure-sandbox-mounts.sh`** mounts three **virtiofs** tags (`host-config`, `host-secrets`, `host-workspace`) and writes matching **fstab** lines. **`~/ai-sandbox/workspace`** symlinks to **`/mnt/host-workspace`**, so **Podman/Cursor project trees live on the host** under **`~/ai-sandbox/workspace/<name>/`** on the same writable share. Legacy **`workspace/projects/<name>/`** is flattened to **`workspace/<name>/`** when **`ensure-sandbox-mounts.sh`** runs; an obsolete **`~/ai-sandbox/projects`** symlink or directory is removed or migrated.

**SMB/CIFS:** If **`/etc/ai-sandbox/cifs.env`** sets **`USE_CIFS=1`** and **`CIFS_URL`** (see **`config/cifs.env.example`**), the same script mounts the **whole host `ai-sandbox` tree** with **CIFS** and **bind-mounts** `config/`, `secrets/`, and `workspace/` to `/mnt/host-*` so paths match the virtiofs layout.

On the **first boot** path, **`/usr/local/bin/ai-sandbox-firstboot.sh`** (installed by kickstart):

1. Loads the **`virtiofs`** kernel module if needed (Fedora: **`modprobe virtiofs`**, not `virtio_fs`).
2. Mounts **`host-config`** at `/mnt/host-config` (**fails** if virtiofs is missing—configure CIFS and run **`ensure-sandbox-mounts.sh`** manually; see **`ks.template.cfg`** message).
3. Runs **`config/ensure-sandbox-mounts.sh`** (from the share) as root for user **`ai`**, which completes mounts and:
   - Appends **fstab** for virtiofs when not using CIFS.
   - Creates **`/home/ai/ai-sandbox`** and symlinks **`config`**, **`secrets`**, and **`workspace`** → the matching **`/mnt/host-*`** trees (no separate **`projects`** symlink).

If first-boot is skipped, run manually:

```bash
sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai
~/ai-sandbox/config/install-inside-vm.sh
```

## `install-inside-vm.sh`

Runs as user **`ai`** (with passwordless sudo from kickstart). Typical actions:

- Ensure mounts via **`ensure-sandbox-mounts.sh`** if needed.
- **`dnf update`** and install **Podman**, language runtimes, **Terminator** (with GNOME autostart), **firewalld**, **audit**, CLI tools.
- **`npm -g`** / **`pip --user`** stacks as scripted.
- **`firewall-cmd`**: default zone **`block`**, add **dns**, **http**, **https**, **ssh** to that zone.
- **`podman build`** using **`config/Containerfile`** → image **`ai-dev`**.
- Download **Cursor** RPM (override **`CURSOR_RPM_URL`**).
- Run **`merge-claude-bootstrap.sh`**: merge **`config/claude-bootstrap/mcp.json`** and **`secrets/claude-mcp.json`** into **`~/.claude.json`**, copy **`config/claude-bootstrap/skills/`** → **`~/.claude/skills/`** (see [Host-backed Claude MCP and skills](#host-backed-claude-mcp-and-skills)).
- Copy **`config/claude-code.settings.json`** (or **`secrets/claude-settings.json`** if present) to **`~/.claude/settings.json`** (see [Non-interactive defaults](#non-interactive-defaults-do-it-without-asking)).
- If **`secrets/claude_api_key`** exists on the **host-backed** **`secrets/`** tree, write **`~/.claude/config.json`** in the guest (see [Host-stored credentials](#host-stored-credentials-cursor-and-claude)).
## Podman configuration

**`config/container.env`** defines:

- **`CONTAINER_IMAGE`**, **`CPU_LIMIT`**, **`MEMORY_LIMIT`**, **`PID_LIMIT`**
- **`SECRETS_DIR`** — e.g. `/mnt/host-secrets` (path to mounted host secrets inside VM)
- **`WORKSPACE_ROOT`** — e.g. `$HOME/ai-sandbox/workspace`

## Starting and stopping project containers

| Action | Command |
|--------|---------|
| Start container (interactive) | `~/ai-sandbox/config/start-container.sh <name>` (or **`first-project-name.sh`** for the lexicographically first non-hidden folder under **`workspace/`**, or **`default`** if empty) |
| Start container (detached) | `~/ai-sandbox/config/start-container.sh --detach <name>` |
| Shell into running container | `~/ai-sandbox/config/shell-into-container.sh <name>` |
| Stop container | `~/ai-sandbox/config/stop-container.sh <name>` |

**`start-container.sh`** refuses to create a duplicate name if a container **`ai-dev-<name>`** already exists (`podman inspect`); remove with **`podman rm -f ai-dev-<name>`** or **`stop-container.sh`** first.

Hardening flags include **`--cap-drop=ALL`**, **`--security-opt=no-new-privileges`**, **`--read-only`**, tmpfs for writable roots, **`--network slirp4netns`** (requires **`slirp4netns`** RPM — installed by **`install-inside-vm.sh`**), bind mounts for **`$WORKSPACE:/workspace`** and **`$HOME/.ssh:/home/dev/.ssh:ro`** (keys are copied from **`secrets/ssh/`** into **`~/.ssh`** by **`install-inside-vm.sh`** because rootless Podman often cannot **`statfs`** virtiofs-backed paths).

## Optional dashboard

- **`config/dashboard.py`** — FastAPI; **`GET /`** health; **`POST /start/{project}`**, **`POST /stop/{project}`** require **`Authorization: Bearer <token>`** matching **`AI_SANDBOX_DASHBOARD_TOKEN`**.
- **`config/run-dashboard.sh`** — Exports token requirement, runs **uvicorn** on **127.0.0.1** (default port **8080**).
- **`config/index.html`** — Simple UI that sends the Bearer header.

## Dev convenience

- **`config/first-project-name.sh`** — Prints the **lexicographically first** directory name under **`~/ai-sandbox/workspace/`** (skipping hidden names); if **`workspace/`** is missing or has no suitable subdirectories, prints **`default`**.
- **`config/start-dev.sh`** — Ensures **`~/ai-sandbox/workspace/<name>/`** exists for that name, starts a **detached** container for **`first-project-name.sh`**, and launches **Cursor** on that workspace.
- **`config/shell-into-container.sh <name>`** — Opens an interactive bash shell in the running **`ai-dev-<name>`** container.

---

## Related

- **[inventory.md](inventory.md)** — full `config/` and `host/` file list.
- **[conventions.md](conventions.md)** — container naming, secrets paths.
