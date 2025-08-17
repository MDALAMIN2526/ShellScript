#!/bin/bash

# Proxmox Alpine LXC Samba/NFS Share Installer
# Run with: bash -c "$(curl -fsSL https://raw.githubusercontent.com/fileshare.sh)"

set -e

# Configuration
CTID=$(pvesh get /cluster/nextid)
CT_NAME="fileserver"
CT_PASSWORD=$(openssl rand -base64 12)
SHARE_USER="samnfs"
SHARE_PASSWORD="vvvvvvvvv"
HOST_MOUNT="/dmp"
MOUNT_POINT="/mnt/dmp"
CT_IP="10.10.10.$((RANDOM%100 + 100))/24"
GW="10.10.10.1"

# Check if running on Proxmox host
if ! grep -q "proxmox" /etc/issue; then
  echo "This script must be run on a Proxmox host"
  exit 1
fi

# Check for existing container
if pct list | grep -q "$CT_NAME"; then
  echo "Container $CT_NAME already exists!"
  exit 1
fi

# Create host directory if needed
mkdir -p "$HOST_MOUNT"
chmod 777 "$HOST_MOUNT"

# Download Alpine template if not exists
if ! pveam list local | grep -q "alpine"; then
  echo "Downloading Alpine template..."
  pveam update
  pveam download local alpine-3.18-default_20230608_amd64.tar.xz
fi

# Create container
echo "Creating container $CT_NAME (ID: $CTID)..."
pct create "$CTID" \
  local:vztmpl/alpine-3.18-default_20230608_amd64.tar.xz \
  --storage local-lvm \
  --hostname "$CT_NAME" \
  --password "$CT_PASSWORD" \
  --unprivileged 1 \
  --cores 1 \
  --memory 512 \
  --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip="$CT_IP",gw="$GW" \
  --mp0 "$HOST_MOUNT,$MOUNT_POINT" \
  --ostype alpine

# Start container
echo "Starting container..."
pct start "$CTID"

# Container setup script
echo "Configuring container..."
pct exec "$CTID" -- bash -c "
set -e

# Update system
echo 'Updating Alpine...'
apk update && apk upgrade

# Install packages
echo 'Installing packages...'
apk add samba nfs-utils shadow sudo

# Create user
echo 'Creating user $SHARE_USER...'
adduser -D -h $MOUNT_POINT $SHARE_USER
echo '$SHARE_USER:$SHARE_PASSWORD' | chpasswd
(echo '$SHARE_PASSWORD'; echo '$SHARE_PASSWORD') | smbpasswd -a $SHARE_USER

# Configure Samba
echo 'Configuring Samba...'
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

# Configure NFS
echo 'Configuring NFS...'
cat > /etc/exports <<EOF
$MOUNT_POINT *(rw,sync,no_subtree_check,no_root_squash)
EOF

# Set permissions
echo 'Setting permissions...'
chown $SHARE_USER:$SHARE_USER $MOUNT_POINT
chmod 775 $MOUNT_POINT

# Enable services
echo 'Enabling services...'
rc-update add samba
rc-update add nfs
service samba start
service nfs start

echo 'Container setup complete!'
"

# Print summary
echo -e "\n\n=== Setup Complete ==="
echo "Container Name: $CT_NAME"
echo "Container ID: $CTID"
echo "Root Password: $CT_PASSWORD"
echo "Share User: $SHARE_USER"
echo "Share Password: $SHARE_PASSWORD"
echo "Samba Share Path: //$CT_NAME/dmp"
echo "NFS Share Path: $CT_NAME:$MOUNT_POINT"
echo -e "\nYou can access the container with:"
echo "pct enter $CTID"
