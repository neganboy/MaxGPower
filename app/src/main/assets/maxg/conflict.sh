#!/system/bin/sh
# MaxG Power - Detector de conflictos.
# Antes de aplicar algo, "ctl chk <orden>" (o "ctl conflicts <orden>") dice con CUÁL otra función choca y por qué; si no hay avisos, aplica en la misma llamada.
#   CONFLICT|nivel|con|mensaje|arreglo   nivel: warn = se pisa con algo (la app pide confirmar) · info = dato útil.
#                                        arreglo = orden de ctl que se puede ejecutar antes para resolverlo (vacío si no hay).
#   CONFEND|total|avisos
# "ctl conflicts scan"  revisa el estado actual (incluye otros módulos root, ahorro de batería de Android, reclamos compartidos y Wi-Fi 2,4 GHz).
# "ctl conflicts who"   dice quién manda ahora en CPU, GPU y calor:  WHO|dominio|clave|texto
# Las comprobaciones de cada orden solo leen la configuración (sin procesos ni llamadas lentas): lo lento (otros módulos, ahorro de batería de Android)
# se mira en "scan" y en el supervisor (cada pocos minutos) y se guarda en un caché.
CX_N=0; CX_W=0
CXMODS=$CONF/mods.scan; CXSAV=$CONF/saver.state
cx() {   # nivel con mensaje [arreglo]
  CX_N=$((CX_N+1)); [ "$1" = warn ] && CX_W=$((CX_W+1))
  echo "CONFLICT|$1|$2|$3|${4-}"
}
cx_why() {   # categoría del modo inteligente -> texto
  case "$1" in game) printf ' (hay un juego abierto)' ;; maps) printf ' (mapas abierto)' ;; low) printf ' (batería baja)' ;; boost) printf ' (impulso al abrir una app)' ;; off) printf ' (pantalla apagada)' ;; esac
}
cx_tagtxt() {   # etiquetas -> texto
  ct_o=""
  for ct_x in $1; do
    case "$ct_x" in gov) ct_n="el gobernador de la CPU" ;; freq) ct_n="las frecuencias de la CPU" ;; gpu) ct_n="la GPU" ;; thermal) ct_n="el control térmico" ;; sched) ct_n="el planificador (boost/uclamp)" ;; *) continue ;; esac
    ct_o="${ct_o:+$ct_o, }$ct_n"
  done
  printf '%s' "$ct_o"
}
cx_gpucfg() {   # CXM/CXB/CXF/CXE = modo, tope, piso y tope libre de GPU "de los otros controles" (con el manual ON están guardados en manual.saved)
  CXM=$(cfg_get gpu_mode auto); CXB=$(cfg_get gm_max 100); CXF=$(cfg_get gpu_floor 0); CXE=$(cfg_get gpu_free 0)
  if manual_on_p && [ -r "$MANSAVED" ]; then
    while IFS='=' read -r cg_k cg_v; do case "$cg_k" in gpu_mode) CXM=$cg_v ;; gm_max) CXB=$cg_v ;; gpu_floor) CXF=$cg_v ;; gpu_free) CXE=$cg_v ;; esac; done < "$MANSAVED"
  fi
}
cx_ignored() {   # CXI = lista de los otros controles de CPU/GPU que tienen algo puesto (los que el manual ON deja sin efecto)
  CXI=""; cx_gpucfg
  ci_p=$(cfg_get profile stock); [ "$ci_p" != stock ] && CXI="$CXI, perfil «$ci_p»"
  [ "$(cfg_get auto 1)" = 1 ] && autod_alive && CXI="$CXI, modo inteligente (no cambiará perfiles)"
  case "$CXM" in auto|"") ;; manual) CXI="$CXI, tope de GPU fijo $CXB %" ;; *) CXI="$CXI, modo de GPU «$CXM»" ;; esac
  case "$CXM" in auto|""|manual) [ "$CXF" != 0 ] && CXI="$CXI, piso de GPU $CXF MHz"; [ "$CXE" = 1 ] && CXI="$CXI, tope libre de GPU" ;; esac
  ci_g=$(cfg_get gov none); case "$ci_g" in none|stock|"") ;; *) CXI="$CXI, gobernador «$ci_g»" ;; esac
  CXI=${CXI#, }
}
cx_gcap() {   # tope de GPU (%) que dejan el modo o el perfil elegidos: CXP (vacío = ninguno) y CXW = quién lo pone. Llamar antes a cx_gpucfg
  CXP=""; CXW=""
  case "$CXM" in auto|"") ;; manual) CXP=$CXB; CXW="Tope de GPU fijo" ;; *) gm_def "$CXM" && { CXP=$GM_max; CXW="Modo de GPU «$CXM»"; } ;; esac
  if [ -z "$CXP" ]; then
    cg_p=$(eff_profile)
    if [ "$cg_p" != stock ] && prof_def "$cg_p" >/dev/null 2>&1 && isnum "$PD_gpu" && [ "$PD_gpu" -lt 100 ]; then CXP=$PD_gpu; CXW="Perfil «$cg_p»"; fi
  fi
  [ -n "$CXP" ]
}
cx_saver_on() {   # ahorro de batería de Android (leído del caché; 0 = encendido)
  [ -r "$CXSAV" ] || return 1
  IFS='|' read -r cs_t cs_v < "$CXSAV"; uptime_v
  isnum "$cs_t" && [ "$UPT" -ge "$cs_t" ] && [ $((UPT-cs_t)) -le 900 ] && [ "$cs_v" = 1 ]
}
cx_saver_refresh() {
  cr_v=0; [ "$(st_get low_power)" = 1 ] && cr_v=1; [ "$(sy_get POWER_SAVE_MODE_OPEN)" = 1 ] && cr_v=1
  uptime_v; echo "$UPT|$cr_v" > "$CXSAV"
}
cx_scan_mods() {   # revisa los otros módulos root: ¿escriben en la CPU, la GPU o el control térmico? -> $CXMODS (id|nombre|etiquetas)
  cm_cr=$(printf '\r'); : > "$CXMODS.t"; cm_own=${MODDIR##*/}
  for cm_d in "${MG_MODS:-$R/data/adb/modules}"/*; do
    [ -d "$cm_d" ] || continue; cm_id=${cm_d##*/}
    case "$cm_id" in "$cm_own"|maxg_*) continue ;; esac
    if [ -e "$cm_d/disable" ] || [ -e "$cm_d/remove" ]; then continue; fi
    cm_n=$cm_id
    if [ -r "$cm_d/module.prop" ]; then while IFS='=' read -r cm_k cm_v; do [ "$cm_k" = name ] && { cm_n=${cm_v%"$cm_cr"}; break; }; done < "$cm_d/module.prop"; fi
    case "$cm_n" in *"|"*) cm_n=$(printf '%s' "$cm_n" | tr '|' ' ') ;; esac
    cm_t=""
    for cm_f in "$cm_d/service.sh" "$cm_d/post-fs-data.sh" "$cm_d/boot-completed.sh" "$cm_d/system.prop"; do
      [ -r "$cm_f" ] || continue
      cm_h=$(grep -h -o -E 'scaling_governor|scaling_(max|min)_freq|cpu_online|kgsl|devfreq|(min|max)_clock_mhz|(min|max)_pwrlevel|max_gpuclk|thermal|cpu_boost|sched_boost|schedutil|uclamp|schedtune|stune|walt|cpuset|msm_performance' "$cm_f" 2>/dev/null </dev/null | sort -u | tr '\n' ' ')
      case "$cm_h" in *scaling_governor*) cm_t="$cm_t gov" ;; esac
      case "$cm_h" in *scaling_max_freq*|*scaling_min_freq*|*cpu_online*) cm_t="$cm_t freq" ;; esac
      case "$cm_h" in *kgsl*|*devfreq*|*clock_mhz*|*pwrlevel*|*max_gpuclk*) cm_t="$cm_t gpu" ;; esac
      case "$cm_h" in *thermal*) cm_t="$cm_t thermal" ;; esac
      case "$cm_h" in *cpu_boost*|*sched_boost*|*schedutil*|*uclamp*|*schedtune*|*stune*|*walt*|*cpuset*|*msm_performance*) cm_t="$cm_t sched" ;; esac
    done
    cm_u=""; for cm_x in $cm_t; do case " $cm_u " in *" $cm_x "*) ;; *) cm_u="$cm_u $cm_x" ;; esac; done; cm_t=${cm_u# }
    if [ -z "$cm_t" ]; then   # sin pistas en los scripts: se mira el nombre (ajustadores conocidos)
      cm_l=$(printf '%s %s' "$cm_id" "$cm_n" | tr 'A-Z' 'a-z')
      case "$cm_l" in *uperf*|*scene*|*ktweak*|*encore*|*azenith*|*lspeed*|*thermal*|*governor*|*overclock*|*kernel*tweak*|*cpu*tweak*|*gpu*tweak*|*perfmgr*) cm_t=name ;; esac
    fi
    [ -n "$cm_t" ] && printf '%s|%s|%s\n' "$cm_id" "$cm_n" "$cm_t" >> "$CXMODS.t"
  done
  mv -f "$CXMODS.t" "$CXMODS"
}
cx_cache_refresh() { cx_scan_mods; cx_saver_refresh; }
cx_mods_use() {   # etiquetas relevantes -> avisa de los módulos (caché) que tocan lo mismo
  [ -r "$CXMODS" ] || return 0
  while IFS='|' read -r cu_id cu_n cu_t; do
    [ -n "$cu_id" ] || continue
    cu_hit=""; for cu_x in "$@"; do case " $cu_t " in *" $cu_x "*) cu_hit="$cu_hit $cu_x" ;; esac; done
    [ -n "$cu_hit" ] && cx warn "Módulo «$cu_n»" "También toca $(cx_tagtxt "$cu_hit") (lo vi en sus scripts): los dos se pisan; si algo no se aplica, prueba con uno solo."
  done < "$CXMODS"
  return 0
}

