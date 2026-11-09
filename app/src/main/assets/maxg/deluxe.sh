#!/system/bin/sh
# MaxG Power (F8 Pro) - Modo Deluxe: lo recomendado para jugar con mando (latencia mínima, estabilidad, calor controlado), en un solo botón.
DLX_ITEMS="pad btfast btguard btfix auto net io hz wifi heat"
deluxe_get() {
  case "$1" in
    pad) [ "$(cfg_get pad 0)" = 1 ] ;;
    btfast) [ "$(cfg_get bt_fast 0)" = 1 ] ;;
    btguard) [ "$(cfg_get bt_guard 1)" = 1 ] ;;
    btfix) [ "$(cfg_get bt_autofix 1)" = 1 ] ;;
    auto) [ "$(cfg_get auto 1)" = 1 ] ;;
    net) [ "$(cfg_get tune_net 1)" = 1 ] ;;
    io) [ "$(cfg_get tune_io 1)" = 1 ] ;;
    hz) [ "$(cfg_get pad_hz 1)" = 1 ] ;;
    wifi) [ "$(cfg_get pad_wifi 1)" = 1 ] ;;
    heat) [ "$(cfg_get heat_mode off)" != off ] ;;
    *) return 1 ;;
  esac
}
deluxe_status() { printf 'DLX'; for dx_i in $DLX_ITEMS; do if deluxe_get "$dx_i"; then printf '|%s:1' "$dx_i"; else printf '|%s:0' "$dx_i"; fi; done; echo; }
deluxe_on() {   # el reinicio del Bluetooth va al final: corta el mando unos segundos
  K_ERR=""; dx_w=$(is_target) || { K_ERR=$dx_w; return 1; }
  cfg_set pad 1; padd_start || { K_ERR="no pude iniciar el vigilante del mando"; return 1; }
  cfg_set bt_autofix 1; cfg_set bt_guard 1; btg_apply
  cfg_set pad_hz 1; cfg_set pad_wifi 1
  tune_set net 1; tune_set io 1
  cfg_set auto 1; autod_start >/dev/null 2>&1
  [ "$(cfg_get heat_mode off)" = off ] && heat_set_mode suave
  [ "$(cfg_get bt_fast 0)" = 1 ] || bt_fast_set on
  log "Deluxe: todo lo recomendado activado"
  return 0
}
