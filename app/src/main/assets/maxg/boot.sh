#!/system/bin/sh
# MaxG Power (app) — lo que hacía post-fs-data.sh del módulo:
# contador de arranques fallidos + props rápidas de Bluetooth LE.
# Se corre al arrancar el servicio desde el arranque. Las props se ponen
# también con resetprop -n para que persistan y apliquen temprano en el
# próximo arranque.
CONF=/data/adb/maxg_power; mkdir -p "$CONF"
n=$(cat "$CONF/bootcount" 2>/dev/null); case "$n" in ''|*[!0-9]*) n=0 ;; esac
n=$((n+1)); echo "$n" > "$CONF/bootcount"
if grep -q "^bt_fast=1" "$CONF/cfg" 2>/dev/null; then
  for kv in bluetooth.core.le.min_connection_interval=6 bluetooth.core.le.max_connection_interval=9 bluetooth.core.le.connection_latency=0 bluetooth.core.le.connection_supervision_timeout=500; do
    setprop "${kv%%=*}" "${kv#*=}" 2>/dev/null || resetprop "${kv%%=*}" "${kv#*=}" 2>/dev/null
    resetprop -n "${kv%%=*}" "${kv#*=}" 2>/dev/null
  done
fi
if [ "$n" -ge 3 ]; then touch "$CONF/safe"; echo "$(date '+%F %T') MODO SEGURO: $n arranques seguidos sin estabilizarse" >> "$CONF/log"; fi
