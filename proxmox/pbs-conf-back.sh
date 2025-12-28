#!/bin/bash

# Set environment variables for API token authentication
export PBS_REPOSITORY='pbs_mon@pbs@192.168.1.223:Backups'
export PBS_PASSWORD='!laban123'

# Settings
BACKUP_ID="pve-config"
INCLUDE_DIR="/etc/pve"

# Optional extras to include
TMP_DIR="/tmp/pve-backup-tmp"
mkdir -p "$TMP_DIR"
cp -a /etc/network "$TMP_DIR/etc-network"
cp -a /root/.ssh "$TMP_DIR/root-ssh"
cp /etc/hosts /etc/hostname /etc/resolv.conf "$TMP_DIR/"
dpkg --get-selections > "$TMP_DIR/package-list.txt"
crontab -l > "$TMP_DIR/root-crontab.txt" 2>/dev/null

# Create one backup job from multiple directories using pxar
proxmox-backup-client backup \
  etc-pve.pxar:$INCLUDE_DIR \
  etc-extra.pxar:$TMP_DIR \
  --backup-id "$BACKUP_ID" \
  --backup-type host

# Cleanup
rm -rf "$TMP_DIR"

