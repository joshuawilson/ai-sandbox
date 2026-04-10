#!/usr/bin/env bash
# Debug firstboot automation failures (run inside the VM as user ai)
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AI Sandbox Firstboot Debugging ===${NC}"
echo ""

# Check if firstboot completed
if [ -f /var/lib/ai-sandbox-firstboot.done ]; then
    echo -e "${GREEN}✓ Firstboot marker exists - automation completed${NC}"
    echo ""
else
    echo -e "${YELLOW}✗ Firstboot marker missing - automation did not complete${NC}"
    echo ""
fi

# Check systemd services
echo -e "${BLUE}=== Systemd Services ===${NC}"
echo ""

for service in ai-sandbox-cifs-mounts.service ai-sandbox-firstboot.service; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo -e "${BLUE}Service: $service${NC}"
        systemctl status "$service" --no-pager || true
        echo ""

        if systemctl is-failed "$service" &>/dev/null; then
            echo -e "${RED}Service failed! Checking journal...${NC}"
            journalctl -u "$service" -b --no-pager | tail -50
            echo ""
        fi
    else
        echo -e "${RED}✗ Service not found: $service${NC}"
        echo "  (Kickstart %post may have failed)"
        echo ""
    fi
done

# Check mounts
echo -e "${BLUE}=== Mount Points ===${NC}"
echo ""

for mount in /mnt/host-ai-sandbox /mnt/host-config /mnt/host-secrets /mnt/host-workspace; do
    if mountpoint -q "$mount" 2>/dev/null; then
        echo -e "${GREEN}✓ $mount (mounted)${NC}"
        ls -la "$mount" | head -5
    else
        echo -e "${RED}✗ $mount (not mounted)${NC}"
    fi
    echo ""
done

# Check ~/ai-sandbox symlinks
echo -e "${BLUE}=== ~/ai-sandbox Structure ===${NC}"
echo ""

if [ -d ~/ai-sandbox ]; then
    ls -la ~/ai-sandbox
    echo ""
else
    echo -e "${RED}✗ ~/ai-sandbox directory does not exist${NC}"
    echo ""
fi

# Check CIFS configuration
echo -e "${BLUE}=== CIFS Configuration ===${NC}"
echo ""

if [ -f /etc/ai-sandbox/cifs.env ]; then
    echo -e "${GREEN}✓ /etc/ai-sandbox/cifs.env exists${NC}"
    echo "Contents:"
    cat /etc/ai-sandbox/cifs.env
    echo ""
else
    echo -e "${RED}✗ /etc/ai-sandbox/cifs.env missing${NC}"
    echo "  (Kickstart may have used wrong template)"
    echo ""
fi

# Check network
echo -e "${BLUE}=== Network Connectivity ===${NC}"
echo ""

# Try to extract hostname from CIFS_URL if config exists
if [ -f /etc/ai-sandbox/cifs.env ]; then
    source /etc/ai-sandbox/cifs.env
    if [ -n "${CIFS_URL:-}" ]; then
        hostname=$(echo "$CIFS_URL" | cut -d/ -f3)
        echo "Testing connection to: $hostname"

        if ping -c 2 -W 2 "$hostname" &>/dev/null; then
            echo -e "${GREEN}✓ Can ping $hostname${NC}"
        else
            echo -e "${RED}✗ Cannot ping $hostname${NC}"
            echo "  Check: Windows firewall, network adapter in VM"
        fi
        echo ""
    fi
fi

# Check cifs-utils
echo -e "${BLUE}=== CIFS Tools ===${NC}"
echo ""

if command -v mount.cifs &>/dev/null; then
    echo -e "${GREEN}✓ mount.cifs installed${NC}"
else
    echo -e "${RED}✗ mount.cifs not installed${NC}"
    echo "  Install: sudo dnf install -y cifs-utils"
fi
echo ""

# Summary and solutions
echo -e "${BLUE}=== Common Solutions ===${NC}"
echo ""

echo "1. Check Windows SMB share:"
echo "   On Windows host: Get-SmbShare -Name ai-sandbox"
echo ""

echo "2. Test manual CIFS mount (run as root):"
echo "   sudo mkdir -p /mnt/test"
echo "   sudo mount -t cifs //HOSTNAME/ai-sandbox /mnt/test -o guest"
echo ""

echo "3. Run firstboot scripts manually:"
echo "   sudo /usr/local/bin/ai-sandbox-cifs-setup.sh"
echo "   sudo /usr/local/bin/ai-sandbox-firstboot.sh"
echo ""

echo "4. Check full logs:"
echo "   journalctl -b --no-pager | grep ai-sandbox"
echo ""
