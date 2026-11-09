#!/system/bin/sh
# MaxG Power - Árbitro de recursos compartidos.
# Hay ajustes (los de Android: escaneos de Wi-Fi/Bluetooth, tasa de refresco...) y prioridades (hilos del Bluetooth) que más de una función quiere tocar.
# Antes cada una guardaba "el valor de antes" por su cuenta y, según el orden en que se apagaban, una dejaba puesto lo de la otra.
# Aquí cada función RECLAMA el recurso con su valor; el original se guarda UNA vez (con el primer reclamo) y se devuelve cuando se suelta el último.
#   st:CLAVE  -> settings global      sy:CLAVE -> settings system      fn:btprio -> prioridad de los hilos del Bluetooth (valor "on")
# Cuando hay varios reclamos con valores distintos manda el dueño que va primero en CLAIM_RANK.
CLAIMF=$CONF/claims; CLAIMO=$CONF/claims.orig; BTPST=$CONF/btprio.state
CLAIM_RANK="pad deluxe btp bt tune hz profile"

res_cur() {   # recurso -> valor actual ("null" si no existe)
  case "$1" in
    st:*) rc_v=$(st_get "${1#st:}") ;;
    sy:*) rc_v=$(sy_get "${1#sy:}") ;;
    fn:btprio) if [ -s "$BTPST" ]; then rc_v=on; else rc_v=off; fi ;;
    *) rc_v="" ;;
  esac
  printf '%s' "${rc_v:-null}"
}
res_write() {   # recurso valor ("null" = borrar el ajuste)
  case "$1" in
    st:*) if [ "$2" = null ]; then $TMO settings delete global "${1#st:}" >/dev/null 2>&1 </dev/null; else st_put "${1#st:}" "$2"; fi ;;
    sy:*) if [ "$2" = null ]; then $TMO settings delete system "${1#sy:}" >/dev/null 2>&1 </dev/null; else sy_put "${1#sy:}" "$2"; fi ;;
    fn:btprio) if [ "$2" = on ]; then btp_apply; else btp_revert; fi ;;
  esac
  return 0
}
claim_orig_get() { CO=""; [ -r "$CLAIMO" ] || return 1; while IFS=$TAB read -r co_r co_v; do [ "$co_r" = "$1" ] && { CO=$co_v; return 0; }; done < "$CLAIMO"; return 1; }
claim_orig_put() { claim_orig_get "$1" && return 0; printf '%s\t%s\n' "$1" "$2" >> "$CLAIMO"; }   # solo la primera vez
claim_orig_del() { [ -r "$CLAIMO" ] || return 0; : > "$CLAIMO.t"; while IFS=$TAB read -r co_r co_v; do [ "$co_r" = "$1" ] || printf '%s\t%s\n' "$co_r" "$co_v" >> "$CLAIMO.t"; done < "$CLAIMO"; mv -f "$CLAIMO.t" "$CLAIMO"; }
claim_has() {   # recurso [dueño]: ¿hay algún reclamo (de ese dueño)?
  [ -r "$CLAIMF" ] || return 1
  while IFS=$TAB read -r ch_r ch_o ch_v; do [ "$ch_r" = "$1" ] || continue; [ -z "${2-}" ] || [ "$ch_o" = "$2" ] || continue; return 0; done < "$CLAIMF"
  return 1
}
claim_owners() {   # recurso -> dueños separados por espacio
  CW=""; [ -r "$CLAIMF" ] || return 0
  while IFS=$TAB read -r ch_r ch_o ch_v; do [ "$ch_r" = "$1" ] && CW="$CW $ch_o"; done < "$CLAIMF"; CW=${CW# }; return 0
}
claim_eff() {   # recurso -> EV = valor del dueño con más rango; EO = ese dueño ("" si no hay reclamos)
  EV=""; EO=""; ce_best=999; ce_i=0
  [ -r "$CLAIMF" ] || return 1
  while IFS=$TAB read -r ce_r ce_o ce_v; do
    [ "$ce_r" = "$1" ] || continue
    ce_k=0; ce_f=0; for ce_x in $CLAIM_RANK; do [ "$ce_x" = "$ce_o" ] && { ce_f=1; break; }; ce_k=$((ce_k+1)); done
    [ "$ce_f" = 1 ] || ce_k=500
    if [ "$ce_k" -lt "$ce_best" ] || { [ "$ce_k" -eq "$ce_best" ] && [ -n "$EO" ]; }; then ce_best=$ce_k; EV=$ce_v; EO=$ce_o; fi   # a igual rango, el más reciente
  done < "$CLAIMF"
  [ -n "$EO" ]
}
claim_drop() {   # recurso dueño -> quita ese reclamo del archivo
  [ -r "$CLAIMF" ] || return 0
  : > "$CLAIMF.t"; while IFS=$TAB read -r cd_r cd_o cd_v; do [ -n "$cd_r" ] || continue; [ "$cd_r" = "$1" ] && [ "$cd_o" = "$2" ] && continue; printf '%s\t%s\t%s\n' "$cd_r" "$cd_o" "$cd_v" >> "$CLAIMF.t"; done < "$CLAIMF"
  mv -f "$CLAIMF.t" "$CLAIMF"
}
claim_put() {   # recurso dueño valor -> reclama y deja puesto el valor que manda
  cp_r=$1; cp_o=$2; cp_v=$3
  if ! claim_has "$cp_r" && ! claim_orig_get "$cp_r"; then claim_orig_put "$cp_r" "$(res_cur "$cp_r")"; fi
  claim_drop "$cp_r" "$cp_o"
  printf '%s\t%s\t%s\n' "$cp_r" "$cp_o" "$cp_v" >> "$CLAIMF"
  claim_eff "$cp_r"; cp_e=$EV
  [ "$(res_cur "$cp_r")" = "$cp_e" ] || res_write "$cp_r" "$cp_e"
  return 0
}
claim_del() {   # recurso dueño -> suelta; si quedan otros manda el siguiente, si no se devuelve el original
  cd_r2=$1
  claim_has "$cd_r2" "$2" || return 0
  claim_drop "$cd_r2" "$2"
  if claim_eff "$cd_r2"; then
    [ "$(res_cur "$cd_r2")" = "$EV" ] || res_write "$cd_r2" "$EV"
  else
    if claim_orig_get "$cd_r2"; then res_write "$cd_r2" "$CO"; fi
    claim_orig_del "$cd_r2"
  fi
  return 0
}
claim_release_owner() {   # dueño -> suelta todo lo que reclamó
  [ -r "$CLAIMF" ] || return 0
  cr_l=""; while IFS=$TAB read -r cr_r cr_o cr_v; do [ "$cr_o" = "$1" ] && cr_l="$cr_l $cr_r"; done < "$CLAIMF"
  for cr_x in $cr_l; do claim_del "$cr_x" "$1"; done
}
claim_release_all() {   # desinstalar / restaurar todo
  [ -r "$CLAIMF" ] || { rm -f "$CLAIMO"; return 0; }
  cr_l=""; while IFS=$TAB read -r cr_r cr_o cr_v; do cr_l="$cr_l $cr_r|$cr_o"; done < "$CLAIMF"
  for cr_x in $cr_l; do claim_del "${cr_x%%|*}" "${cr_x#*|}"; done
  rm -f "$CLAIMF" "$CLAIMO"
}
claim_status() {   # CLAIM|recurso|dueños|valor efectivo|original
  [ -r "$CLAIMF" ] || return 0
  cs_seen=" "
  while IFS=$TAB read -r cs_r cs_o cs_v; do
    case "$cs_seen" in *" $cs_r "*) continue ;; esac; cs_seen="$cs_seen$cs_r "
    claim_owners "$cs_r"; claim_eff "$cs_r"; claim_orig_get "$cs_r"
    echo "CLAIM|$cs_r|$CW|$EV|$CO"
  done < "$CLAIMF"
  return 0
}

