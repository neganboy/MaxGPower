#!/system/bin/sh
# Sondeo de SOLO LECTURA: genera /sdcard/MaxG_power_sonda.txt
OUT=${MG_SONDAH:-/sdcard/MaxG_power_sonda.txt}
rd() { if [ -r "$1" ]; then case "$1" in /proc/*) cat "$1" 2>/dev/null | head -n 1 ;; *) v=""; read -r v < "$1" 2>/dev/null; printf '%s\n' "$v" ;; esac; else printf '(no legible)\n'; fi; }
ls_vals() { for f in "$1"/*; do
    if [ -d "$f" ] && [ "$2" = rec ]; then echo "  [${f##*/}/]"; for g in "$f"/*; do [ -f "$g" ] && echo "    ${g##*/} = $(rd $g)"; done; continue; fi
    [ -f "$f" ] || continue; echo "  ${f##*/} = $(rd $f)"; done; }
{
echo "MaxG Power sonda · $(date '+%F %T')"
echo; echo "## SISTEMA"; uname -a
for p in ro.product.device ro.product.model ro.board.platform ro.soc.model ro.build.version.release ro.build.display.id; do echo "$p=$(getprop $p)"; done
echo; echo "## CPU"
for p in /sys/devices/system/cpu/cpufreq/policy*; do echo "--- ${p##*/}"
  for n in related_cpus scaling_driver cpuinfo_min_freq cpuinfo_max_freq scaling_min_freq scaling_max_freq scaling_cur_freq scaling_governor scaling_available_frequencies; do [ -e "$p/$n" ] && echo "  $n = $(rd $p/$n)"; done
  [ -d "$p/walt" ] && { echo "  [walt]"; ls_vals "$p/walt"; }; done
echo; echo "## /proc/sys/walt"; ls_vals /proc/sys/walt rec
echo; echo "## GPU kgsl"; ls_vals /sys/class/kgsl/kgsl-3d0
echo "[devfreq de la GPU]"; ls_vals /sys/class/kgsl/kgsl-3d0/devfreq
echo; echo "## DEVFREQ"; for d in /sys/class/devfreq/*; do [ -d "$d" ] && { echo "--- ${d##*/}"; ls_vals "$d"; }; done
echo; echo "## BUS / DCVS / LLCC (nombres)"; ls /sys/devices/system/cpu 2>/dev/null | grep -v -E '^cpu[0-9]+$' | tr '\n' ' '; echo
find /sys/devices -maxdepth 3 \( -iname '*bwmon*' -o -iname '*dcvs*' -o -iname '*llcc*' -o -iname '*memlat*' -o -iname '*ddr*' \) 2>/dev/null | head -n 40
echo; echo "## ¿VOLTAJES EXPUESTOS?"
find /sys/devices/system/cpu /sys/class/devfreq /sys/class/kgsl /sys/kernel -maxdepth 5 \( -iname '*volt*' -o -iname '*vdd*' -o -iname '*undervolt*' -o -iname '*cpr*' \) 2>/dev/null | head -n 60
echo "(si esta lista está vacía, no hay voltajes editables)"
echo; echo "## TÉRMICO: limitadores y escenas"
for z in /sys/class/thermal/cooling_device*; do [ -r "$z/type" ] && echo "  ${z##*/}: $(rd $z/type) cur=$(rd $z/cur_state) max=$(rd $z/max_state)"; done
for f in /sys/class/thermal/thermal_message/*; do [ -f "$f" ] && echo "  thermal_message/${f##*/} = $(rd $f)"; done
echo; echo "## TÉRMICO"
for z in /sys/class/thermal/thermal_zone*; do [ -r "$z/type" ] && echo "  ${z##*/}: $(rd $z/type) = $(rd $z/temp)"; done
echo; echo "## CARGA Y BATERÍA (para un posible límite de carga)"
for d in /sys/class/power_supply/*; do [ -d "$d" ] && { echo "--- ${d##*/}"; for n in type status capacity health cycle_count current_now voltage_now temp charge_type input_suspend charge_control_limit charge_control_end_threshold constant_charge_current_max input_current_limit; do [ -e "$d/$n" ] && echo "  $n = $(rd $d/$n)"; done; }; done
ls /sys/class/qcom-battery 2>/dev/null | head -n 40 | sed 's/^/  qcom-battery\//'
echo; echo "## RED (TCP) y ALMACENAMIENTO"
for n in tcp_congestion_control tcp_available_congestion_control tcp_fastopen tcp_slow_start_after_idle tcp_rmem tcp_wmem; do echo "  $n = $(rd /proc/sys/net/ipv4/$n)"; done
for b in /sys/block/sd* /sys/block/dm-0 /sys/block/dm-1; do [ -d "$b/queue" ] && echo "  ${b##*/}: scheduler=$(rd $b/queue/scheduler) read_ahead_kb=$(rd $b/queue/read_ahead_kb)"; done
echo; echo "## MANDO Y BLUETOOTH (sondeo 3)"
echo "[detección]"; sh "$(dirname "$0")/ctl.sh" pad scan 2>/dev/null
echo "[interrupciones de radio]"; grep -i -E 'bt|blue|hci|wlan|wcn|cnss|uart|serial' /proc/interrupts 2>/dev/null | head -n 20
echo "[Bluetooth: parámetros de conexión]"; getprop | grep -i -E 'bluetooth\.(core|le)'; dumpsys bluetooth_manager 2>/dev/null | grep -i -E 'interval|latency|supervision' | head -n 20
echo "[USB]"; for d in /sys/bus/usb/devices/*; do [ -r "$d/idVendor" ] && echo "  ${d##*/}: $(rd $d/idVendor):$(rd $d/idProduct) $(rd $d/product) control=$(rd $d/power/control)"; done
echo "[pantalla]"; dumpsys display 2>/dev/null | grep -o 'fps=[0-9.]*' | sort -u | tr '\n' ' '; echo; echo "  min_refresh_rate=$(settings get system min_refresh_rate) peak_refresh_rate=$(settings get system peak_refresh_rate) user_refresh_rate=$(settings get system user_refresh_rate)"
echo; echo "## MEMORIA"
for f in swappiness vfs_cache_pressure page-cluster; do echo "  vm.$f = $(rd /proc/sys/vm/$f)"; done
echo "  lru_gen min_ttl_ms = $(rd /sys/kernel/mm/lru_gen/min_ttl_ms)"; echo "  zram = $(rd /sys/block/zram0/comp_algorithm)"
echo; echo "## RAM / ZRAM"
grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree|Cached|Dirty' /proc/meminfo
for f in /sys/block/zram0/comp_algorithm /sys/block/zram0/disksize; do echo "  ${f##*/} = $(rd $f)"; done
for f in swappiness vfs_cache_pressure dirty_ratio dirty_background_ratio dirty_expire_centisecs dirty_writeback_centisecs watermark_scale_factor min_free_kbytes extra_free_kbytes; do [ -e /proc/sys/vm/$f ] && echo "  vm.$f = $(rd /proc/sys/vm/$f)"; done
echo; echo "## ALMACENAMIENTO"
for b in /sys/block/sd* /sys/block/mmcblk* /sys/block/dm-* /sys/block/loop0; do [ -d "$b/queue" ] || continue
  echo "--- ${b##*/}  tamaño=$(rd $b/size)"; for n in scheduler read_ahead_kb nr_requests rotational nomerges rq_affinity add_random iostats write_cache; do [ -e "$b/queue/$n" ] && echo "  $n = $(rd $b/queue/$n)"; done; done
