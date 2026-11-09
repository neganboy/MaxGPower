#!/system/bin/sh
# MaxG Power (F8 Pro) - GPU: piso de frecuencia y liberar el tope de la ROM, con protección de temperatura. Experimental.
# + grabador de sesión para ver si la GPU se queda a frecuencia baja mientras está ocupada.
GPUORIG=$CONF/gpu.orig; GPUPID=$CONF/gpud.pid; RECPID=$CONF/rec.pid
GN_MIN=$GPUD/min_clock_mhz; GN_THP=$GPUD/thermal_pwrlevel; GN_MAXG=$GPUD/max_gpuclk; GN_MAXC=$GPUD/max_clock_mhz
REC_OUT=${MG_RECOUT:-/sdcard/MaxG_power_rec.csv}
GPU_HOT=${MG_GPUHOT:-620}; GPU_COOL=${MG_GPUCOOL:-550}; BAT_HOT=430; BAT_COOL=410   # décimas de °C

ztemp10() {   # patrón de tipo de zona -> máximo en décimas de °C (sin crear procesos por zona; en el teléfono hay ~80)
  _m=0; for _z in $R/sys/class/thermal/thermal_zone*; do
    [ -r "$_z/type" ] || continue; rdv "$_z/type"; case "$RV" in $1) ;; *) continue ;; esac
    rdv "$_z/temp"; _x=$RV; isnum "$_x" || continue; [ "$_x" -ge 1000 ] && _x=$((_x/100)); [ "$_x" -gt "$_m" ] && [ "$_x" -lt 1500 ] && _m=$_x
  done; echo "$_m"; }
