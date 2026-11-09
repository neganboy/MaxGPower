package com.neganboy.maxgpower.ui

import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

@Composable
fun MoreScreen(vm: MaxGViewModel, state: MaxGState, onOpenLog: (String) -> Unit, onRevertAll: () -> Unit) {
    var logText by remember { mutableStateOf<String?>(null) }
    var sondaText by remember { mutableStateOf<String?>(null) }

    LazyColumn {
        item {
            SectionCard("Bluetooth", "Ajustes del Bluetooth para el mando y los audífonos") {
                ToggleRow(
                    "Bluetooth rápido",
                    "Intervalos LE cortos para menos latencia",
                    state.bt.fast
                ) { on -> vm.runCommand("Bluetooth") { CtlClient.btFast(on) } }
                ToggleRow(
                    "Prioridad del Bluetooth",
                    "Sube la prioridad de los hilos del Bluetooth",
                    state.btPrio
                ) { on -> vm.runCommand("Bluetooth") { CtlClient.btPrio(if (on) "1" else "0") } }
                Spacer8()
                OutlineActionButton("Reiniciar Bluetooth") {
                    vm.runCommand("Bluetooth") { CtlClient.btRestart() }
                }
            }
        }

        item {
            SectionCard("Ajustes del sistema", "Red, I/O, animaciones y más") {
                ToggleRow("Red optimizada", null, state.tune.net) { on ->
                    vm.runCommand("Ajustes") { CtlClient.tuneSet("net", if (on) "1" else "0") }
                }
                ToggleRow("Lectura anticipada (I/O)", null, state.tune.io) { on ->
                    vm.runCommand("Ajustes") { CtlClient.tuneSet("io", if (on) "1" else "0") }
                }
                ToggleRow("Animaciones reducidas", null, state.tune.anim) { on ->
                    vm.runCommand("Ajustes") { CtlClient.tuneSet("anim", if (on) "1" else "0") }
                }
                ToggleRow("BBR (TCP)", null, state.tune.bbr) { on ->
                    vm.runCommand("Ajustes") { CtlClient.tuneSet("bbr", if (on) "1" else "0") }
                }
                if (state.tune.dns.isNotEmpty()) Text("DNS: ${state.tune.dns}", fontSize = 12.sp, color = MutedText)
                if (state.tune.ra.isNotEmpty()) Text("Read-ahead: ${state.tune.ra}", fontSize = 12.sp, color = MutedText)
            }
        }

        item {
            SectionCard("Mantenimiento", "Limpieza y revisión automática") {
                ToggleRow("Mantenimiento automático", null, state.maint.on) { on ->
                    vm.runCommand("Mantenimiento") { if (on) CtlClient.maintOn() else CtlClient.maintOff() }
                }
                Spacer8()
                OutlineActionButton("Hacer mantenimiento ahora") {
                    vm.runCommand("Mantenimiento") { CtlClient.maintNow() }
                }
            }
        }

        item {
            SectionCard("Modo Deluxe", "Extras de máximo rendimiento") {
                if (state.deluxe.isEmpty()) {
                    Text("Sin datos de Deluxe.", fontSize = 13.sp, color = MutedText)
                } else {
                    for ((k, v) in state.deluxe) {
                        Text("• $k: ${if (v) "ON" else "OFF"}", fontSize = 12.sp)
                    }
                }
                Spacer8()
                OutlineActionButton("Activar Deluxe") {
                    vm.runCommand("Deluxe") { CtlClient.deluxeOn() }
                }
            }
        }

        item {
            SectionCard("Sonda de diagnóstico", "Mide y guarda un informe de tu teléfono") {
                ActionButton("Sonda rápida (rendimiento)") {
                    vm.runCommand("Sonda") { CtlClient.sondaPerf() }
                }
                Spacer8()
                OutlineActionButton("Sonda de hardware") {
                    vm.runCommand("Sonda") { CtlClient.sondaHw() }
                }
                Spacer8()
                OutlineActionButton("Sonda profunda") {
                    vm.runCommand("Sonda") { CtlClient.sondaDeep() }
                }
                Spacer8()
                OutlineActionButton("Ver hallazgos de la última sonda") {
                    sondaText = CtlClient.sondaFindings()
                }
                sondaText?.let { t ->
                    Spacer8()
                    Text(t.take(2000), fontSize = 11.sp)
                }
            }
        }

        item {
            SectionCard("Sesiones", "Historial de uso con perfil, temperaturas y batería") {
                if (state.sessions.isEmpty()) {
                    Text("Sin sesiones registradas.", fontSize = 13.sp, color = MutedText)
                } else {
                    for (s in state.sessions.take(8)) {
                        Text(
                            "• ${s.pkg.ifEmpty { "sistema" }} — ${s.dur / 60} min · ${s.prof} · CPU ${s.cpuC}° · bat ${s.b0}%→${s.b1}%",
                            fontSize = 12.sp
                        )
                    }
                    Spacer8()
                    OutlineActionButton("Borrar historial") {
                        vm.runCommand("Sesiones") { CtlClient.sessClear() }
                    }
                }
            }
        }

        item {
            SectionCard("Registro", "Lo último que hizo MaxG") {
                ActionButton("Ver registro") {
                    logText = CtlClient.log(40)
                    logText?.let { onOpenLog(it) }
                }
                Spacer8()
                OutlineActionButton("Guardar informe completo") {
                    vm.runCommand("Informe") { CtlClient.report() }
                }
            }
        }

        item {
            SectionCard("La app", "Arranque, restablecer y desinstalar") {
                val context = androidx.compose.ui.platform.LocalContext.current
                val prefs = remember { context.getSharedPreferences("maxg", android.content.Context.MODE_PRIVATE) }
                var bootApply by remember { mutableStateOf(prefs.getBoolean("boot_apply", true)) }
                ToggleRow(
                    "Aplicar perfil al encender",
                    "MaxG se activa solo cuando enciendes el teléfono",
                    bootApply
                ) { on ->
                    bootApply = on
                    prefs.edit().putBoolean("boot_apply", on).apply()
                }
                Spacer8()
                OutlineActionButton("Reaplicar todo ahora") {
                    vm.runRaw("Reaplicar") { CtlClient.reapply() }
                }
                Spacer8()
                OutlineActionButton("Revertir todo y detener MaxG") {
                    onRevertAll()
                }
            }
        }

        item { Spacer8() }
    }
}
