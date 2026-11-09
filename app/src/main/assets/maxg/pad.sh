#!/system/bin/sh
# MaxG Power - Modo mando (Bluetooth o USB). Opcional: se activa con un interruptor y todo se revierte al desconectar.
PADORIG=$CONF/pad.orig; PADSTATE=$CONF/pad.state; PADPID=$CONF/padd.pid; QOSPID=$CONF/pad.qos.pid; PADTESTS=$CONF/pad_tests
QOSDEV=${MG_QOSDEV:-/dev/cpu_dma_latency}
IBD=$R/proc/sys/walt/input_boost
JSPOLL=$R/sys/module/usbhid/parameters/jspoll
PADRE='gamesir|xbox|gamepad|controller|dualsense|dualshock|8bitdo|joy-con|kishi|backbone|x4a|stadia|razer'
pad_qos_us() { case "${MG_QOSUS:-$(cfg_get pad_qos 150)}" in 60|100|150|300) echo "${MG_QOSUS:-$(cfg_get pad_qos 150)}" ;; *) echo 150 ;; esac; }   # latencia máxima de salida de reposo que se exige mientras juegas (µs)
PAD_IB0=1152000; PAD_IB6=1209600; PAD_IBMS=200; PAD_RT=4

# ---- detección de mandos ----
# Un dispositivo cuenta como mando si (1) su nombre lo dice, (2) el fabricante es de mandos conocidos o (3) trae botones de gamepad (BTN_SOUTH..BTN_THUMBR).
PADVID='3537 045e 054c 057e 2dc8 0e6f 1532 20d6 0f0d 1bad 046d 2563 0079'
pad_gp_v() {   # mapa KEY del kernel (palabras hex de 64 bits, la más alta primero) -> PGB = 1 si la palabra 4 (teclas 0x100-0x13f) trae 0x130-0x13f
  PGB=0; set -- $1; gb_n=$#; [ "$gb_n" -ge 5 ] || return 0
  shift $((gb_n-5)); gb_w=$1
  while [ "${#gb_w}" -lt 16 ]; do gb_w=0$gb_w; done
  case "${gb_w%????????????}" in 0000) PGB=0 ;; *) PGB=1 ;; esac
  return 0
}
pad_gp_bits() { pad_gp_v "$1"; echo "$PGB"; }
pad_scan_emit() {
  [ -n "$ps_nm" ] && [ -n "$ps_ev" ] || return 0
  ps_rec=0; ps_why=""
  case "$ps_bus" in 0005) ps_tr=bluetooth ;; 0003) ps_tr=usb ;; 0019) ps_tr=interno ;; *) ps_tr=$ps_bus ;; esac
  # el nombre se compara sin distinguir mayúsculas y sin procesos externos (PADRE: gamesir xbox gamepad controller dualsense dualshock 8bitdo joy-con kishi backbone x4a stadia razer)
  case "$ps_nm" in
    *[Cc][Oo][Nn][Ss][Uu][Mm][Ee][Rr]*) ps_why="control multimedia" ;;
    *[Gg][Aa][Mm][Ee][Ss][Ii][Rr]*|*[Xx][Bb][Oo][Xx]*|*[Gg][Aa][Mm][Ee][Pp][Aa][Dd]*|*[Cc][Oo][Nn][Tt][Rr][Oo][Ll][Ll][Ee][Rr]*|*[Dd][Uu][Aa][Ll][Ss][Ee][Nn][Ss][Ee]*|*[Dd][Uu][Aa][Ll][Ss][Hh][Oo][Cc][Kk]*|*8[Bb][Ii][Tt][Dd][Oo]*|*[Jj][Oo][Yy]-[Cc][Oo][Nn]*|*[Kk][Ii][Ss][Hh][Ii]*|*[Bb][Aa][Cc][Kk][Bb][Oo][Nn][Ee]*|*[Xx]4[Aa]*|*[Ss][Tt][Aa][Dd][Ii][Aa]*|*[Rr][Aa][Zz][Ee][Rr]*) ps_rec=1; ps_why="nombre" ;;
    *)
      if [ "$ps_tr" = bluetooth ] || [ "$ps_tr" = usb ]; then   # por botones o por fabricante solo si llega por Bluetooth o USB
        if [ "$ps_gp" = 1 ]; then ps_rec=1; ps_why="botones de gamepad"
        else case " $PADVID " in *" $ps_vid "*) ps_rec=1; ps_why="fabricante $ps_vid" ;; esac; fi
      fi ;;
  esac
  echo "$ps_nm|$ps_tr|$ps_ev|$ps_vid|$ps_rec|$ps_why"
}
pad_scan() {   # una línea por dispositivo de entrada: nombre|conexión|evento|fabricante|reconocido|motivo
  [ -r "$R/proc/bus/input/devices" ] || return 1
  ps_nm=""; ps_bus=""; ps_vid=""; ps_ev=""; ps_gp=0
  while IFS= read -r ps_l; do
    case "$ps_l" in
      I:*) ps_bus=${ps_l#*Bus=}; ps_bus=${ps_bus%% *}; ps_vid=${ps_l#*Vendor=}; ps_vid=${ps_vid%% *} ;;
      N:*) ps_nm=${ps_l#*Name=\"}; ps_nm=${ps_nm%\"*} ;;
      H:*) ps_ev=${ps_l#*Handlers=}; case "$ps_ev" in *event*) ps_ev=${ps_ev#*event}; ps_ev=event${ps_ev%% *} ;; *) ps_ev="" ;; esac ;;
      "B: KEY="*) pad_gp_v "${ps_l#*KEY=}"; ps_gp=$PGB ;;
      "") pad_scan_emit; ps_nm=""; ps_bus=""; ps_vid=""; ps_ev=""; ps_gp=0 ;;
    esac
  done < "$R/proc/bus/input/devices" 2>/dev/null
  pad_scan_emit
  return 0
}
pad_sig() {   # PADSIG = lista de nodos de entrada (cambia al conectar o quitar un dispositivo, sin crear procesos); sin nodos eventN (pruebas) usa una suma del archivo
  PADSIG=""
  for pg_f in "$R"/dev/input/event*; do [ -e "$pg_f" ] && PADSIG="$PADSIG ${pg_f##*/}"; done
  if [ -z "$PADSIG" ]; then PADSIG=$(cksum < "$R/proc/bus/input/devices" 2>/dev/null); fi
  return 0
}
pad_info() {   # imprime "nombre|conexión|eventN" del primer mando conectado (Bluetooth antes que USB)
  pi_all=$(pad_scan); pi_usb=""
  while IFS='|' read -r pi_n pi_t pi_e pi_v pi_r pi_w; do
    [ "$pi_r" = 1 ] || continue
    if [ "$pi_t" = bluetooth ]; then echo "$pi_n|$pi_t|$pi_e"; return 0; fi
    [ -n "$pi_usb" ] || pi_usb="$pi_n|$pi_t|$pi_e"
  done <<EOF
$pi_all
EOF
  [ -n "$pi_usb" ] && { echo "$pi_usb"; return 0; }
  return 1
}
po_put() { grep -q "^$1|" "$PADORIG" 2>/dev/null || echo "$1|$2" >> "$PADORIG"; }
po_get() { grep "^$1|" "$PADORIG" 2>/dev/null | head -n 1 | cut -d'|' -f2-; }
TMO=""; command -v timeout >/dev/null 2>&1 && TMO="timeout 6"
st_get() { $TMO settings get global "$1" 2>/dev/null </dev/null; }
st_put() { $TMO settings put global "$1" "$2" >/dev/null 2>&1 </dev/null; }