# ---- prioridad de los hilos de la pila Bluetooth (recurso fn:btprio) ----
# renice -n -8 a cada hilo de com.android.bluetooth; se guarda "tid|pid" para devolverlo después. El supervisor la reaplica si la pila se reinició.
BTP_NICE=${MG_BTPNICE:-8}
btp_pid() { BP_PID=""; set -- $(pidof com.android.bluetooth 2>/dev/null); BP_PID=${1-}; [ -n "$BP_PID" ]; }
btp_have() { [ -r "$BTPST" ] || return 1; while IFS='|' read -r bh_t bh_p; do [ "$bh_t" = "$1" ] && [ "$bh_p" = "$2" ] && return 0; done < "$BTPST"; return 1; }
btp_apply() {   # sube la prioridad de los hilos que aún no la tienen (se puede llamar muchas veces)
  btp_pid || return 0
  command -v renice >/dev/null 2>&1 || return 0
  for bp_t in "$R/proc/$BP_PID"/task/*; do bp_tid=${bp_t##*/}; [ -d "$bp_t" ] || continue
    btp_have "$bp_tid" "$BP_PID" && continue
    renice -n -"$BTP_NICE" -p "$bp_tid" >/dev/null 2>&1 </dev/null && echo "$bp_tid|$BP_PID" >> "$BTPST"
  done
  return 0
}
btp_revert() {
  [ -r "$BTPST" ] || return 0
  while IFS='|' read -r br_t br_p; do
    [ -d "$R/proc/$br_p/task/$br_t" ] && renice -n "$BTP_NICE" -p "$br_t" >/dev/null 2>&1 </dev/null
  done < "$BTPST"
  rm -f "$BTPST"; return 0
}
btp_refresh() {   # supervisor: si hay reclamo de prioridad y la pila tiene hilos nuevos (o se reinició), se reaplica; y se olvidan los hilos que ya no existen
  claim_has fn:btprio || return 0
  if [ -r "$BTPST" ]; then
    : > "$BTPST.t"; while IFS='|' read -r bf_t bf_p; do [ -d "$R/proc/$bf_p/task/$bf_t" ] && printf '%s|%s\n' "$bf_t" "$bf_p" >> "$BTPST.t"; done < "$BTPST"
    mv -f "$BTPST.t" "$BTPST"
  fi
  btp_apply
}