go_put() { grep -q "^$1|" "$GPUORIG" 2>/dev/null || echo "$1|$2" >> "$GPUORIG"; }
go_get() { grep "^$1|" "$GPUORIG" 2>/dev/null | head -n 1 | cut -d'|' -f2-; }
gpu_save() { for _n in min thp maxg; do case $_n in min) _f=$GN_MIN ;; thp) _f=$GN_THP ;; maxg) _f=$GN_MAXG ;; esac; [ -e "$_f" ] && go_put $_n "$(rd $_f)"; done; }
gpu_restore() {
  [ -f "$GPUORIG" ] || return 0
  for _n in maxg thp min; do
    case $_n in min) _f=$GN_MIN ;; thp) _f=$GN_THP ;; maxg) _f=$GN_MAXG ;; esac
    _v=$(go_get $_n); [ -n "$_v" ] && [ -e "$_f" ] && echo "$_v" > "$_f" 2>/dev/null
  done
  rm -f "$GPUORIG"; log "GPU: valores originales restaurados"
}
gpu_put() {   # nodo valor -> escribe solo si cambia y avisa una vez si el kernel lo rechaza
  [ -e "$1" ] || return 0; [ "$(rd "$1")" = "$2" ] && return 0
  echo "$2" > "$1" 2>/dev/null; [ "$(rd "$1")" = "$2" ] || { [ -e "$CONF/gpu.warn.${1##*/}" ] || { : > "$CONF/gpu.warn.${1##*/}"; log "GPU: el kernel no aceptó ${1##*/}=$2 (quedó en $(rd "$1"))"; }; }
}
gpu_apply() {
  _fl=$(cfg_get gpu_floor 0); _fr=$(cfg_get gpu_free 0)
  gpu_save
  [ "$_fr" = 1 ] && gpu_put "$GN_THP" 0
  isnum "$_fl" && [ "$_fl" -gt 0 ] && gpu_put "$GN_MIN" "$_fl"
}
gpud_alive() { _d=""; [ -r "$GPUPID" ] && read -r _d < "$GPUPID"; [ -n "$_d" ] && kill -0 "$_d" 2>/dev/null; }
gpud_run() {
  echo $$ > "$GPUPID"; rm -f "$CONF/gpud.stop" "$CONF"/gpu.warn.*; _hot=0; log "GPU: vigilante iniciado"
  trap 'gpu_restore; rm -f "$GPUPID"; exit 0' TERM INT
  while [ ! -e "$CONF/gpud.stop" ]; do
    if [ "$(cfg_get gpu_floor 0)" = 0 ] && [ "$(cfg_get gpu_free 0)" = 0 ]; then gpu_restore
    else
      # alcance: con "solo en juegos" el piso y el tope libre solo valen mientras el modo inteligente ve un juego delante (sin él, vale siempre)
      _gin=1
      if [ "$(cfg_get gpu_scope always)" = game ] && [ "$(cfg_get manual_on 0)" != 1 ] && autod_alive; then
        # AUTOST = categoría|perfil|app en pantalla (game/maps/none)|... ; el tercer campo dice si lo que se ve es un juego
        _gs1=""; _gs2=""; _gs3=""; _gs4=""; [ -r "$AUTOST" ] && IFS='|' read -r _gs1 _gs2 _gs3 _gs4 < "$AUTOST"
        case "$_gs3" in game) ;; *) _gin=0 ;; esac
      fi
      if [ "$_gin" = 0 ]; then
        if [ -f "$GPUORIG" ]; then gpu_restore; log "GPU: fuera de un juego, la GPU vuelve a la ROM"; fi
      else
        gpu_temp10_v; _t=$GT10; bat_temp10_v; _b=$BT10
        if [ "$_hot" = 0 ] && { [ "$_t" -ge "$GPU_HOT" ] || [ "$_b" -ge "$BAT_HOT" ]; }; then gpu_restore; _hot=1; log "GPU: calor (gpu $_t, batería $_b), se devuelve el control a la ROM"
        elif [ "$_hot" = 1 ] && [ "$_t" -lt "$GPU_COOL" ] && [ "$_b" -lt "$BAT_COOL" ]; then _hot=0; log "GPU: ya enfrió, se vuelve a aplicar"; fi
        [ "$_hot" = 0 ] && gpu_apply
      fi
    fi
    sleep "${MG_GPUTICK:-4}" & wait $!
  done
  gpu_restore; rm -f "$GPUPID" "$CONF/gpud.stop"
}
gpud_start() {
  gpud_alive && return 0
  rm -f "$CONF/gpud.stop"
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _gpud </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _gpud </dev/null >/dev/null 2>&1 & fi
  _i=0; while [ "$_i" -lt 5 ]; do gpud_alive && return 0; sleep 1; _i=$((_i+1)); done; gpud_alive
}
gpud_stop() {
  : > "$CONF/gpud.stop"; _d=$(cat "$GPUPID" 2>/dev/null); [ -n "$_d" ] && kill "$_d" 2>/dev/null
  _i=0; while [ "$_i" -lt 5 ] && gpud_alive; do sleep 1; _i=$((_i+1)); done
  rm -f "$GPUPID" "$CONF/gpud.stop"; gpu_restore
}
gpu_off() { cfg_set gpu_floor 0; cfg_set gpu_free 0; gpud_stop; }
gpu_probe() {   # escribe en cada nodo el MISMO valor que ya tiene (no cambia nada) y dice si el kernel lo acepta
  for _n in min_clock_mhz max_clock_mhz max_gpuclk thermal_pwrlevel min_pwrlevel max_pwrlevel default_pwrlevel idle_timer force_clk_on force_no_nap; do
    _f=$GPUD/$_n
    if [ -e "$_f" ]; then _v=$(rd "$_f"); if echo "$_v" > "$_f" 2>/dev/null; then _w=1; else _w=0; fi; echo "GPUP|$_n|1|$_w|$_v"
    else echo "GPUP|$_n|0|0|"; fi
  done
}
gpu_rom_path() {   # cooling device «gpu»: lo que pide la ROM, independiente del tope del módulo (se busca una sola vez)
  [ -n "${GRP-}" ] && return 0; GRP=none
  for gr_z in "$R"/sys/class/thermal/cooling_device*; do
    [ -r "$gr_z/type" ] || continue; rdv "$gr_z/type"
    case "$RV" in gpu|gpu[0-9]*|kgsl*) [ -r "$gr_z/cur_state" ] && { GRP=$gr_z; return 0; } ;; esac
  done
  return 0
}
gpu_rom_level() {   # RLV = nivel que pide la ROM (0 = sin límite); vacío si no se puede saber
  RLV=""; gpu_rom_path
  if [ "$GRP" != none ]; then rdv "$GRP/cur_state"; isnum "$RV" && RLV=$RV; return 0; fi
  gpu_be   # sin cooling device: thermal_pwrlevel vale solo si no comparte variable con el tope del módulo (backend pwr, o módulo sin tope propio)
  if [ "$GBE" = pwr ] || [ -z "$(knob_des gpu_max)" ]; then rdv "$GN_THP"; isnum "$RV" && RLV=$RV; fi
  return 0
}
gpu_rom_fields() { gpu_rom_v; echo "$GRF"; }
gpu_rom_v() {   # GRF = backend|MHz del tope de usuario|MHz del límite de la ROM|nivel de la ROM (0 = sin límite)
  gpu_be; ur_u=""; ur_m=""; gpu_rom_level; ur_l=$RLV
  if [ "$GBE" = pwr ] || [ "$GBE" = dev ]; then ur_h=$(knob_cur gpu_max); isnum "$ur_h" && ur_u=$((ur_h/1000000)); fi
  isnum "$ur_l" && [ "$ur_l" -gt 0 ] && gpu_hz_of_level "$ur_l" && ur_m=$((HZV/1000000))
  GRF="$GBE|$ur_u|$ur_m|$ur_l"
}
rom_limits() {   # ROMLIM|nombre=actual/máximo,... de los limitadores de la ROM que están activos (cooling devices con estado > 0, salvo el brillo)
  rl_o=""
  for rl_z in "$R"/sys/class/thermal/cooling_device*; do
    [ -r "$rl_z/cur_state" ] || continue; rdv "$rl_z/cur_state"; isnum "$RV" && [ "$RV" -gt 0 ] || continue; rl_c=$RV
    rdv "$rl_z/type"; rl_t=$RV; case "$rl_t" in *backlight*|*dump*|*skip*|'') continue ;; esac   # «gpu-dump-skip-cdev» y parecidos son banderas, no límites
    rdv "$rl_z/max_state"; rl_o="$rl_o,$rl_t=$rl_c/$RV"
  done
  echo "ROMLIM|${rl_o#,}"
}
gpu_status() {   # GPUCFG|piso|liberar|vigilante|temp_gpu|temp_bat|nivel_tope|mhz_actual|mhz_tope|tabla(MHz separados por coma)
  gq_get; _tb=""; for _x in $FLIST; do _tb="$_tb$((_x/1000000)),"; done
  rdv "$GPUD/gpuclk"; gs_a=${RV%%[!0-9]*}; rdv "$GN_MAXG"; gs_b=${RV%%[!0-9]*}
  gpu_temp10_v; bat_temp10_v; rdv "$GN_THP"; gs_l=$RV; cfg_v gpu_floor 0; gs_f=$CV; cfg_v gpu_free 0; gs_r=$CV; gs_v=0; gpud_alive && gs_v=1; gpu_rom_v
  echo "GPUCFG|$gs_f|$gs_r|$gs_v|$GT10|$BT10|$gs_l|$(( ${gs_a:-0} / 1000000 ))|$(( ${gs_b:-0} / 1000000 ))|$_tb|$GRF"
}

