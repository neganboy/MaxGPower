#!/system/bin/sh
# MaxG Power (F8 Pro) - Modo inteligente.
#  1) Perfil automático según la app en primer plano (juegos / mapas), batería baja y pantalla apagada. Cada app puede tener su propio perfil.
#  2) Impulso de carga: los primeros segundos de un juego o de una app de mapas suben de potencia para que todo cargue rápido, luego pasa al perfil normal.
#  3) Mantenimiento nocturno: con el teléfono cargando y la pantalla apagada hace fstrim y optimiza las apps de juegos y mapas.
#  4) Historial de partidas: duración, batería gastada, temperaturas y corriente media de cada sesión de juego.
# El perfil que elegiste a mano (cfg "profile") no se toca: el modo inteligente solo pone un perfil temporal encima (auto.cur).
# Detección de la app: lee el cgroup "top-app" del kernel (sin llamar a Android, sin bloquear el gestor de ventanas); si ese método no sirve en tu ROM,
# se usa dumpsys automáticamente.
AUTOF=$CONF/auto.cur; AUTOPID=$CONF/autod.pid; AUTOST=$CONF/auto.state; AUTOAPPS=$CONF/auto.apps; AUTOREC=$CONF/auto.recent; SESSF=$CONF/sessions
MAINTPID=$CONF/maint.pid; MAINTRES=$CONF/maint.res; FGMETHOD=$CONF/fg.method
GAME_PKGS="com.dts.freefireth com.dts.freefiremax com.garena.game.codm com.activision.callofduty.shooter com.tencent.ig com.pubg.imobile com.pubg.krmobile com.mobile.legends com.miHoYo.GenshinImpact com.HoYoverse.hkrpgoversea com.HoYoverse.Nap com.kurogame.wutheringwaves.global com.roblox.client com.mojang.minecraftpe com.supercell.brawlstars com.supercell.clashofclans com.supercell.clashroyale com.riotgames.league.wildrift com.epicgames.fortnite com.nianticlabs.pokemongo com.innersloth.spacemafia com.gameloft.android.ANMP.GloftA9HM com.levelinfinite.sgameGlobal org.ppsspp.ppsspp org.ppsspp.ppssppgold"
MAPS_PKGS="com.google.android.apps.maps com.waze com.here.app.maps net.osmand net.osmand.plus app.organicmaps com.google.earth"
AU_PK=" "; FG_CGF=""

# perfil efectivo: el temporal del modo inteligente si hay uno, si no el elegido
eff_profile() {
  if manual_on_p && [ -f "$CUS/u_manual" ]; then echo u_manual; return 0; fi   # control manual ON: manda lo manual, nada más
  _e=""; [ -r "$AUTOF" ] && read -r _e < "$AUTOF"; if [ -n "$_e" ]; then echo "$_e"; else cfg_get profile stock; fi
}

charging() { rdv "$R/sys/class/power_supply/battery/status"; case "$RV" in Charging|Full) return 0 ;; esac; return 1; }
bat_level_v() { rdv "$R/sys/class/power_supply/battery/capacity"; if isnum "$RV"; then BL=$RV; else BL=100; fi; }
bat_level() { bat_level_v; echo "$BL"; }

# devuelve a lo original los topes y ajustes que puso un perfil (los extras de memoria no se tocan)
knobs_restore() {
  [ -s "$ORIG" ] || return 0
  for kr_pass in mx mn ot mx; do
    while IFS="$TAB" read -r kr_n kr_v; do
      case "$kr_pass:$kr_n" in
        mx:cpu_max_*|mx:gpu_max|mn:cpu_min_*|mn:gpu_min|ot:walt_*|ot:sched_*|ot:vm_swap)
          kr_p=$(knob_path "$kr_n"); [ -n "$kr_p" ] && [ -e "$kr_p" ] && knob_put "$kr_n" "$kr_v"; des_del "$kr_n" ;;
      esac
    done < "$ORIG"
  done
}
# aplica un perfil temporal ("" = volver al elegido)
auto_apply() {
  if manual_on_p; then { [ -n "$1" ] && echo "$1" > "$AUTOF"; } || rm -f "$AUTOF"; return 0; fi   # control manual ON: el modo inteligente no toca CPU ni GPU
  lock_take
  if [ -n "$1" ]; then echo "$1" > "$AUTOF"
  else rm -f "$AUTOF"; [ "$(cfg_get profile stock)" = stock ] && { knobs_restore; hz_restore; }; fi
  heat_reapply; lock_free
}

