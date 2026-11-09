#!/system/bin/sh
# MaxG Power - Bluetooth de baja latencia para mandos.
# 1) Conexión BLE rápida: pide intervalos de 7.5-11 ms en las propiedades que lee la pila Bluetooth de Android (bluetooth.core.le.*).
# 2) Prioridad de los hilos de la pila Bluetooth mientras el modo mando está activo (ver pad.sh).
BTORIG=$CONF/bt.orig
BT_PROPS="bluetooth.core.le.min_connection_interval=6 bluetooth.core.le.max_connection_interval=9 bluetooth.core.le.connection_latency=0 bluetooth.core.le.connection_supervision_timeout=500"
bt_setprop() { setprop "$1" "$2" 2>/dev/null || resetprop "$1" "$2" 2>/dev/null; }
bt_on() { [ "$(settings get global bluetooth_on 2>/dev/null </dev/null)" = 1 ]; }
bt_restart() {   # reinicia la pila Bluetooth para que lea las propiedades (los dispositivos se reconectan solos)
  bt_on || return 0
  svc bluetooth disable >/dev/null 2>&1 </dev/null || cmd bluetooth_manager disable >/dev/null 2>&1 </dev/null
  _i=0; while [ "$_i" -lt 8 ] && bt_on; do sleep 1; _i=$((_i+1)); done
  sleep 1
  svc bluetooth enable >/dev/null 2>&1 </dev/null || cmd bluetooth_manager enable >/dev/null 2>&1 </dev/null
}
bt_fast_apply() {   # guarda los valores originales una vez y fija los rápidos
  for _kv in $BT_PROPS; do _k=${_kv%%=*}; _v=${_kv#*=}
    grep -q "^$_k|" "$BTORIG" 2>/dev/null || echo "$_k|$(getprop "$_k" 2>/dev/null)" >> "$BTORIG"
    bt_setprop "$_k" "$_v"
  done
}
bt_fast_restore() {
  [ -f "$BTORIG" ] || return 0
  while IFS='|' read -r _k _v; do [ -n "$_k" ] && bt_setprop "$_k" "$_v"; done < "$BTORIG"
  rm -f "$BTORIG"
}
bt_fast_set() {   # on|off
  K_ERR=""
  echo $(( $(date +%s) + 120 )) > "$CONF/pad.nostat"   # el reinicio del Bluetooth corta el mando a propósito: no cuenta como corte
  case "$1" in
    on) bt_fast_apply; cfg_set bt_fast 1; bt_restart; log "Bluetooth: conexión rápida activada" ;;
    off) bt_fast_restore; cfg_set bt_fast 0; bt_restart; log "Bluetooth: conexión rápida desactivada" ;;
    *) K_ERR="usa on u off"; return 1 ;;
  esac
  return 0
}
bt_status() {   # BT|rápida|min|max|latencia|timeout|encendido
  echo "BT|$(cfg_get bt_fast 0)|$(getprop bluetooth.core.le.min_connection_interval 2>/dev/null)|$(getprop bluetooth.core.le.max_connection_interval 2>/dev/null)|$(getprop bluetooth.core.le.connection_latency 2>/dev/null)|$(getprop bluetooth.core.le.connection_supervision_timeout 2>/dev/null)|$(bt_on && echo 1 || echo 0)"
}
# prioridad de los hilos de com.android.bluetooth (nice -8) mientras juegas
pad_bt_on() { claim_put fn:btprio pad on; }      # el árbitro (claims.sh) sube la prioridad una sola vez aunque también esté la permanente
pad_bt_off() { claim_del fn:btprio pad; }