# nombres de los nodos de input boost: input_boost_* (F8 Pro) o input_touch_boost_* (F8 Ultra)
IBF=$IBD/input_boost_freq; IBM=$IBD/input_boost_ms
[ -e "$IBF" ] || { [ -e "$IBD/input_touch_boost_freq" ] && { IBF=$IBD/input_touch_boost_freq; IBM=$IBD/input_touch_boost_ms; }; }
pad_ib_on() {
  [ -e "$IBF" ] || return 0
  _cur=$(rd "$IBF"); [ -n "$_cur" ] || return 0
  po_put ib_freq "$_cur"
  set -- $_cur; _i=0; _out=""
  for _t in "$@"; do
    case $_i in 0) [ "$_t" -lt "$PAD_IB0" ] && _t=$PAD_IB0 ;; 6) [ "$_t" -lt "$PAD_IB6" ] && _t=$PAD_IB6 ;; esac
    _out="$_out $_t"; _i=$((_i+1))
  done
  echo "${_out# }" > "$IBF" 2>/dev/null
  _ms=$(rd "$IBM")
  if isnum "$_ms"; then po_put ib_ms "$_ms"; [ "$_ms" -lt "$PAD_IBMS" ] && echo "$PAD_IBMS" > "$IBM" 2>/dev/null; fi
}
pad_ib_off() {
  _v=$(po_get ib_freq); [ -n "$_v" ] && echo "$_v" > "$IBF" 2>/dev/null
  _v=$(po_get ib_ms); [ -n "$_v" ] && echo "$_v" > "$IBM" 2>/dev/null
}
pad_qos_alive() { _q=$(cat "$QOSPID" 2>/dev/null); [ -n "$_q" ] && kill -0 "$_q" 2>/dev/null; }
pad_qos_on() {   # PM QoS: mientras este archivo está abierto, el kernel no deja a los núcleos entrar en reposos con salida lenta
  pad_qos_alive && return 0
  [ -e "$QOSDEV" ] || return 1
  _b=$(printf '\\%03o\\000\\000\\000' "$(pad_qos_us)")
  sh -c 'exec 3>"$0"; printf "$1" >&3; exec sleep 2147483647' "$QOSDEV" "$_b" </dev/null >/dev/null 2>&1 &
  echo $! > "$QOSPID"; sleep 0.2 2>/dev/null || sleep 1
  pad_qos_alive
}
pad_qos_off() { _q=$(cat "$QOSPID" 2>/dev/null); [ -n "$_q" ] && kill "$_q" 2>/dev/null; rm -f "$QOSPID"; }
pad_thr_on() {   # prioridad de tiempo real baja para los hilos que leen y reparten la entrada
  _pid=$(pidof system_server 2>/dev/null | cut -d' ' -f1); [ -n "$_pid" ] || return 0
  command -v chrt >/dev/null 2>&1 || return 0
  for _t in "$R/proc/$_pid"/task/*; do
    _c=$(rd "$_t/comm"); case "$_c" in InputReader|InputDispatcher) ;; *) continue ;; esac
    _tid=${_t##*/}; _o=$(chrt -p "$_tid" 2>/dev/null </dev/null)
    _pol=$(printf '%s\n' "$_o" | sed -n 's/.*policy: *//p' | head -n 1); _pr=$(printf '%s\n' "$_o" | sed -n 's/.*priority: *//p' | tail -n 1)
    [ -n "$_pol" ] || continue
    po_put "thr_$_tid" "$_c $_pol ${_pr:-0}"
    chrt -f -p "$PAD_RT" "$_tid" >/dev/null 2>&1 </dev/null
  done
}
pad_thr_off() {
  [ -f "$PADORIG" ] || return 0
  _pid=$(pidof system_server 2>/dev/null | cut -d' ' -f1)
  grep '^thr_' "$PADORIG" | while IFS='|' read -r _k _v; do
    _tid=${_k#thr_}; set -- $_v; _c=$1; _pol=$2; _pr=$3
    [ -n "$_pid" ] && [ "$(rd "$R/proc/$_pid/task/$_tid/comm")" = "$_c" ] || continue
    case "$_pol" in *FIFO*) chrt -f -p "${_pr:-1}" "$_tid" ;; *RR*) chrt -r -p "${_pr:-1}" "$_tid" ;; *) chrt -o -p 0 "$_tid" ;; esac >/dev/null 2>&1 </dev/null
  done
}
pad_radio_on() {   # menos escaneos de radio: cada escaneo de Wi-Fi o BLE comparte la antena de 2.4 GHz con el mando (lo reclama por el árbitro: no choca con "sin escaneos" de Red y carga)
  for _k in wifi_scan_always_enabled ble_scan_always_enabled; do claim_put "st:$_k" pad 0; done
}
pad_radio_off() {
  for _k in wifi_scan_always_enabled ble_scan_always_enabled; do claim_del "st:$_k" pad; done
}
pad_usb_on() { [ -e "$JSPOLL" ] && { po_put jspoll "$(rd $JSPOLL)"; echo 1 > "$JSPOLL" 2>/dev/null; }; }
pad_usb_off() { _v=$(po_get jspoll); [ -n "$_v" ] && echo "$_v" > "$JSPOLL" 2>/dev/null; }

