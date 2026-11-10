#!/system/bin/sh
# MaxG Power - Control de calor: baja los topes de CPU y GPU en escalones cuando el teléfono se calienta y los devuelve al enfriar.
# Mira tres cosas: la batería, la CPU y los sensores de la carcasa (los que se sienten en la mano: pantalla, placa y oscilador).
# Funciona por encima del perfil: prof_set y gpu_mode_apply restan heat_delta puntos de porcentaje a lo que el perfil pide.
HEATF=$CONF/heat.cur; HEATPID=$CONF/heatd.pid; HEATST=$CONF/heat.state
SCRF=$R/sys/class/thermal/thermal_message/screen_state
HEATX=$CONF/heat.extra
# heat.cur lleva "N" (lo mismo para CPU y GPU) o "C G" cuando difieren (la ráfaga sostenida solo baja la CPU)
heat_deltas() { HDC=0; hd2_=""; [ -r "$HEATF" ] && read -r HDC hd2_ < "$HEATF"; isnum "$HDC" || HDC=0; if isnum "$hd2_"; then HDG=$hd2_; else HDG=$HDC; fi; return 0; }
heat_delta() { heat_deltas; echo "$HDC"; }
heat_def() {   # modo -> HT_bw HT_bh (batería tibia/caliente, décimas °C) HT_cw HT_ch (CPU) HT_sw HT_sh (carcasa) HT_dw HT_dh (puntos que se bajan)
  case "$1" in
    suave)    HT_bw=430; HT_bh=450; HT_cw=800; HT_ch=900; HT_sw=420; HT_sh=440; HT_dw=8;  HT_dh=20 ;;
    normal)   HT_bw=410; HT_bh=440; HT_cw=750; HT_ch=850; HT_sw=405; HT_sh=430; HT_dw=10; HT_dh=25 ;;
    estricto) HT_bw=390; HT_bh=420; HT_cw=700; HT_ch=800; HT_sw=390; HT_sh=415; HT_dw=12; HT_dh=30 ;;
    *) return 1 ;;
  esac
}
heat_level() {   # bat cpu carcasa margen_bat margen_cpu margen_carcasa -> HL: 0 normal, 1 tibio, 2 caliente (umbrales ya cargados). Carcasa 0 = sin sensor: no cuenta
  if [ "$1" -ge $((HT_bh-$4)) ] || [ "$2" -ge $((HT_ch-$5)) ] || { [ "$3" -gt 0 ] && [ "$3" -ge $((HT_sh-$6)) ]; }; then HL=2
  elif [ "$1" -ge $((HT_bw-$4)) ] || [ "$2" -ge $((HT_cw-$5)) ] || { [ "$3" -gt 0 ] && [ "$3" -ge $((HT_sw-$6)) ]; }; then HL=1
  else HL=0; fi
}