# ---- estabilidad del mando ----
PADFLAPS=$CONF/pad_flaps; PADTIME=$CONF/pad_time
btg_has_wl() { dumpsys deviceidle whitelist 2>/dev/null </dev/null | grep -q 'com.android.bluetooth'; }
btg_apply() {   # la pila Bluetooth nunca se duerme ni se restringe en segundo plano
  [ "$(cfg_get bt_guard 1)" = 1 ] || { btg_revert; return 0; }
  if ! btg_has_wl; then : > "$CONF/btg.wl"; dumpsys deviceidle whitelist +com.android.bluetooth >/dev/null 2>&1 </dev/null; fi
  : > "$CONF/btg.ops"
  cmd appops set com.android.bluetooth RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1 </dev/null
  am set-standby-bucket com.android.bluetooth active >/dev/null 2>&1 </dev/null
  log "guardia Bluetooth: pila exenta de Doze y de límites en segundo plano"
}
btg_revert() {
  [ -e "$CONF/btg.wl" ] && dumpsys deviceidle whitelist -com.android.bluetooth >/dev/null 2>&1 </dev/null
  [ -e "$CONF/btg.ops" ] && cmd appops set com.android.bluetooth RUN_ANY_IN_BACKGROUND default >/dev/null 2>&1 </dev/null
  rm -f "$CONF/btg.wl" "$CONF/btg.ops"; return 0
}
btg_set() {   # guard|autofix 0|1
  K_ERR=""
  case "$2" in 0|1) ;; *) K_ERR="usa 0 o 1"; return 1 ;; esac
  case "$1" in
    guard) cfg_set bt_guard "$2"; btg_apply ;;
    autofix) cfg_set bt_autofix "$2" ;;
    *) K_ERR="opción desconocida"; return 1 ;;
  esac
  return 0
}
pad_trim() { _n=$(wc -l < "$1" 2>/dev/null); isnum "$_n" && [ "$_n" -gt 80 ] && { tail -n 50 "$1" > "$1.t" && mv -f "$1.t" "$1"; }; return 0; }
pad_autofix() {   # 3 cortes en 15 min con el modo rápido: se desactiva solo
  [ "$(cfg_get bt_fast 0)" = 1 ] && [ "$(cfg_get bt_autofix 1)" = 1 ] || return 0
  af_now=$(date +%s); af_n=0
  while IFS='|' read -r af_t af_f af_g af_x; do isnum "$af_t" && [ "$af_f" = 1 ] && [ $((af_now-af_t)) -le 900 ] && af_n=$((af_n+1)); done < "$PADFLAPS"
  [ "$af_n" -ge 3 ] || return 0
  log "modo mando: $af_n cortes en 15 min con el Bluetooth rápido; se desactiva solo"
  bt_fast_set off; cfg_set bt_autofixed "$af_now"
}
pad_sess_start() {   # $1 = transporte. Si vuelve a conectarse en menos de 90 s tras salir, cuenta como corte
  PS_T0=$(date +%s); PS_F=$(cfg_get bt_fast 0); PS_TR=$1
  [ "$1" = bluetooth ] || return 0
  ps_last=$(cat "$CONF/pad.lastleave" 2>/dev/null); ps_ns=$(cat "$CONF/pad.nostat" 2>/dev/null)
  isnum "$ps_last" || return 0
  ps_gap=$((PS_T0-ps_last))
  if [ "$ps_gap" -le 90 ] && { ! isnum "$ps_ns" || [ "$PS_T0" -ge "$ps_ns" ]; }; then
    echo "$PS_T0|$PS_F|$ps_gap" >> "$PADFLAPS"; pad_trim "$PADFLAPS"
    log "modo mando: corte de Bluetooth (volvió tras $ps_gap s, modo rápido=$PS_F)"
    pad_autofix
  fi
}
pad_sess_end() {
  ps_now=$(date +%s); echo "$ps_now" > "$CONF/pad.lastleave"
  [ "$PS_TR" = bluetooth ] || return 0
  isnum "$PS_T0" && echo "$ps_now|$PS_F|$((ps_now-PS_T0))" >> "$PADTIME" && pad_trim "$PADTIME"
  return 0
}
wifi_mhz() { dumpsys wifi 2>/dev/null </dev/null | grep -m1 -o 'Frequency: [0-9]*' | tr -dc '0-9'; }
padx_status() {   # PADX|cortes_rapido|seg_rapido|cortes_normal|seg_normal|cortes_24h|autofix|autofix_fecha|guardia|wifi_mhz
  px_now=$(date +%s); px_cf=0; px_cn=0; px_tf=0; px_tn=0; px_c24=0
  [ -f "$PADFLAPS" ] && while IFS='|' read -r px_t px_f px_g; do isnum "$px_t" || continue
    if [ "$px_f" = 1 ]; then px_cf=$((px_cf+1)); else px_cn=$((px_cn+1)); fi
    [ $((px_now-px_t)) -le 86400 ] && px_c24=$((px_c24+1)); done < "$PADFLAPS"
  [ -f "$PADTIME" ] && while IFS='|' read -r px_t px_f px_d; do isnum "$px_d" || continue
    if [ "$px_f" = 1 ]; then px_tf=$((px_tf+px_d)); else px_tn=$((px_tn+px_d)); fi; done < "$PADTIME"
  echo "PADX|$px_cf|$px_tf|$px_cn|$px_tn|$px_c24|$(cfg_get bt_autofix 1)|$(cfg_get bt_autofixed 0)|$(cfg_get bt_guard 1)|$([ "${1:-}" = full ] && wifi_mhz)"
}