# ---- grabador de sesión ----
rec_alive() { _d=$(cat "$RECPID" 2>/dev/null); [ -n "$_d" ] && kill -0 "$_d" 2>/dev/null; }
rec_run() {
  _s=${1:-60}; isnum "$_s" || _s=60; [ "$_s" -gt 300 ] && _s=300; [ "$_s" -lt 10 ] && _s=10
  echo $$ > "$RECPID"; trap 'rm -f "$RECPID"; exit 0' TERM INT
  echo "t,perfil,gpu_mhz,gpu_ocup,tope_gpu_mhz,nivel_termico_gpu,cpu0_mhz,cpu6_mhz,max0_mhz,max6_mhz,temp_cpu,temp_gpu,bat" > "$REC_OUT" 2>/dev/null || { rm -f "$RECPID"; return 1; }
  _prof=$(cfg_get profile stock); _i=0; _n=0; _sb=0; _sc=0; _hb=0; _hl=0; _mx=0
  while [ "$_i" -lt "$_s" ]; do
    _c=$(( $(cat "$GPUD/gpuclk" 2>/dev/null | tr -dc 0-9 | head -c 12) + 0 )); _b=$(( $(cat "$GPUD/gpu_busy_percentage" 2>/dev/null | tr -dc 0-9 | head -c 3) + 0 ))
    _cap=$(( $(cat "$GN_MAXG" 2>/dev/null | tr -dc 0-9 | head -c 12) + 0 )); gpu_rom_level; _lv=${RLV:-$(rd "$GN_THP")}
    _a=$(( $(rd "$CPUF/policy0/scaling_cur_freq") / 1000 )); _p=$(( $(rd "$CPUF/policy6/scaling_cur_freq") / 1000 ))
    _x0=$(( $(rd "$CPUF/policy0/scaling_max_freq") / 1000 )); _x6=$(( $(rd "$CPUF/policy6/scaling_max_freq") / 1000 ))
    cpu_temp10_v; gpu_temp10_v; bat_temp10_v
    echo "$_i,$_prof,$((_c/1000000)),$_b,$((_cap/1000000)),$_lv,$_a,$_p,$_x0,$_x6,$CT10,$GT10,$BT10" >> "$REC_OUT"
    _n=$((_n+1)); _sb=$((_sb+_b)); _sc=$((_sc+_c/1000000))
    if [ "$_b" -ge 70 ]; then _hb=$((_hb+1)); [ "$_cap" -gt 0 ] && [ $((_c/1000*100)) -lt $((_cap/1000*60)) ] && _hl=$((_hl+1)); fi
    _i=$((_i+1)); sleep 1 & wait $!
  done
  echo "# resumen: muestras=$_n ocupacion_media=$((_sb/_n))% gpu_media=$((_sc/_n))MHz muestras_ocupadas(>=70%)=$_hb de_ellas_con_frecuencia_baja(<60%_del_tope)=$_hl" >> "$REC_OUT"
  log "grabación terminada: $_n muestras, $_hb ocupadas, $_hl con frecuencia baja"
  rm -f "$RECPID"
}
rec_start() {
  rec_alive && return 0
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _rec "$1" </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _rec "$1" </dev/null >/dev/null 2>&1 & fi
  _i=0; while [ "$_i" -lt 4 ]; do rec_alive && return 0; sleep 1; _i=$((_i+1)); done; rec_alive
}
rec_status() { echo "REC|$(rec_alive && echo 1 || echo 0)|$(grep '^# resumen' "$REC_OUT" 2>/dev/null | tail -n 1 | cut -c3-)|$(wc -l < "$REC_OUT" 2>/dev/null | tr -d ' ')"; }

