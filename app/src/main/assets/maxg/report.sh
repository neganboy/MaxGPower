#!/system/bin/sh
# MaxG Power - informe completo para diagnóstico: /sdcard/MaxG_power_informe.txt (las direcciones Bluetooth se enmascaran).
report_dump() {
  rp_o=${MG_REPORT:-/sdcard/MaxG_power_informe.txt}
  {
    echo "MaxG Power · informe · $(date '+%F %T')"
    echo "módulo: $(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n 1) · dispositivo: $(dev_name) · kernel $(uname -r 2>/dev/null) · $(getprop ro.build.display.id 2>/dev/null)"
    echo; echo "## Vigilantes"
    for rp_d in autod heatd padd gpud; do
      rp_p=""; [ -r "$CONF/$rp_d.pid" ] && read -r rp_p < "$CONF/$rp_d.pid"
      if [ -n "$rp_p" ] && kill -0 "$rp_p" 2>/dev/null; then echo "$rp_d: vivo ($rp_p)"; else echo "$rp_d: detenido"; fi
    done
    echo "detector de apps: $(cat "$FGMETHOD" 2>/dev/null)"
    echo; echo "## Configuración"; cat "$CFG" 2>/dev/null
    echo; echo "## Estado"; echo "auto.state: $(cat "$AUTOST" 2>/dev/null)"; echo "auto.cur: $(cat "$AUTOF" 2>/dev/null)"; echo "heat.state: $(cat "$HEATST" 2>/dev/null)"
    echo "modo seguro: $([ -e "$CONF/safe" ] && echo sí || echo no) · arranques sin estabilizar: $(cat "$BOOTC" 2>/dev/null)"
    echo; echo "## Temperaturas (décimas de °C)"; cpu_temp10_v; bat_temp10_v; skin_temp10_v; echo "cpu=$CT10 bateria=$BT10 carcasa=$SK10"
    echo "zonas cpu: $(echo $CPUZ | wc -w) · zonas de carcasa: $SKINZ"
    echo; echo "## Batería"
    for rp_n in status capacity current_now voltage_now temp cycle_count charge_control_limit; do echo "$rp_n=$(rd "$R/sys/class/power_supply/battery/$rp_n")"; done
    echo "screen_state=$(rd "$R/sys/class/thermal/thermal_message/screen_state")"
    echo; echo "## Apps propias (paquete|categoría|perfil)"; cat "$AUTOAPPS" 2>/dev/null
    echo "## Vistas recientemente"; cat "$AUTOREC" 2>/dev/null
    echo; echo "## Partidas (inicio|seg|paquete|bat0|bat1|cpuMax|batMax|carcasaMax|subidasCalor|perfil|mando|btRápido|mA|cargando)"; cat "$SESSF" 2>/dev/null
    echo; echo "## Detección del primer plano"; fg_report
    echo; echo "## Mando"; pad_scan
    echo "elegido: $(pad_info)"; echo "estado: $(cat "$PADSTATE" 2>/dev/null)"
    [ -f "$PADFLAPS" ] && { echo "cortes:"; cat "$PADFLAPS"; }
    echo; echo "## Bluetooth"; getprop 2>/dev/null | grep -i -E 'bluetooth\.(core|le)'
    echo; echo "## Registro"; tail -n 80 "$LOG" 2>/dev/null
  } 2>/dev/null | sed 's/\([0-9A-Fa-f][0-9A-Fa-f]:\)\{4\}\([0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]\)/XX:XX:XX:XX:\2/g' > "$rp_o" 2>/dev/null
  [ -s "$rp_o" ] && { chmod 0666 "$rp_o" 2>/dev/null; echo "$rp_o"; }
}
