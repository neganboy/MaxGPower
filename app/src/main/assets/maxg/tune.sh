#!/system/bin/sh
# MaxG Power (F8 Pro) - Ajustes de red, almacenamiento y sistema. Cada grupo se enciende y se apaga solo y guarda el valor original.
#  net  : TCP más ágil (Fast Open, sin volver a empezar lento tras una pausa, BBR si el kernel lo tiene) -> mapas y páginas empiezan a cargar antes
#  io   : lectura anticipada de la memoria (read_ahead_kb 512) -> cargan más rápido los mapas y recursos grandes de los juegos
#  dns  : DNS privado rápido (opcional: cloudflare | google)
#  anim : animaciones del sistema a 0.5x (opcional)
#  scan : sin escaneos de Wi-Fi/Bluetooth cuando están apagados (opcional)
TUNEORIG=$CONF/tune.orig
NETD=$R/proc/sys/net/ipv4
tn_put() { grep -q "^$1|" "$TUNEORIG" 2>/dev/null || echo "$1|$2" >> "$TUNEORIG"; }
tn_get() { grep "^$1|" "$TUNEORIG" 2>/dev/null | head -n 1 | cut -d'|' -f2-; }
tn_del() { grep -v "^$1|" "$TUNEORIG" > "$TUNEORIG.t" 2>/dev/null; mv -f "$TUNEORIG.t" "$TUNEORIG" 2>/dev/null; }
tn_wr() {   # clave ruta valor: guarda el original y escribe solo si cambia
  [ -e "$2" ] || return 1
  tn_put "$1" "$(rd "$2")"; [ "$(rd "$2")" = "$3" ] && return 0
  [ -w "$2" ] || chmod u+w "$2" 2>/dev/null
  echo "$3" > "$2" 2>/dev/null; [ "$(rd "$2")" = "$3" ]
}
tn_rs() {   # clave ruta: devuelve el original
  _o=$(tn_get "$1"); [ -n "$_o" ] && [ -e "$2" ] && echo "$_o" > "$2" 2>/dev/null; tn_del "$1"
}
# ---- red ----
tn_net_on() {
  tn_wr net_fo "$NETD/tcp_fastopen" 3
  tn_wr net_ss "$NETD/tcp_slow_start_after_idle" 0
  if [ -r "$NETD/tcp_available_congestion_control" ] && grep -qw bbr "$NETD/tcp_available_congestion_control"; then tn_wr net_cc "$NETD/tcp_congestion_control" bbr; fi
}
tn_net_off() { tn_rs net_fo "$NETD/tcp_fastopen"; tn_rs net_ss "$NETD/tcp_slow_start_after_idle"; tn_rs net_cc "$NETD/tcp_congestion_control"; }
# ---- almacenamiento ----
tn_blocks() { for _b in "$R"/sys/block/*; do case "${_b##*/}" in sd*|dm-*|mmcblk*|nvme*) [ -e "$_b/queue/read_ahead_kb" ] && echo "${_b##*/}" ;; esac; done; }
tn_io_on() { for io_d in $(tn_blocks); do tn_wr "ra_$io_d" "$R/sys/block/$io_d/queue/read_ahead_kb" "${MG_RA:-512}"; done; }
tn_io_off() { for io_d in $(tn_blocks); do tn_rs "ra_$io_d" "$R/sys/block/$io_d/queue/read_ahead_kb"; done; }
# ---- ajustes de Android (settings global) ----
tn_st_put() {   # clave valor: guarda el original (null si no existía)
  _v=$(st_get "$1"); tn_put "st_$1" "${_v:-null}"; st_put "$1" "$2"
}
tn_st_rs() {
  _v=$(tn_get "st_$1"); [ -n "$_v" ] || return 0
  if [ "$_v" = null ]; then $TMO settings delete global "$1" >/dev/null 2>&1 </dev/null; else st_put "$1" "$_v"; fi
  tn_del "st_$1"
}
tn_dns_on() {
  case "$1" in cloudflare) _h=one.one.one.one ;; google) _h=dns.google ;; *) return 1 ;; esac
  tn_st_put private_dns_mode hostname; tn_st_put private_dns_specifier "$_h"
}
tn_dns_off() { tn_st_rs private_dns_mode; tn_st_rs private_dns_specifier; }
tn_anim_on() { for _k in window_animation_scale transition_animation_scale animator_duration_scale; do tn_st_put "$_k" 0.5; done; }
tn_anim_off() { for _k in window_animation_scale transition_animation_scale animator_duration_scale; do tn_st_rs "$_k"; done; }
tn_scan_on() {
  for _k in wifi_scan_always_enabled ble_scan_always_enabled; do
    _o=$(tn_get "st_$_k")   # versiones anteriores guardaban aquí el original: se traspasa al árbitro para que nada se pierda
    if [ -n "$_o" ]; then claim_orig_put "st:$_k" "$_o"; tn_del "st_$_k"; fi
    claim_put "st:$_k" tune 0
  done
}
tn_scan_off() {
  for _k in wifi_scan_always_enabled ble_scan_always_enabled; do
    _o=$(tn_get "st_$_k")
    if [ -n "$_o" ]; then claim_orig_put "st:$_k" "$_o"; tn_del "st_$_k"; claim_has "st:$_k" tune || claim_put "st:$_k" tune 0; fi
    claim_del "st:$_k" tune
  done
}

