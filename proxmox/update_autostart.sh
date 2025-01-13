#!/bin/bash
 
# Function to get autostart status for a given ID
get_autostart_status() {
  local id=$1
  local type=$2
  if [[ $type == "VM" ]]; then
    qm config $id | grep -q '^onboot: 1$' && echo "1" || echo "0"
  elif [[ $type == "LXC" ]]; then
    pct config $id | grep -q '^onboot: 1$' && echo "1" || echo "0"
  fi
}
 
# Function to list the current autostart status of all VMs and LXCs
list_autostart_status() {
  echo "Current Autostart Status:"
  echo "---------------------------------"
 
  # List all VMs with their autostart status
  echo "VMs:"
  vm_ids=($(qm list | awk 'NR>1 {print $1}'))
  for id in "${vm_ids[@]}"; do
    status=$(get_autostart_status $id "VM")
    echo "  [VM] ID: $id, Autostart: $status"
  done
 
  # List all LXCs with their autostart status
  echo "LXCs:"
  lxc_ids=($(pct list | awk 'NR>1 {print $1}'))
  for id in "${lxc_ids[@]}"; do
    status=$(get_autostart_status $id "LXC")
    echo "  [LXC] ID: $id, Autostart: $status"
  done
 
  echo "---------------------------------"
}
 
# Function to change autostart for a given VM or LXC
change_autostart() {
  local id=$1
  local type=$2
  local action=$3
  if [[ $type == "VM" ]]; then
    qm set $id --onboot $action
    echo "Autostart set to $action for VM ID: $id"
  elif [[ $type == "LXC" ]]; then
    pct set $id --onboot $action
    echo "Autostart set to $action for LXC ID: $id"
  fi
}
 
# Function to change autostart for all VMs and LXCs
change_autostart_all() {
  for id in "${vm_ids[@]}"; do
    change_autostart $id "VM" $1
  done
  for id in "${lxc_ids[@]}"; do
    change_autostart $id "LXC" $1
  done
  echo "Autostart set to $1 for all VMs and LXCs."
}
 
# Function to display a menu and get user selection
show_menu() {
  echo "Select the IDs to change autostart:"
  echo "---------------------------------"
 
  # List all VMs with numbering and current autostart status
  echo "VMs:"
  vm_ids=($(qm list | awk 'NR>1 {print $1}'))
  vm_count=${#vm_ids[@]}
  for i in "${!vm_ids[@]}"; do
    status=$(get_autostart_status ${vm_ids[$i]} "VM")
    echo "$((i+1)). [VM] ${vm_ids[$i]} (Autostart: $status)"
  done
 
  # List all LXCs with numbering and current autostart status
  echo "LXCs:"
  lxc_ids=($(pct list | awk 'NR>1 {print $1}'))
  lxc_count=${#lxc_ids[@]}
  for i in "${!lxc_ids[@]}"; do
    status=$(get_autostart_status ${lxc_ids[$i]} "LXC")
    echo "$((i+vm_count+1)). [LXC] ${lxc_ids[$i]} (Autostart: $status)"
  done
 
  # Add "ALL" option at the end
  echo "$((vm_count+lxc_count+1)). [ALL] Change autostart for all VMs and LXCs"
  echo "---------------------------------"
  echo "Enter your choice(s) (numbers or 'ALL'):"
  read -r selected_choices
 
  # Handle user input for selected choices
  for choice in $selected_choices; do
    if [[ $choice == "ALL" ]]; then
      change_autostart_all $1
      return
    elif (( choice > 0 && choice <= vm_count )); then
      change_autostart ${vm_ids[$((choice-1))]} "VM" $1
    elif (( choice > vm_count && choice <= vm_count+lxc_count )); then
      change_autostart ${lxc_ids[$((choice-vm_count-1))]} "LXC" $1
    else
      echo "Invalid choice: $choice"
    fi
  done
}
 
# Main script execution
if [[ $1 == "-l" ]]; then
  list_autostart_status
  exit 0
elif [[ $# -ne 1 ]] || ! [[ $1 =~ ^[01]$ ]]; then
  echo "Usage: $0 <1|0> or $0 -l"
  echo "  1 - Enable autostart"
  echo "  0 - Disable autostart"
  echo "  -l - List current autostart status"
  exit 1
fi
 
show_menu $1
echo "Done."
