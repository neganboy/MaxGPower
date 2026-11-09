#!/system/bin/sh
# MaxG Power - sonda de rendimiento: mide cuánto tarda el módulo en cambiar de perfil, cuánto gastan los vigilantes y qué está ocupando el teléfono.
# Se genera desde la app (Módulo > Sondas) y queda en /sdcard/MaxG_power_rendimiento.txt para que se pueda copiar y enviar. Las direcciones Bluetooth se enmascaran.
SONDAP=${MG_SONDAP:-/sdcard/MaxG_power_rendimiento.txt}
SONDAH=${MG_SONDAH:-/sdcard/MaxG_power_sonda.txt}
tm_now() {   # reloj en milisegundos sin desbordar los 32 bits del sh de Android: segundos y milisegundos por separado
  tn=$(date +%s%N 2>/dev/null)
  case "$tn" in ''|*[!0-9]*) tn=$(date +%s)000000000 ;; esac
  TNs=${tn%?????????}; TNn=${tn#"$TNs"}; TNms=$(( (1$TNn - 1000000000) / 1000000 ))
}
tm_start() { tm_now; T0s=$TNs; T0ms=$TNms; }
tm_ms() { tm_now; TMV=$(( (TNs - T0s) * 1000 + TNms - T0ms )); }
sd_proc() {   # nombre del vigilante -> uso de CPU acumulado desde que arrancó
  sp_n=$1; sp_pid=""; [ -r "$CONF/$sp_n.pid" ] && read -r sp_pid < "$CONF/$sp_n.pid"
  if [ -z "$sp_pid" ] || ! kill -0 "$sp_pid" 2>/dev/null || [ ! -r "/proc/$sp_pid/stat" ]; then echo "$sp_n: detenido"; return 0; fi
  read -r sp_l < "/proc/$sp_pid/stat"; sp_r=${sp_l##*) }; set -- $sp_r; shift 11
  sp_ut=$1; sp_st=$2; sp_cu=$3; sp_cs=$4; shift 8; sp_start=$1
  read -r sp_up _ < /proc/uptime; sp_up=${sp_up%.*}
  isnum "$sp_ut" && isnum "$sp_st" && isnum "$sp_start" && isnum "$sp_up" || { echo "$sp_n: vivo ($sp_pid), sin datos"; return 0; }
  sp_run=$(( sp_up - sp_start / 100 )); [ "$sp_run" -lt 1 ] && sp_run=1
  sp_own=$(( sp_ut + sp_st )); sp_kid=$(( ${sp_cu:-0} + ${sp_cs:-0} ))
  sp_pct=$(( (sp_own + sp_kid) * 100 / sp_run ))   # centésimas de % de un núcleo
  echo "$sp_n: vivo ($sp_pid) · activo desde hace ${sp_run} s · CPU propia $((sp_own/100)).$(printf '%02d' $((sp_own%100))) s + procesos hijos $((sp_kid/100)).$(printf '%02d' $((sp_kid%100))) s = $((sp_pct/100)).$(printf '%02d' $((sp_pct%100))) % de un núcleo"
}
sd_time() {   # etiqueta + orden de ctl -> tiempo de pared
  tm_start; sh "$MODDIR/ctl.sh" "$@" >/dev/null 2>&1; tm_ms; echo "  ctl $* -> $TMV ms"
}
sonda_perf_body() {
  echo "MaxG Power · sonda de rendimiento · $(date '+%F %T')"
  echo "módulo: $(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n 1) · dispositivo: $(dev_name) · kernel $(uname -r 2>/dev/null) · $(getprop ro.build.display.id 2>/dev/null) · Android $(getprop ro.build.version.release 2>/dev/null)"
  read -r sb_up _ < /proc/uptime 2>/dev/null; echo "encendido desde hace ${sb_up%.*} s · SELinux: $(getenforce 2>/dev/null)"
  echo; echo "## Perfil y vigilantes"
  echo "perfil elegido: $(cfg_get profile stock) · temporal del modo inteligente: $(cat "$AUTOF" 2>/dev/null) · calor: $(cfg_get heat_mode off) · mando: $(cfg_get pad 0) · gpu_mode: $(cfg_get gpu_mode auto)"
  for sb_d in autod heatd padd gpud; do sd_proc "$sb_d"; done
  echo; echo "## Quién ocupa el teléfono ahora (top, 1 muestra)"
  { $TMO top -b -n 1 -m 12 2>/dev/null </dev/null || $TMO ps -A -o PID,%CPU,NAME 2>/dev/null </dev/null | head -n 15; } | cut -c1-120
  echo; echo "## Presión del sistema (PSI: avg10 alto = el teléfono va justo)"
  for sb_f in cpu memory io; do echo "$sb_f: $(rd "/proc/pressure/$sb_f" | cut -c1-120)"; [ -r "/proc/pressure/$sb_f" ] && sed -n '2p' "/proc/pressure/$sb_f" 2>/dev/null; done
  echo "loadavg: $(cat /proc/loadavg 2>/dev/null)"
  grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree|Dirty' /proc/meminfo 2>/dev/null
  echo "zram mm_stat: $(rd /sys/block/zram0/mm_stat)"
  echo; echo "## Frecuencias ahora (6 muestras cada 0,5 s)"
  pol_warm; sb_i=0
  while [ "$sb_i" -lt 6 ]; do
    sb_l=""; for sb_p in $(policies); do sb_l="$sb_l p$sb_p=$(rd "$CPUF/policy$sb_p/scaling_cur_freq")/$(rd "$CPUF/policy$sb_p/scaling_max_freq")"; done
    echo "  CPU$sb_l · GPU $(rd "$GPUD/devfreq/cur_freq")/$(rd "$GPUD/devfreq/max_freq") ocupación $(rd "$GPUD/gpu_busy_percentage")"
    sb_i=$((sb_i+1)); sleep 0.5 2>/dev/null || sleep 1
  done
  echo "gobernadores: $(for sb_p in $(policies); do printf 'p%s=%s ' "$sb_p" "$(rd "$CPUF/policy$sb_p/scaling_governor")"; done)"
  echo "walt hispeed_load: $(for sb_p in $(policies); do printf 'p%s=%s ' "$sb_p" "$(rd "$CPUF/policy$sb_p/walt/hispeed_load")"; done) · sched_conservative_pl=$(rd "$R/proc/sys/walt/sched_conservative_pl")"
  echo; echo "## GPU y limitadores de la ROM"
  gpu_be; echo "backend de GPU: $GBE · $(gpu_rom_fields) (backend|MHz tope del módulo|MHz límite de la ROM|nivel que pide la ROM)"
  gpu_rom_level; echo "  cooling device de la GPU (lo que pide la ROM): ${GRP:-?} · nivel ${RLV:-?}  (thermal_pwrlevel puede ser el tope del propio módulo en este kernel)"
  for sb_n in max_pwrlevel min_pwrlevel thermal_pwrlevel default_pwrlevel max_gpuclk max_clock_mhz min_clock_mhz gpuclk gpu_busy_percentage throttling; do echo "  $sb_n=$(rd "$GPUD/$sb_n")"; done
  rom_limits
  for sb_f in balance_mode temp_state special_cpu_limit cpu_limits modem_limit wifi_limit screen_state; do echo "  thermal_message/$sb_f=$(rd "$R/sys/class/thermal/thermal_message/$sb_f")"; done
  echo "topes que el módulo mantiene vs los que tiene el kernel:"
  for sb_p in $(policies); do echo "  policy$sb_p: deseado=$(knob_des cpu_max_$sb_p) kernel=$(rd "$CPUF/policy$sb_p/scaling_max_freq") mín=$(rd "$CPUF/policy$sb_p/scaling_min_freq")"; done
  echo "  gpu_max: deseado=$(knob_des gpu_max) kernel(usuario)=$(knob_cur gpu_max) · original guardado=$(knob_orig gpu_max)"
  echo; echo "## Temperaturas y batería"
  cpu_temp10_v; bat_temp10_v; skin_temp10_v; echo "cpu=$CT10 batería=$BT10 carcasa=$SK10 (décimas de °C)"
  for sb_z in "$R"/sys/class/thermal/thermal_zone*; do [ -r "$sb_z/type" ] && echo "  ${sb_z##*/}: $(rd "$sb_z/type") = $(rd "$sb_z/temp")"; done | head -n 90
  for sb_n in status capacity current_now temp; do echo "  batería $sb_n=$(rd "$R/sys/class/power_supply/battery/$sb_n")"; done
  echo; echo "## Pantalla"
  echo "  modos: $(dumpsys display 2>/dev/null </dev/null | grep -o 'fps=[0-9.]*' | sort -u | tr '\n' ' ')"
  echo "  peak_refresh_rate=$(settings get system peak_refresh_rate 2>/dev/null) min_refresh_rate=$(settings get system min_refresh_rate 2>/dev/null) user_refresh_rate=$(settings get system user_refresh_rate 2>/dev/null)"
  echo; echo "## Tiempo de cambio de perfil (lo que tarda la orden de la app; el teléfono vuelve a tu perfil al terminar)"
  if [ -e "$CONF/safe" ]; then echo "  (omitida: modo seguro activo)"
  elif ! is_target >/dev/null 2>&1; then echo "  (omitida: no es el dispositivo esperado)"
  else
    sd_time state boot; sd_time state static; sd_time state more; sd_time state live
    if [ -n "${MG_SONDA_USE-}" ]; then echo "  (no se cambia de perfil: sonda en uso)"
    else
      sb_p0=$(cfg_get profile stock)
      for sb_x in diario alto ahorro; do sd_time profile "$sb_x"; sd_time state live; done
      sd_time profile "$sb_p0"; echo "  (perfil devuelto a: $sb_p0)"
    fi
  fi
  echo; echo "## Archivos de estado"
  echo "-- cfg"; cat "$CFG" 2>/dev/null
  echo "-- desired (lo que el módulo mantiene)"; cat "$DES" 2>/dev/null
  echo "-- extras: $(cat "$CONF/extras.on" >/dev/null 2>&1 && echo aplicados || echo sin aplicar)"
  echo; echo "## Registro (últimas 100 líneas)"; tail -n 100 "$LOG" 2>/dev/null
  [ -n "${SD_NOFIN-}" ] || { echo; echo FIN; }
}
sonda_perf() {
  sp_tmp="$SONDAP.t"
  sonda_perf_body 2>&1 | sed 's/\([0-9A-Fa-f][0-9A-Fa-f]:\)\{4\}\([0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]\)/XX:XX:XX:XX:\2/g' | head -c 200000 > "$sp_tmp" 2>/dev/null
  [ -s "$sp_tmp" ] || { rm -f "$sp_tmp"; return 1; }
  mv -f "$sp_tmp" "$SONDAP"; chmod 0666 "$SONDAP" 2>/dev/null; log "sonda de rendimiento generada"; echo "$SONDAP"
}
sonda_file() {   # deep|hw|perf|info -> ruta del archivo (si existe)
  case "$1" in hw) sf_f=$SONDAH ;; perf) sf_f=$SONDAP ;; deep) sf_f=${MG_SONDAD:-/sdcard/MaxG_power_profunda.txt} ;; info) sf_f=${MG_REPORT:-/sdcard/MaxG_power_informe.txt} ;; *) return 1 ;; esac
  [ -s "$sf_f" ] && echo "$sf_f"
}
sonda_list() {   # una línea por sonda: SONDA|clave|ruta|bytes|fecha
  for sl_k in deep hw perf info; do
    sl_f=$(sonda_file "$sl_k") || { echo "SONDA|$sl_k||0|"; continue; }
    sl_b=$(wc -c < "$sl_f" 2>/dev/null | tr -d ' '); sl_d=$(date -r "$sl_f" '+%F %T' 2>/dev/null)
    echo "SONDA|$sl_k|$sl_f|${sl_b:-0}|$sl_d"
  done
}

