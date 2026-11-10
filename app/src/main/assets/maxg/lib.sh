#!/system/bin/sh
# MaxG Power - biblioteca común. R = raíz alternativa (solo para pruebas).
R=${MG_ROOT:-}
CONF=${MG_CONF:-/data/adb/maxg_power}
mkdir -p "$CONF" 2>/dev/null
ORIG=$CONF/orig; DES=$CONF/desired; CFG=$CONF/cfg; LOG=$CONF/log; BOOTC=$CONF/bootcount
TAB=$(printf '\t')
NL='
'
CPUF=$R/sys/devices/system/cpu/cpufreq
GPUD=$R/sys/class/kgsl/kgsl-3d0
VER=3.1.0

isnum() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; return 0; }
rd() {   # los archivos de /proc/sys se leen con cat: el builtin read los trunca al primer carácter
  _v=""
  case "$1" in
    */proc/*) if [ -r "$1" ]; then _v=$(cat "$1" 2>/dev/null); _v=${_v%%"$NL"*}; case "$_v" in *"$TAB"*) _v=$(printf '%s' "$_v" | tr '\t' ' ') ;; esac; fi ;;
    *) [ -r "$1" ] && { read -r _v < "$1"; } 2>/dev/null ;;
  esac
  printf '%s' "$_v"
}
log() {
  # la hora se pide a date como mucho cada 2 s de funcionamiento; entre medias se reutiliza (un perfil escribe 5-8 líneas seguidas)
  uptime_v; if [ -z "${LOGD-}" ] || [ "$UPT" -lt "${LOGU:-0}" ] || [ $(( UPT - ${LOGU:-0} )) -ge 2 ]; then LOGD=$(date '+%F %T' 2>/dev/null); LOGU=$UPT; fi
  echo "$LOGD $*" >> "$LOG" 2>/dev/null
  LOGC=$(( ${LOGC:-0} + 1 )); [ $(( LOGC % 25 )) -eq 1 ] || return 0   # el tamaño del registro se revisa cada 25 líneas, no en cada una
  _n=$(wc -l < "$LOG" 2>/dev/null); isnum "$_n" && [ "$_n" -gt 400 ] && { tail -n 250 "$LOG" > "$LOG.t" && mv -f "$LOG.t" "$LOG"; }
  return 0
}
rdv() { RV=""; [ -r "$1" ] && read -r RV < "$1" 2>/dev/null; return 0; }   # primera línea en RV, sin subproceso (no vale para /proc/sys: ahí se usa rd)
rd_v() {   # igual que rd pero deja el valor en RDV; solo los archivos de /proc/sys lanzan un subproceso (cat)
  RDV=""
  case "$1" in
    */proc/*) if [ -r "$1" ]; then RDV=$(cat "$1" 2>/dev/null); RDV=${RDV%%"$NL"*}; case "$RDV" in *"$TAB"*) RDV=$(printf '%s' "$RDV" | tr '\t' ' ') ;; esac; fi ;;
    *) [ -r "$1" ] && { read -r RDV < "$1"; } 2>/dev/null ;;
  esac
  return 0
}
# configuración: lectura sin procesos externos. cfg_get imprime, cfg_v deja el valor en CV (sin subproceso), cfg_load deja todo en CF_<clave>
cfg_get() {
  cg_v=""; cg_f=0
  if [ -r "$CFG" ]; then
    while IFS= read -r cg_l; do case "$cg_l" in "$1="*) cg_v=${cg_l#*=}; cg_f=1 ;; esac; done < "$CFG"
  fi
  if [ "$cg_f" = 1 ]; then printf '%s' "$cg_v"; else printf '%s' "$2"; fi
}
cfg_v() {
  CV=$2
  if [ -r "$CFG" ]; then
    while IFS= read -r cv_l; do case "$cv_l" in "$1="*) CV=${cv_l#*=} ;; esac; done < "$CFG"
  fi
  return 0
}
cfg_load() {
  [ -r "$CFG" ] || return 0
  while IFS= read -r cl_l; do
    cl_k=${cl_l%%=*}
    case "$cl_k" in ''|*[!a-z0-9_]*) continue ;; esac
    cl_v=${cl_l#*=}
    eval "CF_$cl_k=\$cl_v"
  done < "$CFG"
  return 0
}
cfg_set() {   # sin grep: se reescribe el archivo sin la clave y con la nueva al final
  cs_o=""; : > "$CFG.t"
  if [ -r "$CFG" ]; then while IFS= read -r cs_l || [ -n "$cs_l" ]; do case "$cs_l" in "$1="*|"") ;; *) printf '%s\n' "$cs_l" >> "$CFG.t" ;; esac; done < "$CFG"; fi
  printf '%s=%s\n' "$1" "$2" >> "$CFG.t"; mv -f "$CFG.t" "$CFG"
}

# candado simple: el vigilante automático y el usuario no aplican perfiles a la vez (un candado atascado se rompe a los 10 s)
lock_take() { _lk=0; while ! mkdir "$CONF/lk" 2>/dev/null; do _lk=$((_lk+1)); [ "$_lk" -gt 40 ] && { rmdir "$CONF/lk" 2>/dev/null; _lk=0; }; sleep 0.25 2>/dev/null || sleep 1; done; }
lock_free() { rmdir "$CONF/lk" 2>/dev/null; return 0; }

# ---- descubrimiento ----
nsort() {   # imprime sus argumentos numéricos en orden ascendente, uno por línea, sin sort (listas de 2 a 20 números)
  ns_l=""
  for ns_x in "$@"; do isnum "$ns_x" || continue; ns_n=""; ns_d=0
    for ns_y in $ns_l; do if [ "$ns_d" = 0 ] && [ "$ns_x" -lt "$ns_y" ]; then ns_n="$ns_n $ns_x"; ns_d=1; fi; ns_n="$ns_n $ns_y"; done
    [ "$ns_d" = 1 ] || ns_n="$ns_n $ns_x"; ns_l=$ns_n
  done
  for ns_y in $ns_l; do printf '%s\n' "$ns_y"; done
}
policies_raw() { pr_l=""; for _p in "$CPUF"/policy*; do [ -d "$_p" ] && pr_l="$pr_l ${_p##*policy}"; done; nsort $pr_l; }
policies() { if [ -n "${POLC-}" ]; then printf '%s\n' $POLC; else policies_raw; fi; }   # POLC = memoria de este proceso (las tablas no cambian)
pol_warm() { [ -n "${POLC-}" ] || { POLC=""; for pw_x in $(policies_raw); do POLC="$POLC $pw_x"; done; }; }
freqs_raw() {   # policy -> frecuencias kHz ascendentes, una por línea
  _f=$CPUF/policy$1/scaling_available_frequencies
  if [ -r "$_f" ]; then fr_l=""; read -r fr_l < "$_f" 2>/dev/null; nsort $fr_l
  else for fr_k in cpuinfo_min_freq cpuinfo_max_freq; do fr_v=$(rd "$CPUF/policy$1/$fr_k"); [ -n "$fr_v" ] && printf '%s\n' "$fr_v"; done; fi
}
fq_get() {   # policy -> FLIST (sin subproceso si ya se leyó antes en este proceso; llamarla fuera de $( ) para que recuerde)
  eval "FLIST=\${FQC_$1-}"
  [ -n "$FLIST" ] || { FLIST=$(freqs_raw "$1"); eval "FQC_$1=\$FLIST"; }
}
freqs() { fq_get "$1"; [ -n "$FLIST" ] && printf '%s\n' "$FLIST"; return 0; }
gpu_node() {  # min|max -> ruta
  for _d in "$GPUD/devfreq" "$GPUD/devfreq/3d00000.qcom,kgsl-3d0"; do [ -w "$_d/${1}_freq" ] || [ -r "$_d/${1}_freq" ] && { echo "$_d/${1}_freq"; return; }; done
  # sin devfreq: el tope se pone en el propio kgsl, en Hz
  [ "$1" = max ] && [ -r "$GPUD/max_gpuclk" ] && echo "$GPUD/max_gpuclk"
}
gpu_freqs_raw() { # Hz ascendentes
  for _f in "$GPUD/devfreq/available_frequencies" "$GPUD/gpu_available_frequencies"; do
    [ -r "$_f" ] && { gf_l=""; read -r gf_l < "$_f" 2>/dev/null; nsort $gf_l; return; }; done
}
gq_get() { FLIST=${GQC-}; [ -n "$FLIST" ] || { FLIST=$(gpu_freqs_raw); GQC=$FLIST; }; }
gpu_freqs() { gq_get; [ -n "$FLIST" ] && printf '%s\n' "$FLIST"; return 0; }
fitl() {   # lista ascendente, % del máximo, piso % -> FR = la mayor <= % (o la menor de todas); si queda bajo el piso de seguridad sube a la menor que lo cumple. Sin procesos externos
  fl_mx=""; fl_lo=""; for fl_x in $1; do [ -n "$fl_lo" ] || fl_lo=$fl_x; fl_mx=$fl_x; done
  isnum "$fl_mx" || { FR=""; return 1; }
  fl_t=$(( fl_mx / 100 * $2 )); fl_m=$(( fl_mx / 100 * ${3:-0} )); FR=""   # sin multiplicar primero: el sh de Android calcula con 32 bits
  for fl_x in $1; do [ "$fl_x" -le "$fl_t" ] && FR=$fl_x; done
  [ -n "$FR" ] || FR=$fl_lo
  if [ "$FR" -lt "$fl_m" ]; then for fl_x in $1; do [ "$fl_x" -ge "$fl_m" ] && { FR=$fl_x; break; }; done; fi
  return 0
}

# Backend de la GPU. dev = devfreq (max_freq en Hz) · pwr = max_pwrlevel/min_pwrlevel (tope de USUARIO por nivel: el límite térmico de la ROM
# vive aparte, en thermal_pwrlevel, y gana si es más bajo) · clk = max_gpuclk (comparte variable con el térmico de la ROM: último en escribir gana).
gpu_be() {
  [ -n "${GBE-}" ] && return 0
  if [ -e "$GPUD/devfreq/max_freq" ] || [ -e "$GPUD/devfreq/3d00000.qcom,kgsl-3d0/max_freq" ]; then GBE=dev
  elif [ -e "$GPUD/max_pwrlevel" ] && [ -e "$GPUD/min_pwrlevel" ] && [ -r "$GPUD/gpu_available_frequencies" ]; then GBE=pwr
  elif [ -r "$GPUD/max_gpuclk" ]; then GBE=clk
  else GBE=none; fi
}
gpu_level_of() {   # Hz de la tabla -> LV (0 = la más rápida, como numera kgsl); vacío si no está en la tabla
  gq_get; gl_n=0; for gl_x in $FLIST; do gl_n=$((gl_n+1)); done
  LV=""; gl_i=0; for gl_x in $FLIST; do [ "$gl_x" = "$1" ] && LV=$((gl_n-1-gl_i)); gl_i=$((gl_i+1)); done
}
gpu_hz_of_level() {   # nivel -> HZV (Hz); vacío si no existe
  HZV=""; isnum "$1" || return 1
  gq_get; gl_n=0; for gl_x in $FLIST; do gl_n=$((gl_n+1)); done
  gl_p=$((gl_n-1-$1)); [ "$gl_p" -ge 0 ] || return 1
  gl_i=0; for gl_x in $FLIST; do [ "$gl_i" -eq "$gl_p" ] && HZV=$gl_x; gl_i=$((gl_i+1)); done
  [ -n "$HZV" ]
}
# Las funciones terminadas en _v dejan el resultado en una variable (KC, KP, KO, KD, KR) y no lanzan subprocesos: en el teléfono cada $( ) cuesta 8-20 ms.
# Las de siempre (knob_cur, knob_path...) siguen existiendo e imprimen lo mismo para quien las use con $( ).
knob_cur_v() {   # valor actual del ajuste en KC
  KC=""
  case "$1" in gpu_max|gpu_min) gpu_be; if [ "$GBE" = pwr ]; then
      kc_l=""; [ -r "$GPUD/${1#gpu_}_pwrlevel" ] && { read -r kc_l < "$GPUD/${1#gpu_}_pwrlevel"; } 2>/dev/null
      gpu_hz_of_level "$kc_l" && KC=$HZV; return 0; fi ;; esac
  knob_path_v "$1"; [ -n "$KP" ] && [ -r "$KP" ] && { rd_v "$KP"; KC=$RDV; }
  return 0
}
knob_cur() { knob_cur_v "$1"; printf '%s' "$KC"; }
knob_put() {   # escribe un nodo sin más trámite (la traducción Hz -> nivel de la GPU incluida)
  case "$1" in gpu_max|gpu_min) gpu_be; if [ "$GBE" = pwr ]; then
      gpu_level_of "$2"; [ -n "$LV" ] || return 1; echo "$LV" > "$GPUD/${1#gpu_}_pwrlevel" 2>/dev/null; return $?; fi ;; esac
  knob_path_v "$1"; kp_p=$KP; [ -n "$kp_p" ] && echo "$2" > "$kp_p" 2>/dev/null
}
# ---- nodo de cada ajuste ----
gpu_node_v() {  # min|max -> KP
  KP=""
  for gn_d in "$GPUD/devfreq" "$GPUD/devfreq/3d00000.qcom,kgsl-3d0"; do [ -w "$gn_d/${1}_freq" ] || [ -r "$gn_d/${1}_freq" ] && { KP="$gn_d/${1}_freq"; return 0; }; done
  # sin devfreq: el tope se pone en el propio kgsl, en Hz
  [ "$1" = max ] && [ -r "$GPUD/max_gpuclk" ] && KP="$GPUD/max_gpuclk"
  return 0
}
knob_path_v() {   # nodo del ajuste en KP (vacío si este kernel no lo tiene); devuelve 1 si el nombre no es de un ajuste
  KP=""
  case "$1" in
    cpu_max_*) KP="$CPUF/policy${1#cpu_max_}/scaling_max_freq" ;;
    cpu_min_*) KP="$CPUF/policy${1#cpu_min_}/scaling_min_freq" ;;
    walt_hl_*) KP="$CPUF/policy${1#walt_hl_}/walt/hispeed_load" ;;
    walt_up_*) KP="$CPUF/policy${1#walt_up_}/walt/up_rate_limit_us" ;;
    walt_down_*) KP="$CPUF/policy${1#walt_down_}/walt/down_rate_limit_us" ;;
    gov_*) KP="$CPUF/policy${1#gov_}/scaling_governor" ;;
    gpu_max) gpu_be; if [ "$GBE" = pwr ]; then KP="$GPUD/max_pwrlevel"; else gpu_node_v max; fi ;;
    gpu_min) gpu_be; if [ "$GBE" = pwr ]; then KP="$GPUD/min_pwrlevel"; else gpu_node_v min; fi ;;
    gpu_idle) KP="$GPUD/idle_timer" ;;
    sched_cpl) KP="$R/proc/sys/walt/sched_conservative_pl" ;;
    vm_swap) KP="$R/proc/sys/vm/swappiness" ;;
    vm_vfs) KP="$R/proc/sys/vm/vfs_cache_pressure" ;;
    vm_pc) KP="$R/proc/sys/vm/page-cluster" ;;
    vm_ttl) KP="$R/sys/kernel/mm/lru_gen/min_ttl_ms" ;;
    *) return 1 ;;
  esac
  return 0
}
knob_path() { knob_path_v "$1" || return 1; [ -n "$KP" ] && printf '%s\n' "$KP"; return 0; }
# Rango permitido [mín máx] para valores numéricos simples (protege de errores de tipeo)
knob_range_v() {
  KR=""
  case "$1" in
    walt_hl_*) KR="50 100" ;; walt_up_*|walt_down_*) KR="0 100000" ;;
    gpu_idle) KR="10 1000" ;; sched_cpl) KR="0 1" ;;
    vm_swap) KR="0 200" ;; vm_vfs) KR="10 500" ;; vm_pc) KR="0 3" ;; vm_ttl) KR="0 5000" ;;
  esac
  return 0
}
knob_range() { knob_range_v "$1"; echo "$KR"; }
knob_orig_v() { KO=""; if [ -r "$ORIG" ]; then while IFS=$TAB read -r ko_k ko_v; do [ "$ko_k" = "$1" ] && { KO=$ko_v; break; }; done < "$ORIG"; fi; return 0; }
knob_des_v() { KD=""; if [ -r "$DES" ]; then while IFS=$TAB read -r ko_k ko_v; do [ "$ko_k" = "$1" ] && KD=$ko_v; done < "$DES"; fi; return 0; }
knob_orig() { knob_orig_v "$1"; printf '%s' "$KO"; }
knob_des() { knob_des_v "$1"; printf '%s' "$KD"; }
orig_has() { [ -r "$ORIG" ] || return 1; while IFS=$TAB read -r oh_k oh_v; do [ "$oh_k" = "$1" ] && return 0; done < "$ORIG"; return 1; }
des_put() { dp_f=$DES.t; : > "$dp_f"; if [ -r "$DES" ]; then while IFS=$TAB read -r dp_k dp_v; do [ -n "$dp_k" ] && [ "$dp_k" != "$1" ] && printf '%s\t%s\n' "$dp_k" "$dp_v" >> "$dp_f"; done < "$DES"; fi; printf '%s\t%s\n' "$1" "$2" >> "$dp_f"; mv -f "$dp_f" "$DES"; }
des_del() { [ -r "$DES" ] || return 0; dp_f=$DES.t; : > "$dp_f"; while IFS=$TAB read -r dp_k dp_v; do [ -n "$dp_k" ] && [ "$dp_k" != "$1" ] && printf '%s\t%s\n' "$dp_k" "$dp_v" >> "$dp_f"; done < "$DES"; mv -f "$dp_f" "$DES" 2>/dev/null; return 0; }

# Escribe un nodo guardando el valor original la primera vez. Devuelve 0 si quedó aplicado.
raw_write() {   # knob valor  (variables propias rw_*: cpu_set y gpu_set siguen usando _p, _k, _v después de llamarla)
  knob_path_v "$1"; rw_p=$KP; [ -n "$rw_p" ] && [ -e "$rw_p" ] || { K_ERR="este kernel no tiene ese ajuste"; return 2; }
  [ -w "$rw_p" ] || chmod u+w "$rw_p" 2>/dev/null
  knob_cur_v "$1"; rw_c=$KC
  orig_has "$1" || printf '%s\t%s\n' "$1" "$rw_c" >> "$ORIG"
  knob_put "$1" "$2"
  knob_cur_v "$1"; rw_n=$KC
  # El kernel aplica scaling_max_freq/scaling_min_freq de forma ASÍNCRONA (cpufreq actualiza la política en un
  # trabajo diferido): leer justo después de escribir devuelve el valor ANTERIOR aunque la escritura ya se aceptó.
  # Antes eso se daba por "rechazado" (FALLO ... lo dejó en <el valor anterior>), el perfil no se guardaba y no
  # quedaba en "deseado". Se espera (hasta ~0,5 s) a que el valor nuevo se vea antes de decidir.
  case "$1" in cpu_max_*|cpu_min_*)
    rw_i=0
    while [ "$rw_n" != "$2" ] && [ "$rw_i" -lt 16 ]; do
      sleep 0.03 2>/dev/null || break
      knob_cur_v "$1"; rw_n=$KC; rw_i=$((rw_i+1))
    done ;;
  esac
  if [ "$rw_n" = "$2" ]; then return 0; fi
  # algunos nodos devuelven el valor redondeado al escalón más cercano (hasta un 8 %); más lejos que eso es que alguien más lo cambió o el kernel lo rechazó
  case "$1" in cpu_*|gpu_max|gpu_min) gpu_be; if [ "${GBE-}" != pwr ] || { [ "$1" != gpu_max ] && [ "$1" != gpu_min ]; }; then
      isnum "$rw_n" && isnum "$2" && [ "$rw_n" -le $(( $2 + $2 / 12 )) ] && [ "$rw_n" -ge $(( $2 - $2 / 12 )) ] && return 0; fi ;; esac
  K_ERR="el sistema o el kernel lo dejó en $rw_n en vez de $2"; return 1
}
pick_freq() {   # lista ascendente (stdin), porcentaje -> la mayor frecuencia <= pct del máximo
  _top=$(tail -n 1 "$2"); _lim=$(( _top / 100 * $1 )); _res=""
  while read -r _x; do [ "$_x" -le "$_lim" ] && _res=$_x; done < "$2"
  [ -n "$_res" ] && echo "$_res" || head -n 1 "$2"
}
cpu_set() {   # max|min policy kHz  (cuida el orden entre mín y máx)
  _k=$1; _p=$2; _v=$3; isnum "$_v" || { K_ERR="valor no válido"; return 1; }
  rdv "$CPUF/policy$_p/scaling_min_freq"; _mn=$RV; rdv "$CPUF/policy$_p/scaling_max_freq"; _mx=$RV
  fq_get "$_p"; _lo=""; _hi=""; for _x in $FLIST; do [ -n "$_lo" ] || _lo=$_x; _hi=$_x; done
  isnum "$_lo" && isnum "$_hi" || { K_ERR="no pude leer las frecuencias de la CPU"; return 1; }
  [ "$_v" -ge "$_lo" ] && [ "$_v" -le "$_hi" ] || { K_ERR="fuera de rango ($_lo-$_hi)"; return 1; }
  # el tope nunca baja del 40 % de la frecuencia máxima: un teléfono inutilizable no ayuda a nadie
  if [ "$_k" = max ] && [ "$_v" -lt $(( _hi / 100 * ${CAP_MINPCT:-40} )) ]; then K_ERR="el tope mínimo permitido es ${CAP_MINPCT:-40} % ($(( _hi / 100 * ${CAP_MINPCT:-40} )) kHz)"; return 1; fi
  if [ "$_k" = max ]; then
    isnum "$_mn" && [ "$_v" -lt "$_mn" ] && raw_write "cpu_min_$_p" "$_v"
    raw_write "cpu_max_$_p" "$_v"
  else
    isnum "$_mx" && [ "$_v" -gt "$_mx" ] && raw_write "cpu_max_$_p" "$_v"
    raw_write "cpu_min_$_p" "$_v"
  fi
}
gpu_set() {
  _k=$1; _v=$2; isnum "$_v" || { K_ERR="valor no válido"; return 1; }
  gq_get; _lo=""; _hi=""; for _x in $FLIST; do [ -n "$_lo" ] || _lo=$_x; _hi=$_x; done
  [ -n "$_hi" ] && { [ "$_v" -ge "$_lo" ] && [ "$_v" -le "$_hi" ] || { K_ERR="fuera de rango"; return 1; }; }
  [ -n "$_hi" ] && [ "$_k" = max ] && [ "$_v" -lt $(( _hi / 100 * ${GPU_MINPCT:-30} )) ] && { K_ERR="el tope mínimo permitido es ${GPU_MINPCT:-30} %"; return 1; }
  knob_cur_v gpu_min; _mn=$KC; knob_cur_v gpu_max; _mx=$KC
  if [ "$_k" = max ]; then   # nunca se sube por encima del tope que puso la ROM (límite térmico): solo se baja
    knob_orig_v gpu_max; _o=$KO; _ref=${_o:-$_mx}
    if isnum "$_ref" && [ "$_v" -ge "$_ref" ]; then
      [ -n "$_o" ] && [ "$_mx" != "$_o" ] && knob_put gpu_max "$_o"
      des_del gpu_max; return 3
    fi
  fi
  if [ "$_k" = max ]; then isnum "$_mn" && [ "$_v" -lt "$_mn" ] && raw_write gpu_min "$_v"; raw_write gpu_max "$_v"
  else isnum "$_mx" && [ "$_v" -gt "$_mx" ] && raw_write gpu_max "$_v"; raw_write gpu_min "$_v"; fi
}
# API única: set_knob nombre valor  -> aplica y recuerda en "desired"
set_knob() {
  K_ERR=""; _n=$1; _v=$2
  case "$_n" in
    cpu_max_*) cpu_set max "${_n#cpu_max_}" "$_v"; _rc=$? ;;
    cpu_min_*) cpu_set min "${_n#cpu_min_}" "$_v"; _rc=$? ;;
    gpu_max) gpu_set max "$_v"; _rc=$? ;;
    gpu_min) gpu_set min "$_v"; _rc=$? ;;
    *) knob_range_v "$_n"; _rg=$KR; [ -n "$_rg" ] || { K_ERR="ajuste desconocido"; return 1; }
       isnum "$_v" || { K_ERR="valor no válido"; return 1; }
       set -- $_rg; [ "$_v" -ge "$1" ] && [ "$_v" -le "$2" ] || { K_ERR="debe estar entre $1 y $2"; return 1; }
       raw_write "$_n" "$_v"; _rc=$? ;;
  esac
  if [ "$_rc" -eq 3 ]; then log "$_n=$_v: la ROM ya limita por debajo, no se toca"; return 0; fi
  if [ "$_rc" -eq 0 ]; then
    des_put "$_n" "$_v"
    case "$_n" in cpu_max_*) knob_cur_v "cpu_min_${_n#cpu_max_}"; des_put "cpu_min_${_n#cpu_max_}" "$KC" ;; esac
    log "set $_n=$_v"
  else log "FALLO $_n=$_v: $K_ERR"; fi
  return "$_rc"
}
# Restaura todo a lo original y olvida lo deseado
reset_all() {
  rm -f "$CONF/auto.cur"; extras_revert; hz_restore; cfg_set gpu_mode auto; cfg_set gm_max 100; type gpu_off >/dev/null 2>&1 && gpu_off
  [ -s "$ORIG" ] || { : > "$DES"; cfg_set profile stock; cfg_set gov none; return 0; }
  _rest() {   # modo -> escribe los originales de ese grupo
    while IFS="$TAB" read -r _n _v; do
      case "$1:$_n" in
        gv:gov_*|mx:cpu_max_*|mx:gpu_max|mn:cpu_min_*|mn:gpu_min|ot:walt_*|ot:gpu_idle|ot:sched_*|ot:vm_*)
          knob_path_v "$_n"; _p=$KP; [ -n "$_p" ] && [ -e "$_p" ] && knob_put "$_n" "$_v" ;;
      esac
    done < "$ORIG"
  }
  _rest gv; _rest mx; _rest mn; _rest ot; _rest mx     # máximos (suben) -> mínimos -> resto -> máximos otra vez por si se cruzaron
  : > "$DES"; rm -f "$ORIG"; cfg_set profile stock; cfg_set gov none; log "restaurado todo a los valores originales"
}
# Reaplica lo deseado si algo (HAL, térmico) lo pisó. Imprime cuántos cambió.
reapply() {
  _c=0
  [ -s "$DES" ] || { echo 0; return; }
  while IFS="$TAB" read -r _n _v; do
    knob_cur_v "$_n"; _cur=$KC; [ -n "$_cur" ] && [ "$_cur" != "$_v" ] || continue
    case "$_n" in cpu_min_*) continue ;; esac     # el mínimo lo mueve el sistema con frecuencia; no lo peleamos
    case "$_n" in gpu_max) gpu_be; [ "$GBE" = clk ] && isnum "$_cur" && isnum "$_v" && [ "$_cur" -lt "$_v" ] && continue ;; esac   # max_gpuclk es el límite térmico de la ROM: nunca se le gana
    knob_put "$_n" "$_v"; _c=$((_c+1))
  done < "$DES"
  [ "$_c" -gt 0 ] && log "reaplicados $_c ajustes que otro componente había cambiado"
  echo "$_c"
}
# ---- exclusivo: Poco F8 Pro (annibale) con Snapdragon 8 Elite ----
dev_name() { printf '%s' "${MG_DEVICE:-$(getprop ro.product.device 2>/dev/null)}"; }
is_target() {   # imprime nada si es el dispositivo correcto; si no, el motivo
  _d=$(dev_name); [ "$_d" = annibale ] || { echo "este módulo es solo para el Poco F8 Pro (annibale); aquí: ${_d:-desconocido}"; return 1; }
  _a=$(rd "$CPUF/policy0/cpuinfo_max_freq"); _b=$(rd "$CPUF/policy6/cpuinfo_max_freq")
  isnum "$_a" && isnum "$_b" && [ "$_a" -ge 3400000 ] && [ "$_a" -le 3700000 ] && [ "$_b" -ge 4200000 ] && [ "$_b" -le 4500000 ] || { echo "los clústeres de CPU no son los del Snapdragon 8 Elite (0-5 a ~3.5 GHz, 6-7 a ~4.3 GHz)"; return 1; }
  return 0
}

# ---- perfiles ajustados al 8 Elite (6 núcleos 0-5 hasta 3.53 GHz, 2 prime 6-7 hasta 4.32 GHz, Adreno 830) ----
# los topes son % del máximo real de cada tabla de frecuencias (así valen aunque la ROM cambie la tabla)
prof_def() {
  PD_hl=0; PD_cpl=0; PD_swap=""; PD_gfl=""; PD_gfr=""; PD_floor=40; PD_gmin=30; PD_hz=0   # piso de seguridad de CPU/GPU (%). PD_hz queda en 0: ningún perfil mueve los Hz de la pantalla (solo se deshace un tope viejo de v3.9.0)
  case "$1" in
    minimo)      PD_perf=21; PD_prime=23; PD_gpu=15;  PD_hl=15;  PD_cpl=1; PD_floor=20; PD_gmin=14 ;;
    ultra)       PD_perf=30; PD_prime=34; PD_gpu=15;  PD_hl=14;  PD_cpl=1; PD_floor=20; PD_gmin=14 ;;
    profundo)    PD_perf=39; PD_prime=34; PD_gpu=30;  PD_hl=10;  PD_cpl=1; PD_floor=30 ;;
    ahorro)      PD_perf=55; PD_prime=52; PD_gpu=45;  PD_hl=8;   PD_cpl=1 ;;
    bateria)     PD_perf=68; PD_prime=65; PD_gpu=55;  PD_hl=5;   PD_cpl=1 ;;
    eco)         PD_perf=75; PD_prime=72; PD_gpu=68;  PD_hl=2;   PD_cpl=1 ;;
    juego)       PD_perf=82; PD_prime=76; PD_gpu=82;  PD_hl=0;   PD_cpl=1 ;;
    medio)       PD_perf=86; PD_prime=83; PD_gpu=86;  PD_hl=-2;  PD_cpl=0 ;;
    diario)      PD_perf=90; PD_prime=90; PD_gpu=91;  PD_hl=-5;  PD_cpl=0 ;;
    rendfresco)  PD_perf=96; PD_prime=96; PD_gpu=91;  PD_hl=-8;  PD_cpl=0 ;;
    alto)        PD_perf=98; PD_prime=98; PD_gpu=96;  PD_hl=-12; PD_cpl=0 ;;
    maximo)      PD_perf=100; PD_prime=100; PD_gpu=100; PD_hl=-15; PD_cpl=0 ;;
    u_*) custom_load "$1" ;;
    *) return 1 ;;
  esac
}
BUILTIN="minimo ultra profundo ahorro bateria eco juego medio diario rendfresco alto maximo"

# ---- perfiles propios (ajuste manual) ----
CUS=$CONF/custom
isint() { case "$1" in ''|-|*[!0-9-]*|*?-*) return 1 ;; esac; return 0; }
custom_ok_id() { case "$1" in u_*) _x=${1#u_}; [ -n "$_x" ] && [ "${#_x}" -le 16 ] && case "$_x" in *[!a-z0-9]*) return 1 ;; esac ;; *) return 1 ;; esac; }
custom_check() {   # perf prime gpu hl cpl swap -> 0 si todo está dentro de rango
  isint "$1" && [ "$1" -ge 40 ] && [ "$1" -le 100 ] || { K_ERR="núcleos 0-5: entre 40 y 100 %"; return 1; }
  isint "$2" && [ "$2" -ge 40 ] && [ "$2" -le 100 ] || { K_ERR="prime: entre 40 y 100 %"; return 1; }
  isint "$3" && [ "$3" -ge 30 ] && [ "$3" -le 100 ] || { K_ERR="GPU: entre 30 y 100 %"; return 1; }
  isint "$4" && [ "$4" -ge -20 ] && [ "$4" -le 10 ] || { K_ERR="subida de frecuencia: entre -20 y 10"; return 1; }
  case "$5" in 0|1) ;; *) K_ERR="conservador: 0 o 1"; return 1 ;; esac
  case "$6" in 0|"") ;; *) isint "$6" && [ "$6" -ge 10 ] && [ "$6" -le 200 ] || { K_ERR="swappiness: 0 (sin tocar) o entre 10 y 200"; return 1; } ;; esac
  case "$7" in 0|"") ;; *) isint "$7" && [ "$7" -ge 100 ] && [ "$7" -le 2000 ] || { K_ERR="piso de GPU: 0 (sin tocar) o una frecuencia en MHz"; return 1; } ;; esac
  case "$8" in 0|1|"") ;; *) K_ERR="liberar tope: 0 o 1"; return 1 ;; esac
  return 0
}
CR=$(printf '\r')
custom_get() {   # id clave -> valor (primera coincidencia), sin procesos externos
  cg2_r=""
  if [ -r "$CUS/$1" ]; then while IFS= read -r cg2_l || [ -n "$cg2_l" ]; do case "$cg2_l" in "$2="*) cg2_r=${cg2_l#*=}; break ;; esac; done < "$CUS/$1"; fi
  printf '%s' "${cg2_r%"$CR"}"
}
custom_load() {
  custom_ok_id "$1" && [ -f "$CUS/$1" ] || return 1
  _a=$(custom_get "$1" perf); _b=$(custom_get "$1" prime); _c=$(custom_get "$1" gpu); _d=$(custom_get "$1" hl); _e=$(custom_get "$1" cpl); _f=$(custom_get "$1" swap)
  _g=$(custom_get "$1" gfloor); _h=$(custom_get "$1" gfree)
  custom_check "$_a" "$_b" "$_c" "$_d" "$_e" "$_f" "$_g" "$_h" || return 1
  PD_gfl=${_g:-0}; PD_gfr=${_h:-0}; PD_perf=$_a; PD_prime=$_b; PD_gpu=$_c; PD_hl=$_d; PD_cpl=$_e; PD_swap=$_f; [ "$PD_swap" = 0 ] && PD_swap=""; return 0
}
custom_name() { _n=$(custom_get "$1" name); [ -n "$_n" ] && printf '%s' "$_n" || printf '%s' "$1"; }
custom_ids() { for _f in "$CUS"/u_*; do [ -f "$_f" ] && echo "${_f##*/}"; done 2>/dev/null; }
custom_save() {   # id nombre perf prime gpu hl cpl swap
  K_ERR=""; _id=$1; _nm=$2; shift 2
  custom_ok_id "$_id" || { K_ERR="id de perfil no válido"; return 1; }
  custom_check "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" || return 1
  _nm=$(printf '%s' "$_nm" | tr -cd 'A-Za-z0-9 ._+-' | cut -c1-24); [ -n "$_nm" ] || _nm=Mio
  mkdir -p "$CUS"
  if [ "$_id" != u_manual ] && [ ! -f "$CUS/$_id" ] && [ "$(custom_ids | grep -vc '^u_manual$')" -ge 12 ]; then K_ERR="máximo 12 perfiles propios; borra alguno"; return 1; fi
  printf 'name=%s\nperf=%s\nprime=%s\ngpu=%s\nhl=%s\ncpl=%s\nswap=%s\ngfloor=%s\ngfree=%s\n' "$_nm" "$1" "$2" "$3" "$4" "$5" "${6:-0}" "${7:-0}" "${8:-0}" > "$CUS/$_id.t" && mv -f "$CUS/$_id.t" "$CUS/$_id"
  log "perfil propio $_id ($_nm): $1/$2/$3 hl$4 cpl$5 swap${6:-0}"
  return 0
}
custom_del() {
  custom_ok_id "$1" && [ -f "$CUS/$1" ] || { K_ERR="ese perfil no existe"; return 1; }
  [ "$1" = u_manual ] && manual_on_p && manual_disable
  rm -f "$CUS/$1"; log "perfil propio $1 borrado"
  [ "$(cfg_get profile stock)" = "$1" ] && reset_all
  return 0
}

