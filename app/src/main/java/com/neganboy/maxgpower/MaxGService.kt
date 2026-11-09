package com.neganboy.maxgpower

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Servicio en primer plano que mantiene vivo el supervisor de MaxG.
 * Es el equivalente al service.sh del módulo: aplica el perfil guardado
 * al arrancar y cada 45 s vuelve a aplicar lo que la ROM haya pisado.
 * service.sh ya contiene toda esa lógica; aquí solo lo lanzamos como root
 * y lo revivimos si se muere.
 */
class MaxGService : Service() {

    companion object {
        const val EXTRA_FROM_BOOT = "from_boot"
        private const val NOTIF_ID = 1
        private const val CHANNEL_ID = "maxg_supervisor"
    }

    @Volatile
    private var running = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(NOTIF_ID, buildNotification("MaxG Power activo"))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (running) return START_STICKY
        running = true
        val fromBoot = intent?.getBooleanExtra(EXTRA_FROM_BOOT, false) ?: false
        Thread {
            try {
                // Contador de arranques + props BT tempranas (lo que hacía
                // post-fs-data.sh del módulo). Solo cuando venimos del arranque.
                if (fromBoot) {
                    RootShell.exec("sh ${ScriptsInstaller.BIN_DIR}/boot.sh")
                }
                // Bucle: lanzar service.sh y revivirlo si se detiene.
                while (running) {
                    if (!ScriptsInstaller.supervisorRunning()) {
                        val proc = RootShell.startLong(
                            "sh ${ScriptsInstaller.BIN_DIR}/service.sh"
                        )
                        proc?.waitFor()
                    }
                    if (running) Thread.sleep(10_000)
                }
            } catch (_: InterruptedException) {
            } catch (_: Exception) {
            }
        }.start()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun createChannel() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val ch = NotificationChannel(
            CHANNEL_ID,
            "Supervisor MaxG",
            NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Mantiene aplicado tu perfil de energía y rendimiento" }
        nm.createNotificationChannel(ch)
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MaxG Power")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_idle_charging)
            .setOngoing(true)
            .build()
    }
}
