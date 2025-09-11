#!/usr/bin/env python3

import os
import re
import sys
from typing import List, Tuple

# --- Type Aliases ---
MarkdownRow = str

# --- Argument Parsing ---
def parse_args(args: List[str]) -> str:
    outfile: str = ""
    i: int = 0
    while i < len(args):
        if args[i] in ("-o", "--outfile") and i + 1 < len(args):
            outfile = args[i + 1]
            i += 2
        else:
            print("Usage: script.py [-o|--outfile output.md]")
            sys.exit(1)
    return outfile

# --- VM Parsing ---
def parse_vm_configs() -> Tuple[List[MarkdownRow], int, int]:
    vm_rows: List[MarkdownRow] = []
    total_vm_mem: int = 0
    total_vm_disk: int = 0

    for cfg_path in glob_files("/etc/pve/qemu-server", ".conf"):
        vmid: str = os.path.basename(cfg_path).replace(".conf", "")
        name: str = extract_value(cfg_path, "^name") or "(no name)"
        mem_str: str = extract_value(cfg_path, "^memory") or "0"
        mem: int = int(mem_str)

        disk_size_sum: int = 0
        disk_locations: List[str] = []
        with open(cfg_path) as f:
            for line in f:
                disk_match = re.match(r"^(scsi|sata|virtio|efidisk)\d+:\s*([^\s,]+)", line)
                if disk_match:
                    storage_location = disk_match.group(2).split(":")[0].split(",")[0]
                    disk_locations.append(storage_location)
                    size_match = re.search(r",size=([\d]+)([GM])", line)
                    if size_match:
                        size_val: int = int(size_match.group(1))
                        unit: str = size_match.group(2)
                        if unit == "G":
                            disk_size_sum += size_val
                        elif unit == "M":
                            disk_size_sum += size_val // 1024

        disk_locations_str = ", ".join(disk_locations) if disk_locations else "-"
        vm_rows.append(f"| {vmid} | {name} | {mem} | {disk_size_sum} | {disk_locations_str} |")
        total_vm_mem += mem
        total_vm_disk += disk_size_sum

    return vm_rows, total_vm_mem, total_vm_disk

# --- LXC Parsing ---
def parse_lxc_configs() -> Tuple[List[MarkdownRow], int, int]:
    lxc_rows: List[MarkdownRow] = []
    total_lxc_mem: int = 0
    total_lxc_disk: int = 0

    for cfg_path in glob_files("/etc/pve/lxc", ".conf"):
        vmid: str = os.path.basename(cfg_path).replace(".conf", "")
        name: str = extract_value(cfg_path, "^hostname") or "(no name)"
        mem: int = int(extract_value(cfg_path, "^memory") or "0")
        swap: int = int(extract_value(cfg_path, "^swap") or "0")

        rootfs_line: str = extract_line(cfg_path, "^rootfs")
        disk_gb: int = 0
        disk_location: str = "-"
        if rootfs_line:
            # rootfs: local-lvm:vm-101-disk-0,size=8G
            rootfs_match = re.match(r"^rootfs:\s*([^\s,]+)", rootfs_line)
            if rootfs_match:
                disk_location = rootfs_match.group(1).split(":")[0].split(",")[0]
            size_match = re.search(r",size=([\d]+)([GM])", rootfs_line)
            if size_match:
                size_val: int = int(size_match.group(1))
                unit: str = size_match.group(2)
                if unit == "G":
                    disk_gb = size_val
                elif unit == "M":
                    disk_gb = size_val // 1024

        lxc_rows.append(f"| {vmid} | {name} | {mem} | {swap} | {disk_gb} | {disk_location} |")
        total_lxc_mem += mem
        total_lxc_disk += disk_gb

    return lxc_rows, total_lxc_mem, total_lxc_disk

# --- Helpers ---
def glob_files(directory: str, extension: str) -> List[str]:
    return [os.path.join(directory, f) for f in os.listdir(directory) if f.endswith(extension)]

def extract_value(filepath: str, pattern: str) -> str:
    with open(filepath) as f:
        for line in f:
            if re.match(pattern, line, re.IGNORECASE):
                # Matcha både "key=value" och "key: value"
                parts = re.split(r"[=:]", line, maxsplit=1)
                if len(parts) == 2:
                    return parts[1].strip()
    return ""


def extract_line(filepath: str, pattern: str) -> str:
    with open(filepath) as f:
        for line in f:
            if re.match(pattern, line, re.IGNORECASE):
                return line.strip()
    return ""

# --- Output ---
def print_output(
    vm_rows: List[MarkdownRow],
    lxc_rows: List[MarkdownRow],
    total_vm_mem: int,
    total_vm_disk: int,
    total_lxc_mem: int,
    total_lxc_disk: int
) -> None:
    summary_mem: int = total_vm_mem + total_lxc_mem
    summary_disk: int = total_vm_disk + total_lxc_disk

    output_lines: List[str] = [
        "### VM Memory & Disk Allocation",
        "| VM ID | Name | Memory (MB) | Disk (GB) | Disk Location(s) |",
        "|------|------|-------------|-----------|------------------|",
        *vm_rows,
        "",
        "### LXC Memory & Disk Allocation",
        "| LXC ID | Hostname | Memory (MB) | Swap (MB) | Disk (GB) | Disk Location |",
        "|--------|----------|-------------|-----------|-----------|---------------|",
        *lxc_rows,
        "",
        "### Summary",
        f"- Total VM Memory: {total_vm_mem} MB",
        f"- Total VM Disk: {total_vm_disk} GB",
        f"- Total LXC Memory: {total_lxc_mem} MB",
        f"- Total LXC Disk: {total_lxc_disk} GB",
        f"- Total Allocated Memory: {summary_mem} MB",
        f"- Total Allocated Disk: {summary_disk} GB"
    ]

    for line in output_lines:
        print(line)

# --- Main ---
def main() -> None:
    outfile: str = parse_args(sys.argv[1:])
    vm_rows, total_vm_mem, total_vm_disk = parse_vm_configs()
    lxc_rows, total_lxc_mem, total_lxc_disk = parse_lxc_configs()

    if outfile:
        with open(outfile, "w") as f:
            sys.stdout = f
            print_output(vm_rows, lxc_rows, total_vm_mem, total_vm_disk, total_lxc_mem, total_lxc_disk)
        print(f"Saved report to {outfile}")
    else:
        print_output(vm_rows, lxc_rows, total_vm_mem, total_vm_disk, total_lxc_mem, total_lxc_disk)

if __name__ == "__main__":
    main()

root@proxxen:~#