tune_apply_one() {   # grupo -> aplica o revierte según cfg
  case "$1" in
    net) [ "$(cfg_get tune_net 1)" = 1 ] && tn_net_on || tn_net_off ;;
    io) [ "$(cfg_get tune_io 1)" = 1 ] && tn_io_on || tn_io_off ;;
    dns) case "$(cfg_get tune_dns off)" in cloudflare|google) tn_dns_off; tn_dns_on "$(cfg_get tune_dns off)" ;; *) tn_dns_off ;; esac ;;
    anim) [ "$(cfg_get tune_anim 0)" = 1 ] && tn_anim_on || tn_anim_off ;;
    scan) [ "$(cfg_get tune_scan 0)" = 1 ] && tn_scan_on || tn_scan_off ;;
  esac
  return 0
}
tune_apply_all() { for _g in net io dns anim scan; do tune_apply_one "$_g"; done; log "ajustes de red y sistema aplicados"; }
tune_revert_all() { tn_net_off; tn_io_off; tn_dns_off; tn_anim_off; tn_scan_off; rm -f "$TUNEORIG"; }
tune_set() {   # grupo valor
  K_ERR=""
  case "$1" in
    net|io|anim|scan) case "$2" in 0|1) cfg_set "tune_$1" "$2" ;; *) K_ERR="usa 0 o 1"; return 1 ;; esac ;;
    dns) case "$2" in off|cloudflare|google) cfg_set tune_dns "$2" ;; *) K_ERR="DNS: off, cloudflare o google"; return 1 ;; esac ;;
    *) K_ERR="ajuste desconocido"; return 1 ;;
  esac
  _w=$(is_target) || { K_ERR=$_w; return 1; }
  tune_apply_one "$1"; log "ajuste $1=$2"; return 0
}
tune_status() {   # TUNE|red|io|dns|anim|scan|congestion|bbr_disponible|readahead|dns_actual
  _cc=$(rd "$NETD/tcp_congestion_control"); _bb=0; [ -r "$NETD/tcp_available_congestion_control" ] && grep -qw bbr "$NETD/tcp_available_congestion_control" && _bb=1
  _ra=""; for _d in $(tn_blocks | head -n 1); do _ra=$(rd "$R/sys/block/$_d/queue/read_ahead_kb"); done
  echo "TUNE|$(cfg_get tune_net 1)|$(cfg_get tune_io 1)|$(cfg_get tune_dns off)|$(cfg_get tune_anim 0)|$(cfg_get tune_scan 0)|$_cc|$_bb|$_ra"
}
