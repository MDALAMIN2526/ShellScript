#!/bin/bash

# Proxmox Alpine LXC Samba/NFS Share Installer (Compatible with Debian-based Proxmox)
# Run with: bash -c "$(curl -fsSL https://raw.githubusercontent.com/MDALAMIN2526/ShellScript/main/fileshare.sh)"

set -eo pipefail
exec > >(tee /var/log/fileshare-setup.log) 2>&1

### Functions
error() {
  echo -e "\n❌ Error: $1" >&2
  exit 1
}

check_proxmox() {
  # Check for Proxmox-specific commands instead of OS detection
  local proxmox_commands=(pvesh pct pveam)
  for cmd in "${proxmox_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Command '$cmd' not found. Are you sure this is a Proxmox host?"
    fi
  done
  echo "✓ Verified Proxmox host (Proxmox commands available)"
}

check_deps() {
  for cmd in curl openssl; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Missing required command: $cmd"
    fi
  done
}

### Main
clear
echo "=== Proxmox Samba/NFS Share Setup ==="

# Verify environment
check_proxmox
check_deps

# Prompt for credentials
read -rp "Enter username for Samba/NFS access: " SHARE_USER
read -rsp "Enter password for $SHARE_USER: " SHARE_PASSWORD
echo
read -rsp "Confirm password: " SHARE_PASSWORD_CONFIRM
echo

if [[ "$SHARE_PASSWORD" != "$SHARE_PASSWORD_CONFIRM" ]]; then
  error "Passwords do not match!"
fi

# Generate random CTID if not specified
CTID=$(pvesh get /cluster/nextid || error "Failed to get next CTID")
CT_NAME="fileserver"
CT_PASSWORD=$(openssl rand -base64 12)
HOST_MOUNT="/dmp"
MOUNT_POINT="/mnt/dmp"
CT_IP="10.10.10.$((RANDOM%100 + 100))/24"
GW="10.10.10.1"

echo -e "\n📝 Configuration Summary:"
echo "----------------------"
echo "Container ID: $CTID"
echo "Container Name: $CT_NAME"
echo "Host Mount: $HOST_MOUNT → $MOUNT_POINT"
echo "Samba/NFS User: $SHARE_USER"
echo -e "----------------------\n"

read -rp "Proceed? (y/n): " confirm
[[ "$confirm" != "y" ]] && error "Aborted by user."

# Create host directory
mkdir -p "$HOST_MOUNT" || error "Failed to create $HOST_MOUNT"
chmod 1777 "$HOST_MOUNT"  # Sticky bit for shared dir

# Download Alpine template if missing
ALPINE_TEMPLATE="alpine-3.18-default_20230608_amd64.tar.xz"
if ! pveam list local | grep -q "$ALPINE_TEMPLATE"; then
  echo "Downloading Alpine template..."
  pveam update || error "Failed to update templates"
  
  # List available templates and select Alpine
  AVAILABLE_TEMPLATES=$(pveam available --section system)
  if echo "$AVAILABLE_TEMPLATES" | grep -q "$ALPINE_TEMPLATE"; then
    pveam download local "$ALPINE_TEMPLATE" || error "Failed to download Alpine template"
  else
    # Fallback to newest Alpine version if exact match not found
    NEWEST_ALPINE=$(echo "$AVAILABLE_TEMPLATES" | grep "alpine" | head -1 | awk '{print $2}')
    if [ -z "$NEWEST_ALPINE" ]; then
      error "No Alpine templates available in your Proxmox storage"
    fi
    echo "Using newest available Alpine template: $NEWEST_ALPINE"
    pveam download local "$NEWEST_ALPINE" || error "Failed to download Alpine template"
  fi
fi

# Create container
echo "Creating container..."
pct create "$CTID" \
  local:vztmpl/"$ALPINE_TEMPLATE" \
  --storage local-lvm \
  --hostname "$CT_NAME" \
  --password "$CT_PASSWORD" \
  --unprivileged 1 \
  --cores 1 \
  --memory 512 \
  --swap 512 \
  --net0 "name=eth0,bridge=vmbr0,ip=$CT_IP,gw=$GW" \
  --mp0 "/$HOST_MOUNT,mp=$MOUNT_POINT" \
  --ostype alpine || error "Container creation failed"

# Start container
pct start "$CTID" || error "Failed to start container"

# Container setup
echo "Configuring container..."
pct exec "$CTID" -- sh -c "
set -e
apk update && apk upgrade
apk add samba nfs-utils shadow sudo

# Create user
adduser -D -h $MOUNT_POINT $SHARE_USER || exit 1
echo -e \"$SHARE_PASSWORD\n$SHARE_PASSWORD\" | passwd $SHARE_USER || exit 1
(echo \"$SHARE_PASSWORD\"; echo \"$SHARE_PASSWORD\") | smbpasswd -a $SHARE_USER || exit 1

# Configure Samba
cat > /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = bad user
   dns proxy = no

[dmp]
   path = $MOUNT_POINT
   browseable = yes
   read only = no
   guest ok = no
   valid users = $SHARE_USER
EOF

# Configure NFS (restricted to local network)
cat > /etc/exports <<EOF
$MOUNT_POINT 10.10.10.0/24(rw,sync,no_subtree_check,no_root_squash)
EOF

# Set permissions
chown $SHARE_USER:$SHARE_USER $MOUNT_POINT
chmod 1777 $MOUNT_POINT  # Sticky bit for shared dir

# Enable services
rc-update add samba
rc-update add nfs
service samba start
service nfs start
" || error "Container setup failed"

echo -e "\n✅ Setup Complete!"
echo "----------------------"
echo "Samba Share: //$CT_IP/dmp"
echo "NFS Share: $CT_IP:$MOUNT_POINT"
echo "Username: $SHARE_USER"
echo "Password: [hidden]"
echo -e "----------------------\n"
