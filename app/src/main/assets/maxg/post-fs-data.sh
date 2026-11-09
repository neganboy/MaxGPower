#!/system/bin/sh
# Contador de arranques fallidos: se reinicia a 0 cuando el sistema lleva un rato estable (service.sh).
MODDIR=${0%/*}
CONF=/data/adb/maxg_power; mkdir -p "$CONF"
n=$(cat "$CONF/bootcount" 2>/dev/null); case "$n" in ''|*[!0-9]*) n=0 ;; esac
n=$((n+1)); echo "$n" > "$CONF/bootcount"
# Bluetooth rápido: las propiedades deben existir antes de que arranque la pila Bluetooth
if grep -q "^bt_fast=1" "$CONF/cfg" 2>/dev/null; then
  for kv in bluetooth.core.le.min_connection_interval=6 bluetooth.core.le.max_connection_interval=9 bluetooth.core.le.connection_latency=0 bluetooth.core.le.connection_supervision_timeout=500; do setprop "${kv%%=*}" "${kv#*=}" 2>/dev/null || resetprop "${kv%%=*}" "${kv#*=}" 2>/dev/null; done
fi
if [ "$n" -ge 3 ]; then touch "$CONF/safe"; echo "$(date '+%F %T') MODO SEGURO: $n arranques seguidos sin estabilizarse" >> "$CONF/log"; fi
