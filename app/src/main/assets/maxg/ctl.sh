#!/system/bin/sh
case "$0" in */*) MODDIR=${0%/*} ;; *) MODDIR=$(pwd) ;; esac
. "$MODDIR/lib.sh"
C=$1; shift
if [ "$C" = chk ]; then   # chk <orden…>: revisa si choca con otra función; si no hay avisos aplica en esta misma llamada (si los hay, la app pide confirmar y luego manda la orden sin chk)
  [ $# -gt 0 ] || exit 0
  conflicts_check "$@"; echo "CONFEND|$CX_N|$CX_W"
  [ "$CX_W" -gt 0 ] && exit 0
  C=$1; shift
fi
res() { echo "RESULT|$1|$2|$3"; }
case "$C" in
  state)
    # state [full|boot|live|more|static]. live = lo que cambia (rápido, sin tocar paquetes ni entradas); more = pestañas Mando/Auto (lento: pm, input); static = tablas de perfiles
    _sm=${1:-full}; case "$_sm" in full|boot|live|more|static) ;; *) _sm=full ;; esac
    case "$_sm" in full|boot|live)
      [ "$_sm" = live ] || heal_gpu
      echo "SECT|core"
      if [ "$_sm" != live ]; then   # el dispositivo no cambia: se pregunta solo al abrir
        _why=$(is_target) && echo "DEV|1|$(dev_name)|$(uname -r 2>/dev/null)|$(getprop ro.build.display.id 2>/dev/null | cut -c1-48)" || echo "DEV|0|$(dev_name)|$_why"
      fi
      rdv "$BOOTC"; isnum "$RV" || RV=0
      echo "CFG|$(cfg_get profile stock)|$([ -e "$CONF/safe" ] && echo 1 || echo 0)|$RV"
      _gl=""; for _g in $(gov_avail); do _gl="$_gl$_g,"; done
      echo "GOV|$(gov_cur)|$_gl|$(cfg_get gov none)"
      gpu_status; rom_limits
      for _p in $(policies); do echo "CPUCAP|$_p|$(rd $CPUF/policy$_p/scaling_max_freq)"; done
      heat_status; heatx_status; guard_targets; watch_status
      echo "GPUMODE|$(cfg_get gpu_mode auto)|$(cfg_get gm_max 100)"
      echo "GPUSC|$(cfg_get gpu_scope always)"
      manual_status; conflicts_who
      [ "$_sm" = full ] || { rdv "$AUTOST"; [ -n "$RV" ] && echo "AUTOST|$RV"; } ;;
    esac
    case "$_sm" in full|more)
      [ "${2-}" = fresh ] && PKGFRESH=1
      echo "SECT|more"; pad_status; bt_status; bt_extra_status; auto_status; sess_status; tune_status; maint_status; deluxe_status; bgapps_status ;;
    esac
    case "$_sm" in full|boot|static)
      echo "SECT|static"
      pol_warm; for p in $BUILTIN $(custom_ids); do plan_v "$p" || continue; echo "PLAN|$p|$PLNB"; echo "PCT|$p|$PD_perf|$PD_prime|$PD_gpu|$PD_hl|$PD_cpl|${PD_swap:-0}"; [ "$PD_hz" -gt 0 ] && echo "HZP|$p|$PD_hz"; done
      for p in $(custom_ids); do echo "CUSTOM|$p|$(custom_name $p)"; done
      for _p in $(policies); do fq_get "$_p"; echo "FREQ|cpu$_p|$(printf '%s,' $FLIST)"; done
      gq_get; echo "FREQ|gpu|$(for _x in $FLIST; do printf '%s,' $((_x/1000000)); done)" ;;
    esac
    ;;
  pad) case "$1" in
         on) cfg_set pad 1; if padd_start; then res pad ok "Modo mando activado"; else res pad err "no pude iniciar el vigilante"; fi ;;
         off) cfg_set pad 0; padd_stop; res pad ok "Modo mando desactivado" ;;
         test) pad_test "$2" ;;
         status) pad_status ;;
         stats) padx_status "$2" ;;
         qos) if pad_qos_set "$2"; then res pad ok "reposo de CPU: $2 µs"; else res pad err "$K_ERR"; fi ;;
         opt) if pad_opt_set "$2" "$3"; then res pad ok "$2: $3"; else res pad err "$K_ERR"; fi ;;
         dump) _f=$(pad_dump); if [ -n "$_f" ]; then res pad ok "$_f"; else res pad err "no pude escribir el informe (¿permiso sobre /sdcard?)"; fi ;;
         scan) pad_scan ;;
         clear) rm -f "$PADTESTS"; res pad ok "historial borrado" ;;
         *) echo "uso: pad on|off|test [seg]|status|clear" ;;
       esac ;;
  info)
    _mt=$(sed -n 's/^MemTotal: *\([0-9]*\).*/\1/p' $R/proc/meminfo); _ma=$(sed -n 's/^MemAvailable: *\([0-9]*\).*/\1/p' $R/proc/meminfo)
    isnum "$_mt" && isnum "$_ma" && [ "$_mt" -gt 0 ] && echo "I|ram|$((_ma/(_mt/100)))|$((_mt/1024))"
    echo "I|bat|$(rd $R/sys/class/power_supply/battery/capacity)|$(bat_temp10)"
    echo "I|cpu|$(cpu_temp10)"
    _cu=$(rd $R/sys/class/power_supply/battery/current_now); _cy=$(rd $R/sys/class/power_supply/battery/cycle_count)
    case "$_cu" in -*) _cu=${_cu#-}; _cs=- ;; *) _cs=+ ;; esac; isnum "$_cu" && echo "I|cur|$_cs$((_cu/1000))"
    isnum "$_cy" && echo "I|cyc|$_cy"
    echo "I|chg|$(rd $R/sys/class/power_supply/battery/status)"
    _d=$(df -k /data 2>/dev/null | tail -n 1); set -- $_d; isnum "$2" && isnum "$4" && [ "$2" -gt 0 ] && echo "I|disk|$(( $4/($2/100) ))|$(( $2/1048576 ))" ;;
  profile)
    if prof_apply "$1"; then res profile ok "$1"; else res profile err "$K_ERR"; fi ;;
  gov) if manual_block; then res gov err "$K_ERR"; exit 0; fi
       case "$1" in
         stock|none) gov_restore; res gov ok "gobernador original" ;;
         *) if gov_set "$1"; then res gov ok "$1"; else res gov err "$K_ERR"; fi ;;
       esac ;;
  gpu) case "$1" in floor|free|off|scope) if manual_block; then res gpu err "$K_ERR"; exit 0; fi ;; esac
       case "$1" in
         floor) _f=$2; isnum "$_f" || { res gpu err "valor no válido"; exit 0; }
                if [ "$_f" -gt 0 ]; then gpu_freqs | while read -r _x; do echo $((_x/1000000)); done | grep -qx "$_f" || { res gpu err "esa frecuencia no existe en tu GPU"; exit 0; }; fi
                gpu_mode_pin; cfg_set gpu_floor "$_f"; if [ "$_f" = 0 ] && [ "$(cfg_get gpu_free 0)" = 0 ]; then gpud_stop; res gpu ok "piso de GPU apagado"
                elif gpud_start; then res gpu ok "piso de GPU: $_f MHz"; else res gpu err "no pude iniciar el vigilante de GPU"; fi ;;
         free) gpu_mode_pin; case "$2" in on) cfg_set gpu_free 1; if gpud_start; then res gpu ok "tope de la ROM liberado (con protección de temperatura)"; else res gpu err "no pude iniciar el vigilante de GPU"; fi ;;
                 *) cfg_set gpu_free 0; if [ "$(cfg_get gpu_floor 0)" = 0 ]; then gpud_stop; fi; res gpu ok "tope de la ROM devuelto" ;; esac ;;
         mode) if gpu_mode_set "$2"; then res gpu ok "modo de GPU: $2"; else res gpu err "$K_ERR"; fi ;;
         manual) if gpu_manual "$2"; then res gpu ok "tope de GPU: $2 %"; else res gpu err "$K_ERR"; fi ;;
         scope) case "$2" in always|game) cfg_set gpu_scope "$2"; res gpu ok "piso de GPU: $([ "$2" = game ] && echo 'solo en juegos' || echo 'siempre')" ;; *) res gpu err "usa always o game" ;; esac ;;
         probe) gpu_probe ;;
         status) gpu_status ;;
         off) gpu_off; res gpu ok "GPU devuelta a la ROM" ;;
         *) echo "uso: gpu floor <MHz|0>|free on|off|probe|status|off" ;;
       esac ;;
  rec) case "$1" in
         start) if rec_start "$2"; then res rec ok "grabando"; else res rec err "no pude iniciar la grabación (¿permiso sobre /sdcard?)"; fi ;;
         stop) _d=$(cat "$RECPID" 2>/dev/null); [ -n "$_d" ] && kill "$_d" 2>/dev/null; rm -f "$RECPID"; res rec ok "detenida" ;;
         *) rec_status ;;
       esac ;;
  _gpud) gpud_run ;;
  _rec) rec_run "$1" ;;
  manual) case "$1" in
      on) if manual_enable; then res manual ok "Control manual ON"; else res manual err "$K_ERR"; fi ;;
      off) manual_disable; res manual ok "Control manual OFF" ;;
      set) shift; if manual_set "$@"; then res manual ok "ajuste guardado"; else res manual err "$K_ERR"; fi ;;
      try) shift; if manual_try "$@"; then res manual ok "Control manual ON"; else res manual err "$K_ERR"; fi ;;
      status|"") manual_status ;;
      *) echo "uso: manual on|off|status|set perf prime gpu hl cpl swap [gfloor gfree]|try ..." ;;
    esac ;;
  custom) case "$1" in
      save) shift; if custom_save "$@"; then res custom ok "perfil guardado"; else res custom err "$K_ERR"; fi ;;
      try) shift; if manual_try "$@"; then res custom ok "ajuste manual aplicado"; else res custom err "$K_ERR"; fi ;;
      del) if custom_del "$2"; then res custom ok "perfil borrado"; else res custom err "$K_ERR"; fi ;;
      list) for p in $(custom_ids); do echo "CUSTOM|$p|$(custom_name $p)"; done ;;
      *) echo "uso: custom save <id> <nombre> perf prime gpu hl cpl swap | try perf prime gpu hl cpl swap | del <id> | list" ;;
    esac ;;
  heat) case "$1" in
      mode) if heat_set_mode "$2"; then res heat ok "control de calor: $2"; else res heat err "$K_ERR"; fi ;;
      tgt) if guard_target_set "$2" "$3"; then res heat ok "objetivo de $2: $3 °C"; else res heat err "$K_ERR"; fi ;;
      tgts) guard_targets ;;
      ant) if heatx_set ant "$2"; then res heat ok "anticipación térmica: $2"; else res heat err "$K_ERR"; fi ;;
      burst) if heatx_set burst "$2"; then res heat ok "ráfaga sostenida: $2"; else res heat err "$K_ERR"; fi ;;
      screen) case "$2" in 0|1) cfg_set heat_screen "$2"; res heat ok "ahorro con pantalla apagada: $([ "$2" = 1 ] && echo sí || echo no)" ;; *) res heat err "usa 0 o 1" ;; esac ;;
      status) heat_status ;;
      *) echo "uso: heat mode off|suave|normal|estricto|guardian | tgt <perfil> <30-45> | tgts | ant on|off | burst off|15|30|60 | screen 0|1 | status" ;;
    esac ;;
  watch) case "$1" in
      on|off) if watch_set "$1"; then res watch ok "vigilante de topes: $1"; else res watch err "$K_ERR"; fi ;;
      status) watch_status ;;
      *) echo "uso: watch on|off|status" ;;
    esac ;;
  bgapps) case "$1" in
      list) bgapps_status ;;
      add) if bgapps_add "$2" "$3" "$4" "$5"; then res bgapps ok "$2 añadida a segundo plano"; else res bgapps err "$K_ERR"; fi ;;
      del) if bgapps_del "$2"; then res bgapps ok "$2 quitada de segundo plano"; else res bgapps err "$K_ERR"; fi ;;
      apply) rm -f "$CONF/extras.on"; extras_apply; res bgapps ok "segundo plano aplicado" ;;
      *) echo "uso: bgapps list|add <paquete>|del <paquete>|apply" ;;
    esac ;;
  bt) case "$1" in
      prio) if btprio_set "$2"; then res bt ok "prioridad del Bluetooth: $2"; else res bt err "$K_ERR"; fi ;;
      restart) if bt_restart_now; then res bt ok "Bluetooth reiniciado"; else res bt err "$K_ERR"; fi ;;
      xstatus) bt_extra_status ;;
      fast) if bt_fast_set "$2"; then res bt ok "Bluetooth rápido: $2"; else res bt err "$K_ERR"; fi ;;
      status) bt_status ;;
      *) echo "uso: bt fast on|off | status" ;;
    esac ;;
  auto) case "$1" in
      on) cfg_set auto 1; if autod_start; then res auto ok "Modo inteligente activado"; else res auto err "no pude iniciar el vigilante"; fi ;;
      off) cfg_set auto 0; autod_stop; res auto ok "Modo inteligente desactivado" ;;
      set) if auto_rule_set "$2" "$3"; then res auto ok "regla guardada"; else res auto err "$K_ERR"; fi ;;
      app) case "$2" in
             add) if auto_app_add "$3" "$4" "$5"; then res auto ok "app guardada"; else res auto err "$K_ERR"; fi ;;
             del) auto_app_del "$3"; res auto ok "app quitada" ;;
             *) echo "uso: auto app add <paquete> game|maps|none [perfil] | del <paquete>" ;;
           esac ;;
      recent) case "$2" in clear) rm -f "$AUTOREC"; res auto ok "lista borrada" ;; *) echo "uso: auto recent clear" ;; esac ;;
      fg) fg_report ;;
      status) auto_status ;;
      *) echo "uso: auto on|off | set game|maps|low|off <perfil|none> | set lowpct N | set boost N | set mapboost N | app add|del | recent clear | fg | status" ;;
    esac ;;
  tune) case "$1" in
      status) tune_status ;;
      *) if tune_set "$1" "$2"; then res tune ok "$1: $2"; else res tune err "$K_ERR"; fi ;;
    esac ;;
  maint) case "$1" in
      on|off) cfg_set maint "$([ "$1" = on ] && echo 1 || echo 0)"; res maint ok "mantenimiento: $1" ;;
      now) if maint_start 1; then res maint ok "mantenimiento en marcha"; else res maint err "no pude iniciarlo"; fi ;;
      status) maint_status ;;
      *) echo "uso: maint on|off|now|status" ;;
    esac ;;
  btg) if btg_set "$1" "$2"; then res btg ok "$1: $2"; else res btg err "$K_ERR"; fi ;;
  conflicts) case "${1-}" in
      scan) conflicts_scan; echo "CONFEND|$CX_N|$CX_W" ;;
      who) conflicts_who ;;
      "") echo "uso: conflicts scan|who|<orden…>" ;;
      *) conflicts_check "$@"; echo "CONFEND|$CX_N|$CX_W" ;;
    esac ;;
  deluxe) case "$1" in
      on) if deluxe_on; then res deluxe ok "Modo Deluxe activado"; else res deluxe err "$K_ERR"; fi ;;
      status) deluxe_status ;;
      *) echo "uso: deluxe on|status" ;;
    esac ;;
  sess) case "$1" in clear) rm -f "$SESSF"; res sess ok "historial borrado" ;; *) sess_status ;; esac ;;
  report) _f=$(report_dump); if [ -n "$_f" ]; then res report ok "$_f"; else res report err "no pude escribir el informe (¿permiso sobre /sdcard?)"; fi ;;
  desc) case "$1" in on|off) cfg_set desc_live "$([ "$1" = on ] && echo 1 || echo 0)"; res desc ok "descripción en vivo: $1" ;; *) echo "uso: desc on|off" ;; esac ;;
  _autod) autod_run ;;
  _maint) maint_job "$1" ;;
  _heatd) heatd_run ;;
  _watchd) watchd_run ;;
  _padd) padd_run ;;
  _sondause) sonda_use_run "$1" ;;
  safe) case "$1" in clear) rm -f "$CONF/safe"; echo 0 > "$BOOTC"; res safe ok "modo seguro desactivado" ;; *) echo "uso: safe clear" ;; esac ;;
  reapply) echo "reaplicados=$(reapply)" ;;
  log) tail -n "${1:-60}" "$LOG" 2>/dev/null ;;
  volt) find $R/sys/devices/system/cpu $R/sys/class/devfreq $R/sys/class/kgsl $R/sys/kernel -maxdepth 5 \( -iname '*volt*' -o -iname '*vdd*' -o -iname '*undervolt*' -o -iname '*cpr*' \) 2>/dev/null | head -n 40 ;;
  sonda) case "$1" in
      perf) _f=$(sonda_perf); if [ -n "$_f" ]; then res sonda ok "$_f"; else res sonda err "no pude escribir la sonda (¿permiso sobre /sdcard?)"; fi ;;
      hw) sh "$MODDIR/action.sh" >/dev/null 2>&1; _f=$(sonda_file hw); if [ -n "$_f" ]; then res sonda ok "$_f"; else res sonda err "no pude escribir la sonda (¿permiso sobre /sdcard?)"; fi ;;
      deep) _f=$(sonda_deep); if [ -n "$_f" ]; then res sonda ok "$_f"; else res sonda err "no pude escribir la sonda profunda (¿permiso sobre /sdcard?)"; fi ;;
      findings) sonda_findings ;;
      use) _s=${2:-60}; isnum "$_s" || _s=60; [ "$_s" -lt "${MG_SONDAMIN:-30}" ] && _s=${MG_SONDAMIN:-30}; [ "$_s" -gt 300 ] && _s=300
           if sonda_use_start "$_s"; then res sonda ok "midiendo en $((_s/3)) s; en total unos $((_s+45)) s"; else res sonda err "ya hay una sonda en uso en curso"; fi ;;
      list) sonda_list ;;
      show) _f=$(sonda_file "$2") && cat "$_f" || echo "(esa sonda todavía no se generó)" ;;
      *) sh "$MODDIR/action.sh" ;;
    esac ;;
  *) echo "uso: ctl.sh state|profile <id>|pad on|off|test|status|info|safe clear|reapply|log|volt|sonda"; exit 2 ;;
esac