# ---- extras de latencia ----
sy_get() { $TMO settings get system "$1" 2>/dev/null </dev/null; }
sy_put() { $TMO settings put system "$1" "$2" >/dev/null 2>&1 </dev/null; }
# ---- tope de pantalla (Hz) de los perfiles de ahorro ----
HZORIG=$CONF/hz.orig; HZCUR=$CONF/hz.cur
hz_modes() {   # tasas que anuncia la pantalla, ascendentes ("60 90 120"); se calcula una vez
  hm_l=$(cfg_get hzmodes ""); [ -n "$hm_l" ] && { echo "$hm_l"; return 0; }
  hm_l=$(dumpsys display 2>/dev/null </dev/null | grep -o 'fps=[0-9]*' | cut -d= -f2 | sort -nu | tr '\n' ' '); hm_l=${hm_l% }
  [ -n "$hm_l" ] && cfg_set hzmodes "$hm_l"; echo "$hm_l"
}
hz_pick() {   # objetivo -> la mayor tasa de la pantalla <= objetivo (si todas son mayores, la menor)
  hp_r=""; hp_lo=""
  for hp_m in $(hz_modes); do isnum "$hp_m" || continue; [ -n "$hp_lo" ] || hp_lo=$hp_m; [ "$hp_m" -le "$1" ] && hp_r=$hp_m; done
  echo "${hp_r:-$hp_lo}"
}
hz_apply() {   # tope de Hz del perfil (0 = el perfil no toca la pantalla)
  case "$1" in ''|0) hz_restore; return 0 ;; esac
  [ -e "$PADSTATE" ] && [ "$(cfg_get pad_hz 1)" = 1 ] && return 0   # jugando con mando la pantalla va al máximo; al soltarlo se reaplica
  ha_t=$(hz_pick "$1"); isnum "$ha_t" || return 0
  ha_c=""; [ -r "$HZCUR" ] && read -r ha_c < "$HZCUR"
  [ "$ha_c" = "$ha_t" ] && return 0
  if [ ! -f "$HZORIG" ]; then { for ha_k in min_refresh_rate peak_refresh_rate; do ha_v=$(sy_get $ha_k); echo "$ha_k|${ha_v:-null}"; done; } > "$HZORIG"; fi
  sy_put peak_refresh_rate "$ha_t.0"
  ha_m=$(sy_get min_refresh_rate); ha_m=${ha_m%%.*}
  isnum "$ha_m" && [ "$ha_m" -gt "$ha_t" ] && sy_put min_refresh_rate "$ha_t.0"
  echo "$ha_t" > "$HZCUR"; log "pantalla: tope de $ha_t Hz"
}
hz_restore() {
  [ -f "$HZORIG" ] || { rm -f "$HZCUR"; return 0; }
  [ -e "$PADSTATE" ] && [ "$(cfg_get pad_hz 1)" = 1 ] && return 0
  while IFS='|' read -r hr_k hr_v; do
    [ -n "$hr_k" ] || continue
    if [ "$hr_v" = null ]; then $TMO settings delete system "$hr_k" >/dev/null 2>&1 </dev/null; else sy_put "$hr_k" "$hr_v"; fi
  done < "$HZORIG"
  rm -f "$HZORIG" "$HZCUR"; log "pantalla: tasa devuelta a como estaba"
}
hz_reapply() { hz_rp=$(eff_profile); if [ "$hz_rp" != stock ] && prof_def "$hz_rp"; then hz_apply "$PD_hz"; else hz_restore; fi; }
pad_maxhz() {   # tasa de refresco máxima que anuncia la pantalla (vacío si no se pudo saber); se calcula una vez
  _mh=$(cfg_get maxhz ""); isnum "$_mh" && { echo "$_mh"; return 0; }
  _mh=$(dumpsys display 2>/dev/null </dev/null | grep -o 'fps=[0-9]*' | cut -d= -f2 | sort -n | tail -n 1)
  isnum "$_mh" && cfg_set maxhz "$_mh"; echo "$_mh"
}
pad_hz_on() {   # pantalla a la tasa máxima mientras juegas: el cuadro se muestra antes y la entrada se ve antes
  [ "$(cfg_get pad_hz 1)" = 1 ] || return 0
  _hz=$(pad_maxhz); isnum "$_hz" && [ "$_hz" -ge 60 ] || return 0
  for _k in min_refresh_rate peak_refresh_rate; do _v=$(sy_get $_k); po_put "hz_$_k" "${_v:-null}"; sy_put $_k "$_hz.0"; done
}
pad_hz_off() {
  for _k in min_refresh_rate peak_refresh_rate; do
    _v=$(po_get "hz_$_k"); [ -n "$_v" ] || continue
    if [ "$_v" = null ]; then $TMO settings delete system $_k >/dev/null 2>&1 </dev/null; else sy_put $_k "$_v"; fi
  done
}
pad_wifi_on() {   # Wi-Fi sin ahorro de energía y en baja latencia: menos saltos de ping mientras juegas en línea
  [ "$(cfg_get pad_wifi 1)" = 1 ] || return 0
  cmd wifi force-hi-perf-mode enabled >/dev/null 2>&1 </dev/null; cmd wifi force-low-latency-mode enabled >/dev/null 2>&1 </dev/null; po_put wifi 1
}
pad_wifi_off() { [ "$(po_get wifi)" = 1 ] || return 0; cmd wifi force-hi-perf-mode disabled >/dev/null 2>&1 </dev/null; cmd wifi force-low-latency-mode disabled >/dev/null 2>&1 </dev/null; }
pad_usbpm_on() {   # mandos por USB: sin autosuspensión (un mando quieto 2 s se dormía y el primer movimiento llegaba tarde)
  for _d in "$R"/sys/bus/usb/devices/*; do
    [ -r "$_d/idVendor" ] || continue; _vid=$(rd "$_d/idVendor")
    case " $PADVID " in *" $_vid "*) ;; *) continue ;; esac
    [ -e "$_d/power/control" ] || continue
    po_put "usbpm_${_d##*/}" "$(rd "$_d/power/control")"; echo on > "$_d/power/control" 2>/dev/null
  done
}
pad_usbpm_off() {
  [ -f "$PADORIG" ] || return 0
  grep '^usbpm_' "$PADORIG" | while IFS='|' read -r _k _v; do _d="$R/sys/bus/usb/devices/${_k#usbpm_}"; [ -e "$_d/power/control" ] && [ -n "$_v" ] && echo "$_v" > "$_d/power/control" 2>/dev/null; done
}
pad_qos_set() {   # µs: 60 estricto, 100, 150 normal, 300 suave
  case "$1" in 60|100|150|300) ;; *) K_ERR="el reposo debe ser 60, 100, 150 o 300 µs"; return 1 ;; esac
  cfg_set pad_qos "$1"
  if pad_qos_alive; then pad_qos_off; pad_qos_on; fi
  return 0
}
pad_opt_set() {   # hz|wifi 0|1
  K_ERR=""; case "$2" in 0|1) ;; *) K_ERR="usa 0 o 1"; return 1 ;; esac
  case "$1" in hz) cfg_set pad_hz "$2"; [ -f "$PADSTATE" ] && { pad_hz_off; [ "$2" = 1 ] && pad_hz_on; } ;;
               wifi) cfg_set pad_wifi "$2"; [ -f "$PADSTATE" ] && { pad_wifi_off; [ "$2" = 1 ] && pad_wifi_on; } ;;
               *) K_ERR="opción desconocida"; return 1 ;; esac
  return 0
}