# ---- modos de GPU (independientes del perfil de CPU) ----
# auto = la GPU sigue lo que diga el perfil. Los demás fijan tope (% de la tabla), piso (% de la tabla) y si se libera el tope de la ROM.
gm_def() { case "$1" in
  ahorro) GM_max=45; GM_fl=0; GM_free=0 ;; equilibrado) GM_max=70; GM_fl=0; GM_free=0 ;;
  rendimiento) GM_max=90; GM_fl=30; GM_free=0 ;; maximo) GM_max=100; GM_fl=40; GM_free=1 ;; *) return 1 ;; esac; }
GPU_MODES="ahorro equilibrado rendimiento maximo"
gm_floor_mhz() {   # % -> mayor frecuencia de la tabla (MHz) <= % del máximo; 0 si %=0
  [ "$1" -gt 0 ] || { echo 0; return; }
  gpu_freqs > "$CONF/gm.tmp"; [ -s "$CONF/gm.tmp" ] || { rm -f "$CONF/gm.tmp"; echo 0; return; }
  _h=$(fit_pct "$CONF/gm.tmp" "$1"); rm -f "$CONF/gm.tmp"; echo $((_h/1000000))
}
gpu_mode_apply() {
  manual_on_p && return 0   # control manual ON: los modos de GPU se ignoran
  _m=$(cfg_get gpu_mode auto)
  case "$_m" in auto|"") return 0 ;;
    manual) GM_max=$(cfg_get gm_max 100) ;;
    *) gm_def "$_m" || return 0; cfg_set gm_max "$GM_max"
       cfg_set gpu_floor "$(gm_floor_mhz "$GM_fl")"; cfg_set gpu_free "$GM_free" ;;
  esac
  heat_deltas 2>/dev/null; GM_max=$((GM_max-HDG)); [ "$GM_max" -lt 30 ] && GM_max=30
  gpu_freqs > "$CONF/gm.tmp"
  if [ -s "$CONF/gm.tmp" ]; then _g=$(fit_pct "$CONF/gm.tmp" "$GM_max"); set_knob gpu_max "$_g" >/dev/null 2>&1; fi
  rm -f "$CONF/gm.tmp"
  if [ "$(cfg_get gpu_floor 0)" != 0 ] || [ "$(cfg_get gpu_free 0)" != 0 ]; then gpud_start >/dev/null 2>&1; else gpud_alive && gpud_stop; fi
  log "modo de GPU $_m (tope $GM_max %)"
  return 0
}
gpu_mode_set() {   # id -> aplica el modo; "auto" devuelve el control al perfil de CPU
  K_ERR=""; manual_block && return 1
  case "$1" in
    auto) cfg_set gpu_mode auto; gpu_off
          _o=$(knob_orig gpu_max); _p=$(cfg_get profile stock)
          if [ "$_p" != stock ] && prof_def "$_p"; then prof_set "$_p" >/dev/null 2>&1
          elif [ -n "$_o" ]; then knob_put gpu_max "$_o"; des_del gpu_max; fi
          log "modo de GPU: automático"; return 0 ;;
    ahorro|equilibrado|rendimiento|maximo) _w=$(is_target) || { K_ERR=$_w; return 1; }; cfg_set gpu_mode "$1"; gpu_mode_apply; return 0 ;;
    *) K_ERR="modo de GPU desconocido"; return 1 ;;
  esac
}
gpu_manual() {   # % de tope -> modo manual (piso y tope libre los siguen controlando sus propios botones)
  K_ERR=""; manual_block && return 1; isnum "$1" && [ "$1" -ge 30 ] && [ "$1" -le 100 ] || { K_ERR="el tope de GPU debe estar entre 30 y 100 %"; return 1; }
  _w=$(is_target) || { K_ERR=$_w; return 1; }
  case "$(cfg_get gpu_mode auto)" in manual) ;; auto|"") ;; *) gm_def "$(cfg_get gpu_mode)" && { cfg_set gpu_floor "$(gm_floor_mhz "$GM_fl")"; cfg_set gpu_free "$GM_free"; } ;; esac
  cfg_set gm_max "$1"; cfg_set gpu_mode manual; gpu_mode_apply; return 0
}
gpu_mode_pin() {   # el usuario tocó piso/liberar a mano mientras había un modo fijo: pasa a manual conservando su tope
  case "$(cfg_get gpu_mode auto)" in auto|manual|"") ;; *) cfg_set gpu_mode manual ;; esac
}
