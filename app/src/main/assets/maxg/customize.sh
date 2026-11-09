SKIPUNZIP=0
ui_print ""
ui_print "   _  _                      _"
ui_print "  | \\| |___ __ _ __ _ _ _ | |__  ___ _  _"
ui_print "  | .\` / -_) _\` / _\` | ' \\| '_ \\/ _ \\ || |"
ui_print "  |_|\\_\\___\\__, \\__,_|_||_|_.__/\\___/\\_, |"
ui_print "           |___/                     |__/"
ui_print ""
ui_print "  MaxG Power v3.12.2  ·  por Neganboy"
ui_print "- Exclusivo Poco F8 Pro (Snapdragon 8 Elite)"
ui_print "- Perfiles, control manual ON/OFF y detector de conflictos"
ui_print "- Bluetooth pulido, CPU/GPU frescos y sonda profunda"
ui_print "- Modo seguro: si el teléfono se reinicia 3 veces seguidas,"
ui_print "  no se aplica nada en el arranque"
ui_print "- Abre el módulo desde la WebUI de KernelSU"
set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in service.sh post-fs-data.sh uninstall.sh action.sh lib.sh ctl.sh pad.sh gpu.sh heat.sh bt.sh auto.sh tune.sh deluxe.sh report.sh sonda.sh claims.sh conflict.sh manual.sh; do [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755; done
