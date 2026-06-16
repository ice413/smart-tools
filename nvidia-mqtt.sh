#!/bin/bash

# --- Inställningar ---
MQTT_HOST="192.168.1.95"
TOPIC_PREFIX="homeassistant/sensor/smarty_gpu"

# --- Skicka Discovery för sensorer ---
# (Behåller dina befintliga och lägger till Tx/Rx)
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/temp/config" -m '{"name": "GPU Temperatur", "stat_t": "'$TOPIC_PREFIX'/state", "unit_of_meas": "°C", "val_tpl": "{{ value_json.temp }}", "unique_id": "smarty_gpu_temp", "icon": "mdi:thermometer", "dev_cla": "temperature", "state_cla": "measurement"}'
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/power/config" -m '{"name": "GPU Power Draw", "stat_t": "'$TOPIC_PREFIX'/state", "unit_of_meas": "W", "val_tpl": "{{ value_json.power }}", "unique_id": "smarty_gpu_power", "icon": "mdi:flash", "dev_cla": "power", "state_cla": "measurement"}'

mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/fan/config" -m '{"name": "GPU Fan Speed", "stat_t": "'$TOPIC_PREFIX'/state", "unit_of_meas": "%", "val_tpl": "{{ value_json.fan }}", "unique_id": "smarty_gpu_fan", "icon": "mdi:fan"}'
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/load/config" -m '{"name": "GPU Load", "stat_t": "'$TOPIC_PREFIX'/state", "unit_of_meas": "%", "val_tpl": "{{ value_json.load }}", "unique_id": "smarty_gpu_load", "icon": "mdi:gauge"}'
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/mem/config" -m '{"name": "GPU Memory Used", "stat_t": "'$TOPIC_PREFIX'/state", "unit_of_meas": "MiB", "val_tpl": "{{ value_json.mem }}", "unique_id": "smarty_gpu_mem", "icon": "mdi:memory"}'
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/pstate/config" -m '{"name": "GPU Performance State", "stat_t": "'$TOPIC_PREFIX'/state", "val_tpl": "{{ value_json.pstate }}", "unique_id": "smarty_gpu_pstate", "icon": "mdi:speedometer"}'

# NYA: PCIe Tx & Rx
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/tx/config" -m '{"name": "GPU PCIe Tx", "stat_t": "'$TOPIC_PREFIX'/state", "unit_of_meas": "KB/s", "val_tpl": "{{ value_json.tx }}", "unique_id": "smarty_gpu_tx", "icon": "mdi:transfer-up"}'
mosquitto_pub -h "$MQTT_HOST" -r -t "$TOPIC_PREFIX/rx/config" -m '{"name": "GPU PCIe Rx", "stat_t": "'$TOPIC_PREFIX'/state", "unit_of_meas": "KB/s", "val_tpl": "{{ value_json.rx }}", "unique_id": "smarty_gpu_rx", "icon": "mdi:transfer-down"}'

# --- Loop för data ---
while true; do
  # 1. Hämta standard-data
  DATA=$(nvidia-smi --query-gpu=temperature.gpu,power.draw,fan.speed,utilization.gpu,memory.used,pstate --format=csv,noheader,nounits | tr -d ' ')

  TEMP=$(echo $DATA | cut -d',' -f1)
  POWER=$(echo $DATA | cut -d',' -f2)
  FAN=$(echo $DATA | cut -d',' -f3)
  LOAD=$(echo $DATA | cut -d',' -f4)
  MEM=$(echo $DATA | cut -d',' -f5)
  PSTATE=$(echo $DATA | cut -d',' -f6)

  # 2. Hämta PCIe Throughput (Eftersom --query-gpu inte stödde dem på din maskin)
  # Vi extraherar siffran före "KB/s"
  TX=$(nvidia-smi -q | grep "Tx Throughput" | awk '{print $4}')
  RX=$(nvidia-smi -q | grep "Rx Throughput" | awk '{print $4}')

  # Om värdena är tomma (t.ex. vid tillfälligt läsfel), sätt till 0
  TX=${TX:-0}
  RX=${RX:-0}

  # 3. Skicka allt som ett JSON-paket
  mosquitto_pub -h "$MQTT_HOST" -t "$TOPIC_PREFIX/state" -m "{\"temp\": $TEMP, \"power\": $POWER, \"fan\": $FAN, \"load\": $LOAD, \"mem\": $MEM, \"pstate\": \"$PSTATE\", \"tx\": $TX, \"rx\": $RX}"

  sleep 10
done