fit_freq() {   # lista ascendente (archivo), objetivo -> la mayor <= objetivo (o la mayor de todas si el objetivo la supera)
  _res=""; while read -r _x; do [ "$_x" -le "$2" ] && _res=$_x; done < "$1"; [ -n "$_res" ] && echo "$_res" || head -n 1 "$1"
}
fit_pct() {   # archivo ascendente, % -> mayor frecuencia <= % del máximo de la tabla
  _mx=$(tail -n 1 "$1"); isnum "$_mx" || return 1; fit_freq "$1" $(( _mx / 100 * $2 ))   # sin multiplicar primero: el sh de Android calcula con 32 bits y 1100000000*91 se desborda
}
fit_pct_fl() {   # igual que fit_pct, pero si la frecuencia que toca queda bajo el piso de seguridad ($3 %), sube a la menor que lo cumple (las tablas reales no coinciden con los porcentajes justos)
  _fr=$(fit_pct "$1" "$2") || return 1; _fx=$(tail -n 1 "$1"); isnum "$_fx" || { echo "$_fr"; return 0; }
  _fm=$(( _fx / 100 * $3 ))
  if isnum "$_fr" && [ "$_fr" -lt "$_fm" ]; then
    _fb=""; while read -r _fy; do [ -z "$_fb" ] && [ "$_fy" -ge "$_fm" ] && _fb=$_fy; done < "$1"
    [ -n "$_fb" ] && _fr=$_fb
  fi
  echo "$_fr"
}
plan_v() {   # perfil -> PLN = "perf prime gpu hl cpl" ya resueltos con las tablas reales (sin procesos externos; llamarla fuera de $( ))
  prof_def "$1" || return 1
  _pf=""; _pr=""; _first=""
  for pv_p in $(policies); do
    [ -n "$_first" ] || _first=$pv_p
    fq_get "$pv_p"; [ -n "$FLIST" ] || continue
    if [ "$pv_p" = "$_first" ]; then fitl "$FLIST" "$PD_perf" "$PD_floor"; _pf=$FR; else fitl "$FLIST" "$PD_prime" "$PD_floor"; _pr=$FR; fi
  done
  _gg=""; gq_get; if [ -n "$FLIST" ]; then fitl "$FLIST" "$PD_gpu" "$PD_gmin"; _gg=$FR; fi
  PLN="$_pf $_pr $_gg $PD_hl $PD_cpl"; PLNB="$_pf|$_pr|$_gg|$PD_hl|$PD_cpl"
}
plan_of() { plan_v "$1" && echo "$PLN"; }
prof_set() {   # aplica un perfil: sus topes (con el piso de seguridad que le toca) y el tope de pantalla en Hz
  prof_def "$1" || { K_ERR="perfil desconocido"; return 1; }
  CAP_MINPCT=$PD_floor; GPU_MINPCT=$PD_gmin; prof_set_u "$1"; _psr=$?; CAP_MINPCT=40; GPU_MINPCT=30
  prof_def "$1" && hz_apply "$PD_hz"
  return $_psr
}
prof_set_u() {   # aplica los ajustes de un perfil (no cambia el perfil elegido)
  prof_def "$1" || { K_ERR="perfil desconocido"; return 1; }
  heat_deltas 2>/dev/null
  if [ $((HDC+HDG)) -gt 0 ] && [ "$PD_floor" -ge 40 ]; then   # los perfiles de supervivencia ya están en el piso: el calor no los baja más
   # control de calor: se bajan los topes que pide el perfil (la CPU y la GPU pueden bajar distinto: la ráfaga sostenida solo toca la CPU)
    PD_perf=$((PD_perf-HDC)); PD_prime=$((PD_prime-HDC)); PD_gpu=$((PD_gpu-HDG))
    [ "$PD_perf" -lt 40 ] && PD_perf=40; [ "$PD_prime" -lt 40 ] && PD_prime=40; [ "$PD_gpu" -lt 30 ] && PD_gpu=30
  fi
  _fail=0; _first=""
  pol_warm
  for ps_p in $POLC; do
    [ -n "$_first" ] || _first=$ps_p
    fq_get "$ps_p"; [ -n "$FLIST" ] || continue
    if [ "$ps_p" = "$_first" ]; then ps_t=$PD_perf; else ps_t=$PD_prime; fi
    fitl "$FLIST" "$ps_t" "$PD_floor"; ps_f=$FR
    # el tope no baja del 40 % ni sube de lo que permite el chip
    set_knob "cpu_max_$ps_p" "$ps_f" || _fail=$((_fail+1))
    knob_path_v "walt_hl_$ps_p"
    if [ -e "$KP" ]; then
      knob_orig_v "walt_hl_$ps_p"; ps_b=$KO; [ -n "$ps_b" ] || { knob_cur_v "walt_hl_$ps_p"; ps_b=$KC; }
      if isnum "$ps_b"; then ps_n=$((ps_b + PD_hl)); [ "$ps_n" -lt 60 ] && ps_n=60; [ "$ps_n" -gt 98 ] && ps_n=98; set_knob "walt_hl_$ps_p" "$ps_n" || _fail=$((_fail+1)); fi
    fi
  done
  gq_get
  if [ -n "$FLIST" ]; then fitl "$FLIST" "$PD_gpu" "$PD_gmin"; set_knob gpu_max "$FR" || _fail=$((_fail+1)); fi
  knob_path_v sched_cpl; [ -e "$KP" ] && { set_knob sched_cpl "$PD_cpl" || _fail=$((_fail+1)); }
  if [ -n "$PD_gfl" ]; then   # perfil propio: también define el piso y el tope libre de la GPU y manda sobre el modo de GPU
    cfg_set gpu_mode auto; cfg_set gpu_floor "$PD_gfl"; cfg_set gpu_free "$PD_gfr"
    if [ "$PD_gfl" != 0 ] || [ "$PD_gfr" != 0 ]; then gpud_start >/dev/null 2>&1; else gpud_alive && gpud_stop; fi
  fi
  if [ -n "$PD_swap" ]; then set_knob vm_swap "$PD_swap" || _fail=$((_fail+1))
  elif knob_des_v vm_swap; [ -n "$KD" ]; then   # el perfil anterior tocaba swappiness y este no: se devuelve el original
    knob_orig_v vm_swap; _so=$KO; knob_path_v vm_swap; [ -n "$_so" ] && echo "$_so" > "$KP" 2>/dev/null; des_del vm_swap; grep -v "^vm_swap$TAB" "$ORIG" > "$ORIG.t" 2>/dev/null; mv -f "$ORIG.t" "$ORIG" 2>/dev/null
  fi
  [ "$_fail" -eq 0 ]
}


