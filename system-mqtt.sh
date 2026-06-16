#!/bin/bash

# --- Inställningar ---
MQTT_HOST="192.168.1.95"
TOPIC_PREFIX="homeassistant/sensor/smarty_cpu"

# Gemensam enhetsinformation för att gruppera alla sensorer i HA
DEVICE_INFO="\"dev\": {\"ids\": [\"smarty_host\"], \"name\": \"Smarty Server\", \"model\": \"Linux Host\", \"mf\": \"Custom Script\"}"

# --- Skicka Discovery för sensorer ---

function send_disk_discovery() {
  local id=$1
  local name=$2
  mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/disk_${id}_total/config" -m "{\"name\": \"$name Total\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"GB\", \"val_tpl\": \"{{ value_json.disk_${id}_total }}\", \"unique_id\": \"smarty_disk_${id}_total\", \"icon\": \"mdi:database\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
  mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/disk_${id}_used/config" -m "{\"name\": \"$name Used\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"GB\", \"val_tpl\": \"{{ value_json.disk_${id}_used }}\", \"unique_id\": \"smarty_disk_${id}_used\", \"icon\": \"mdi:database-export\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
  mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/disk_${id}_perc/config" -m "{\"name\": \"$name Used %\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"%\", \"val_tpl\": \"{{ value_json.disk_${id}_perc }}\", \"unique_id\": \"smarty_disk_${id}_perc\", \"icon\": \"mdi:chart-pie\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
}

# Skicka discovery för diskar
send_disk_discovery "root" "Smarty Disk Root"
send_disk_discovery "pbs" "Smarty PBS Share"
send_disk_discovery "photo" "Smarty Photo Share"

# Discovery för system-sensorer
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/temp/config" -m "{\"name\": \"Smarty CPU Temp\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"°C\", \"val_tpl\": \"{{ value_json.smarty_cpu_temp }}\", \"unique_id\": \"smarty_cpu_temp\", \"dev_cla\": \"temperature\", \"state_cla\": \"measurement\", \"icon\": \"mdi:thermometer\", $DEVICE_INFO}"
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/nvme_temp/config" -m "{\"name\": \"Smarty NVMe Temp\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"°C\", \"val_tpl\": \"{{ value_json.smarty_nvme_temp }}\", \"unique_id\": \"smarty_nvme_temp\", \"dev_cla\": \"temperature\", \"state_cla\": \"measurement\", \"icon\": \"mdi:harddisk\", $DEVICE_INFO}"
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/fan/config" -m "{\"name\": \"Smarty CPU Fan\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"RPM\", \"val_tpl\": \"{{ value_json.smarty_fan_speed }}\", \"unique_id\": \"smarty_fan_speed\", \"icon\": \"mdi:fan\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/load/config" -m "{\"name\": \"Smarty CPU Usage\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"%\", \"val_tpl\": \"{{ value_json.smarty_cpu_usage }}\", \"unique_id\": \"smarty_cpu_usage\", \"icon\": \"mdi:cpu-64-bit\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/load_avg/config" -m "{\"name\": \"Smarty CPU Load Avg\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"val_tpl\": \"{{ value_json.smarty_cpu_load_avg }}\", \"unique_id\": \"smarty_cpu_load_avg\", \"icon\": \"mdi:chart-line\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/mem_used/config" -m "{\"name\": \"Smarty RAM Used\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"GB\", \"val_tpl\": \"{{ value_json.smarty_sys_mem_gb }}\", \"unique_id\": \"smarty_ram_used_gb\", \"icon\": \"mdi:memory\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/mem_tot/config" -m "{\"name\": \"Smarty RAM Total\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"GB\", \"val_tpl\": \"{{ value_json.smarty_sys_mem_tot_gb }}\", \"unique_id\": \"smarty_ram_total_gb\", \"icon\": \"mdi:memory\", \"state_cla\": \"measurement\", $DEVICE_INFO}"
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/mem_perc/config" -m "{\"name\": \"Smarty RAM Load\", \"stat_t\": \"$TOPIC_PREFIX/state\", \"unit_of_meas\": \"%\", \"val_tpl\": \"{{ value_json.smarty_sys_mem_perc }}\", \"unique_id\": \"smarty_ram_load_perc\", \"icon\": \"mdi:memory\", \"state_cla\": \"measurement\", $DEVICE_INFO}"

# --- Loop för data ---
while true; do
  # 1. Systemvärden
  C_TEMP=$(sensors 2>/dev/null | grep "Tctl" | head -1 | awk '{print $2}' | tr -d '+°C')
  C_FAN=$(sensors 2>/dev/null | grep "fan1" | awk '{print $2}' | grep -o '[0-9]*')
  N_TEMP=$(sensors 2>/dev/null | grep -A 2 "nvme-pci-0a00" | grep "Composite" | awk '{print $2}' | tr -d '+°C')
  C_USAGE=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | sed 's/,/./g' | awk -F'id' '{split($1, a, " "); print 100 - a[length(a)]}')
  C_LOAD_AVG=$(cat /proc/loadavg | awk '{print $1}')
  
  M_TOTAL_GB=$(free -m | awk '/Mem:/ {printf "%.2f", $2/1024}')
  M_USED_GB=$(free -m | awk '/Mem:/ {printf "%.2f", $3/1024}')
  M_PERC=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')

  # 2. Disknyttjande
  D_ROOT_TOT=$(df -BG / | awk 'NR==2 {print $2}' | tr -d 'G')
  D_ROOT_USED=$(df -BG / | awk 'NR==2 {print $3}' | tr -d 'G')
  D_ROOT_PERC=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

  D_PBS_TOT=$(df -BG /mnt/pbs_share | awk 'NR==2 {print $2}' | tr -d 'G')
  D_PBS_USED=$(df -BG /mnt/pbs_share | awk 'NR==2 {print $3}' | tr -d 'G')
  D_PBS_PERC=$(df /mnt/pbs_share | awk 'NR==2 {print $5}' | tr -d '%')

  D_PHOTO_TOT=$(df -BG /mnt/photo_share | awk 'NR==2 {print $2}' | tr -d 'G')
  D_PHOTO_USED=$(df -BG /mnt/photo_share | awk 'NR==2 {print $3}' | tr -d 'G')
  D_PHOTO_PERC=$(df /mnt/photo_share | awk 'NR==2 {print $5}' | tr -d '%')

  # 3. Bygg JSON
  PAYLOAD="{"
  PAYLOAD+="\"smarty_cpu_temp\": ${C_TEMP:-0}, "
  PAYLOAD+="\"smarty_nvme_temp\": ${N_TEMP:-0}, "
  PAYLOAD+="\"smarty_fan_speed\": ${C_FAN:-0}, "
  PAYLOAD+="\"smarty_cpu_usage\": ${C_USAGE:-0}, "
  PAYLOAD+="\"smarty_cpu_load_avg\": ${C_LOAD_AVG:-0}, "
  PAYLOAD+="\"smarty_sys_mem_gb\": ${M_USED_GB:-0}, "
  PAYLOAD+="\"smarty_sys_mem_tot_gb\": ${M_TOTAL_GB:-0}, "
  PAYLOAD+="\"smarty_sys_mem_perc\": ${M_PERC:-0}, "
  PAYLOAD+="\"disk_root_total\": ${D_ROOT_TOT:-0}, \"disk_root_used\": ${D_ROOT_USED:-0}, \"disk_root_perc\": ${D_ROOT_PERC:-0}, "
  PAYLOAD+="\"disk_pbs_total\": ${D_PBS_TOT:-0}, \"disk_pbs_used\": ${D_PBS_USED:-0}, \"disk_pbs_perc\": ${D_PBS_PERC:-0}, "
  PAYLOAD+="\"disk_photo_total\": ${D_PHOTO_TOT:-0}, \"disk_photo_used\": ${D_PHOTO_USED:-0}, \"disk_photo_perc\": ${D_PHOTO_PERC:-0}"
  PAYLOAD+="}"

  # 4. Skicka med Retain
  mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/state" -m "$PAYLOAD"

  sleep 30
done