# ---------- comprobaciones por orden ----------
cx_profile() {   # profile <id>
  cp_id=$1
  if [ "$cp_id" = stock ]; then
    manual_on_p && cx info "Control manual" "«Original» también apaga el control manual y deja todo como lo pone la ROM."
    return 0
  fi
  if manual_on_p; then
    cx warn "Control manual" "El control manual está ON y manda sobre los perfiles: «$cp_id» se guardaría pero no cambiaría nada." "manual off"
    return 0
  fi
  cp_t=""; [ -r "$AUTOF" ] && read -r cp_t < "$AUTOF"
  if [ -n "$cp_t" ] && [ "$cp_t" != "$cp_id" ]; then
    cp_c=""; [ -r "$AUTOST" ] && IFS='|' read -r cp_c _ < "$AUTOST"
    cx warn "Modo inteligente" "Ahora mismo el modo inteligente tiene puesto «$cp_t»$(cx_why "$cp_c") y manda sobre el perfil que elijas hasta que termine."
  fi
  cx_gpucfg
  case "$CXM" in
    auto|"") ;;
    manual) cx warn "Tope de GPU fijo" "Tienes un tope de GPU fijo de $CXB %: manda sobre la parte de GPU del perfil." "gpu mode auto" ;;
    *) cx warn "Modo de GPU" "El modo de GPU «$CXM» manda sobre la parte de GPU del perfil (la CPU sí sigue el perfil)." "gpu mode auto" ;;
  esac
  if [ "$(cfg_get heat_mode off)" != off ]; then heat_deltas; [ "$HDC" -gt 0 ] && cx info "Control de calor" "Ahora mismo resta $HDC puntos a los topes de CPU porque el teléfono está caliente."; fi
  cx_saver_on && cx warn "Ahorro de batería de Android" "Está encendido: Android recorta CPU y GPU por su cuenta y puede dejar el perfil a medias."
  cx_mods_use freq gpu sched
  return 0
}
cx_manual_on() {
  manual_on_p && return 0   # ya manda el manual: aplicar otra vez no cambia quién manda
  cx_ignored
  [ -n "$CXI" ] && cx warn "Perfiles y modos de CPU/GPU" "Con el manual ON se ignoran (se conservan y vuelven al apagarlo): $CXI."
  { [ "$(cfg_get heat_mode off)" != off ] || [ "$(cfg_get burst off)" != off ]; } && cx info "Control de calor" "Sigue protegiendo con el manual ON: si el teléfono se calienta puede bajar tus topes unos puntos."
  cx_saver_on && cx warn "Ahorro de batería de Android" "Está encendido: Android recorta CPU y GPU por su cuenta y puede ignorar tu ajuste manual."
  cx_mods_use freq gpu sched gov
  return 0
}
cx_manual_off() {
  manual_on_p || return 0
  cx_ignored; [ -n "$CXI" ] && cx info "Perfiles y modos de CPU/GPU" "Al apagar el manual vuelven: $CXI."
  return 0
}
cx_gov() {
  if manual_on_p; then cx warn "Control manual" "El control manual está ON: el gobernador se ignora hasta que lo apagues." "manual off"; return 0; fi
  cx_mods_use gov
  return 0
}
cx_gpu() {   # gpu mode|floor|free|manual|scope <valor>
  cg_a=$1; cg_v=${2-}
  if manual_on_p; then cx warn "Control manual" "El control manual está ON: los controles de GPU se ignoran hasta que lo apagues." "manual off"; return 0; fi
  cx_gpucfg
  case "$cg_a" in
    mode) case "$cg_v" in auto|"") ;; *)
            if [ "$CXM" != "$cg_v" ] && { [ "$CXF" != 0 ] || [ "$CXE" = 1 ]; }; then
              cx warn "Piso / tope libre de GPU" "El modo «$cg_v» pone por su cuenta el piso y el tope libre de la GPU: lo que pusiste a mano ($([ "$CXF" != 0 ] && printf 'piso %s MHz ' "$CXF")$([ "$CXE" = 1 ] && printf 'tope libre')) se reemplaza."
            fi
            cg_p=$(cfg_get profile stock); [ "$cg_p" != stock ] && cx info "Perfil «$cg_p»" "El modo de GPU manda sobre la parte de GPU del perfil; la CPU sigue con el perfil." ;;
          esac ;;
    manual) cg_p=$(cfg_get profile stock); [ "$cg_p" != stock ] && cx info "Perfil «$cg_p»" "El tope fijo de GPU manda sobre la parte de GPU del perfil." ;;
    floor) isnum "$cg_v" && [ "$cg_v" -gt 0 ] || return 0
           case "$CXM" in auto|""|manual) ;; *) cx info "Modo de GPU «$CXM»" "Al tocar el piso, el modo «$CXM» pasa a Fijo conservando su tope de $CXB %." ;; esac
           if cx_gcap; then
             cg_c=$(gm_floor_mhz "$CXP")
             isnum "$cg_c" && [ "$cg_c" -gt 0 ] && [ "$cg_v" -gt "$cg_c" ] && cx warn "$CXW" "Pone el tope de la GPU en unos $cg_c MHz y el piso pide $cg_v MHz: la GPU quedaría clavada en el piso (se pierde el ahorro)." "gpu mode auto"
           fi
           [ "$(cfg_get heat_mode off)" != off ] && cx info "Control de calor" "Si se calienta, el vigilante de GPU devuelve la GPU a la ROM y suelta el piso; lo vuelve a poner al enfriar."
           [ "$(cfg_get gpu_scope always)" = game ] && ! autod_alive && cx warn "Modo inteligente" "«Solo en juegos» necesita el modo inteligente encendido; sin él el piso vale siempre." "auto on" ;;
    free) [ "$cg_v" = on ] || return 0
          cx info "Control de calor" "Quita el límite térmico de la ROM sobre la GPU; el vigilante de GPU vuelve a ponerlo si se calienta demasiado."
          [ "$(cfg_get gpu_scope always)" = game ] && ! autod_alive && cx warn "Modo inteligente" "«Solo en juegos» necesita el modo inteligente encendido; sin él el tope libre vale siempre." "auto on" ;;
    scope) [ "$cg_v" = game ] || return 0
           { ! autod_alive || [ "$(cfg_get auto 1)" != 1 ]; } && cx warn "Modo inteligente" "«Solo en juegos» necesita el modo inteligente encendido para saber cuándo hay un juego." "auto on"
           [ "$CXF" = 0 ] && [ "$CXE" != 1 ] && cx info "Piso de GPU" "Todavía no tienes piso ni tope libre puestos: no hay nada que limitar a los juegos." ;;
  esac
  cx_mods_use gpu
  return 0
}
cx_heat() {   # heat mode <modo>
  case "$1" in
    off) ch_t=$(bat_temp10); isnum "$ch_t" && [ "$ch_t" -ge 400 ] && cx warn "Temperatura" "La batería ya está a $((ch_t/10)),$((ch_t%10)) °C: sin control de calor solo te protege la ROM."
         [ "$(cfg_get burst off)" != off ] && cx info "Ráfaga sostenida" "La ráfaga sigue activa aunque apagues el control de calor (se apaga aparte)." ;;
    suave|normal|estricto)
         manual_on_p && cx info "Control manual" "Con el manual ON el calor puede seguir bajando tus topes: el manual no lo desactiva."
         cx_mods_use thermal ;;
  esac
  return 0
}
cx_auto() {   # auto on|off
  case "$1" in
    on) manual_on_p && cx warn "Control manual" "El control manual está ON: el modo inteligente vigilará las apps pero no cambiará perfiles hasta que lo apagues." "manual off" ;;
    off) [ "$(cfg_get gpu_scope always)" = game ] && { [ "$(cfg_get gpu_floor 0)" != 0 ] || [ "$(cfg_get gpu_free 0)" = 1 ]; } && cx warn "Piso de GPU solo en juegos" "Sin el modo inteligente no se sabe cuándo hay un juego: el piso / tope libre de GPU valdría siempre." "gpu scope always" ;;
  esac
  return 0
}
cx_pad() {   # pad on
  [ "$(cfg_get tune_scan 0)" = 1 ] && cx info "Escaneos de Wi-Fi/BLE (Ajustes)" "El modo mando también apaga estos escaneos mientras juegas: manda el modo mando y al soltar el mando vuelve lo de Ajustes."
  [ "$(cfg_get pad_hz 1)" = 1 ] && cx info "Pantalla" "Con un mando conectado la pantalla sube a su tasa máxima (se devuelve al soltarlo)."
  return 0
}
cx_btrestart() {
  bt_on || return 0
  if [ -e "$PADSTATE" ]; then cx warn "Mando conectado" "Reiniciar el Bluetooth corta el mando y los audífonos unos segundos (se reconectan solos)."
  else cx info "Bluetooth" "Se reinicia la pila Bluetooth: tus dispositivos se desconectan unos segundos y vuelven solos."; fi
}
cx_bt() {   # bt fast on|off · restart · prio on
  case "$1" in
    fast) cx_btrestart ;;
    restart) cx_btrestart ;;
    prio) [ "$2" = on ] && ! command -v renice >/dev/null 2>&1 && cx warn "Sistema" "Este Android no trae renice: no puedo subir la prioridad de la pila Bluetooth." ;;
  esac
  return 0
}
cx_tune() {   # tune scan 1
  [ "$1" = scan ] && [ "$2" = 1 ] && [ "$(cfg_get pad 0)" = 1 ] && cx info "Modo mando" "El modo mando también apaga estos escaneos mientras juegas; manda el modo mando y al soltarlo vuelve lo que pongas aquí."
  return 0
}
cx_deluxe() {
  [ "$(cfg_get bt_fast 0)" = 1 ] || cx_btrestart
  manual_on_p && cx info "Control manual" "Deluxe no toca los perfiles de CPU/GPU: con el manual ON sigue mandando el manual."
  return 0
}
cx_burst() {   # heat burst off|15|30|60
  [ "$1" = off ] && return 0
  [ "$(cfg_get heat_mode off)" = off ] && cx info "Control de calor" "La ráfaga funciona aunque el control de calor esté apagado: solo recorta la CPU si pasa mucho tiempo a tope."
  manual_on_p && cx info "Control manual" "La ráfaga también recorta los topes manuales tras $1 s a tope sostenido."
  return 0
}

