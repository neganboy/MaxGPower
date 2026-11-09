package com.neganboy.maxgpower

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Al encender el teléfono, arranca el supervisor para que el perfil
 * guardado se aplique solo, como hacía service.sh del módulo.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) return
        val prefs = context.getSharedPreferences("maxg", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("boot_apply", true)) return
        val svc = Intent(context, MaxGService::class.java)
            .putExtra(MaxGService.EXTRA_FROM_BOOT, true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(svc)
        } else {
            context.startService(svc)
        }
    }
}
