#!/system/bin/sh
# MaxG Power - Vigilante de topes: si la ROM u otra app sube un tope de CPU o GPU
# por encima de lo que pide el perfil, lo devuelve al instante, por evento
# (sin esperar al ciclo de 45 s del supervisor). Solo corrige hacia abajo:
# si el térmico de la ROM baja un tope, se respeta.
WATCHPID=$CONF/watchd.pid
watch_inotifyd() {   # busybox del gestor root (KernelSU, APatch o Magisk); si no hay, el inotifyd de toybox del sistema
  for _b in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    [ -x "$_b" ] && "$_b" inotifyd 2>&1 | grep -q Usage && { echo "$_b inotifyd"; return 0; }
  done
  command -v inotifyd
}
watchd_alive() { _d=""; [ -r "$WATCHPID" ] && read -r _d < "$WATCHPID"; [ -n "$_d" ] && kill -0 "$_d" 2>/dev/null; }
watchd_run() {
  echo $$ > "$WATCHPID"; rm -f "$CONF/watchd.stop"; log "vigilante de topes iniciado"
  trap 'rm -f "$WATCHPID"; exit 0' TERM INT
  INOTIFYD=$(watch_inotifyd)
  [ -z "$INOTIFYD" ] && { log "vigilante de topes: sin inotifyd en este teléfono, no se vigila"; rm -f "$WATCHPID"; exit 0; }
  WATCH=""
  for _p in $(policies); do [ -e "$CPUF/policy$_p/scaling_max_freq" ] && WATCH="$WATCH $CPUF/policy$_p/scaling_max_freq:w"; done
  gpu_be
  case "$GBE" in
    dev|clk) _gp=$(gpu_node max); [ -n "$_gp" ] && WATCH="$WATCH $_gp:w" ;;
    pwr) [ -e "$GPUD/max_pwrlevel" ] && WATCH="$WATCH $GPUD/max_pwrlevel:w" ;;
  esac
  [ -n "$WATCH" ] || { log "vigilante de topes: nada que vigilar"; rm -f "$WATCHPID"; exit 0; }
  $INOTIFYD - $WATCH | while read -r _ev _f; do
    [ -e "$CONF/watchd.stop" ] && break
    case "$_f" in
      *scaling_max_freq) _k="cpu_max_${_f##*policy}"; _k=${_k%%/*} ;;
      *max_pwrlevel|*max_gpuclk|*max_freq) _k=gpu_max ;;
      *) continue ;;
    esac
    knob_des_v "$_k"; _cap=$KD
    [ -n "$_cap" ] || continue
    knob_cur_v "$_k"; _cur=$KC
    isnum "$_cur" && isnum "$_cap" && [ "$_cur" -gt "$_cap" ] && { knob_put "$_k" "$_cap"; log "vigilante de topes: $_k estaba en $_cur, devuelto a $_cap"; }
  done
  rm -f "$WATCHPID"
}
watchd_start() {
  watchd_alive && return 0
  rm -f "$CONF/watchd.stop"
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _watchd </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _watchd </dev/null >/dev/null 2>&1 & fi
  _i=0; while [ "$_i" -lt 5 ]; do watchd_alive && return 0; sleep 1; _i=$((_i+1)); done; watchd_alive
}
watchd_stop() {
  : > "$CONF/watchd.stop"; _d=$(cat "$WATCHPID" 2>/dev/null); [ -n "$_d" ] && kill "$_d" 2>/dev/null
  _i=0; while [ "$_i" -lt 5 ] && watchd_alive; do sleep 1; _i=$((_i+1)); done
  rm -f "$WATCHPID" "$CONF/watchd.stop"
}
watch_status() {   # WATCH|encendido|vivo|inotifyd_disponible
  _in=0; [ -n "$(watch_inotifyd)" ] && _in=1
  echo "WATCH|$(cfg_get watch 1)|$(watchd_alive && echo 1 || echo 0)|$_in"
}
watch_set() {   # on|off
  case "$1" in
    on) cfg_set watch 1; if watchd_start; then return 0; else K_ERR="no pude iniciar el vigilante de topes"; return 1; fi ;;
    off) cfg_set watch 0; watchd_stop; return 0 ;;
    *) K_ERR="usa on o off"; return 1 ;;
  esac
}