pad_enter() {   # $1 = "nombre|bus|evento"
  : > "$PADORIG"; echo "$1|qos=0" > "$PADSTATE"; log "modo mando: mando detectado ($1), activando"
  pad_ib_on; pad_thr_on; pad_radio_on; pad_usb_on; pad_bt_on; pad_hz_on; pad_wifi_on
  case "$1" in *"|usb|"*) pad_usbpm_on ;; esac
  pad_qos_on && _q=1 || _q=0
  echo "$1|qos=$_q" > "$PADSTATE"; log "modo mando: activo con $1 (qos=$_q)"
}
pad_leave() {
  [ -f "$PADSTATE" ] || [ -f "$PADORIG" ] || return 0
  pad_qos_off; pad_thr_off; pad_ib_off; pad_radio_off; pad_usb_off; pad_bt_off; pad_hz_off; pad_wifi_off; pad_usbpm_off
  rm -f "$PADORIG" "$PADSTATE"; log "modo mando: revertido"; hz_reapply
}
padd_run() {
  echo $$ > "$PADPID"; rm -f "$CONF/padd.stop"; log "modo mando: vigilante iniciado"
  _in=0; _hot=0; pd_sg="x"; pd_k=0; pd_p=""; pd_t=0
  trap 'pad_leave; rm -f "$PADPID"; exit 0' TERM INT
  while [ ! -e "$CONF/padd.stop" ]; do
    # la lista de dispositivos solo se lee cuando cambia la firma de /dev/input (o cada ~30 s por si acaso): antes se leía cada segundo
    pad_sig; pd_k=$((pd_k+1))
    if [ "$PADSIG" != "$pd_sg" ] || [ "$pd_k" -ge "${MG_PADFULL:-60}" ]; then pd_sg=$PADSIG; pd_k=0; pd_p=$(pad_info); [ -n "${MG_PADDBG:-}" ] && echo x >> "$CONF/pad.scans"; fi
    if [ -n "$pd_p" ]; then
      [ "$_in" = 0 ] && { pad_enter "$pd_p"; _in=1; _hot=0; pd_t=0; _tr=${pd_p#*\|}; _tr=${_tr%%\|*}; pad_sess_start "$_tr"; }
      # seguridad térmica: si el chip pasa de 56 °C se suelta el bloqueo de reposo hasta que baje de 50 °C (se mide cada 2 vueltas)
      pd_t=$((pd_t+1))
      if [ $((pd_t % 2)) -eq 1 ]; then
        cpu_temp10_v; _ct=$CT10
        if [ "$_hot" = 0 ] && [ "$_ct" -ge 560 ]; then pad_qos_off; _hot=1; log "modo mando: calor, se suelta el bloqueo de reposo"
        elif [ "$_hot" = 1 ] && [ "$_ct" -lt 500 ]; then pad_qos_on; _hot=0; fi
      fi
    else
      [ "$_in" = 1 ] && { pad_leave; _in=0; pad_sess_end; }
    fi
    if [ "$_in" = 1 ]; then sleep "${MG_PADTICK:-3}" & wait $!; else sleep "${MG_PADTICK:-2}" & wait $!; fi
  done
  [ "$_in" = 1 ] && pad_leave
  rm -f "$PADPID" "$CONF/padd.stop"
}
padd_alive() { _d=""; [ -r "$PADPID" ] && read -r _d < "$PADPID"; [ -n "$_d" ] && kill -0 "$_d" 2>/dev/null; }
padd_start() {
  padd_alive && return 0
  rm -f "$CONF/padd.stop"
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _padd </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _padd </dev/null >/dev/null 2>&1 & fi
  _i=0; while [ "$_i" -lt 5 ]; do padd_alive && return 0; sleep 1; _i=$((_i+1)); done; padd_alive
}
padd_stop() {
  : > "$CONF/padd.stop"; _d=$(cat "$PADPID" 2>/dev/null); [ -n "$_d" ] && kill "$_d" 2>/dev/null
  _i=0; while [ "$_i" -lt 5 ] && padd_alive; do sleep 1; _i=$((_i+1)); done
  rm -f "$PADPID" "$CONF/padd.stop"; pad_leave
}

# ---- medidor: frecuencia real de reportes y saltos del mando ----
pad_test() {   # segundos
  _s=${1:-5}; isnum "$_s" || _s=5; [ "$_s" -lt 3 ] && _s=3; [ "$_s" -gt 15 ] && _s=15
  _pi=$(pad_info) || { echo "PAD|err|No hay ningún mando conectado"; return 1; }
  _ev=${_pi##*\|}; _rest=${_pi%\|*}; _nm=${_rest%\|*}; _tr=${_rest#*\|}   # la barra va escapada: en mksh (el sh de Android) una | sin escapar en un patrón significa "o"
  command -v getevent >/dev/null 2>&1 || { echo "PAD|err|Este sistema no trae getevent"; return 1; }
  getevent -t "$R/dev/input/$_ev" > "$CONF/pt.txt" 2>/dev/null </dev/null & _g=$!
  sleep "$_s"; kill "$_g" 2>/dev/null; wait "$_g" 2>/dev/null
  _prev=0; _ps=0; _pu=0; _first=0; _n=0; _sum=0; _mx=0; _g16=0; _g33=0; _fr=0
  while IFS= read -r _l; do
    case "$_l" in *"0000 0000 00000000"*) ;; *) continue ;; esac
    _ts=${_l#*\[}; _ts=${_ts%%\]*}; set -- $_ts; _ts=$1
    _sec=${_ts%.*}; _us=${_ts#*.}
    while [ "${_us#0}" != "$_us" ]; do _us=${_us#0}; done; _us=${_us:-0}
    _fr=$((_fr+1))   # los tiempos van en segundos desde el arranque: se restan por separado para no pasar de 32 bits
    if [ "$_prev" = 1 ]; then
      _gap=$(( (_sec - _ps) * 1000000 + _us - _pu )); _n=$((_n+1)); _sum=$((_sum+_gap)); [ "$_gap" -gt "$_mx" ] && _mx=$_gap
      [ "$_gap" -gt 16000 ] && _g16=$((_g16+1)); [ "$_gap" -gt 33000 ] && _g33=$((_g33+1))
    fi
    _prev=1; _ps=$_sec; _pu=$_us
  done < "$CONF/pt.txt"
  rm -f "$CONF/pt.txt"
  if [ "$_n" -lt 20 ]; then echo "PAD|err|Muy pocos datos ($_fr reportes). Mueve los sticks sin parar durante la prueba"; return 1; fi
  _avg=$((_sum / _n)); _hz=$((1000000 / _avg)); _pc=$((_g16 * 100 / _n))
  _mode=0; [ -f "$PADSTATE" ] && _mode=1
  echo "$(date +%s)|$_mode|$_tr|$_hz|$_avg|$_mx|$_pc|$_nm" >> "$PADTESTS"
  { tail -n 8 "$PADTESTS" > "$PADTESTS.t"; mv -f "$PADTESTS.t" "$PADTESTS"; } 2>/dev/null
  echo "PAD|ok|$_hz|$_avg|$_mx|$_pc|$_fr|$_mode|$_tr|$_nm"
}
pad_status() {   # PADCFG|activado|vigilante|dentro|qos|existe_qos|nombre|conexión|evento
  [ "$(cfg_get pad 0)" = 1 ] && ! padd_alive && { log "modo mando: el vigilante estaba detenido, se reinicia"; padd_start; }
  _pi=$(pad_info)
  echo "PADCFG|$(cfg_get pad 0)|$(padd_alive && echo 1 || echo 0)|$([ -f "$PADSTATE" ] && echo 1 || echo 0)|$(sed -n 's/.*qos=\(.\).*/\1/p' "$PADSTATE" 2>/dev/null)|$([ -e "$QOSDEV" ] && echo 1 || echo 0)|${_pi:-||}"
  [ -f "$PADTESTS" ] && sed 's/^/PADTEST|/' "$PADTESTS"
  echo "PADOPT|$(cfg_get pad_hz 1)|$(cfg_get pad_wifi 1)|$(pad_qos_us)|$(pad_maxhz)"
  pad_scan | sed 's/^/PADSCAN|/'
  return 0
}

# ---- informe del mando: se guarda en /sdcard para poder revisarlo (las direcciones Bluetooth se enmascaran) ----
pad_dump() {
  _o=${MG_PADDUMP:-/sdcard/MaxG_power_mando.txt}
  {
    echo "MaxG Power · informe del mando · $(date '+%F %T')"
    echo; echo "## Detección (nombre|conexión|evento|fabricante|reconocido|motivo)"; pad_scan
    echo; echo "## Mando elegido"; pad_info
    echo; echo "## /proc/bus/input/devices"; cat "$R/proc/bus/input/devices" 2>/dev/null
    echo; echo "## Modo mando"; grep -E '^(pad|pad_|bt_|auto|heat_)' "$CFG" 2>/dev/null; echo "estado: $(cat "$PADSTATE" 2>/dev/null)"; echo "vigilante: $(padd_alive && echo vivo || echo detenido)"
    [ -f "$PADFLAPS" ] && { echo "cortes:"; cat "$PADFLAPS"; }; [ -f "$PADTIME" ] && { echo "sesiones:"; cat "$PADTIME"; }
    echo; echo "## Bluetooth: propiedades"; getprop 2>/dev/null | grep -i -E 'bluetooth\.(core|le)' 
    echo; echo "## Bluetooth: dumpsys (filtrado)"; $TMO dumpsys bluetooth_manager 2>/dev/null </dev/null | grep -i -E 'hid|hogp|gatt|a2dp|interval|latency|supervision|bonded|connected|name:' | head -n 120
    echo; echo "## Interrupciones de radio"; grep -i -E 'bt|blue|hci|wlan|wcn|cnss|uart|serial' "$R/proc/interrupts" 2>/dev/null | head -n 20
    echo; echo "## USB"; for _d in "$R"/sys/bus/usb/devices/*; do [ -r "$_d/idVendor" ] && echo "${_d##*/}: $(rd "$_d/idVendor"):$(rd "$_d/idProduct") $(rd "$_d/product") control=$(rd "$_d/power/control") autosuspend=$(rd "$_d/power/autosuspend_delay_ms")"; done
    echo; echo "## Pantalla"; dumpsys display 2>/dev/null </dev/null | grep -i -E 'fps=|refreshRate|renderFrameRate' | head -n 20
    echo "min_refresh_rate=$(sy_get min_refresh_rate) peak_refresh_rate=$(sy_get peak_refresh_rate) user_refresh_rate=$(sy_get user_refresh_rate)"
    echo; echo "## Registro"; tail -n 40 "$LOG" 2>/dev/null
  } 2>/dev/null | sed 's/\([0-9A-Fa-f][0-9A-Fa-f]:\)\{4\}\([0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]\)/XX:XX:XX:XX:\2/g' > "$_o" 2>/dev/null
  [ -s "$_o" ] && echo "$_o"
}
