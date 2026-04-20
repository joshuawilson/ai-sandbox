# VM Management Guide

Day-to-day operations for managing your AI Sandbox Fedora VM on a libvirt/KVM host.

---

## Quick Setup - virsh Commands

By default, `virsh` connects to your user session, but the VM runs on the system instance. Set this once:

```bash
export LIBVIRT_DEFAULT_URI=qemu:///system
```

**Make it permanent:**
```bash
echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' >> ~/.bashrc
source ~/.bashrc
```

Now all `virsh` commands will work without the `--connect qemu:///system` flag.

---

## Basic VM Operations

```bash
# List all VMs
virsh list --all

# Start VM
virsh start ai-sandbox
# Or use the helper script:
./start-vm.sh

# Shutdown cleanly
virsh shutdown ai-sandbox

# Force stop (like pulling the plug)
virsh destroy ai-sandbox

# Stop and optionally remove VM
./stop-vm.sh
./stop-vm.sh --remove   # Deletes VM and disk
```

---

## Creating a Reliable Baseline Snapshot

Create a snapshot you can always revert to when things break:

```bash
# 1. Shut down cleanly for a consistent snapshot
virsh shutdown ai-sandbox

# 2. Wait for it to stop (check with: virsh list --all)

# 3. Create your reliable baseline
virsh snapshot-create-as ai-sandbox baseline --description "Reliable working state"

# 4. Start it back up
virsh start ai-sandbox
```

**To revert to this baseline later:**
```bash
virsh shutdown ai-sandbox
virsh snapshot-revert ai-sandbox baseline
virsh start ai-sandbox
```

**Note:** Your VM already has a "clean" snapshot from initial setup. Use the helper script to revert:
```bash
./host/reset-sandbox.sh
```

---

## Save & Restore VM State (Free RAM / Reboot Host)

When you need to free up RAM or reboot your host, save the exact VM state to disk:

```bash
# Save current state to disk and stop the VM
virsh save ai-sandbox ~/ai-sandbox-saved-state.img

# This shuts down the VM and saves all RAM to that file
# Your host RAM is now free - reboot if needed
```

**To restore exactly where you left off:**
```bash
# This automatically starts the VM in the exact state
virsh restore ~/ai-sandbox-saved-state.img

# You'll be right back where you were:
# - Same programs running
# - Same terminal windows open
# - Same file positions
```

**Notes:**
- The save file will be large (same size as your VM's RAM, typically 32GB)
- Restoring deletes the save file (it's consumed)
- Create a new save file each time you want to preserve state

---

## Snapshot Management

### Create Snapshots

```bash
# Create snapshot (VM can be running)
virsh snapshot-create-as ai-sandbox my-snapshot --description "Description here"

# Create snapshot with timestamp
virsh snapshot-create-as ai-sandbox snapshot-$(date +%Y%m%d-%H%M)
```

### List Snapshots

```bash
virsh snapshot-list ai-sandbox
```

### Revert to Snapshot

```bash
# Must shut down first
virsh shutdown ai-sandbox

# Revert to snapshot
virsh snapshot-revert ai-sandbox my-snapshot

# Start back up
virsh start ai-sandbox
```

### Delete Snapshots

```bash
virsh snapshot-delete ai-sandbox old-snapshot-name
```

**Note:** Snapshots are stored inside the qcow2 disk file. Delete old ones you don't need to keep disk size manageable.

---

## Pause/Resume VM

Temporarily freeze the VM without shutting down:

```bash
# Pause (freeze VM in memory)
virsh suspend ai-sandbox

# Resume
virsh resume ai-sandbox
```

**What pause does:**
- VM process stays in memory but stops executing
- Guest OS is completely frozen
- No CPU usage, but RAM stays allocated
- Network connections may timeout
- Very fast - happens instantly

**Use when:**
- Briefly freeing up CPU
- Taking a snapshot for extra consistency (optional)

---

## Common Workflows

### Daily: Start Working

```bash
# On host - start the VM
./start-vm.sh

# In guest - start your dev environment
bash ~/ai-sandbox/config/start-dev.sh
```

### Daily: Done for the Day (Save State)

```bash
# Save state and free RAM
virsh save ai-sandbox ~/ai-sandbox-saved-state.img

# Next day - restore
virsh restore ~/ai-sandbox-saved-state.img
```

### Weekly: Create Checkpoint

```bash
# Create a dated snapshot
virsh snapshot-create-as ai-sandbox weekly-$(date +%Y%m%d)
```

### Something Broke: Revert to Baseline

```bash
virsh shutdown ai-sandbox
virsh snapshot-revert ai-sandbox baseline
virsh start ai-sandbox
```

### Need to Reboot Host

```bash
# Save VM state first
virsh save ai-sandbox ~/ai-sandbox-saved-state.img

# Reboot host
sudo reboot

# After reboot - restore VM
export LIBVIRT_DEFAULT_URI=qemu:///system
virsh restore ~/ai-sandbox-saved-state.img
```

---

## Snapshot vs Save: What's the Difference?

| Feature | Snapshot | Save/Restore |
|---------|----------|--------------|
| **Purpose** | Create restore points | Hibernate/resume exact state |
| **Storage** | Inside VM disk (qcow2) | Separate file on host |
| **Can have multiple?** | Yes, many snapshots | No, one save file at a time |
| **RAM saved?** | Yes | Yes |
| **VM must stop?** | No (but recommended) | Yes (automatically) |
| **Frees host RAM?** | No | Yes |
| **Speed** | Fast | Moderate (writes RAM to disk) |
| **Use case** | "Good known state" | "Pause work, resume later" |

---

## Disk Space Management

### Check VM Disk Usage

```bash
# Find VM disk location
virsh domblklist ai-sandbox

# Check disk size
ls -lh /var/lib/libvirt/images/ai-sandbox.qcow2

# Check actual usage vs allocated
qemu-img info /var/lib/libvirt/images/ai-sandbox.qcow2
```

### Clean Up Old Snapshots

```bash
# List snapshots
virsh snapshot-list ai-sandbox

# Delete old ones
virsh snapshot-delete ai-sandbox old-snapshot-2024-01-15
```

---

## Troubleshooting

### Can't Connect to VM

```bash
# Make sure URI is set
export LIBVIRT_DEFAULT_URI=qemu:///system

# Verify you're in libvirt group
groups

# If not, log out and back in after running setup-host.sh
```

### Save File Too Large

The save file equals your VM's RAM size. If disk space is tight:

```bash
# Use snapshots instead of save
virsh snapshot-create-as ai-sandbox before-reboot

# Then just shutdown
virsh shutdown ai-sandbox

# After host reboot, start normally
virsh start ai-sandbox
```

### VM Won't Start After Restore

```bash
# If restore fails, start normally
virsh start ai-sandbox

# You'll lose the saved state but VM will boot fresh
```

### Snapshot Revert Fails

```bash
# Make sure VM is shut down first
virsh shutdown ai-sandbox

# Wait for it to fully stop
virsh list --all

# Then try revert again
virsh snapshot-revert ai-sandbox my-snapshot
```

---

## Related Documentation

- [README.md](README.md) — Initial setup and first-time installation
- [host/README.md](host/README.md) — Host scripts and VM creation
- [spec/how/operations.md](spec/how/operations.md) — Advanced operations