# ---- apps registradas (integradas + propias) ----
pkg_esc() { printf '%s' "$1" | sed 's/\./\\./g'; }
au_load() {   # AU_PK = " pkg1 pkg2 " con las apps propias (una sola lectura del archivo por vuelta)
  AU_PK=" "; [ -s "$AUTOAPPS" ] || return 0
  while IFS='|' read -r al_p al_r; do [ -n "$al_p" ] && AU_PK="$AU_PK$al_p "; done < "$AUTOAPPS"
  return 0
}
pkg_hit() { case " $GAME_PKGS $MAPS_PKGS$AU_PK" in *" $1 "*) return 0 ;; esac; return 1; }   # ¿está registrada (aunque sea para ignorarla)?
pkg_cat_v() {   # paquete -> PC_CAT (game|maps|"" = ignorada o desconocida), PC_PROF (perfil propio de la app o ""), PC_HIT (1 si está registrada)
  PC_CAT=""; PC_PROF=""; PC_HIT=0
  if [ -s "$AUTOAPPS" ]; then
    while IFS='|' read -r pc_p pc_c pc_f; do
      [ "$pc_p" = "$1" ] || continue
      PC_HIT=1; PC_CAT=""; PC_PROF=""
      case "$pc_c" in game|maps) PC_CAT=$pc_c; PC_PROF=$pc_f ;; esac     # la última línea manda; "none" deja la app ignorada
    done < "$AUTOAPPS"
  fi
  [ "$PC_HIT" = 1 ] && return 0
  case " $GAME_PKGS " in *" $1 "*) PC_CAT=game; PC_HIT=1; return 0 ;; esac
  case " $MAPS_PKGS " in *" $1 "*) PC_CAT=maps; PC_HIT=1 ;; esac
  return 0
}
pkg_cat() { pkg_cat_v "$1"; printf '%s' "$PC_CAT"; }   # paquete -> game|maps|nada
# apps vistas en primer plano que todavía no están registradas (se ofrecen en la pantalla con un toque)
rc_ok() {   # 0 si el paquete puede ofrecerse (no es del sistema, ni un launcher, ni el administrador de root)
  case "$1" in
    android|android.*|com.android.*|com.google.android.*|com.miui.*|com.xiaomi.*|com.mi.*|com.qualcomm.*|com.qti.*|org.codeaurora.*|com.mediatek.*|com.rifsxd.*|me.weishu.*|com.topjohnwu.*|com.lbe.*|vendor.*) return 1 ;;
  esac
  return 0
}
rc_note() {   # $1 = paquete visto
  RC_LAST=$1
  rc_ok "$1" || return 0
  pkg_hit "$1" && return 0
  { echo "$1|$ad_now"; grep -v "^$(pkg_esc "$1")|" "$AUTOREC" 2>/dev/null; } | head -n 12 > "$AUTOREC.t" 2>/dev/null; mv -f "$AUTOREC.t" "$AUTOREC" 2>/dev/null
  return 0
}
auto_app_add() {   # paquete game|maps|none [perfil|none|-]
  K_ERR=""
  case "$1" in ''|*[!A-Za-z0-9_.]*) K_ERR="nombre de paquete no válido"; return 1 ;; esac
  case "$1" in [A-Za-z]*.*) ;; *) K_ERR="un paquete lleva puntos, por ejemplo com.empresa.app"; return 1 ;; esac
  [ "${#1}" -le 80 ] || { K_ERR="nombre demasiado largo"; return 1; }
  case "$2" in game|maps|none) ;; *) K_ERR="categoría: game, maps o none"; return 1 ;; esac
  aa_pf=${3:-}
  case "$aa_pf" in ''|-) aa_pf="" ;; none) ;; *) rule_ok "$aa_pf" || { K_ERR="perfil desconocido"; return 1; } ;; esac
  [ "$2" = none ] && aa_pf=""
  if ! grep -q "^$(pkg_esc "$1")|" "$AUTOAPPS" 2>/dev/null && [ "$(grep -c . "$AUTOAPPS" 2>/dev/null)" -ge 30 ] 2>/dev/null; then K_ERR="máximo 30 apps propias"; return 1; fi
  { grep -v "^$(pkg_esc "$1")|" "$AUTOAPPS" 2>/dev/null; echo "$1|$2|$aa_pf"; } > "$AUTOAPPS.t"; mv -f "$AUTOAPPS.t" "$AUTOAPPS"
  grep -v "^$(pkg_esc "$1")|" "$AUTOREC" > "$AUTOREC.t" 2>/dev/null; mv -f "$AUTOREC.t" "$AUTOREC" 2>/dev/null   # ; y no &&: si era la única de la lista, grep no imprime nada y devuelve 1
  log "auto: app $1 -> $2${aa_pf:+ (perfil $aa_pf)}"; return 0
}
auto_app_del() { grep -v "^$(pkg_esc "$1")|" "$AUTOAPPS" > "$AUTOAPPS.t" 2>/dev/null; mv -f "$AUTOAPPS.t" "$AUTOAPPS" 2>/dev/null; return 0; }

