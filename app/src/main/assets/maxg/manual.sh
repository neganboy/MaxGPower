#!/system/bin/sh
# MaxG Power - Control manual ON/OFF.
# ON : mandan los valores de la pestaña Manual (perfil propio u_manual) y se IGNORAN los demás controles de CPU y GPU:
#      perfiles, perfiles automáticos (modo inteligente), modos/piso/«quitar freno» de la GPU y gobernador.
#      (El control de calor sigue protegiendo: puede bajar los topes si el teléfono se calienta. «Original» siempre deshace todo.)
# OFF: el ajuste manual se ignora y vuelven a mandar los demás controles, con lo que tenían antes de encenderlo.
MANSAVED=$CONF/manual.saved
manual_on_p() { cfg_v manual_on 0; [ "$CV" = 1 ]; }
manual_has() { [ -f "$CUS/u_manual" ] && custom_load u_manual; }
manual_block() {   # 0 si este control debe ignorarse porque el manual está ON (deja el motivo en K_ERR)
  manual_on_p || return 1
  K_ERR="El control manual está ON: este control se ignora hasta que lo apagues (pestaña Manual)"
  return 0
}
manual_apply() {   # pone u_manual como lo que manda
  pol_warm; prof_def u_manual || { K_ERR="el ajuste manual guardado no es válido"; return 1; }
  prof_set u_manual || { [ -n "$K_ERR" ] || K_ERR="algunos ajustes no se aceptaron (mira el registro)"; return 1; }
  extras_apply; return 0
}
manual_enable() {
  K_ERR=""; _w=$(is_target) || { K_ERR=$_w; return 1; }
  manual_has || { K_ERR="Primero ajusta los controles y pulsa «Aplicar ahora»"; return 1; }
  if ! manual_on_p; then
    # lo que usan los otros controles de la GPU se guarda para devolverlo al apagar (el perfil propio los pisa)
    { echo "gpu_mode=$(cfg_get gpu_mode auto)"; echo "gm_max=$(cfg_get gm_max 100)"; echo "gpu_floor=$(cfg_get gpu_floor 0)"; echo "gpu_free=$(cfg_get gpu_free 0)"; } > "$MANSAVED"
    cfg_set manual_on 1
  fi
  lock_take; manual_apply; _mr=$?; lock_free
  if [ "$_mr" -eq 0 ]; then log "control manual: ON"; else log "control manual: ON con fallos ($K_ERR)"; fi
  return "$_mr"
}
manual_disable() {
  K_ERR=""
  manual_on_p || return 0
  cfg_set manual_on 0
  if [ -r "$MANSAVED" ]; then
    while IFS='=' read -r md_k md_v; do case "$md_k" in gpu_mode|gm_max|gpu_floor|gpu_free) cfg_set "$md_k" "$md_v" ;; esac; done < "$MANSAVED"
    rm -f "$MANSAVED"
  fi
  lock_take
  md_p=$(cfg_get profile stock)
  if [ "$md_p" = stock ] || ! prof_def "$md_p" >/dev/null 2>&1; then knobs_restore; hz_restore
  else pol_warm; prof_set "$md_p" >/dev/null 2>&1; extras_apply; fi
  heat_reapply >/dev/null 2>&1
  gpu_mode_apply
  if [ "$(cfg_get gpu_floor 0)" != 0 ] || [ "$(cfg_get gpu_free 0)" != 0 ]; then gpud_start >/dev/null 2>&1; else gpud_alive && gpud_stop; fi
  lock_free
  log "control manual: OFF (vuelve el perfil $md_p)"
  return 0
}
manual_set() {   # perf prime gpu hl cpl swap [gfloor gfree] -> guarda el ajuste (y lo aplica si el manual está ON)
  K_ERR=""
  custom_save u_manual Manual "$@" || return 1
  if manual_on_p; then lock_take; manual_apply; _mr=$?; lock_free; return "$_mr"; fi
  return 0
}
manual_try() {   # guarda, enciende y aplica (lo que hacía «Aplicar ahora»)
  K_ERR=""
  custom_save u_manual Manual "$@" || return 1
  manual_enable
}
manual_status() {   # MANUAL|activo|existe|perf|prime|gpu|hl|cpl|swap|gfloor|gfree
  if manual_on_p; then ms_o=1; else ms_o=0; fi
  if [ -f "$CUS/u_manual" ]; then
    echo "MANUAL|$ms_o|1|$(custom_get u_manual perf)|$(custom_get u_manual prime)|$(custom_get u_manual gpu)|$(custom_get u_manual hl)|$(custom_get u_manual cpl)|$(custom_get u_manual swap)|$(custom_get u_manual gfloor)|$(custom_get u_manual gfree)"
  else echo "MANUAL|$ms_o|0|||||||"; fi
}