conflicts_check() {   # orden [args...] -> líneas CONFLICT
  CX_N=0; CX_W=0; cxa=${1-}; [ $# -gt 0 ] && shift
  case "$cxa" in
    profile) cx_profile "${1-}" ;;
    manual) case "${1-}" in on) manual_has && cx_manual_on ;; try) cx_manual_on ;; off) cx_manual_off ;; esac ;;   # «on» sin ajuste guardado: no hay nada que avisar, ctl responde qué falta
    custom) [ "${1-}" = try ] && cx_manual_on ;;
    gov) cx_gov ;;
    gpu) cx_gpu "${1-}" "${2-}" ;;
    heat) case "${1-}" in mode) cx_heat "${2-}" ;; burst) cx_burst "${2-}" ;; esac ;;
    auto) cx_auto "${1-}" ;;
    pad) [ "${1-}" = on ] && cx_pad ;;
    bt) cx_bt "${1-}" "${2-}" ;;
    tune) cx_tune "${1-}" "${2-}" ;;
    deluxe) [ "${1-}" = on ] && cx_deluxe ;;
  esac
  return 0
}
conflicts_scan() {   # estado actual: revisa de cero (otros módulos, ahorro de batería, reclamos, Wi-Fi) y deja los cachés al día
  CX_N=0; CX_W=0
  cx_cache_refresh
  [ -e "$CONF/safe" ] && cx warn "Modo seguro" "El módulo está en modo seguro (hubo arranques fallidos): no aplica nada hasta que lo desactives en Ajustes."
  if manual_on_p; then
    cx_ignored; [ -n "$CXI" ] && cx info "Control manual" "Mientras esté ON se ignoran: $CXI."
  fi
  if ! manual_on_p; then
    cx_gpucfg
    if { [ "$CXF" != 0 ]; } && cx_gcap; then
      cs_c=$(gm_floor_mhz "$CXP"); isnum "$cs_c" && [ "$cs_c" -gt 0 ] && [ "$CXF" -gt "$cs_c" ] && cx warn "$CXW" "Limita la GPU a unos $cs_c MHz pero el piso pide $CXF MHz: la GPU queda clavada en el piso."
    fi
    [ "$(cfg_get gpu_scope always)" = game ] && ! autod_alive && { [ "$CXF" != 0 ] || [ "$CXE" = 1 ]; } && cx warn "Piso de GPU solo en juegos" "Necesita el modo inteligente encendido para saber cuándo hay un juego; ahora vale siempre." "auto on"
  fi
  cx_saver_on && cx warn "Ahorro de batería de Android" "Está encendido: Android recorta CPU y GPU por su cuenta y puede pelear con los perfiles del módulo."
  if [ -r "$CXMODS" ]; then
    while IFS='|' read -r sm_id sm_n sm_t; do
      [ -n "$sm_id" ] || continue
      if [ "$sm_t" = name ]; then cx info "Módulo «$sm_n»" "Por su nombre parece un ajustador de CPU/GPU/temperatura: si algo no se aplica como esperas, puede ser él."
      else cx warn "Módulo «$sm_n»" "También toca $(cx_tagtxt "$sm_t") (lo vi en sus scripts): los dos se pisan; si algo no se aplica, prueba con uno solo."; fi
    done < "$CXMODS"
  fi
  # recursos compartidos que piden varias funciones a la vez (los resuelve el árbitro de claims.sh)
  claim_status > "$CONF/cx.t" 2>/dev/null
  while IFS='|' read -r _ sc_r sc_o sc_e sc_g; do
    case "$sc_o" in *" "*) cx info "Árbitro de recursos" "«${sc_r#*:}» lo piden varias funciones ($sc_o): manda la de más prioridad y al soltarse la última se devuelve el valor original." ;; esac
  done < "$CONF/cx.t"; rm -f "$CONF/cx.t"
  if bt_on; then
    sc_b=$(bt_wifi_band); [ "$sc_b" = 2.4 ] && cx info "Wi-Fi en 2,4 GHz" "Comparte la banda con el Bluetooth (audífonos y mandos): si puedes, conéctate a la red de 5 GHz para menos cortes."
  fi
  ct_t=$(bat_temp10); [ "$(cfg_get heat_mode off)" = off ] && isnum "$ct_t" && [ "$ct_t" -ge 420 ] && cx warn "Temperatura" "La batería está a $((ct_t/10)),$((ct_t%10)) °C y el control de calor está apagado."
  return 0
}
conflicts_who() {   # WHO|dominio|clave|texto
  cw_t=""; [ -r "$AUTOF" ] && read -r cw_t < "$AUTOF"; cw_c=""; [ -r "$AUTOST" ] && IFS='|' read -r cw_c _ < "$AUTOST"
  cw_p=$(cfg_get profile stock)
  if manual_on_p; then echo "WHO|cpu|manual|Control manual (tu ajuste propio)"
  elif [ -n "$cw_t" ]; then echo "WHO|cpu|auto|Modo inteligente$(cx_why "$cw_c"): perfil $cw_t"
  elif [ "$cw_p" = stock ]; then echo "WHO|cpu|rom|La ROM (sin tocar)"
  else echo "WHO|cpu|perfil|Perfil $cw_p"; fi
  cx_gpucfg
  if manual_on_p; then echo "WHO|gpu|manual|Control manual (tu ajuste propio)"
  else
    case "$CXM" in
      manual) echo "WHO|gpu|modo|Tope de GPU fijo $CXB %" ;;
      auto|"") if [ "$CXF" != 0 ] || [ "$CXE" = 1 ]; then echo "WHO|gpu|piso|Piso / tope libre de la GPU"
               elif [ -n "$cw_t" ]; then echo "WHO|gpu|auto|Modo inteligente: perfil $cw_t"
               elif [ "$cw_p" = stock ]; then echo "WHO|gpu|rom|La ROM (sin tocar)"
               else echo "WHO|gpu|perfil|Perfil $cw_p"; fi ;;
      *) echo "WHO|gpu|modo|Modo de GPU $CXM" ;;
    esac
  fi
  heat_deltas
  cw_hm=$(cfg_get heat_mode off); cw_bu=$(cfg_get burst off)
  if [ "$cw_hm" = off ] && [ "$cw_bu" = off ]; then echo "WHO|calor|off|Control de calor apagado"
  elif [ "$HDC" -gt 0 ] || [ "$HDG" -gt 0 ]; then echo "WHO|calor|activo|Control de calor $cw_hm: baja CPU $HDC % y GPU $HDG %"
  else echo "WHO|calor|vigila|Control de calor $cw_hm: vigilando (sin recortes ahora)"; fi
  return 0
}