# ---- prioridad permanente de la pila Bluetooth y utilidades ----
# La pila (com.android.bluetooth) sube de prioridad (nice -8) para atender antes los paquetes de audio y de mandos. Se pide por el árbitro (claims.sh),
# así que no choca con el modo mando, que pide lo mismo mientras juegas. El supervisor la reaplica si la pila se reinicia.
btprio_set() {   # on|off
  K_ERR=""
  case "$1" in
    on|1) cfg_set bt_prio 1; claim_put fn:btprio bt on; log "Bluetooth: prioridad permanente activada" ;;
    off|0) cfg_set bt_prio 0; claim_del fn:btprio bt; log "Bluetooth: prioridad permanente desactivada" ;;
    *) K_ERR="usa on u off"; return 1 ;;
  esac
  return 0
}
btprio_boot() { [ "$(cfg_get bt_prio 1)" = 1 ] && claim_put fn:btprio bt on; return 0; }
bt_restart_now() {   # reinicia la pila Bluetooth a petición del usuario (los dispositivos se reconectan solos)
  K_ERR=""
  bt_on || { K_ERR="el Bluetooth está apagado"; return 1; }
  echo $(( $(date +%s) + 120 )) > "$CONF/pad.nostat"
  bt_restart; log "Bluetooth: reiniciado a petición del usuario"
  btprio_boot
  return 0
}
bt_proc_nice() {   # nice actual de los hilos de la pila (para ver si la prioridad quedó puesta): "min/max/hilos"
  btp_pid || { echo "-"; return 0; }
  bn_min=99; bn_max=-99; bn_n=0
  for bn_t in "$R/proc/$BP_PID"/task/*; do
    [ -r "$bn_t/stat" ] || continue
    bn_l=""; read -r bn_l < "$bn_t/stat" 2>/dev/null; bn_l=${bn_l##*) }
    set -- $bn_l; bn_v=${17-}
    case "$bn_v" in ''|*[!0-9-]*) continue ;; esac
    bn_n=$((bn_n+1)); [ "$bn_v" -lt "$bn_min" ] && bn_min=$bn_v; [ "$bn_v" -gt "$bn_max" ] && bn_max=$bn_v
  done
  if [ "$bn_n" -eq 0 ]; then echo "-"; else echo "$bn_min/$bn_max/$bn_n"; fi
}
bt_wifi_band() {   # 2.4 | 5 | 6 | "" según la frecuencia a la que está conectado el Wi-Fi
  bw_f=$(wifi_mhz); isnum "$bw_f" || { echo ""; return 0; }
  if [ "$bw_f" -lt 3000 ]; then echo 2.4; elif [ "$bw_f" -lt 5900 ]; then echo 5; else echo 6; fi
}
bt_extra_status() {   # BTP|prioridad|escaneos apagados|nice de la pila
  echo "BTP|$(cfg_get bt_prio 1)|$(cfg_get tune_scan 0)|$(bt_proc_nice)"
}