# ---- extras permanentes (los que traía Annibale Tweaks): memoria y apps en segundo plano ----
EXTRA=$CONF/extras.state
pkg_has() { pm path "$1" >/dev/null 2>&1; }
ex_has() { grep -q "^$1" "$EXTRA" 2>/dev/null; }
ex_put() { echo "$1" >> "$EXTRA"; }
bucket_name() { case "$1" in 10) echo active ;; 20) echo working_set ;; 30) echo frequent ;; 40) echo rare ;; 45) echo restricted ;; *) echo active ;; esac; }
ex_bucket() {   # paquete -> pone bucket rare guardando el original la primera vez
  pkg_has "$1" || return 0
  if ! ex_has "bucket:$1:"; then ex_put "bucket:$1:$(bucket_name "$(am get-standby-bucket "$1" 2>/dev/null </dev/null | tr -dc '0-9')")"; fi
  am set-standby-bucket "$1" rare >/dev/null 2>&1 </dev/null
}
extras_apply() {
  [ -e "$CONF/extras.on" ] && return 0   # solo la primera vez tras el arranque (cada perfil lo repetía: pm, dumpsys, appops... eso era el trabón)
  # memoria: leer 1 página por fallo de zram y proteger el working set 1 s (deja actuar a lmkd en vez de trabar)
  set_knob vm_pc 0 >/dev/null 2>&1; set_knob vm_ttl 1000 >/dev/null 2>&1

  # Brave fuera de la lista blanca de Doze
  if pkg_has com.brave.browser && dumpsys deviceidle whitelist 2>/dev/null </dev/null | grep -q 'com.brave.browser'; then
    ex_has brave_wl || ex_put brave_wl
    dumpsys deviceidle whitelist -com.brave.browser >/dev/null 2>&1 </dev/null
  fi
  # TikTok: sin ejecución en segundo plano y bucket rare
  if pkg_has com.zhiliaoapp.musically; then
    ex_has tiktok_ops || ex_put tiktok_ops
    cmd appops set com.zhiliaoapp.musically RUN_ANY_IN_BACKGROUND ignore >/dev/null 2>&1 </dev/null
    ex_bucket com.zhiliaoapp.musically
  fi
  ex_bucket com.claro.pe.miclaro
  : > "$CONF/extras.on"; log "extras aplicados (memoria y segundo plano)"
}
extras_revert() {
  [ -f "$EXTRA" ] || return 0
  ex_has brave_wl && dumpsys deviceidle whitelist +com.brave.browser >/dev/null 2>&1 </dev/null
  ex_has tiktok_ops && cmd appops set com.zhiliaoapp.musically RUN_ANY_IN_BACKGROUND default >/dev/null 2>&1 </dev/null
  while IFS=: read -r _k _pk _bk; do [ "$_k" = bucket ] && am set-standby-bucket "$_pk" "${_bk:-active}" >/dev/null 2>&1 </dev/null; done < "$EXTRA"
  rm -f "$EXTRA" "$CONF/extras.on"; log "extras revertidos"
}

