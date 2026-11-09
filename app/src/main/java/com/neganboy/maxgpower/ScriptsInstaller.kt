package com.neganboy.maxgpower

import android.content.Context

/**
 * Instala los scripts del módulo en /data/adb/maxg_power/bin (con root).
 * Es el mismo directorio de configuración del módulo (/data/adb/maxg_power),
 * así la app hereda la configuración que ya tenía Alejandro.
 */
object ScriptsInstaller {

    const val CONF_DIR = "/data/adb/maxg_power"
    const val BIN_DIR = "$CONF_DIR/bin"
    private const val MARKER = "$BIN_DIR/.maxg-app-v1"

    /** Copia los scripts si falta el marcador de esta versión. Devuelve true si están listos. */
    fun ensureInstalled(context: Context): Boolean {
        val check = RootShell.exec("[ -f $MARKER ] && echo ok || echo no")
        if (check.out.trim() == "ok") return true
        val filesDir = context.filesDir.absolutePath
        // 1) assets -> directorio privado de la app (sin root)
        val assetList = context.assets.list("maxg") ?: emptyArray()
        if (assetList.isEmpty()) return false
        for (name in assetList) {
            if (!name.endsWith(".sh") && name != "index.html") continue
            context.assets.open("maxg/$name").use { input ->
                context.openFileOutput("maxg_$name", Context.MODE_PRIVATE).use { output ->
                    input.copyTo(output)
                }
            }
        }
        // 2) directorio privado -> /data/adb/maxg_power/bin (con root)
        val r = RootShell.exec(
            "mkdir -p $BIN_DIR && " +
            "cp $filesDir/maxg_*.sh $BIN_DIR/ && " +
            "chmod 0755 $BIN_DIR/*.sh && " +
            "touch $MARKER && echo ok"
        )
        return r.code == 0 && r.out.contains("ok")
    }

    /** ¿Está instalado el módulo de KernelSU? (la app y el módulo no deben convivir) */
    fun moduleInstalled(): Boolean {
        val r = RootShell.exec("[ -d /data/adb/modules/maxg_power ] && echo si || echo no")
        return r.out.trim() == "si"
    }

    /** Desactiva el módulo (reversible) para que la app tome el control. */
    fun disableModule(): Boolean {
        val r = RootShell.exec("touch /data/adb/modules/maxg_power/disable && echo ok")
        return r.code == 0 && r.out.contains("ok")
    }

    /** ¿Ya está corriendo el supervisor (service.sh)? */
    fun supervisorRunning(): Boolean {
        val r = RootShell.exec("pgrep -f 'maxg_power/bin/service.sh' >/dev/null && echo si || echo no")
        return r.out.trim() == "si"
    }
}