# ====== v3.12: hallazgos automáticos y sonda profunda ======
SONDAD=${MG_SONDAD:-/sdcard/MaxG_power_profunda.txt}
fd_n=0
fd() { fd_n=$((fd_n+1)); echo "FIND|$1|$2|$3"; }   # nivel(alto|medio|info) título texto  (sin el carácter |)
psi10() {   # cpu|memory|io -> avg10 entero
  pv_l=$(rd "$R/proc/pressure/$1"); pv_v=0
  case "$pv_l" in *avg10=*) pv_v=${pv_l#*avg10=}; pv_v=${pv_v%% *}; pv_v=${pv_v%.*} ;; esac
  isnum "$pv_v" || pv_v=0; echo "$pv_v"
}
t1() { echo "$(($1/10)),$(($1%10))"; }
sonda_findings() {   # rápida (sin muestreo largo): qué está pisando al módulo y qué se puede mejorar
  fd_n=0; pol_warm
  sf_fm=$(cfg_get heat_mode off); sf_fb=$(cfg_get burst off); sf_fp=$(eff_profile)
  cpu_temp10_v; bat_temp10_v; skin_temp10_v
  # 1) alguien pisa los topes que el módulo mantiene
  for sf_p in $(policies); do
    sf_d=$(knob_des "cpu_max_$sf_p"); sf_k=$(rd "$CPUF/policy$sf_p/scaling_max_freq")
    if isnum "$sf_d" && isnum "$sf_k" && [ "$sf_d" != "$sf_k" ]; then
      fd alto "Algo pisa el tope de la CPU (clúster $sf_p)" "El módulo quiere $((sf_d/1000)) MHz pero el kernel tiene $((sf_k/1000)) MHz. Lo cambió la ROM u otro módulo; el módulo lo vuelve a poner cada 45 s. Mira «Quién manda ahora» y «Choques»."
    fi
  done
  sf_d=$(knob_des gpu_max); sf_k=$(knob_cur gpu_max)
  if isnum "$sf_d" && isnum "$sf_k" && [ "$sf_d" != "$sf_k" ]; then fd alto "Algo pisa el tope de la GPU" "El módulo quiere $sf_d y el kernel tiene $sf_k (nivel o MHz según tu kernel). Lo cambió la ROM u otro módulo."; fi
  # 2) límites de la ROM
  sf_r=$(rom_limits 2>/dev/null); sf_r=${sf_r#ROMLIM?}; sf_l=""
  if [ -n "$sf_r" ]; then
    sf_o=$IFS; IFS=,; set -- $sf_r; IFS=$sf_o
    sf_gl=""
    for sf_x in "$@"; do sf_n=${sf_x%%=*}; case "$sf_n" in ufs|ddr-cdev|display-fps|"") continue ;; gpu) sf_gl=$sf_x; continue ;; esac; sf_l="$sf_l $sf_x"; done
  fi
  if [ -n "${sf_gl-}" ]; then   # la GPU limitada por la ROM: en frío es el tope de fábrica, no calor
    sf_gs=${sf_gl#*=}; sf_gc=${sf_gs%%/*}; sf_gm=${sf_gs#*/}; sf_mh="?"; gpu_hz_of_level "$sf_gc" && sf_mh=$((HZV/1000000))
    if [ "$BT10" -lt 400 ] && [ "$SK10" -lt 400 ]; then
      fd info "La ROM limita la GPU a $sf_mh MHz (nivel $sf_gc de $sf_gm)" "El teléfono está frío (batería $(t1 "$BT10") °C · carcasa $(t1 "$SK10") °C): no es calor, es el tope de fábrica de HyperOS para el uso normal. El módulo nunca pasa de ese tope, así que Diario y Alto no suben la GPU más. Para rebasarlo: modo de GPU «Máximo» (quita el freno; la GPU puede calentar más)."
    else
      fd medio "La ROM limita la GPU a $sf_mh MHz (nivel $sf_gc de $sf_gm)" "Batería $(t1 "$BT10") °C · carcasa $(t1 "$SK10") °C: la ROM la frena por temperatura o carga. El control de calor y la ráfaga sostenida ayudan a que no frene de golpe."
    fi
  fi
  [ -n "$sf_l" ] && fd medio "La ROM limita el rendimiento" "Limitadores activos:${sf_l}. Son límites térmicos o de carga de la ROM: el módulo no puede subirlos. El control de calor y la ráfaga sostenida ayudan a que no lleguen a frenar de golpe."
  # 3) temperatura
  sf_hot=0; { [ "$BT10" -ge 420 ] || [ "$CT10" -ge 850 ] || [ "$SK10" -ge 430 ]; } && sf_hot=1
  if [ "$sf_hot" = 1 ] && [ "$sf_fm" = off ]; then fd alto "Calor alto y el control de calor está apagado" "Batería $(t1 "$BT10") °C · CPU $(t1 "$CT10") °C · carcasa $(t1 "$SK10") °C. Activa el control de calor (suave o normal) en Perfiles: recorta unos puntos antes de que la ROM frene de golpe."
  elif [ "$sf_hot" = 1 ] && [ "$sf_fb" = off ]; then fd info "Oportunidad: ráfaga sostenida" "El teléfono está caliente (batería $(t1 "$BT10") °C · CPU $(t1 "$CT10") °C). Prueba la ráfaga sostenida de 30 s en Perfiles: más fresco sin perder los picos."; fi
  # 4) control manual
  if manual_on_p; then
    manual_has || fd medio "Control manual ON sin ajuste guardado" "El manual está encendido pero no hay un ajuste propio guardado. Apágalo o ajusta los controles y pulsa Aplicar ahora."
    cx_ignored; [ -n "$CXI" ] && fd info "Control manual ON" "Se ignoran: $CXI. Si no lo querías así, apágalo en la pestaña Manual."
  fi
  # 5) vigilantes caídos
  [ "$(cfg_get auto 1)" = 1 ] && ! autod_alive && fd alto "El modo inteligente no está corriendo" "Está activado pero su vigilante no está vivo. El supervisor lo reinicia cada 45 s; si sigue así, apágalo y vuelve a encenderlo."
  { [ "$sf_fm" != off ] || [ "$sf_fb" != off ]; } && ! heatd_alive && fd alto "El vigilante de calor no está corriendo" "El control de calor o la ráfaga están activados pero el vigilante no está vivo. Vuelve a elegir el modo de calor."
  [ "$(cfg_get pad 0)" = 1 ] && ! padd_alive && fd medio "El vigilante del mando no está corriendo" "El modo mando está activado pero su vigilante no está vivo; el supervisor lo reinicia cada 45 s."
  { [ "$(cfg_get gpu_floor 0)" != 0 ] || [ "$(cfg_get gpu_free 0)" = 1 ]; } && ! gpud_alive && fd medio "El vigilante de GPU no está corriendo" "Hay piso o tope libre de GPU puesto pero su vigilante no está vivo; el supervisor lo reinicia cada 45 s."
  # 6) arranque
  [ -e "$CONF/safe" ] && fd alto "Modo seguro activo" "Hubo 3 arranques seguidos sin estabilizarse: el módulo no aplica nada al arrancar. Desactívalo desde la app cuando lo hayas revisado."
  rdv "$BOOTC"; isnum "$RV" && [ "$RV" -ge 2 ] && fd medio "Arranques sin estabilizar" "Van $RV arranques seguidos sin llegar a estable. Con 3 entra el modo seguro. Mira el registro."
  # 7) recursos compartidos con varios dueños
  claim_status > "$CONF/fd.t" 2>/dev/null
  while IFS='|' read -r _ sf_cr sf_co _; do case "$sf_co" in *" "*) fd info "Recursos compartidos" "«${sf_cr#*:}» lo piden varias funciones ($sf_co); el árbitro deja mandar a la de más prioridad." ;; esac; done < "$CONF/fd.t"; rm -f "$CONF/fd.t"
  # 8) Bluetooth
  if bt_on; then
    if [ "$(cfg_get bt_prio 1)" = 1 ]; then
      sf_n=$(bt_proc_nice); case "$sf_n" in -|"") ;; *) sf_m=${sf_n%%/*}; case "$sf_m" in -*) ;; *) isnum "$sf_m" && fd medio "La prioridad del Bluetooth no está aplicada" "La prioridad permanente está activada pero los hilos de la pila siguen en prioridad normal ($sf_n). Pulsa Reiniciar Bluetooth en la pestaña Mando; el supervisor la reaplica cada 45 s." ;; esac ;; esac
    fi
    sf_b=$(bt_wifi_band); [ "$sf_b" = 2.4 ] && fd info "Wi-Fi en 2,4 GHz con Bluetooth encendido" "El Wi-Fi de 2,4 GHz comparte banda con el Bluetooth (audífonos y mandos): si puedes, conéctate a la red de 5 GHz para tener menos cortes."
  fi
  sf_px=$(padx_status); sf_c24=0
  IFS='|' read -r _ _ _ _ _ sf_c24 _ <<EOF
$sf_px
EOF
  if isnum "$sf_c24" && [ "$sf_c24" -ge 3 ]; then
    if [ "$(cfg_get bt_fast 0)" = 1 ]; then fd alto "Cortes de Bluetooth con la conexión rápida" "$sf_c24 cortes en 24 h. Apaga «Conexión Bluetooth rápida» (la autoprotección lo hace sola tras 3 cortes en 15 min) y compara."
    else fd medio "Cortes de Bluetooth" "$sf_c24 cortes en 24 h con la conexión normal. Activa la prioridad permanente de la pila, revisa que el Wi-Fi no esté en 2,4 GHz y que no haya dos dispositivos compitiendo por la radio."; fi
  fi
  # 9) presión del sistema
  sf_pc=$(psi10 cpu); sf_pm=$(psi10 memory); sf_pi=$(psi10 io)
  [ "$sf_pc" -ge 25 ] && fd medio "La CPU va justa" "Presión de CPU (PSI avg10) al $sf_pc %: hay tareas esperando núcleo. Revisa qué ocupa el teléfono o sube el perfil."
  [ "$sf_pm" -ge 10 ] && fd medio "Poca memoria libre" "Presión de memoria (PSI avg10) al $sf_pm %: Android está matando o comprimiendo apps. Cierra apps pesadas o sube la swappiness en Manual."
  [ "$sf_pi" -ge 20 ] && fd info "El almacenamiento va lento" "Presión de E/S (PSI avg10) al $sf_pi %: algo está leyendo o escribiendo mucho. Puede ser una actualización o el mantenimiento."
  # 10) oportunidades de la GPU
  sf_fl=$(cfg_get gpu_floor 0); rdv "$GPUD/gpu_busy_percentage"; sf_bz=${RV%%[!0-9]*}
  [ "$sf_fl" != 0 ] && isnum "$sf_bz" && [ "$sf_bz" -lt 25 ] && [ "$(cfg_get gpu_scope always)" = always ] && fd info "Piso de GPU alto con poca carga" "La GPU está al $sf_bz % de ocupación con un piso de $sf_fl MHz: gasta calor sin necesidad. Pon el piso en «Solo en juegos» (pestaña GPU)."
  # 11) Android y otros módulos (caché que mantiene el supervisor)
  cx_saver_on && fd medio "Ahorro de batería de Android encendido" "Android recorta CPU y GPU por su cuenta y puede dejar los perfiles a medias. Apágalo si quieres que mande el módulo."
  if [ -r "$CXMODS" ]; then
    while IFS='|' read -r sf_mi sf_mn sf_mt; do
      [ -n "$sf_mi" ] && [ "$sf_mt" != name ] && fd medio "Otro módulo toca la CPU o la GPU: $sf_mn" "Lo vi en sus scripts ($sf_mt). Dos ajustadores a la vez se pisan; si algo no se aplica, prueba con uno solo."
    done < "$CXMODS"
  fi
  # 12) el kernel rechaza escrituras
  sf_n=$(grep -c 'el kernel no aceptó' "$LOG" 2>/dev/null); isnum "$sf_n" || sf_n=0
  [ "$sf_n" -ge 3 ] && fd medio "El kernel rechaza algunas escrituras" "$sf_n avisos «el kernel no aceptó…» en el registro: algún nodo de la GPU es de solo lectura o no existe en tu kernel. Mira la prueba «¿Qué acepta tu GPU?» en la pestaña GPU."
  [ "$fd_n" -eq 0 ] && fd info "Todo en orden" "No encontré nada que pise al módulo ni nada claro que mejorar ahora mismo. Genera la sonda profunda si quieres revisar con más detalle."
  echo "FINDEND|$fd_n"
}
sd_sample() {   # muestreo con estadísticas: CPU por clúster, GPU y temperaturas
  ss_n=${MG_SONDAN:-20}; ss_dt=${MG_SONDADT:-0.5}; pol_warm; ss_i=0
  for ss_p in $(policies); do eval "ss_s_$ss_p=0; ss_lo_$ss_p=999999999; ss_hi_$ss_p=0; ss_h_$ss_p=0; ss_m_$ss_p=0; ss_k_$ss_p=0"; done
  ss_gs=0; ss_glo=999999; ss_ghi=0; ss_gb=0; ss_gbh=0; ss_gk=0; ss_tc=0; ss_tb=0; ss_tk=0
  while [ "$ss_i" -lt "$ss_n" ]; do
    for ss_p in $(policies); do
      rdv "$CPUF/policy$ss_p/scaling_cur_freq"; ss_c=$RV; rdv "$CPUF/policy$ss_p/scaling_max_freq"; ss_x=$RV
      isnum "$ss_c" || continue; isnum "$ss_x" || ss_x=0
      eval "ss_s_$ss_p=\$((ss_s_$ss_p+ss_c)); [ $ss_c -lt \$ss_lo_$ss_p ] && ss_lo_$ss_p=$ss_c; [ $ss_c -gt \$ss_hi_$ss_p ] && ss_hi_$ss_p=$ss_c; ss_m_$ss_p=$ss_x; ss_k_$ss_p=\$((ss_k_$ss_p+1))"
      if [ "$ss_x" -gt 0 ] && [ $((ss_c*100)) -ge $((ss_x*93)) ]; then eval "ss_h_$ss_p=\$((ss_h_$ss_p+1))"; fi
    done
    rdv "$GPUD/devfreq/cur_freq"; if isnum "$RV"; then ss_g=$((RV/1000000)); ss_gs=$((ss_gs+ss_g)); ss_gk=$((ss_gk+1)); [ "$ss_g" -lt "$ss_glo" ] && ss_glo=$ss_g; [ "$ss_g" -gt "$ss_ghi" ] && ss_ghi=$ss_g; fi
    rdv "$GPUD/gpu_busy_percentage"; ss_b=${RV%%[!0-9]*}; if isnum "$ss_b"; then ss_gb=$((ss_gb+ss_b)); [ "$ss_b" -ge 80 ] && ss_gbh=$((ss_gbh+1)); fi
    if [ $((ss_i % 4)) -eq 0 ]; then cpu_temp10_v; bat_temp10_v; skin_temp10_v; [ "$CT10" -gt "$ss_tc" ] && ss_tc=$CT10; [ "$BT10" -gt "$ss_tb" ] && ss_tb=$BT10; [ "$SK10" -gt "$ss_tk" ] && ss_tk=$SK10; fi
    ss_i=$((ss_i+1)); sleep "$ss_dt" 2>/dev/null || sleep 1
  done
  echo "$ss_i muestras cada $ss_dt s"; ss_top=0
  for ss_p in $(policies); do
    eval "ss_a=\$ss_s_$ss_p; ss_l=\$ss_lo_$ss_p; ss_u=\$ss_hi_$ss_p; ss_h=\$ss_h_$ss_p; ss_x=\$ss_m_$ss_p; ss_q=\$ss_k_$ss_p"
    [ "$ss_q" -gt 0 ] || { echo "  policy$ss_p: sin lecturas"; continue; }
    ss_pc=$((ss_h*100/ss_q)); [ "$ss_pc" -gt "$ss_top" ] && ss_top=$ss_pc
    echo "  policy$ss_p: frecuencia mín/media/máx = $((ss_l/1000))/$((ss_a/ss_q/1000))/$((ss_u/1000)) MHz · tope $((ss_x/1000)) MHz · al 93 % o más del tope: $ss_h de $ss_q muestras ($ss_pc %)"
  done
  if [ "$ss_gk" -gt 0 ]; then echo "  GPU: mín/media/máx = $ss_glo/$((ss_gs/ss_gk))/$ss_ghi MHz · ocupación media $((ss_gb/ss_gk)) % · con más de 80 % de ocupación: $ss_gbh de $ss_gk muestras"; fi
  echo "  temperaturas máximas: CPU $(t1 "$ss_tc") °C · batería $(t1 "$ss_tb") °C · carcasa $(t1 "$ss_tk") °C"
  if [ "$ss_top" -ge 70 ]; then echo "  LECTURA: una CPU pasa casi todo el rato al tope ($ss_top % de las muestras): hay carga sostenida. Si además hay calor, la ráfaga sostenida o un perfil un escalón más bajo ayudan."
  elif [ "$ss_top" -le 10 ]; then echo "  LECTURA: la CPU casi no llega a su tope ($ss_top %): el perfil actual no es lo que te limita."
  else echo "  LECTURA: la CPU llega al tope de vez en cuando ($ss_top %): carga mixta."; fi
}
sd_nodes() {   # lista de nodos con su valor y si son escribibles
  for sn_f in "$@"; do [ -f "$sn_f" ] || continue; sn_w=ro; [ -w "$sn_f" ] && sn_w=rw
    case "$sn_f" in */proc/*) sn_v=$(cat "$sn_f" 2>/dev/null | head -c 60 | tr '\n\t' '  ') ;; *) sn_v=""; [ -r "$sn_f" ] && { read -r sn_v < "$sn_f"; } 2>/dev/null ;; esac
    echo "  [$sn_w] ${sn_f#"$R"} = $(printf '%s' "$sn_v" | cut -c1-70)"
  done
}
sd_cs() {   # SDCS = centésimas de segundo desde el arranque, sin subproceso
  SDCS=0; read -r sdc_u _ < /proc/uptime 2>/dev/null || return 0
  sdc_f=${sdc_u#*.}; sdc_f=${sdc_f}00; sdc_f=${sdc_f%"${sdc_f#??}"}
  SDCS=$(( ${sdc_u%.*} * 100 + 1$sdc_f - 100 ))
}
SD_TT=""; SD_LAST=""
sd_mark() {   # sd_mark "nombre de la sección que empieza": apunta cuánto tardó la anterior
  sd_cs; [ -n "$SD_LAST" ] && SD_TT="$SD_TT  $SD_LASTN: $(( (SDCS - SD_LAST) * 10 )) ms$NL"
  SD_LAST=$SDCS; SD_LASTN=$1
}
sd_rec() {   # la última grabación de sesión (pestaña GPU): resumen y filas (como mucho ~120)
  [ -s "$REC_OUT" ] || { echo "  (sin grabación de sesión: graba una partida en la pestaña GPU o usa «Profunda en uso»)"; return 0; }
  echo "  archivo: $REC_OUT · $(date -r "$REC_OUT" '+%F %T' 2>/dev/null)"
  sr_n=$(wc -l < "$REC_OUT" 2>/dev/null | tr -d ' '); isnum "$sr_n" || sr_n=0; sr_st=$(( (sr_n + 119) / 120 )); [ "$sr_st" -ge 1 ] || sr_st=1
  sr_i=0; while IFS= read -r sr_l; do
    case "$sr_l" in "# resumen"*) echo "  ${sr_l#?}"; continue ;; "#"*) continue ;; esac
    if [ $(( sr_i % sr_st )) -eq 0 ] || [ "$sr_i" -eq 0 ]; then echo "    $sr_l"; fi; sr_i=$((sr_i+1))
  done < "$REC_OUT"
}
sonda_deep_body() {
  SD_NOFIN=1
  echo "MaxG Power · sonda PROFUNDA · $(date '+%F %T')"
  echo "módulo: $(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n 1) · dispositivo: $(dev_name) · kernel $(uname -r 2>/dev/null) · $(getprop ro.build.display.id 2>/dev/null) · Android $(getprop ro.build.version.release 2>/dev/null)"
  read -r sd_up _ < /proc/uptime 2>/dev/null; echo "encendido desde hace ${sd_up%.*} s · SELinux: $(getenforce 2>/dev/null)"
  SD_TT=""; SD_LAST=""; sd_mark "1 hallazgos"
  echo; echo "## 1. HALLAZGOS (qué está pisando al módulo y qué se puede mejorar)"
  sonda_findings | while IFS='|' read -r fa fb fc fdd; do case "$fa" in FIND) echo "[$fb] $fc"; echo "      $fdd" ;; FINDEND) echo "(total: $fb)" ;; esac; done
  sd_mark "2 quién manda"; echo; echo "## 2. QUIÉN MANDA y CHOQUES"
  conflicts_who
  conflicts_scan
  echo "(choques: $CX_N · avisos: $CX_W)"
  sd_mark "3 muestreo"; echo; echo "## 3. MUESTREO (carga y calor reales ahora)"
  sd_sample
  if [ -z "${MG_SONDA_USE-}" ]; then echo; echo "## 3b. ÚLTIMA GRABACIÓN DE SESIÓN (la de la pestaña GPU; si es de hace rato, no es de este momento)"; sd_rec; fi
  sd_mark "4 deseado vs kernel"; echo; echo "## 4. DESEADO vs KERNEL (lo que el módulo mantiene frente a lo que tiene el kernel)"
  for sd_p in $(policies); do echo "  cpu_max_$sd_p: deseado=$(knob_des cpu_max_$sd_p) kernel=$(rd "$CPUF/policy$sd_p/scaling_max_freq") original=$(knob_orig cpu_max_$sd_p)"; done
  echo "  gpu_max: deseado=$(knob_des gpu_max) kernel=$(knob_cur gpu_max) original=$(knob_orig gpu_max)"
  echo "  veces que el kernel no aceptó una escritura (registro): $(grep -c 'el kernel no aceptó' "$LOG" 2>/dev/null)"
  echo "  reaplicaciones por el supervisor (registro): $(grep -c 'reaplic' "$LOG" 2>/dev/null)"
  sd_mark "5 bluetooth"; echo; echo "## 5. BLUETOOTH A FONDO"
  echo "  encendido: $(bt_on && echo sí || echo no) · conexión rápida: $(cfg_get bt_fast 0) · prioridad permanente: $(cfg_get bt_prio 1) · guardia: $(cfg_get bt_guard 1) · autoprotección: $(cfg_get bt_autofix 1)"
  echo "  pila (pid $(pidof com.android.bluetooth 2>/dev/null)) · prioridad de los hilos mín/máx/n: $(bt_proc_nice)"
  echo "  Wi-Fi: banda $(bt_wifi_band) GHz ($(wifi_mhz) MHz) · lista blanca de Doze: $(btg_has_wl && echo sí || echo no)"
  echo "  $(padx_status)"
  echo "  $(bt_extra_status)"
  echo "  propiedades:"; getprop 2>/dev/null | grep -i 'bluetooth' | head -n 40 | cut -c1-140 | sed 's/^/    /'
  sd_bt="$CONF/sd.bt"; $TMO dumpsys bluetooth_manager > "$sd_bt" 2>/dev/null </dev/null
  echo "  dumpsys bluetooth_manager (sin la lista de funciones [ ] / [■], que no sirve): conexión, códec, offload, latencia"
  grep -v -E '^[[:space:]]*\[[^]]*\]:' "$sd_bt" 2>/dev/null | grep -i -E 'ConnectionState|A2dpOffload|offload|codec|active ?device|latency|interval|sniff|bond state|connected|le audio|hearing' | grep -v -i 'processProfileServiceStateChanged' | head -n 70 | cut -c1-170 | sed 's/^/    /'
  echo "  bloque A2DP (45 líneas desde «A2DP:»):"
  sed -n '/^[[:space:]]*A2DP:/,$p' "$sd_bt" 2>/dev/null | head -n 45 | cut -c1-170 | sed 's/^/    /'
  echo "  bloque LE Audio (30 líneas desde «LE Audio:»):"
  sed -n '/^[[:space:]]*LE Audio:/,$p' "$sd_bt" 2>/dev/null | head -n 30 | cut -c1-170 | sed 's/^/    /'
  rm -f "$sd_bt"
  echo "  latencia de audio (dumpsys media.audio_flinger: hilos de salida, tamaño de búfer, desbordes):"
  $TMO dumpsys media.audio_flinger 2>/dev/null </dev/null | grep -i -E 'Output thread|Standby|latency|HAL frame count|Normal frame count|Sample rate|Output device|AUDIO_DEVICE_OUT_BLUETOOTH|a2dp|underrun|Total writes|Delayed writes|Blocked in write' | head -n 60 | cut -c1-170 | sed 's/^/    /'
  echo "  audio (dumpsys audio: dispositivo activo, códec y volumen):"
  $TMO dumpsys audio 2>/dev/null </dev/null | grep -i -E 'a2dp|bluetooth|codec|latency|Active communication|Audio mode' | head -n 30 | cut -c1-170 | sed 's/^/    /'
  sd_mark "6 capacidades"; echo; echo "## 6. CAPACIDADES (qué nodos existen y se pueden escribir)"
  pol_warm
  for sd_p in $(policies); do echo " -- cpufreq/policy$sd_p"; sd_nodes "$CPUF/policy$sd_p"/walt/* "$CPUF/policy$sd_p/scaling_governor" "$CPUF/policy$sd_p/scaling_min_freq" "$CPUF/policy$sd_p/scaling_max_freq"; done | head -n 90
  echo " -- /proc/sys/walt y planificador"; sd_nodes "$R"/proc/sys/walt/* "$R/proc/sys/kernel/sched_energy_aware" "$R/proc/sys/kernel/sched_util_clamp_min" "$R/proc/sys/kernel/sched_util_clamp_max" | head -n 160
  echo " -- GPU (kgsl)"; sd_nodes "$GPUD"/* | head -n 110
  echo " -- thermal_message"; sd_nodes "$R"/sys/class/thermal/thermal_message/* | head -n 20
  echo " -- msm_performance / cpu_boost / core_ctl"; sd_nodes "$R"/sys/module/msm_performance/parameters/* "$R"/sys/module/cpu_boost/parameters/* "$R"/sys/devices/system/cpu/cpu0/core_ctl/* "$R"/sys/devices/system/cpu/cpu6/core_ctl/* | head -n 40
  echo " -- devfreq (GPU, memoria, DDR, LLCC...): gobernador · frecuencia actual · mínimo · máximo"
  for sd_d in "$R"/sys/class/devfreq/*; do [ -d "$sd_d" ] || continue
    rdv "$sd_d/governor"; sd_gv=$RV; rdv "$sd_d/cur_freq"; sd_cf=$RV; rdv "$sd_d/min_freq"; sd_mf=$RV; rdv "$sd_d/max_freq"; sd_xf=$RV
    echo "  ${sd_d##*/}: $sd_gv · $sd_cf · $sd_mf · $sd_xf"
  done | head -n 40
  echo " -- bus_dcvs (DDR / LLCC / L3 de Qualcomm: los topes de memoria que sigue el rendimiento de verdad)"
  for sd_d in "$R"/sys/devices/system/cpu/bus_dcvs/*; do [ -d "$sd_d" ] || continue
    echo "  ${sd_d##*/}:"; sd_nodes "$sd_d"/*; for sd_e in "$sd_d"/*; do [ -d "$sd_e" ] && sd_nodes "$sd_e"/*; done
  done | head -n 140
  echo " -- memoria"; sd_nodes "$R/proc/sys/vm/swappiness" "$R/proc/sys/vm/page-cluster" "$R/sys/kernel/mm/lru_gen/min_ttl_ms" "$R/sys/block/zram0/disksize"
  sd_mark "6b ideas"; echo; echo "## 6b. IDEAS DE MEJORA (nodos presentes que el módulo todavía no usa)"
  sd_idea() { [ -e "$1" ] && echo "  - ${1#"$R"}: $2"; }
  sd_idea "$CPUF/policy0/walt/hispeed_freq" "frecuencia a la que salta la CPU al pasar hispeed_load; bajarla recorta picos que solo calientan."
  sd_idea "$CPUF/policy6/walt/hispeed_freq" "igual para los núcleos prime."
  sd_idea "$R/proc/sys/walt/sched_upmigrate" "cuándo una tarea pasa a los núcleos grandes; subirlo = más fresco, algo menos de respuesta."
  sd_idea "$R/proc/sys/walt/sched_downmigrate" "cuándo vuelve a los núcleos pequeños."
  sd_idea "$R/proc/sys/walt/sched_boost" "boost del planificador: útil para la ráfaga de arranque de apps."
  sd_idea "$R/sys/devices/system/cpu/cpu0/core_ctl/min_cpus" "núcleos mínimos encendidos; bajarlo ahorra batería en reposo."
  sd_idea "$R/sys/module/cpu_boost/parameters/input_boost_ms" "input boost del kernel (lo usa el modo mando); podría darse un toque de boost al tocar la pantalla."
  sd_idea "$GPUD/idle_timer" "tiempo que tarda la GPU en dormirse; menos = ahorra, más = menos tirones al volver."
  sd_idea "$GPUD/devfreq/governor" "gobernador de la GPU (msm-adreno-tz o performance)."
  sd_idea "$R/sys/class/thermal/thermal_message/balance_mode" "modo de rendimiento de la ROM (HyperOS): el módulo lo lee, no lo cambia."
  sd_mark "7 otros módulos"; echo; echo "## 7. OTROS MÓDULOS Y AJUSTES DEL SISTEMA"
  for sd_m in "${MG_MODS:-$R/data/adb/modules}"/*/module.prop; do [ -f "$sd_m" ] || continue; sd_d=${sd_m%/module.prop}
    echo "  $(sed -n 's/^name=//p' "$sd_m" | head -n 1) $(sed -n 's/^version=//p' "$sd_m" | head -n 1)$([ -e "$sd_d/disable" ] && echo ' [desactivado]')$([ -e "$sd_d/remove" ] && echo ' [se quitará]')"
  done
  [ -r "$CXMODS" ] && { echo "  los que tocan CPU/GPU/térmico (id|nombre|etiquetas):"; sed 's/^/    /' "$CXMODS"; }
  echo "  ahorro de batería de Android: low_power=$(st_get low_power) POWER_SAVE_MODE_OPEN=$(sy_get POWER_SAVE_MODE_OPEN)"
  echo "  propiedades térmicas/rendimiento:"; getprop 2>/dev/null | grep -i -E 'thermal|perf_mode|powerhal|sys\.perf' | head -n 30 | cut -c1-140 | sed 's/^/    /'
  sd_mark "8 estado"; echo; echo "## 8. ESTADO DEL MÓDULO"
  for sd_f in claims claims.orig heat.state heat.extra auto.state auto.cur manual.saved; do [ -s "$CONF/$sd_f" ] && { echo "-- $sd_f"; cat "$CONF/$sd_f"; }; done
  echo "-- cfg"; cat "$CFG" 2>/dev/null
  echo "-- desired"; cat "$DES" 2>/dev/null
  sd_mark "9 registro"; echo; echo "## 9. REGISTRO (últimas 120 líneas)"; tail -n 120 "$LOG" 2>/dev/null
  sd_mark "10 rendimiento"; echo; echo "## 10. SONDA DE RENDIMIENTO (vigilantes, top, PSI, tiempos de cambio de perfil)"
  sonda_perf_body
  sd_mark "fin"; echo; echo "## 11. TIEMPO QUE TARDÓ CADA SECCIÓN DE ESTA SONDA"; printf '%s' "$SD_TT"
  [ -n "${MG_SONDA_USE-}" ] || { echo; echo FIN; }
}
# Sonda en uso: graba la sesión (grabador de la pestaña GPU) y, a un tercio del tiempo, toma la sonda profunda SIN cambiar de perfil, mientras se usa el teléfono
SONDAU=$CONF/sonda.use.pid
sonda_use_alive() { su_d=""; [ -r "$SONDAU" ] && read -r su_d < "$SONDAU"; [ -n "$su_d" ] && kill -0 "$su_d" 2>/dev/null; }
sonda_use_run() {
  su_s=${1:-60}; isnum "$su_s" || su_s=60; echo $$ > "$SONDAU"; trap 'rm -f "$SONDAU"; exit 0' TERM INT
  rec_start "$su_s" >/dev/null 2>&1
  su_w=$((su_s/3)); sleep "$su_w" 2>/dev/null || sleep 1
  MG_SONDA_USE=1 sonda_deep >/dev/null 2>&1
  su_i=0; while rec_alive && [ "$su_i" -lt $((su_s+20)) ]; do sleep 1; su_i=$((su_i+1)); done
  if [ -s "$SONDAD" ]; then { echo; echo "## 12. GRABACIÓN DE LA PARTIDA (sesión completa, cada fila = 1 s)"; sd_rec; echo; echo FIN; } >> "$SONDAD" 2>/dev/null; fi
  log "sonda en uso terminada"; rm -f "$SONDAU"
}
sonda_use_start() {   # $1 = segundos de grabación
  sonda_use_alive && return 1
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _sondause "$1" </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _sondause "$1" </dev/null >/dev/null 2>&1 & fi
  su_i=0; while [ "$su_i" -lt 4 ]; do sonda_use_alive && return 0; sleep 1; su_i=$((su_i+1)); done; sonda_use_alive
}
sonda_deep() {
  sp_tmp="$SONDAD.t"
  sonda_deep_body 2>&1 | sed 's/\([0-9A-Fa-f][0-9A-Fa-f]:\)\{4\}\([0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]\)/XX:XX:XX:XX:\2/g' | head -c 250000 > "$sp_tmp" 2>/dev/null
  [ -s "$sp_tmp" ] || { rm -f "$sp_tmp"; return 1; }
  mv -f "$sp_tmp" "$SONDAD"; chmod 0666 "$SONDAD" 2>/dev/null; log "sonda profunda generada"; echo "$SONDAD"
}