# ---- temperaturas (solo lectura) ----
# Las zonas térmicas se buscan una sola vez por proceso (hay ~80) y después solo se leen las que importan, sin crear procesos.
CPUZ=""; SKINZ=""; GPUZ=""; ZONES_OK=0
zones_init() {
  CPUZ=""; SKINZ=""; GPUZ=""
  for zi_z in "$R"/sys/class/thermal/thermal_zone*; do
    [ -r "$zi_z/type" ] || continue; rdv "$zi_z/type"
    case "$RV" in
      *trip*|*hw*) ;;
      xo-therm|quiet_therm|display_therm) SKINZ="$SKINZ $zi_z" ;;   # sensores de la carcasa (lo que se siente en la mano)
      gpuss*) GPUZ="$GPUZ $zi_z" ;;
      *cpu*) CPUZ="$CPUZ $zi_z" ;;
    esac
  done
  ZONES_OK=1
}
zmax_v() {   # lista de zonas -> ZM = máxima temperatura en décimas de °C (0 si no hay datos)
  ZM=0
  for zm_z in $1; do
    rdv "$zm_z/temp"; isnum "$RV" || continue; zm_x=$RV
    [ "$zm_x" -ge 1000 ] && zm_x=$((zm_x/100))
    [ "$zm_x" -gt "$ZM" ] && [ "$zm_x" -lt 1500 ] && ZM=$zm_x
  done
  return 0
}
cpu_temp10_v() { [ "$ZONES_OK" = 1 ] || zones_init; zmax_v "$CPUZ"; CT10=$ZM; }
skin_temp10_v() { [ "$ZONES_OK" = 1 ] || zones_init; zmax_v "$SKINZ"; SK10=$ZM; }
gpu_temp10_v() { [ "$ZONES_OK" = 1 ] || zones_init; zmax_v "$GPUZ"; GT10=$ZM; }   # zonas gpuss*: ~8 lecturas en vez de recorrer las ~80 con un proceso cada una
bat_temp10_v() { rdv "$R/sys/class/power_supply/battery/temp"; isnum "$RV" && BT10=$RV || BT10=0; }
cpu_temp10() { cpu_temp10_v; echo "$CT10"; }  # décimas de °C: máximo de las zonas cpu
skin_temp10() { skin_temp10_v; echo "$SK10"; }
bat_temp10() { bat_temp10_v; echo "$BT10"; }
uptime_v() {   # UPT = segundos desde el arranque, sin llamar a date (en las pruebas, con raíz falsa, usa el /proc real)
  UPT=0; up_a=""; up_f=$R/proc/uptime; [ -r "$up_f" ] || up_f=/proc/uptime
  read -r up_a up_b < "$up_f" 2>/dev/null; up_a=${up_a%%.*}; isnum "$up_a" && UPT=$up_a; return 0
}