echo "[montajes de /data]"; grep -E ' /data | /sdcard ' /proc/mounts | cut -c1-200
echo "[ufs]"; for u in /sys/devices/platform/soc/*ufs*; do [ -d "$u" ] && { echo "  ${u##*/}"; for n in clkscale_enable clkgate_enable rpm_lvl spm_lvl auto_hibern8; do [ -e "$u/$n" ] && echo "    $n = $(rd $u/$n)"; done; }; done
echo "[f2fs]"; for d in /sys/fs/f2fs/*; do [ -d "$d" ] || continue; echo "  ${d##*/}"; for n in gc_urgent_sleep_time discard_idle_interval gc_idle ra_nid_pages readdir_ra ; do [ -e "$d/$n" ] && echo "    $n = $(rd $d/$n)"; done; done
echo; echo "## ENTRADA / MANDOS (solo nombres de dispositivos)"
grep -E '^(N: Name|H: Handlers)' /proc/bus/input/devices | cut -c1-120
echo "[usbhid]"; for n in jspoll mousepoll kbpoll; do [ -e /sys/module/usbhid/parameters/$n ] && echo "  $n = $(rd /sys/module/usbhid/parameters/$n)" || echo "  $n = (no existe)"; done
echo "[dispositivos USB conectados]"
for d in /sys/bus/usb/devices/*; do [ -r "$d/idVendor" ] || continue
  echo "--- ${d##*/} vendor=$(rd $d/idVendor) producto=$(rd $d/idProduct) nombre=$(rd $d/product) velocidad=$(rd $d/speed) Mb/s"
  for e in $d/*/ep_* $d/ep_*; do [ -r "$e/interval" ] && echo "    ${e##*/}: intervalo=$(rd $e/interval) tipo=$(rd $e/type) dir=$(rd $e/direction)"; done; done
echo "[bluetooth]"; getprop | grep -i -E 'bluetooth\.(a2dp|le|profile)|persist\.bluetooth' | head -n 20
echo; echo "## OTROS MÓDULOS"
for m in /data/adb/modules/*/module.prop; do [ -f "$m" ] && echo "  $(sed -n 's/^name=//p' $m | head -n1) $(sed -n 's/^version=//p' $m | head -n1)"; done
echo; echo FIN
} > "$OUT" 2>&1
chmod 0666 "$OUT" 2>/dev/null
echo "Listo: $OUT"
# además, el informe del módulo (estado, detección de apps, partidas, mando, registro)
_r=$(sh "$(dirname "$0")/ctl.sh" report 2>/dev/null | sed -n 's/^RESULT|report|ok|//p')
[ -n "$_r" ] && echo "Informe del módulo: $_r"
