#!/bin/bash

# Parse arguments
OUTFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--outfile)
      OUTFILE="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [-o|--outfile output.md]"
      exit 1
      ;;
  esac
done

# Headers for tables
VM_HEADER="| VM ID | Name | Memory (MB) | Disk (GB) |"
LXC_HEADER="| LXC ID | Hostname | Memory (MB) | Swap (MB) | Disk (GB) |"
VM_SEPARATOR="|------|------|------|------|"
LXC_SEPARATOR="|------|------|------|------|------|"

vm_rows=()
lxc_rows=()

total_vm_mem=0
total_vm_disk=0
total_lxc_mem=0
total_lxc_disk=0

# --- VM Section ---
for cfg in /etc/pve/qemu-server/*.conf; do
    vmid=$(basename "$cfg" .conf)
    name=$(grep -i '^name' "$cfg" | cut -d '=' -f2)
    mem=$(grep -i '^memory' "$cfg" | awk '{print $2}')

    disk_size_sum=0
    while IFS= read -r disk; do
        size=$(echo "$disk" | grep -oP '(?<=,size=)[^,]+')
        if [[ $size =~ G$ ]]; then
            disk_size_sum=$((disk_size_sum + ${size%G}))
        elif [[ $size =~ M$ ]]; then
            disk_size_sum=$((disk_size_sum + ${size%M} / 1024))
        fi
    done < <(grep -E '^(scsi|sata|virtio|efidisk)[0-9]+:' "$cfg")

    vm_rows+=("| $vmid | ${name:-(no name)} | ${mem:-0} | ${disk_size_sum:-0} |")

    total_vm_mem=$((total_vm_mem + mem))
    total_vm_disk=$((total_vm_disk + disk_size_sum))
done

# --- LXC Section ---
for cfg in /etc/pve/lxc/*.conf; do
    vmid=$(basename "$cfg" .conf)
    name=$(grep -i '^hostname' "$cfg" | cut -d '=' -f2)
    mem=$(grep -i '^memory' "$cfg" | awk '{print $2}')
    swap=$(grep -i '^swap' "$cfg" | awk '{print $2}')

    rootfs_line=$(grep -i '^rootfs' "$cfg")
    size=$(echo "$rootfs_line" | grep -oP '(?<=,size=)[^,]+')
    disk_gb=0
    if [[ $size =~ G$ ]]; then
        disk_gb=${size%G}
    elif [[ $size =~ M$ ]]; then
        disk_gb=$(( ${size%M} / 1024 ))
    fi

    lxc_rows+=("| $vmid | ${name:-(no name)} | ${mem:-0} | ${swap:-0} | ${disk_gb:-0} |")

    total_lxc_mem=$((total_lxc_mem + mem))
    total_lxc_disk=$((total_lxc_disk + disk_gb))
done

# Summary
summary_mem=$((total_vm_mem + total_lxc_mem))
summary_disk=$((total_vm_disk + total_lxc_disk))

# --- Output Function ---
print_output() {
  echo "### VM Memory & Disk Allocation"
  echo "$VM_HEADER"
  echo "$VM_SEPARATOR"
  printf "%s\n" "${vm_rows[@]}"

  echo
  echo "### LXC Memory & Disk Allocation"
  echo "$LXC_HEADER"
  echo "$LXC_SEPARATOR"
  printf "%s\n" "${lxc_rows[@]}"

  echo
  echo "### Summary"
  echo "- Total VM Memory: $total_vm_mem MB"
  echo "- Total VM Disk: $total_vm_disk GB"
  echo "- Total LXC Memory: $total_lxc_mem MB"
  echo "- Total LXC Disk: $total_lxc_disk GB"
  echo "- Total Allocated Memory: $summary_mem MB"
  echo "- Total Allocated Disk: $summary_disk GB"
}

# --- Output to file or screen ---
if [[ -n "$OUTFILE" ]]; then
  print_output > "$OUTFILE"
  echo "Saved report to $OUTFILE"
else
  print_output
fi