# ---- gobernador de CPU (opcional, aparte de los perfiles) ----
gov_p0() { set -- $(policies); GP0=$1; }
gov_avail() {   # un gobernador por línea, sin procesos externos
  gov_p0; ga_f=$CPUF/policy$GP0/scaling_available_governors; ga_l=""; [ -r "$ga_f" ] && read -r ga_l < "$ga_f" 2>/dev/null
  for ga_w in $ga_l; do case "$ga_w" in *[!A-Za-z0-9_.-]*) ;; *) printf '%s\n' "$ga_w" ;; esac; done
  return 0
}
gov_cur() { gov_p0; rd "$CPUF/policy$GP0/scaling_governor"; }
gov_set() {   # nombre -> lo pone en todos los clústeres (se puede deshacer con gov_restore o "Original")
  K_ERR=""; gov_avail | grep -qx "$1" || { K_ERR="este kernel no tiene el gobernador «$1»"; return 1; }
  _bad=0; for gs_p in $(policies); do
    raw_write "gov_$gs_p" "$1" && des_put "gov_$gs_p" "$1" || _bad=$((_bad+1)); done
  if [ "$_bad" -eq 0 ]; then cfg_set gov "$1"; log "gobernador $1"; return 0; fi
  K_ERR="el kernel no aceptó el gobernador en $_bad clúster(es)"; log "FALLO gobernador $1"; return 1
}
gov_restore() {
  for gr_p in $(policies); do
    gr_v=$(knob_orig "gov_$gr_p"); [ -n "$gr_v" ] && echo "$gr_v" > "$CPUF/policy$gr_p/scaling_governor" 2>/dev/null
    grep -v "^gov_$gr_p$TAB" "$ORIG" > "$ORIG.t" 2>/dev/null; mv -f "$ORIG.t" "$ORIG" 2>/dev/null; des_del "gov_$gr_p"
  done
  cfg_set gov none; log "gobernador restaurado"
}
# Repara un tope de GPU dañado por la v3.3/3.4 original (el cálculo se desbordaba y dejaba la GPU en su frecuencia mínima)
heal_gpu() {
  [ -s "$DES" ] || return 0
  case "$(eff_profile)" in ultra|minimo) return 0 ;; esac   # estos perfiles dejan la GPU en su frecuencia mínima a propósito
  _hd=$(knob_des gpu_max); isnum "$_hd" || return 0
  gpu_freqs > "$CONF/h.tmp"; _ht=$(tail -n 1 "$CONF/h.tmp"); rm -f "$CONF/h.tmp"; isnum "$_ht" || return 0
  _hth=$(( _ht / 100 * 30 )); [ "$_hd" -lt "$_hth" ] || return 0
  _hp=$(knob_path gpu_max); _ho=$(knob_orig gpu_max); isnum "$_ho" && [ "$_ho" -ge "$_hth" ] && _hv=$_ho || _hv=$_ht
  [ -n "$_hp" ] && knob_put gpu_max "$_hv"; des_del gpu_max
  log "REPARADO: el tope de GPU estaba en $_hd (por un error de cálculo); se devolvió a $_hv"
  _hf=$(cfg_get profile stock); [ "$_hf" != stock ] && prof_set "$_hf" >/dev/null 2>&1
  type gpu_mode_apply >/dev/null 2>&1 && gpu_mode_apply
  return 0
}
prof_apply() {   # perfil elegido por el usuario
  lock_take; prof_apply_u "$@"; _pr=$?; lock_free; return $_pr
}
prof_apply_u() {
  _w=$(is_target) || { K_ERR=$_w; return 1; }
  pol_warm
  case "$1" in
    stock) if manual_on_p; then cfg_set manual_on 0; rm -f "$MANSAVED"; log "control manual: OFF («Original» lo deshace todo)"; fi; reset_all; return 0 ;;
  esac
  manual_block && return 1
  case "$1" in
    minimo|ultra|profundo|ahorro|bateria|eco|juego|medio|diario|rendfresco|alto|maximo|u_*)
       prof_def "$1" || { K_ERR="perfil desconocido o con valores no válidos"; return 1; }
       _g=$(cfg_get gov none); [ "$_g" != none ] && [ "$(gov_cur)" != "$_g" ] && gov_set "$_g"
       prof_set "$1" || { [ -n "$K_ERR" ] || K_ERR="algunos ajustes no se aceptaron (mira el registro)"; return 1; }
       extras_apply; cfg_set profile "$1"; log "perfil $1"; gpu_mode_apply; return 0 ;;
    *) K_ERR="perfil desconocido"; return 1 ;;
  esac
}
[ -f "$MODDIR/pad.sh" ] && . "$MODDIR/pad.sh"
[ -f "$MODDIR/claims.sh" ] && . "$MODDIR/claims.sh"
[ -f "$MODDIR/manual.sh" ] && . "$MODDIR/manual.sh"
[ -f "$MODDIR/conflict.sh" ] && . "$MODDIR/conflict.sh"
[ -f "$MODDIR/gpu.sh" ] && . "$MODDIR/gpu.sh"
[ -f "$MODDIR/heat.sh" ] && . "$MODDIR/heat.sh"
[ -f "$MODDIR/bt.sh" ] && . "$MODDIR/bt.sh"
[ -f "$MODDIR/auto.sh" ] && . "$MODDIR/auto.sh"
[ -f "$MODDIR/tune.sh" ] && . "$MODDIR/tune.sh"
[ -f "$MODDIR/deluxe.sh" ] && . "$MODDIR/deluxe.sh"
[ -f "$MODDIR/report.sh" ] && . "$MODDIR/report.sh"
[ -f "$MODDIR/sonda.sh" ] && . "$MODDIR/sonda.sh"