# ---- guardián de 7 niveles (modo "guardian"): lazo cerrado sobre la temperatura objetivo del perfil ----
# Nivel 0 = sin recorte. El 1 entra 2 °C antes del objetivo, el 3 justo en el objetivo y el 6 a +3 °C.
# El nivel sube en cuanto se cruza un umbral y baja recién 0,5 °C por debajo, para no oscilar entre dos niveles.
# Manda el sensor más caliente: la batería, o la carcasa con 3 °C de margen (se siente antes que la batería).
# El chip pone un piso de nivel (85 °C -> 1, 95 °C -> 2) aunque la batería siga fría: el chip sube en segundos, la batería en minutos.
# Con la pantalla apagada el nivel no baja de 4 (si el ahorro de pantalla está encendido).
GUARD_LVL_CPU="100 92 85 78 70 62 52"
GUARD_LVL_GPU="100 90 80 70 60 50 40"
GUARD_MAX=6
GUARD_SKIN_OFF=30
GUARD_CHIP1=850
GUARD_CHIP2=950
guard_target() {   # perfil -> GT: objetivo en °C (30-45); por defecto 35 en diario y 40 en juego y rendimiento
  case "$1" in juego|rendfresco|alto|maximo) GT=40 ;; *) GT=35 ;; esac
  cfg_v "heat_tgt_$1" "$GT"; isnum "$CV" && [ "$CV" -ge 30 ] && [ "$CV" -le 45 ] && GT=$CV
  return 0
}
guard_target_set() {   # perfil temp -> valida y guarda el objetivo de ese perfil
  case "$1" in minimo|ultra|profundo|ahorro|bateria|eco|juego|medio|diario|rendfresco|alto|maximo|u_*) ;; *) K_ERR="perfil desconocido"; return 1 ;; esac
  isnum "$2" && [ "$2" -ge 30 ] && [ "$2" -le 45 ] || { K_ERR="objetivo entre 30 y 45 °C"; return 1; }
  cfg_set "heat_tgt_$1" "$2"; log "calor: objetivo de $1 a $2 °C"; return 0
}
guard_targets() {   # TGT|perfil|objetivo para los 12 perfiles (y los propios, si los hay)
  for _p in $BUILTIN $(custom_ids); do guard_target "$_p"; echo "TGT|$_p|$GT"; done
}
guard_level() {   # temp_décimas objetivo_°C nivel_actual -> GL (con histéresis de 0,5 °C al bajar)
  gl_d=$(($1 - $2 * 10)); GL=$3
  gl_up=0; [ "$gl_d" -ge -30 ] && gl_up=$(((gl_d + 30) / 10))
  gl_dn=0; [ "$gl_d" -ge -35 ] && gl_dn=$(((gl_d + 35) / 10))
  [ "$gl_up" -gt "$GUARD_MAX" ] && gl_up=$GUARD_MAX
  [ "$gl_dn" -gt "$GUARD_MAX" ] && gl_dn=$GUARD_MAX
  if [ "$gl_up" -gt "$GL" ]; then GL=$gl_up
  elif [ "$gl_dn" -lt "$GL" ]; then GL=$gl_dn; fi
  return 0
}
guard_pct() {   # nivel -> GC (puntos de CPU) y GG (puntos de GPU) que se restan de lo que pide el perfil
  _i=0; GC=0; GG=0
  for _c in $GUARD_LVL_CPU; do [ "$_i" = "$1" ] && GC=$((100-_c)); _i=$((_i+1)); done
  _i=0
  for _g in $GUARD_LVL_GPU; do [ "$_i" = "$1" ] && GG=$((100-_g)); _i=$((_i+1)); done
  return 0
}
caps_restore() {   # devuelve los topes de CPU y GPU a lo que tenía la ROM
  [ -s "$ORIG" ] || return 0
  while IFS="$TAB" read -r _n _v; do
    case "$_n" in cpu_max_*|gpu_max) _p=$(knob_path "$_n"); [ -n "$_p" ] && [ -e "$_p" ] && knob_put "$_n" "$_v"; des_del "$_n" ;; esac
  done < "$ORIG"
}
heat_stock() {   # sin perfil elegido: aplica solo la reducción de calor sobre lo que trae la ROM
  heat_deltas
  if [ "$HDC" -le 0 ] && [ "$HDG" -le 0 ]; then caps_restore; return 0; fi
  hs_pc=$((100-HDC)); [ "$hs_pc" -lt 40 ] && hs_pc=40
  for hs_p in $(policies); do fq_get "$hs_p"; [ -n "$FLIST" ] && { fitl "$FLIST" "$hs_pc" 40; set_knob "cpu_max_$hs_p" "$FR" >/dev/null 2>&1; }; done
  hs_gp=$((100-HDG)); [ "$hs_gp" -lt 30 ] && hs_gp=30
  if [ "$HDG" -gt 0 ]; then gq_get; [ -n "$FLIST" ] && { fitl "$FLIST" "$hs_gp" 30; set_knob gpu_max "$FR" >/dev/null 2>&1; }
  else _go=$(knob_orig gpu_max); [ -n "$_go" ] && { knob_put gpu_max "$_go"; des_del gpu_max; }; fi
}
heat_reapply() {
  hr_p=$(eff_profile)
  if [ "$hr_p" != stock ] && prof_def "$hr_p"; then prof_set "$hr_p" >/dev/null 2>&1; else heat_stock; fi
  gpu_mode_apply
}
heat_apply() { if [ "${2:-$1}" = "$1" ]; then echo "$1" > "$HEATF"; else echo "$1 $2" > "$HEATF"; fi; heat_reapply; }
screen_off() {   # 0 si la pantalla está apagada: primero thermal_message/screen_state (1 = encendida), si no existe, el brillo del panel
  if [ -r "$SCRF" ]; then rdv "$SCRF"; case "$RV" in 0) return 0 ;; ?*) return 1 ;; esac; fi
  for _b in "$R"/sys/class/backlight/*/brightness; do [ -r "$_b" ] || continue; rdv "$_b"; [ "$RV" = 0 ] && return 0; return 1; done
  return 1
}
des_has() { [ -s "$DES" ] || return 1; while IFS="$TAB" read -r dh_n dh_v; do [ "$dh_n" = "$1" ] && return 0; done < "$DES"; return 1; }
heat_dif() { hd_x=$(( $1 - $2 )); [ "$hd_x" -lt 0 ] && hd_x=$((0-hd_x)); return 0; }   # |a-b| en hd_x
heatd_alive() { _d=""; [ -r "$HEATPID" ] && read -r _d < "$HEATPID"; [ -n "$_d" ] && kill -0 "$_d" 2>/dev/null; }
heatd_run() {
  echo $$ > "$HEATPID"; rm -f "$CONF/heatd.stop"; hd_L=0; hd_calm=0; hd_off=0; hd_cur=0; hd_curg=0; hd_lk=""; hd_wt=0; hd_lc=0; hd_lb=0; hd_ls=0
  hd_cf=0; hd_tgt=35; hd_src=bateria
  hd_an=0; hd_ancalm=0; hd_bn=0; hd_bx=0; hd_bcalm=0; hd_xk=""; hd_tk=${MG_HEATTICK:-5}
  hd_fp=$(policies | head -n 1); hd_lp=""; for hd_x in $(policies); do hd_lp=$hd_x; done   # hd_lp = el último clúster (el prime): el que más calienta
  cpu_temp10_v; hd_t1=$CT10; hd_t2=$CT10; hd_t3=$CT10
  cfg_v heat_mode off; log "calor: vigilante iniciado ($CV)"
  trap 'echo 0 > "$HEATF"; rm -f "$HEATX"; heat_reapply; rm -f "$HEATPID" "$HEATST"; exit 0' TERM INT
  while [ ! -e "$CONF/heatd.stop" ]; do
    cfg_load
    hd_m=${CF_heat_mode:-off}; hd_bm=${CF_burst:-off}
    if [ "$hd_m" = off ]; then
      [ "$hd_bm" = off ] && { sleep 5; break; }   # ni calor ni ráfaga: nada que vigilar
    elif [ "$hd_m" != guardian ]; then heat_def "$hd_m" || { sleep 5; continue; }; fi
    bat_temp10_v; hd_b=$BT10; cpu_temp10_v; hd_c=$CT10; skin_temp10_v; hd_k=$SK10
    if [ "$hd_m" = guardian ]; then
      hd_prof=$(eff_profile); guard_target "$hd_prof"; hd_tgt=$GT
      hd_e=$hd_b; hd_src=bateria
      if [ "$hd_k" -gt 0 ] && [ $((hd_k - GUARD_SKIN_OFF)) -gt "$hd_e" ]; then hd_e=$((hd_k - GUARD_SKIN_OFF)); hd_src=carcasa; fi
      guard_level "$hd_e" "$hd_tgt" "$hd_L"; hd_L=$GL
      # chip muy caliente: piso de nivel 1 o 2 (se suelta 5 °C más abajo)
      if [ "$hd_c" -ge "$GUARD_CHIP2" ]; then hd_cf=2
      elif [ "$hd_c" -ge "$GUARD_CHIP1" ]; then
        [ "$hd_cf" -lt 1 ] && hd_cf=1
        [ "$hd_cf" = 2 ] && [ "$hd_c" -lt $((GUARD_CHIP2 - 50)) ] && hd_cf=1
      elif [ "$hd_c" -lt $((GUARD_CHIP1 - 50)) ]; then hd_cf=0
      elif [ "$hd_cf" = 2 ]; then hd_cf=1
      fi
      if [ "$hd_cf" -gt "$hd_L" ]; then hd_L=$hd_cf; hd_src=chip; fi
      # pantalla apagada (opcional): el nivel no baja de 4
      if [ "${CF_heat_screen:-0}" = 1 ] && screen_off; then hd_off=$((hd_off+1)); else hd_off=0; fi
      if [ "$hd_off" -ge 2 ] && [ "$hd_L" -lt 4 ]; then hd_L=4; hd_src=pantalla; fi
      guard_pct "$hd_L"; hd_want=$GC; hd_wantg=$GG; hd_ap=4
    elif [ "$hd_m" != off ]; then
      heat_level "$hd_b" "$hd_c" "$hd_k" 0 0 0; hd_up=$HL
      heat_level "$hd_b" "$hd_c" "$hd_k" 20 50 20; hd_dn=$HL
      if [ "$hd_up" -gt "$hd_L" ]; then hd_L=$hd_up; hd_calm=0
      elif [ "$hd_dn" -lt "$hd_L" ]; then hd_calm=$((hd_calm+1)); if [ "$hd_calm" -ge 2 ]; then hd_L=$hd_dn; hd_calm=0; fi
      else hd_calm=0; fi
      case "$hd_L" in 1) hd_want=$HT_dw ;; 2) hd_want=$HT_dh ;; *) hd_want=0 ;; esac
      hd_wantg=$hd_want; hd_ap=$((HT_dw/2))
      if [ "${CF_heat_screen:-0}" = 1 ] && screen_off; then hd_off=$((hd_off+1)); else hd_off=0; fi
      [ "$hd_off" -ge 2 ] && [ "$hd_want" -lt 35 ] && hd_want=35
    else hd_L=0; hd_calm=0; hd_want=0; hd_wantg=0; hd_off=0; fi
    # ---- anticipación: si la CPU sube rápido y ya está cerca de «tibio», se baja un poco ANTES de llegar (menos subidas y bajadas bruscas) ----
    # En modo guardián no hace falta: el piso del chip ya se adelanta al calor.
    hd_sl=$((hd_c - hd_t3)); hd_t3=$hd_t2; hd_t2=$hd_t1; hd_t1=$hd_c
    if [ "$hd_m" != off ] && [ "$hd_m" != guardian ] && [ "${CF_heat_ant:-1}" = 1 ] && [ "$hd_L" = 0 ]; then
      if [ "$hd_an" = 0 ]; then
        if [ "$hd_sl" -ge "${MG_ANTSL:-30}" ] && [ "$hd_c" -ge $((HT_cw-100)) ]; then hd_an=1; hd_ancalm=0; fi
      else
        if [ "$hd_sl" -le 0 ]; then hd_ancalm=$((hd_ancalm+1)); [ "$hd_ancalm" -ge 3 ] && hd_an=0; else hd_ancalm=0; fi
        [ "$hd_c" -lt $((HT_cw-150)) ] && hd_an=0
      fi
    else hd_an=0; fi
    hd_wc=$hd_want
    [ "$hd_an" = 1 ] && [ "$hd_ap" -gt "$hd_wc" ] && hd_wc=$hd_ap
    hd_wg=$hd_wantg
    # ---- ráfaga sostenida: el prime puede ir a tope hasta N s; si sigue al tope más tiempo, el tope baja unos puntos (solo CPU) hasta que la carga afloje ----
    hd_bw=0
    case "$hd_bm" in 15|30|60)
      rdv "$CPUF/policy$hd_lp/scaling_cur_freq"; hd_cf=$RV; rdv "$CPUF/policy$hd_lp/scaling_max_freq"; hd_cm=$RV
      if isnum "$hd_cf" && isnum "$hd_cm" && [ "$hd_cm" -gt 0 ]; then
        if [ $((hd_cf*100)) -ge $((hd_cm*93)) ]; then hd_bn=$((hd_bn+1))
        elif [ $((hd_cf*100)) -lt $((hd_cm*75)) ]; then hd_bn=0; fi
        if [ "$hd_bx" = 0 ]; then
          if [ $((hd_bn*hd_tk)) -ge "$hd_bm" ]; then hd_bx=1; hd_bcalm=0; fi
        else
          if [ $((hd_cf*100)) -lt $((hd_cm*80)) ]; then hd_bcalm=$((hd_bcalm+1)); [ "$hd_bcalm" -ge 2 ] && { hd_bx=0; hd_bn=0; hd_bcalm=0; }; else hd_bcalm=0; fi
        fi
      fi
      [ "$hd_bx" = 1 ] && hd_bw=${MG_BURSTD:-6} ;;
    *) hd_bx=0; hd_bn=0 ;;
    esac
    [ "$hd_bw" -gt "$hd_wc" ] && hd_wc=$hd_bw
    if [ "$hd_wc" != "$hd_cur" ] || [ "$hd_wg" != "$hd_curg" ]; then
      hd_tag=""; [ "$hd_an" = 1 ] && hd_tag=" [anticipación]"; [ "$hd_bx" = 1 ] && hd_tag="$hd_tag [ráfaga sostenida]"
      hd_cur=$hd_wc; hd_curg=$hd_wg; heat_apply "$hd_cur" "$hd_curg"
      if [ "$hd_m" = guardian ]; then log "calor: guardián nivel $hd_L/6 (objetivo ${hd_tgt}°C, manda $hd_src), CPU -$hd_cur % GPU -$hd_curg % (batería $hd_b, cpu $hd_c, carcasa $hd_k)$hd_tag"
      elif [ "$hd_cur" = "$hd_curg" ]; then log "calor: nivel $hd_L, topes -$hd_cur % (batería $hd_b, cpu $hd_c, carcasa $hd_k)$hd_tag"
      else log "calor: nivel $hd_L, CPU -$hd_cur % GPU -$hd_curg % (batería $hd_b, cpu $hd_c, carcasa $hd_k)$hd_tag"; fi
    elif [ "$hd_cur" -gt 0 ] && ! des_has "cpu_max_$hd_fp"; then
      hd_e=""; [ -r "$AUTOF" ] && read -r hd_e < "$AUTOF"; [ -n "$hd_e" ] || hd_e=${CF_profile:-stock}
      [ "$hd_e" = stock ] && heat_reapply
    fi
    # el estado se escribe solo si cambió algo (nivel, 0.3 °C) o pasaron 30 s: menos escrituras a la memoria
    uptime_v; hd_wr=0
    [ "$hd_L|$hd_cur" != "$hd_lk" ] && hd_wr=1
    [ $((UPT-hd_wt)) -ge 30 ] && hd_wr=1
    if [ "$hd_wr" = 0 ]; then
      heat_dif "$hd_c" "$hd_lc"; [ "$hd_x" -ge 3 ] && hd_wr=1
      heat_dif "$hd_b" "$hd_lb"; [ "$hd_x" -ge 3 ] && hd_wr=1
      heat_dif "$hd_k" "$hd_ls"; [ "$hd_x" -ge 3 ] && hd_wr=1
    fi
    if [ "$hd_wr" = 1 ]; then echo "$hd_L|$hd_cur|$hd_c|$hd_b|$hd_k" > "$HEATST"; hd_lk="$hd_L|$hd_cur"; hd_wt=$UPT; hd_lc=$hd_c; hd_lb=$hd_b; hd_ls=$hd_k; fi
    hd_xn="$hd_an|$hd_bx|$hd_cur|$hd_curg"; [ "$hd_xn" != "$hd_xk" ] && { echo "$hd_xn" > "$HEATX"; hd_xk=$hd_xn; }
    sleep "$hd_tk" & wait $!
  done
  echo 0 > "$HEATF"; rm -f "$HEATX"; heat_reapply; rm -f "$HEATPID" "$HEATST" "$CONF/heatd.stop"
}
heatd_start() {
  heatd_alive && return 0
  rm -f "$CONF/heatd.stop"
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _heatd </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _heatd </dev/null >/dev/null 2>&1 & fi
  _i=0; while [ "$_i" -lt 5 ]; do heatd_alive && return 0; sleep 1; _i=$((_i+1)); done; heatd_alive
}
heatd_stop() {
  : > "$CONF/heatd.stop"; _d=$(cat "$HEATPID" 2>/dev/null); [ -n "$_d" ] && kill "$_d" 2>/dev/null
  _i=0; while [ "$_i" -lt 5 ] && heatd_alive; do sleep 1; _i=$((_i+1)); done
  rm -f "$HEATPID" "$CONF/heatd.stop" "$HEATST" "$HEATX"; echo 0 > "$HEATF"; heat_reapply
}
heat_set_mode() {   # off|suave|normal|estricto|guardian
  case "$1" in
    off) cfg_set heat_mode off; if [ "$(cfg_get burst off)" = off ]; then heatd_stop; else heatd_start; fi ;;
    suave|normal|estricto|guardian) _w=$(is_target) || { K_ERR=$_w; return 1; }; cfg_set heat_mode "$1"; heatd_start || { K_ERR="no pude iniciar el vigilante de calor"; return 1; } ;;
    *) K_ERR="modo de calor desconocido"; return 1 ;;
  esac
  return 0
}
heat_status() {   # HEAT|modo|nivel|puntos|cpu10|bat10|ahorro_pantalla|vivo|carcasa10|objetivo|maxnivel
  hs_l=0; hs_pt=0; hs_c=""; hs_b=""; hs_k=""
  [ -r "$HEATST" ] && IFS='|' read -r hs_l hs_pt hs_c hs_b hs_k < "$HEATST"
  if [ -z "$hs_c" ]; then cpu_temp10_v; hs_c=$CT10; bat_temp10_v; hs_b=$BT10; skin_temp10_v; hs_k=$SK10; hs_l=0; hs_pt=0; fi
  hs_t=35; hs_ml=2
  if [ "$(cfg_get heat_mode off)" = guardian ]; then hs_ml=6; _hp=$(eff_profile); guard_target "$_hp"; hs_t=$GT; fi
  echo "HEAT|$(cfg_get heat_mode off)|$hs_l|$hs_pt|$hs_c|$hs_b|$(cfg_get heat_screen 0)|$(heatd_alive && echo 1 || echo 0)|${hs_k:-0}|$hs_t|$hs_ml"
}
heatx_set() {   # ant 0|1 · burst off|15|30|60
  K_ERR=""
  case "$1" in
    ant) case "$2" in 0|1) cfg_set heat_ant "$2" ;; *) K_ERR="usa 0 o 1"; return 1 ;; esac ;;
    burst) case "$2" in off|15|30|60) ;; *) K_ERR="la ráfaga puede ser off, 15, 30 o 60 s"; return 1 ;; esac
           _w=$(is_target) || { K_ERR=$_w; return 1; }
           cfg_set burst "$2"
           if [ "$2" = off ]; then
             if [ "$(cfg_get heat_mode off)" = off ]; then heatd_stop; else rm -f "$HEATX"; fi
           else heatd_start || { K_ERR="no pude iniciar el vigilante de calor"; return 1; }; fi ;;
    *) K_ERR="opción desconocida"; return 1 ;;
  esac
  log "calor: $1=$2"; return 0
}
heatx_status() {   # HTX|anticipación (config)|ráfaga (config)|anticipación activa|ráfaga activa|puntos CPU|puntos GPU
  hx_a=0; hx_b=0; hx_c=0; hx_g=0
  [ -r "$HEATX" ] && IFS='|' read -r hx_a hx_b hx_c hx_g < "$HEATX"
  echo "HTX|$(cfg_get heat_ant 1)|$(cfg_get burst off)|$hx_a|$hx_b|$hx_c|$hx_g"
}
