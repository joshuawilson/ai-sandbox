# What — requirements

## Product requirements

These are the behaviors the sandbox is **intended** to provide.

| ID | Requirement |
|----|-------------|
| PR-1 | **Host isolation:** Development and AI tooling run **inside a hypervisor guest**, not directly on the operator’s bare-metal OS for routine file and process access. |
| PR-2 | **Guest stack:** The VM runs **Fedora Workstation** (desktop-oriented) with **rootless Podman** and a single reusable **dev container image** (`ai-dev`). |
| PR-3 | **Toolchains:** The environment supports **Node**, **TypeScript**, **React-oriented** tooling, **Python**, and **Go** (via `config/Containerfile` and `config/install-inside-vm.sh`). |
| PR-4 | **Multi-project:** The **same** `ai-dev` image is used with **separate workspaces** per project; directories are **`~/ai-sandbox/workspace/<name>`**, which resolve to **host** storage under **`workspace/<name>/`** (virtiofs/CIFS), not only guest disk. |
| PR-5 | **Network:** The guest may use the **internet** for packages, APIs, and browsing; firewall rules apply as implemented in `install-inside-vm.sh`. |
| PR-6 | **Git over SSH:** The operator can **clone, pull, and push** using **GitHub** and **GitLab** with **sandbox-specific** SSH keys that live on the **host** and are mounted **read-only** into containers. |
| PR-7 | **IDE and assistants:** **Cursor** runs **inside** the Fedora guest. **Claude**-related configuration may use secrets from `secrets/` inside the guest. LLM traffic originates from the **guest**, not from the host OS session by default. |
| PR-8 | **Secrets placement:** **SSH private keys** and API-related files remain on the **host** under `~/ai-sandbox/secrets/` so they are not recreated on every guest reinstall; only key **registration** with forges is repeated as needed. |
| PR-9 | **Configuration:** Automation, `Containerfile`, and related files live under **`config/`** in the repository and are visible inside the VM (e.g. via virtiofs on Linux). |
| PR-10 | **Host installers:** Scripts exist to prepare **Fedora Linux**, **macOS**, and **Windows** hosts and to create or refresh the guest (bash vs PowerShell as appropriate). |
| PR-11 | **Automation:** First-boot provisioning in the guest runs via **systemd** (`ai-sandbox-firstboot.service`) when kickstart is used; manual paths are documented if first-boot is skipped. |
| PR-12 | **Documented system:** The **`spec/`** tree describes architecture, workflows, script roles (**[../how/inventory.md](../how/inventory.md)**), and conventions (**[../how/conventions.md](../how/conventions.md)**) so operators and automated tools can reason about the whole project without relying only on scattered READMEs. |

### Installation media and configuration mounts

**Requirement:** Deliver the guest OS using **official Fedora Workstation** install bits, and deliver **this repo’s** `config/`, `secrets/`, and `workspace/` from the **host** without baking them into a custom Fedora image.

**Implementation:** This repository **does not** build a remastered Fedora ISO. **Linux (libvirt)** uses the official **netinstall `os/`** tree plus **kickstart** (`--initrd-inject`). **macOS** and **Windows** download an **official Workstation live ISO** and can serve **`ks.cfg` over HTTP** via **`tools/serve-kickstart.sh`** / **`tools/serve-kickstart.ps1`** (`inst.ks=http://<host>:8000/ks.cfg`). **Windows** may expose the repo with **`create-vm-windows.ps1 -CreateSmbShare`** for **SMB**; the guest uses **`config/ensure-sandbox-mounts.sh`** in **virtiofs** or **CIFS** mode (`config/cifs.env.example`).

Optional future work: a **small secondary volume** (data ISO, cloud-init) carrying only `config/`—not part of the current automation.

## Functional requirements (implementation)

| ID | Requirement |
|----|-------------|
| FR-1 | Operator can create a Fedora VM from a supported host using documented scripts. **VM sizing and related tunables** (disk, RAM, vCPUs, VM name, Fedora release, netinstall or ISO URLs, libvirt network, Hyper-V switch) are configured via **`host/vm-host.env`** (copy from **`host/vm-host.env.example`** or run **`host/configure-vm-host.*`**, including from **`setup-host`**) before **`create-vm-*`**. |
| FR-2 | Kickstart generated from **`host/ks.template.cfg`** incorporates sandbox **SSH public key** and **hashed VM user password** from `secrets/`. |
| FR-3 | On first boot, the VM runs **`install-inside-vm.sh`** after **`ensure-sandbox-mounts.sh`** (virtiofs or CIFS), unless the operator skips first-boot. |
| FR-4 | Podman runs use **`config/container.env`** for image name, resource limits, `SECRETS_DIR`, and `WORKSPACE_ROOT`. |
| FR-5 | On Linux hosts with libvirt, operator can **revert** the VM to snapshot **`clean`** when that snapshot exists (`host/reset-sandbox.sh`). |
| FR-6 | Container invocation uses **documented** hardening flags (`cap-drop`, read-only root, read-only SSH bind, etc.). |
| FR-7 | **macOS / Windows** hosts can publish **`ks.cfg`** for the installer (**`tools/serve-kickstart.*`**) and attach the repo to the guest via **documented** SMB or manual shares. |
| FR-8 | **Regression checks:** **`tests/run.sh`** exercises shell syntax and selected integration tests (**`tests/test_merge_claude_bootstrap.sh`**, **`tests/test_first_project_name.sh`**); CI runs this suite (**`.github/workflows/tests.yml`**). |

## Non-functional requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | Secrets are **excluded from version control** via `.gitignore`. |
| NFR-2 | Optional HTTP dashboard does not expose **unauthenticated** remote control (`AI_SANDBOX_DASHBOARD_TOKEN`, localhost binding). |
| NFR-3 | **Specifications** in **`spec/`** stay aligned with **observable behavior** (scripts, mounts, env vars); major behavioral changes update **`inventory.md`** or **`conventions.md`** as appropriate. |

## Constraints

- **Not a malware-analysis environment:** intentional virus or malware testing is **out of product scope**; host-backed workspaces and network access are unsuitable for that threat model. See [overview.md — Malware analysis and untrusted code](overview.md#malware-analysis-and-untrusted-code).
- Fedora **mirror URLs** and **release numbers** change; scripts expose **variables** (`FEDORA_VER`, `LOCATION_URL`, ISO URLs in Mac/Windows scripts).
- **Apple Silicon** Macs may need **aarch64** media or accept **x86_64** emulation.
- **Windows Hyper-V** virtual switch names and **Gen2** firmware settings vary by machine.
