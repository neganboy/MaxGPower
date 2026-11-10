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
# Mejor algoritmo disponible, en orden de preferencia; fastopen, sin volver a
# empezar lento tras una pausa, sack y baja latencia (con guardas).
tn_net_on() {
  tn_wr net_fo "$NETD/tcp_fastopen" 3
  tn_wr net_ss "$NETD/tcp_slow_start_after_idle" 0
  tn_wr net_sack "$NETD/tcp_sack" 1
  tn_wr net_ll "$NETD/tcp_low_latency" 1
}
tn_net_off() { tn_rs net_fo "$NETD/tcp_fastopen"; tn_rs net_ss "$NETD/tcp_slow_start_after_idle"; tn_rs net_sack "$NETD/tcp_sack"; tn_rs net_ll "$NETD/tcp_low_latency"; }
# Algoritmo de congestión TCP (el interruptor "BBR" de la app): el mejor disponible, en orden de preferencia.
tn_cc_on() {
  for _a in bbr3 bbr2 bbrplus bbr westwood cubic; do
    if [ -r "$NETD/tcp_available_congestion_control" ] && grep -qw "$_a" "$NETD/tcp_available_congestion_control" 2>/dev/null; then
      tn_wr net_cc "$NETD/tcp_congestion_control" "$_a"
      break
    fi
  done
}
tn_cc_off() { tn_rs net_cc "$NETD/tcp_congestion_control"; }
# ---- almacenamiento ----
tn_blocks() { for _b in "$R"/sys/block/*; do case "${_b##*/}" in sd*|dm-*|mmcblk*|nvme*) [ -e "$_b/queue/read_ahead_kb" ] && echo "${_b##*/}" ;; esac; done; }
tn_io_on() {   # lectura anticipada y peticiones según el perfil efectivo (512 si no hay perfil)
  _p=$(eff_profile); _ra=512; _nr=64
  if prof_def "$_p" 2>/dev/null; then _ra=$PD_ra; _nr=$PD_nr; fi
  for io_d in $(tn_blocks); do
    tn_wr "ra_$io_d" "$R/sys/block/$io_d/queue/read_ahead_kb" "$_ra"
    tn_wr "nr_$io_d" "$R/sys/block/$io_d/queue/nr_requests" "$_nr"
  done
}
tn_io_off() { for io_d in $(tn_blocks); do tn_rs "ra_$io_d" "$R/sys/block/$io_d/queue/read_ahead_kb"; tn_rs "nr_$io_d" "$R/sys/block/$io_d/queue/nr_requests"; done; }
# I/O y memoria por perfil: se aplica al cambiar de perfil y se revierte con "Original".
io_profile_apply() {   # ra nr vfs
  [ "$(cfg_get tune_io 1)" = 1 ] || return 0   # con el ajuste de I/O apagado no se toca la lectura anticipada
  for _d in $(tn_blocks); do
    tn_wr "ra_$_d" "$R/sys/block/$_d/queue/read_ahead_kb" "$1"
    tn_wr "nr_$_d" "$R/sys/block/$_d/queue/nr_requests" "$2"
  done
  set_knob vm_vfs "$3" >/dev/null 2>&1
  return 0
}
io_profile_revert() {
  for _d in $(tn_blocks); do
    tn_rs "ra_$_d" "$R/sys/block/$_d/queue/read_ahead_kb"
    tn_rs "nr_$_d" "$R/sys/block/$_d/queue/nr_requests"
  done
  knob_orig_v vm_vfs; _o=$KO; knob_path_v vm_vfs; [ -n "$_o" ] && [ -n "$KP" ] && echo "$_o" > "$KP" 2>/dev/null; des_del vm_vfs
  return 0
}
# ---- scheduler y colas de I/O (una vez por arranque; se revierte con "Original") ----
sched_apply() {
  tn_wr sch_stats "$R/proc/sys/kernel/sched_schedstats" 0
  tn_wr sch_ag "$R/proc/sys/kernel/sched_autogroup_enabled" 0
  tn_wr sch_crf "$R/proc/sys/kernel/sched_child_runs_first" 1
  tn_wr sch_nrm "$R/proc/sys/kernel/sched_nr_migrate" 32
  tn_wr sch_mig "$R/proc/sys/kernel/sched_migration_cost_ns" 50000
  tn_wr sch_ming "$R/proc/sys/kernel/sched_min_granularity_ns" 1000000
  tn_wr sch_wake "$R/proc/sys/kernel/sched_wakeup_granularity_ns" 1500000
  for _d in $(tn_blocks); do
    tn_wr "sch_io_$_d" "$R/sys/block/$_d/queue/iostats" 0
    tn_wr "sch_ar_$_d" "$R/sys/block/$_d/queue/add_random" 0
  done
  return 0
}
sched_revert() {
  tn_rs sch_stats "$R/proc/sys/kernel/sched_schedstats"
  tn_rs sch_ag "$R/proc/sys/kernel/sched_autogroup_enabled"
  tn_rs sch_crf "$R/proc/sys/kernel/sched_child_runs_first"
  tn_rs sch_nrm "$R/proc/sys/kernel/sched_nr_migrate"
  tn_rs sch_mig "$R/proc/sys/kernel/sched_migration_cost_ns"
  tn_rs sch_ming "$R/proc/sys/kernel/sched_min_granularity_ns"
  tn_rs sch_wake "$R/proc/sys/kernel/sched_wakeup_granularity_ns"
  for _d in $(tn_blocks); do
    tn_rs "sch_io_$_d" "$R/sys/block/$_d/queue/iostats"
    tn_rs "sch_ar_$_d" "$R/sys/block/$_d/queue/add_random"
  done
  return 0
}
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
    cc) [ "$(cfg_get tune_cc 1)" = 1 ] && tn_cc_on || tn_cc_off ;;
    io) [ "$(cfg_get tune_io 1)" = 1 ] && tn_io_on || tn_io_off ;;
    dns) case "$(cfg_get tune_dns off)" in cloudflare|google) tn_dns_off; tn_dns_on "$(cfg_get tune_dns off)" ;; *) tn_dns_off ;; esac ;;
    anim) [ "$(cfg_get tune_anim 0)" = 1 ] && tn_anim_on || tn_anim_off ;;
    scan) [ "$(cfg_get tune_scan 0)" = 1 ] && tn_scan_on || tn_scan_off ;;
  esac
  return 0
}
tune_apply_all() { for _g in net cc io dns anim scan; do tune_apply_one "$_g"; done; log "ajustes de red y sistema aplicados"; }
tune_revert_all() { tn_net_off; tn_cc_off; tn_io_off; tn_dns_off; tn_anim_off; tn_scan_off; rm -f "$TUNEORIG"; }
tune_set() {   # grupo valor
  K_ERR=""
  case "$1" in
    net|cc|io|anim|scan) case "$2" in 0|1) cfg_set "tune_$1" "$2" ;; *) K_ERR="usa 0 o 1"; return 1 ;; esac ;;
    dns) case "$2" in off|cloudflare|google) cfg_set tune_dns "$2" ;; *) K_ERR="DNS: off, cloudflare o google"; return 1 ;; esac ;;
    *) K_ERR="ajuste desconocido"; return 1 ;;
  esac
  _w=$(is_target) || { K_ERR=$_w; return 1; }
  tune_apply_one "$1"; log "ajuste $1=$2"; return 0
}
tune_status() {   # TUNE|red|io|dns|anim|scan|congestion|bbr_disponible|readahead|sack|baja_latencia|cc_encendido
  _cc=$(rd "$NETD/tcp_congestion_control"); _bb=0; [ -r "$NETD/tcp_available_congestion_control" ] && grep -qw bbr "$NETD/tcp_available_congestion_control" && _bb=1
  _ra=""; for _d in $(tn_blocks | head -n 1); do _ra=$(rd "$R/sys/block/$_d/queue/read_ahead_kb"); done
  _sk=$(rd "$NETD/tcp_sack"); _ll=$(rd "$NETD/tcp_low_latency")
  echo "TUNE|$(cfg_get tune_net 1)|$(cfg_get tune_io 1)|$(cfg_get tune_dns off)|$(cfg_get tune_anim 0)|$(cfg_get tune_scan 0)|$_cc|$_bb|$_ra|$_sk|$_ll|$(cfg_get tune_cc 1)"
}
