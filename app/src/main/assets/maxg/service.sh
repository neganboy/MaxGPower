#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib.sh"
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
# Margen para que el power HAL y la ROM apliquen lo suyo primero
sleep "${MG_BOOTWAIT:-30}"
why=$(is_target) || { log "no es el dispositivo esperado: $why. No se aplica nada."; exit 0; }
# Lo que se guardó como "original" en el arranque anterior ya no vale (pudo ser un límite térmico o de carga de ese momento): se vuelve a leer de lo que tenga la ROM ahora
rm -f "$ORIG" "$CONF/gpu.orig"
claim_release_owner pad; rm -f "$BTPST"   # la sesión del mando y las prioridades de hilos no sobreviven a un reinicio
if [ -e "$CONF/safe" ]; then
  log "arranque en modo seguro: no se aplica nada. Desactívalo desde la app."
  exit 0
fi
heal_gpu
rm -f "$CONF/heat.cur" "$CONF/auto.cur"
lock_take   # con el candado el arranque y un toque de la app no se pisan (en tu sonda se cruzaron): el último en tomarlo manda
if manual_on_p && manual_has; then
  manual_apply && log "arranque: control manual ON aplicado"   # con el manual ON no se aplican perfiles ni gobernador ni modos de GPU
else
  g=$(cfg_get gov none); [ "$g" != none ] && { gov_set "$g" && log "arranque: gobernador $g aplicado"; }
  p=$(cfg_get profile stock)
  case "$p" in
    auto) p=diario; cfg_set profile diario; prof_set diario; extras_apply; log "arranque: perfil diario (migrado desde automático)" ;;
    stock) ;;
    *) prof_set "$p" && log "arranque: perfil $p aplicado"; extras_apply ;;
  esac
  gpu_mode_apply
fi
lock_free
grep -q '^heat_mode=' "$CONF/cfg" 2>/dev/null || cfg_set heat_mode suave   # primera vez: control de calor suave por defecto
{ [ "$(cfg_get heat_mode off)" != off ] || [ "$(cfg_get burst off)" != off ]; } && heatd_start && log "arranque: control de calor activo"
tune_apply_all; btg_apply; btprio_boot
[ "$(cfg_get auto 1)" = 1 ] && autod_start && log "arranque: modo inteligente activo"
{ [ "$(cfg_get gpu_floor 0)" != 0 ] || [ "$(cfg_get gpu_free 0)" = 1 ]; } && gpud_start && log "arranque: vigilante de GPU activo"
[ "$(cfg_get pad 0)" = 1 ] && padd_start && log "arranque: modo mando activo"
# Si 60 s después seguimos vivos, el arranque fue estable
sleep "${MG_STABLE:-60}"; echo 0 > "$BOOTC"; log "arranque estable"
# Supervisor: cada 45 s reaplica lo que la ROM haya pisado y revive los vigilantes que se hayan detenido sin que nadie los apagara
sv_n=0
while :; do
  sleep "${MG_SUPTICK:-45}"
  [ -e "$CONF/safe" ] && continue
  cfg_load
  if [ -s "$DES" ]; then lock_take; reapply >/dev/null; lock_free; fi
  btp_refresh
  sv_n=$((sv_n+1)); [ $((sv_n % 4)) -eq 1 ] && cx_cache_refresh   # otros módulos y ahorro de batería de Android: se miran cada ~3 min para avisar de choques sin frenar a la app
  if [ "${CF_auto:-1}" = 1 ] && [ ! -e "$CONF/autod.stop" ] && ! autod_alive; then log "supervisor: el vigilante automático se había detenido, se reinicia"; autod_start; fi
  if { [ "${CF_heat_mode:-off}" != off ] || [ "${CF_burst:-off}" != off ]; } && [ ! -e "$CONF/heatd.stop" ] && ! heatd_alive; then log "supervisor: el vigilante de calor se había detenido, se reinicia"; heatd_start; fi
  if [ "${CF_pad:-0}" = 1 ] && [ ! -e "$CONF/padd.stop" ] && ! padd_alive; then log "supervisor: el vigilante del mando se había detenido, se reinicia"; padd_start; fi
  if { [ "${CF_gpu_floor:-0}" != 0 ] || [ "${CF_gpu_free:-0}" = 1 ]; } && [ ! -e "$CONF/gpud.stop" ] && ! gpud_alive; then log "supervisor: el vigilante de GPU se había detenido, se reinicia"; gpud_start; fi
done