# ---- app en primer plano ----
fg_cg_find() {   # ruta del cgroup "top-app" (procesos de la app que tienes delante); falla si este kernel no la tiene
  FG_CGF=""
  for fc_f in "$R/dev/cpuset/top-app/cgroup.procs" "$R/dev/cpuctl/top-app/cgroup.procs" "$R/dev/stune/top-app/cgroup.procs" "$R/sys/fs/cgroup/top-app/cgroup.procs"; do
    if [ -r "$fc_f" ]; then FG_CGF=$fc_f; return 0; fi
  done
  return 1
}
fg_pid_name() {   # pid -> FGN: nombre del proceso (sin ":sufijo") si parece un paquete, si no vacío
  FGN=""; fn_f="$R/proc/$1/cmdline"
  [ -r "$fn_f" ] || return 0
  fn_c=""; read -r fn_c < "$fn_f" 2>/dev/null
  fn_c=${fn_c%%:*}
  case "$fn_c" in ''|*/*|*' '*|[!A-Za-z]*) return 0 ;; *.*) FGN=$fn_c ;; esac
  return 0
}
fg_scan() {   # procesos del cgroup top-app: FG_PKG = app registrada delante (los juegos mandan sobre los mapas), FG_ANY = primera app cualquiera que se puede ofrecer
  FG_PKG=""; FG_ANY=""
  [ -n "$FG_CGF" ] && [ -r "$FG_CGF" ] || return 1
  while read -r fs_pid; do
    isnum "$fs_pid" || continue
    fg_pid_name "$fs_pid"; [ -n "$FGN" ] || continue
    if pkg_hit "$FGN"; then
      pkg_cat_v "$FGN"
      case "$PC_CAT" in game) FG_PKG=$FGN ;; maps) [ -n "$FG_PKG" ] || FG_PKG=$FGN ;; esac
    elif [ -z "$FG_ANY" ] && rc_ok "$FGN"; then FG_ANY=$FGN; fi
  done < "$FG_CGF"
  return 0
}
fg_parse() {   # $1 = líneas de dumpsys -> FG_D = primer paquete que se pueda leer ("Window{abc u0 com.x/com.x.Main}" o "ActivityRecord{abc u0 com.x/.Main t12}")
  FG_D=""
  while IFS= read -r fp_l; do
    case "$fp_l" in *'{'*) ;; *) continue ;; esac
    fp_l=${fp_l#*\{}; fp_l=${fp_l#* }; fp_l=${fp_l#* }
    fp_p=${fp_l%%/*}
    case "$fp_p" in ''|*[!A-Za-z0-9_.]*) continue ;; *.*) FG_D=$fp_p; return 0 ;; esac
  done <<FGEOF
$1
FGEOF
  return 0
}
fg_dump() {   # FG_D = paquete con el foco según dumpsys (vacío si no se pudo saber). Es más pesado: solo se usa de apoyo
  fd_o=$($TMO dumpsys window 2>/dev/null </dev/null | grep -E 'mCurrentFocus=|mFocusedApp=' | head -n 4)
  fg_parse "$fd_o"
  if [ -z "$FG_D" ]; then
    fd_o=$($TMO dumpsys activity activities 2>/dev/null </dev/null | grep -E 'topResumedActivity=|mResumedActivity' | head -n 3)
    fg_parse "$fd_o"
  fi
  return 0
}
fg_pkg() { fg_dump; printf '%s' "$FG_D"; }
fg_detect() {   # -> FGD_PK (app registrada delante o ""), ad_seen (cualquier app vista), ad_fgk (0 si no se pudo saber)
  FGD_PK=""; ad_seen=""; ad_fgk=1
  if [ "$ad_fgm" = cg ]; then
    if ! fg_scan; then ad_fgm=dump; echo dump > "$FGMETHOD"; log "auto: no puedo leer el cgroup top-app, se usa dumpsys"; fi
  fi
  if [ "$ad_fgm" = cg ]; then
    FGD_PK=$FG_PKG; ad_seen=${FG_PKG:-$FG_ANY}
    # verificación cruzada de vez en cuando: si dumpsys ve una app registrada que el cgroup no vio, el cgroup no sirve en esta ROM
    if [ -z "$FGD_PK" ] && [ $((ad_n % ${MG_FGCHK:-16})) -eq 3 ]; then
      fg_dump
      if [ -n "$FG_D" ]; then
        [ -n "$ad_seen" ] || ad_seen=$FG_D
        pkg_cat_v "$FG_D"
        if [ -n "$PC_CAT" ]; then ad_fgm=dump; echo dump > "$FGMETHOD"; FGD_PK=$FG_D; log "auto: el cgroup no vio a $FG_D, se usa dumpsys"; fi
      fi
    fi
  else
    fg_dump
    if [ -n "$FG_D" ]; then
      ad_seen=$FG_D; pkg_cat_v "$FG_D"; [ -n "$PC_CAT" ] && FGD_PK=$FG_D
    else ad_fgk=0; fi
  fi
  return 0
}
fg_report() {   # FG|dumpsys|categoría|método|cgroup|otra (para depurar desde la pantalla o la consola)
  au_load; fg_dump; fr_d=$FG_D; pkg_cat_v "$fr_d"; fr_c=$PC_CAT
  FG_PKG=""; FG_ANY=""; fr_m=dump; fg_cg_find && { fr_m=cg; fg_scan; }
  echo "FG|$fr_d|$fr_c|$fr_m|$FG_PKG|$FG_ANY"
}

# ---- reglas ----
rule_ok() { [ "$1" = none ] && return 0; prof_def "$1" >/dev/null 2>&1; }
auto_rule_set() {   # game|maps|low|off perfil|none   |   lowpct N   |   boost N   |   mapboost N
  K_ERR=""
  case "$1" in
    game|maps|low|off) rule_ok "$2" || { K_ERR="perfil desconocido"; return 1; }; cfg_set "auto_$1" "$2" ;;
    lowpct) case "$2" in 0|10|15|20|30) cfg_set auto_lowpct "$2" ;; *) K_ERR="el aviso de batería baja va de 0 (apagado) a 30 %"; return 1 ;; esac ;;
    boost) case "$2" in 0|15|25|40) cfg_set auto_boost "$2" ;; *) K_ERR="el impulso puede ser 0, 15, 25 o 40 s"; return 1 ;; esac ;;
    mapboost) case "$2" in 0|8|15) cfg_set auto_mboost "$2" ;; *) K_ERR="el impulso de mapas puede ser 0, 8 o 15 s"; return 1 ;; esac ;;
    *) K_ERR="regla desconocida"; return 1 ;;
  esac
  log "auto: regla $1=$2"; return 0
}

# ---- historial de partidas ----
# una línea por partida: inicio|segundos|paquete|bat_inicio|bat_fin|cpu_max|bat_max|carcasa_max|subidas_calor|perfil|mando|btrapido|mA_medios|cargando   (temperaturas en décimas de °C)
ss_open() { SS_ON=1; SS_PK=$1; SS_T0=$ad_now; SS_TL=$ad_now; SS_B0=$ad_lvl; SS_BL=$ad_lvl; SS_N=0; SS_CS=0; SS_CMX=0; SS_BMX=0; SS_SMX=0; SS_HL=0; SS_HP=0; SS_CH=0; SS_PD=0; SS_PR=${CF_profile:-stock}; }
ss_sample() {
  SS_N=$((SS_N+1)); SS_TL=$ad_now; SS_BL=$ad_lvl
  [ "$ad_chg" = 1 ] && SS_CH=1
  [ -f "$PADSTATE" ] && SS_PD=1
  rdv "$R/sys/class/power_supply/battery/current_now"; ss_c=${RV#-}
  isnum "$ss_c" && SS_CS=$((SS_CS + ss_c/1000))
  ss_l=0
  if [ -r "$HEATST" ]; then IFS='|' read -r ss_l ss_p ss_ct ss_bt ss_sk < "$HEATST" 2>/dev/null
  else cpu_temp10_v; ss_ct=$CT10; bat_temp10_v; ss_bt=$BT10; skin_temp10_v; ss_sk=$SK10; fi
  isnum "$ss_ct" && [ "$ss_ct" -gt "$SS_CMX" ] && SS_CMX=$ss_ct
  isnum "$ss_bt" && [ "$ss_bt" -gt "$SS_BMX" ] && SS_BMX=$ss_bt
  isnum "$ss_sk" && [ "$ss_sk" -gt "$SS_SMX" ] && SS_SMX=$ss_sk
  if isnum "$ss_l"; then [ "$ss_l" -gt "$SS_HP" ] && SS_HL=$((SS_HL+1)); SS_HP=$ss_l; fi
  [ "$ad_cat" = game ] && SS_PR=${ad_cur:-${CF_profile:-stock}}
  return 0
}
ss_close() {
  [ "$SS_ON" = 1 ] || return 0; SS_ON=0
  ss_d=$((SS_TL-SS_T0))
  if [ "$ss_d" -ge "${MG_SESSMIN:-60}" ] && [ "$SS_N" -gt 0 ]; then
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$SS_T0" "$ss_d" "$SS_PK" "$SS_B0" "$SS_BL" "$SS_CMX" "$SS_BMX" "$SS_SMX" "$SS_HL" "$SS_PR" "$SS_PD" "${CF_bt_fast:-0}" "$((SS_CS/SS_N))" "$SS_CH" >> "$SESSF"
    ss_n=$(wc -l < "$SESSF" 2>/dev/null); isnum "$ss_n" && [ "$ss_n" -gt 20 ] && { tail -n 20 "$SESSF" > "$SESSF.t" && mv -f "$SESSF.t" "$SESSF"; }
    log "auto: partida de $SS_PK terminada ($((ss_d/60)) min, batería $SS_B0 -> $SS_BL %)"
  fi
  return 0
}
sess_status() { [ -s "$SESSF" ] && sed 's/^/SESS|/' "$SESSF"; return 0; }

# ---- descripción en vivo del módulo (se ve en la lista de módulos del administrador) ----
desc_pname() {
  case "$1" in
    stock|'') DS_PN=Original ;; minimo) DS_PN=Supervivencia ;; ultra) DS_PN="Ultra ahorro" ;; profundo) DS_PN="Ahorro profundo" ;; ahorro) DS_PN="Ahorro fuerte" ;; bateria) DS_PN=Batería ;; eco) DS_PN=Eco ;; juego) DS_PN="Juego fresco" ;; medio) DS_PN=Equilibrado ;;
    diario) DS_PN=Fluido ;; rendfresco) DS_PN="Rend. fresco" ;; alto) DS_PN=Alto ;; maximo) DS_PN=Máximo ;; u_*) DS_PN=$(custom_name "$1") ;; *) DS_PN=$1 ;;
  esac
}
desc_make() {
  ds_e=""; [ -r "$AUTOF" ] && read -r ds_e < "$AUTOF"
  [ -n "$ds_e" ] || ds_e=${CF_profile:-stock}
  desc_pname "$ds_e"; ds_t="Perfil: $DS_PN"
  if [ -r "$HEATST" ]; then
    IFS='|' read -r ds_l ds_p ds_c ds_b ds_k < "$HEATST" 2>/dev/null
    isnum "$ds_b" && [ "$ds_b" -gt 0 ] && ds_t="$ds_t · Batería $((ds_b/10)).$((ds_b%10)) °C"
  fi
  if [ -r "$PADSTATE" ]; then ds_p=""; read -r ds_p < "$PADSTATE" 2>/dev/null; if [ -n "$ds_p" ]; then ds_m=${ds_p%%\|*}; ds_t="$ds_t · Mando: $ds_m"; fi; fi
  if [ -s "$SESSF" ]; then
    ds_s=$(tail -n 1 "$SESSF"); IFS='|' read -r ds_a ds_d ds_pk ds_b0 ds_b1 ds_x1 ds_x2 ds_x3 ds_x4 ds_x5 ds_x6 ds_x7 ds_x8 ds_ch <<DSEOF
$ds_s
DSEOF
    if isnum "$ds_d"; then ds_t="$ds_t · Última partida: $((ds_d/60)) min"; [ "$ds_ch" = 0 ] && isnum "$ds_b0" && isnum "$ds_b1" && [ "$ds_b0" -ge "$ds_b1" ] && ds_t="$ds_t (−$((ds_b0-ds_b1)) %)"; fi
  fi
  DS_TXT="Poco F8 Pro · $ds_t"
}
desc_update() {   # reescribe la línea description= de module.prop solo si cambió
  [ "${CF_desc_live:-1}" = 1 ] || return 0
  ds_f=${MG_DESCFILE:-}
  if [ -z "$ds_f" ] && [ "$MODDIR" = /data/adb/modules/maxg_power ]; then ds_f=$MODDIR/module.prop; fi
  [ -n "$ds_f" ] && [ -w "$ds_f" ] || return 0
  desc_make
  [ "$DS_TXT" = "$DS_LAST" ] && return 0
  DS_LAST=$DS_TXT
  { while IFS= read -r ds_l || [ -n "$ds_l" ]; do case "$ds_l" in description=*) printf 'description=%s\n' "$DS_TXT" ;; *) printf '%s\n' "$ds_l" ;; esac; done < "$ds_f"; } > "$ds_f.t" 2>/dev/null && mv -f "$ds_f.t" "$ds_f" 2>/dev/null
  return 0
}

# ---- vigilante ----
autod_alive() { _d=""; [ -r "$AUTOPID" ] && read -r _d < "$AUTOPID"; [ -n "$_d" ] && kill -0 "$_d" 2>/dev/null; }
autod_run() {
  echo $$ > "$AUTOPID"; rm -f "$CONF/autod.stop" "$AUTOF"
  ad_fgc=""; ad_pk=""; ad_pfk=""; ad_gone=0; ad_boostend=0; ad_bl=-99999; ad_bp=""; ad_lpk=""; ad_ocat=""
  ad_n=0; ad_mn=0; ad_stp=""; ad_cur=""; ad_cat=""; ad_scr=1; ad_chg=0
  SS_ON=0; SS_GONE=0; RC_LAST=""; DS_LAST=""
  ad_fgm=cg; fg_cg_find || ad_fgm=dump; echo "$ad_fgm" > "$FGMETHOD"
  uptime_v; ad_eo=$(( $(date +%s) - UPT ))   # la hora de reloj se calcula como uptime + ad_eo: sin llamar a date en cada vuelta
  log "auto: vigilante iniciado (detector de apps: $ad_fgm)"
  trap 'ss_close; auto_apply ""; rm -f "$AUTOPID" "$AUTOST"; exit 0' TERM INT
  while [ ! -e "$CONF/autod.stop" ]; do
    uptime_v; ad_t=$UPT; ad_now=$((ad_t+ad_eo))
    [ $((ad_n % 60)) -eq 59 ] && ad_eo=$(( $(date +%s) - ad_t ))
    cfg_load
    bat_level_v; ad_lvl=$BL
    if charging; then ad_chg=1; else ad_chg=0; fi
    if screen_off; then ad_scr=0; else ad_scr=1; fi
    ad_lp=${CF_auto_lowpct:-15}; isnum "$ad_lp" || ad_lp=15
    ad_gm=${CF_auto_game:-juego}; ad_mp=${CF_auto_maps:-medio}
    if [ "$ad_scr" = 1 ]; then
      au_load; fg_detect
      if [ "$ad_fgk" = 1 ]; then
        ad_pk=$FGD_PK; ad_new=""; ad_pfk=""
        if [ -n "$ad_pk" ]; then pkg_cat_v "$ad_pk"; ad_new=$PC_CAT; ad_pfk=$PC_PROF; fi
        if [ -n "$ad_new" ] && [ "$ad_pk" != "$ad_lpk" ]; then   # app registrada recién abierta
          ad_boostend=0
          if [ "$ad_pk" != "$ad_bp" ] || [ $((ad_now-ad_bl)) -gt 300 ]; then   # impulso: solo si es otra app o pasaron más de 5 min desde el último
            if [ "$ad_new" = game ]; then ad_bs=${MG_BOOSTS:-${CF_auto_boost:-25}}; else ad_bs=${MG_MBOOSTS:-${CF_auto_mboost:-8}}; fi
            isnum "$ad_bs" || ad_bs=0
            ad_boostend=$((ad_now+ad_bs)); ad_bp=$ad_pk; ad_bl=$ad_now
          fi
        fi
        ad_lpk=$ad_pk; ad_fgc=$ad_new
      fi
      [ -n "$ad_seen" ] && [ "$ad_seen" != "$RC_LAST" ] && rc_note "$ad_seen"
    else ad_fgc=""; ad_pk=""; ad_pfk=""; ad_lpk=""; fi
    # ---- qué perfil toca ----
    ad_cat=""; ad_want=""
    if [ "$ad_lp" -gt 0 ] && [ "$ad_chg" = 0 ] && [ "$ad_lvl" -le "$ad_lp" ]; then
      ad_cat=low; ad_want=${CF_auto_low:-bateria}; [ "$ad_lvl" -le $((ad_lp/2)) ] && [ "$ad_want" != none ] && ad_want=ahorro
    elif [ "$ad_scr" = 0 ]; then
      [ "$ad_chg" = 0 ] && { ad_cat=off; ad_want=${CF_auto_off:-none}; }
    elif [ "$ad_fgc" = game ]; then
      ad_cat=game; ad_want=${ad_pfk:-$ad_gm}
      if [ "$ad_want" != none ] && [ "$ad_now" -lt "$ad_boostend" ]; then ad_cat=boost; ad_want=maximo; fi
    elif [ "$ad_fgc" = maps ]; then
      ad_cat=maps; ad_want=${ad_pfk:-$ad_mp}
      if [ "$ad_want" != none ] && [ "$ad_now" -lt "$ad_boostend" ]; then ad_cat=boost; ad_want=alto; fi
    fi
    [ "$ad_want" = none ] && ad_want=""
    [ "${CF_manual_on:-0}" = 1 ] && { ad_want=""; ad_cat=""; }   # control manual ON: sin perfiles automáticos
    ad_cur=""; [ -r "$AUTOF" ] && read -r ad_cur < "$AUTOF"
    if [ "$ad_want" != "$ad_cur" ]; then
      if [ -z "$ad_want" ]; then
        # al despertar o al conectar el cargador vuelve de inmediato; al salir de un juego espera 2 vueltas para no parpadear
        ad_gone=$((ad_gone+1))
        if [ "$ad_gone" -ge 2 ] || [ "$ad_ocat" = off ] || [ "$ad_ocat" = low ]; then
          auto_apply ""; ad_gone=0; ad_ocat=""; ad_cur=""; log "auto: fin del perfil temporal, vuelve a ${CF_profile:-stock}"
        fi
      elif prof_def "$ad_want" >/dev/null 2>&1; then
        ad_gone=0; auto_apply "$ad_want"; ad_ocat=$ad_cat; ad_cur=$ad_want; log "auto: $ad_cat -> perfil $ad_want (batería $ad_lvl %)"
      else ad_gone=0; log "auto: el perfil «$ad_want» no es válido, se ignora"; fi
    else ad_gone=0; fi
    ad_n=$((ad_n+1)); [ -n "$ad_cur" ] && [ $((ad_n % 9)) -eq 0 ] && reapply >/dev/null
    # ---- historial de partidas ----
    if [ "$ad_scr" = 1 ] && [ "$ad_fgc" = game ] && [ -n "$ad_pk" ]; then
      if [ "$SS_ON" = 1 ] && [ "$SS_PK" != "$ad_pk" ]; then ss_close; fi
      [ "$SS_ON" = 1 ] || ss_open "$ad_pk"
      SS_GONE=0; ss_sample
    elif [ "$SS_ON" = 1 ]; then
      SS_GONE=$((SS_GONE+1)); [ "$SS_GONE" -ge 3 ] && ss_close
    fi
    ad_st="$ad_cat|$ad_cur|$ad_fgc|$ad_boostend|$ad_lvl|$ad_scr|$ad_chg|$ad_pk"
    if [ "$ad_st" != "$ad_stp" ]; then echo "$ad_st" > "$AUTOST"; ad_stp=$ad_st; fi
    [ $((ad_n % ${MG_DESCN:-15})) -eq 1 ] && desc_update
    # mantenimiento: cargando, pantalla apagada un buen rato
    if [ "$ad_scr" = 0 ] && [ "$ad_chg" = 1 ]; then ad_mn=$((ad_mn+1)); else ad_mn=0; fi
    if [ "$ad_mn" -ge "${MG_MAINTN:-40}" ] && [ "${CF_maint:-1}" = 1 ]; then
      ad_ml=${CF_maint_last:-0}; isnum "$ad_ml" || ad_ml=0
      if [ $((ad_now-ad_ml)) -ge 86400 ] && ! maint_alive; then maint_start 0 >/dev/null 2>&1; fi
    fi
    # ---- cuánto dormir: con la pantalla apagada y un perfil temporal puesto se vigila más seguido para volver rápido al despertar ----
    if [ "$ad_scr" = 0 ]; then
      if [ "$ad_ocat" = off ] && [ -n "$ad_cur" ]; then ad_sl=${MG_AUTOTICKOFF:-5}; else ad_sl=${MG_AUTOTICKIDLE:-${MG_AUTOTICKOFF:-15}}; fi
    elif [ "$ad_fgm" = cg ]; then ad_sl=${MG_AUTOTICK:-4}
    elif [ "$ad_fgc" = game ]; then ad_sl=${MG_AUTOTICKG:-${MG_AUTOTICK:-10}}
    else ad_sl=${MG_AUTOTICK:-6}; fi
    sleep "$ad_sl" & wait $!
  done
  ss_close; auto_apply ""; rm -f "$AUTOPID" "$AUTOST" "$CONF/autod.stop"
}
autod_start() {
  autod_alive && return 0
  rm -f "$CONF/autod.stop"
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _autod </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _autod </dev/null >/dev/null 2>&1 & fi
  _i=0; while [ "$_i" -lt 5 ]; do autod_alive && return 0; sleep 1; _i=$((_i+1)); done; autod_alive
}
autod_stop() {
  : > "$CONF/autod.stop"; _d=$(cat "$AUTOPID" 2>/dev/null); [ -n "$_d" ] && kill "$_d" 2>/dev/null
  _i=0; while [ "$_i" -lt 6 ] && autod_alive; do sleep 1; _i=$((_i+1)); done
  rm -f "$AUTOPID" "$CONF/autod.stop" "$AUTOST"
  [ -e "$AUTOF" ] && auto_apply ""
  return 0
}
# Lista de paquetes instalados: "pm list packages" arranca Java y tarda; se guarda 10 min (o hasta pedir "state more fresh")
pkgs_v() {
  PKGS=""; pk_t=""; pk_l=""; uptime_v
  if [ "${PKGFRESH-}" != 1 ] && [ -r "$CONF/pkgs.cache" ]; then { read -r pk_t; read -r pk_l; } < "$CONF/pkgs.cache" 2>/dev/null; fi
  if [ -n "$pk_l" ] && isnum "$pk_t" && [ "$UPT" -ge "$pk_t" ] && [ $((UPT - pk_t)) -lt "${MG_PKGTTL:-600}" ]; then PKGS=" $pk_l"; return 0; fi
  pk_l=$(pm list packages 2>/dev/null </dev/null | sed 's/^package://' | tr '\n' ' ')
  PKGS=" $pk_l"; [ -n "$pk_l" ] && printf '%s\n%s\n' "$UPT" "$pk_l" > "$CONF/pkgs.cache" 2>/dev/null
  return 0
}
auto_status() {   # AUTOCFG|activo|vigilante|juego|mapas|bateria|umbral|pantalla|impulso  AUTOX|impulso_mapas|detector|descripcion_viva  AUTOST|categoría|perfil|app|fin_impulso|batería|pantalla|cargando|paquete  AUTOAPP|paquete|cat|instalada|propia|perfil  AUTOREC|paquete|hora
  echo "AUTOCFG|$(cfg_get auto 1)|$(autod_alive && echo 1 || echo 0)|$(cfg_get auto_game juego)|$(cfg_get auto_maps medio)|$(cfg_get auto_low bateria)|$(cfg_get auto_lowpct 15)|$(cfg_get auto_off none)|$(cfg_get auto_boost 25)"
  echo "AUTOX|$(cfg_get auto_mboost 8)|$(cat "$FGMETHOD" 2>/dev/null)|$(cfg_get desc_live 1)"
  [ -s "$AUTOST" ] && echo "AUTOST|$(cat "$AUTOST")"
  pkgs_v; ap_i=$PKGS
  for ap_p in $GAME_PKGS $MAPS_PKGS; do
    case "$ap_i" in *" $ap_p "*) ;; *) continue ;; esac
    grep -q "^$(pkg_esc "$ap_p")|" "$AUTOAPPS" 2>/dev/null && continue
    pkg_cat_v "$ap_p"; echo "AUTOAPP|$ap_p|$PC_CAT|1|0|"
  done
  [ -s "$AUTOAPPS" ] && while IFS='|' read -r ap_p ap_c ap_f; do
    [ -n "$ap_p" ] || continue
    case "$ap_i" in *" $ap_p "*) ap_x=1 ;; *) ap_x=0 ;; esac
    echo "AUTOAPP|$ap_p|$ap_c|$ap_x|1|$ap_f"
  done < "$AUTOAPPS"
  [ -s "$AUTOREC" ] && sed 's/^/AUTOREC|/' "$AUTOREC"
  return 0
}

# ---- mantenimiento ----
maint_alive() { _d=$(cat "$MAINTPID" 2>/dev/null); [ -n "$_d" ] && kill -0 "$_d" 2>/dev/null; }
maint_ok() { charging && screen_off && [ "$(bat_level)" -ge 30 ] && [ "$(cpu_temp10)" -lt 420 ]; }
maint_job() {   # $1 = 1 fuerza (ignora pantalla apagada)
  mt_force=${1:-0}; echo $$ > "$MAINTPID"; trap 'rm -f "$MAINTPID"; exit 0' TERM INT
  mt_t0=$(date +%s); mt_n=0; mt_why=""; mt_to=""; command -v timeout >/dev/null 2>&1 && mt_to="timeout 900"
  log "mantenimiento: inicio (forzado=$mt_force)"
  mt_chk() { if [ "$mt_force" = 1 ]; then charging || [ "$(bat_level)" -ge 50 ]; else maint_ok; fi; }
  if mt_chk; then
    if $mt_to sm idle-maintenance >/dev/null 2>&1 </dev/null || $mt_to sm fstrim >/dev/null 2>&1 </dev/null; then mt_n=$((mt_n+1)); fi
    if mt_chk; then $mt_to cmd package bg-dexopt-job >/dev/null 2>&1 </dev/null && mt_n=$((mt_n+1)); fi
    ap_inst=$(pm list packages 2>/dev/null </dev/null)
    for mt_p in $GAME_PKGS $MAPS_PKGS $(cut -d'|' -f1 "$AUTOAPPS" 2>/dev/null); do
      printf '%s\n' "$ap_inst" | grep -qx "package:$mt_p" || continue
      mt_chk || { mt_why="se interrumpió (ya no cumple las condiciones)"; break; }
      $mt_to cmd package compile -m speed-profile -f "$mt_p" >/dev/null 2>&1 </dev/null && mt_n=$((mt_n+1))
    done
  else mt_why="no cumple las condiciones (cargando, pantalla apagada, batería ≥ 30 %, sin calor)"; fi
  mt_t1=$(date +%s); cfg_set maint_last "$mt_t1"
  echo "$mt_t1|$mt_n|$((mt_t1-mt_t0))|$mt_why" > "$MAINTRES"
  log "mantenimiento: terminó ($mt_n pasos en $((mt_t1-mt_t0)) s) $mt_why"
  rm -f "$MAINTPID"
}
maint_start() {
  maint_alive && return 0
  mt_s=$(date +%s)
  if command -v setsid >/dev/null 2>&1; then setsid sh "$MODDIR/ctl.sh" _maint "${1:-0}" </dev/null >/dev/null 2>&1 &
  else nohup sh "$MODDIR/ctl.sh" _maint "${1:-0}" </dev/null >/dev/null 2>&1 & fi
  _i=0; while [ "$_i" -lt 4 ]; do maint_alive && return 0; _ts=$(cut -d'|' -f1 "$MAINTRES" 2>/dev/null); isnum "$_ts" && [ "$_ts" -ge "$mt_s" ] && return 0; sleep 1; _i=$((_i+1)); done; maint_alive
}
maint_status() { echo "MAINT|$(cfg_get maint 1)|$(cfg_get maint_last 0)|$(maint_alive && echo 1 || echo 0)|$(cat "$MAINTRES" 2>/dev/null)"; }
