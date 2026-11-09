package com.neganboy.maxgpower.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

/**
 * Pestaña Mando, copiada de la WebUI (s-pad): Deluxe, modo mando,
 * Bluetooth, estabilidad, estado del mando, latencia, qué ve el
 * módulo y diagnóstico.
 */
@Composable
fun PadScreen(vm: MaxGViewModel, state: MaxGState, onOpenLog: (String) -> Unit) {
    var qosUs by remember(state.padOpt.qos) { mutableStateOf(state.padOpt.qos) }
    var scanText by remember { mutableStateOf<String?>(null) }
    val lastTest = state.padTests.firstOrNull()

    LazyColumn(Modifier.padding(horizontal = 18.dp)) {
        // Modo Deluxe
        item {
            NeuCard(Modifier.padding(top = 18.dp)) {
                SectionTitle("Modo Deluxe")
                SectionSub("Lo recomendado para jugar con mando: latencia mínima, conexión estable y calor controlado. Cada pieza se puede apagar por separado más abajo.")
                Spacer(Modifier.height(10.dp))
                if (state.deluxe.isEmpty()) {
                    Text("Sin datos de Deluxe.", fontSize = 13.sp, color = NeuColors.Muted)
                } else {
                    for ((k, v) in state.deluxe) {
                        Text("• $k: ${if (v) "ON" else "OFF"}", fontSize = 12.5.sp, color = NeuColors.Muted)
                    }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Activar Deluxe", primary = true) {
                    vm.runCommand("Deluxe") { CtlClient.deluxeOn() }
                }
            }
        }

        // Modo mando
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                RuleRow(
                    "Modo mando",
                    "Menos latencia con tu GameSir, por Bluetooth o cable. Solo actúa mientras el mando está conectado."
                ) {
                    NeuSwitch(state.pad.on) {
                        vm.runCommand("Mando") { if (!state.pad.on) CtlClient.padOn() else CtlClient.padOff() }
                    }
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    "Estado: ${if (state.pad.connected) "mando conectado (${state.pad.name.ifEmpty { "sin nombre" }})" else "sin mando conectado"} · ${if (state.pad.alive) "vigilante activo" else "vigilante parado"}",
                    fontSize = 12.5.sp, color = NeuColors.Muted
                )
            }
        }

        // Bluetooth
        item { GroupHeader("Bluetooth") }
        item {
            NeuCard {
                RuleRow(
                    "Conexión Bluetooth rápida",
                    "Pide a Android un intervalo de 7.5 a 11 ms con tu mando (lo normal es 15-30 ms). Reinicia el Bluetooth al cambiarla; los dispositivos se reconectan solos."
                ) {
                    NeuSwitch(state.bt.fast) {
                        vm.runCommand("Bluetooth") { CtlClient.btFast(!state.bt.fast) }
                    }
                }
                Spacer(Modifier.height(14.dp))
                RuleRow(
                    "Prioridad del Bluetooth",
                    "Sube la prioridad de los hilos del Bluetooth."
                ) {
                    NeuSwitch(state.btPrio) {
                        vm.runCommand("Bluetooth") { CtlClient.btPrio(if (!state.btPrio) "1" else "0") }
                    }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Reiniciar Bluetooth") {
                    vm.runCommand("Bluetooth") { CtlClient.btRestart() }
                }
                if (state.bt.min > 0 || state.bt.lat.isNotEmpty()) {
                    Text(
                        "Intervalo ${state.bt.min}–${state.bt.max} ms · latencia ${state.bt.lat}",
                        fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 10.dp)
                    )
                }
            }
        }

        // Estabilidad del mando
        item { GroupHeader("Estabilidad del mando") }
        item {
            NeuCard {
                SectionSub("Cuenta los cortes de Bluetooth (el mando se desconecta y vuelve en menos de 90 s) para que compares con datos, no a ojo.")
                Spacer(Modifier.height(10.dp))
                RuleRow("Contar cortes de Bluetooth", null) {
                    NeuSwitch(state.btScan) {
                        vm.runCommand("Bluetooth") { CtlClient.cmd("bt", "scan", if (!state.btScan) "on" else "off") }
                    }
                }
                if (state.btNice != "-") {
                    Text("Prioridad de hilos: ${state.btNice}", fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 8.dp))
                }
            }
        }

        // Estado del mando
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            if (state.pad.connected) state.pad.name.ifEmpty { "Mando conectado" } else "Sin mando conectado",
                            fontSize = 16.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text
                        )
                        Text(
                            if (state.pad.connected) "Conecta tu mando; el modo se activa solo y se desactiva al desconectarlo."
                            else "Conecta tu mando; el modo se activa solo y se desactiva al desconectarlo.",
                            fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                    InfoChip(if (state.pad.on) "Encendido" else "Apagado", gray = !state.pad.on)
                }
                if (state.pad.transport.isNotEmpty()) {
                    Text("Transporte: ${state.pad.transport}", fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 8.dp))
                }
            }
        }

        // Ajustes de latencia
        item { GroupHeader("Ajustes de latencia") }
        item {
            NeuCard {
                RuleRow(
                    "Frecuencia alta del mando",
                    "Pide al mando que reporte más veces por segundo."
                ) {
                    NeuSwitch(state.padOpt.hz) {
                        vm.runCommand("Mando") { CtlClient.padOpt("hz", if (!state.padOpt.hz) "on" else "off") }
                    }
                }
                Spacer(Modifier.height(14.dp))
                RuleRow(
                    "Wi-Fi en segundo plano",
                    "Mantiene el Wi-Fi despierto mientras juegas con mando."
                ) {
                    NeuSwitch(state.padOpt.wifi) {
                        vm.runCommand("Mando") { CtlClient.padOpt("wifi", if (!state.padOpt.wifi) "on" else "off") }
                    }
                }
                Spacer(Modifier.height(14.dp))
                Text("Reposo de la CPU mientras juegas", fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                Text("Qué tan rápido deben despertar los núcleos al mover un stick. «Estricto» responde primero y gasta más batería; con calor se suelta solo.", fontSize = 12.5.sp, color = NeuColors.Muted)
                SliderRow("Reposo de CPU (QoS)", qosUs, 0..2000, { qosUs = it }, { "$it µs" })
                NeuButton("Aplicar reposo $qosUs µs") {
                    vm.runCommand("Mando") { CtlClient.padQos(qosUs) }
                }
            }
        }

        // Medidor de latencia
        item { GroupHeader("Medidor de latencia") }
        item {
            NeuCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RingGauge(
                        pctA = if (state.padOpt.maxHz > 0) (lastTest?.hz ?: 0) * 100f / state.padOpt.maxHz else 0f,
                        pctB = null,
                        centerText = "${lastTest?.hz ?: 0}",
                        centerSub = "Hz"
                    )
                    Column(Modifier.weight(1f).padding(start = 18.dp)) {
                        Text("Frecuencia real", fontSize = 19.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                        Text(
                            "Mide cuántos reportes por segundo manda tu mando y si hay saltos. Mueve los sticks sin parar durante la prueba.",
                            fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Probar mando 5 s", primary = true) {
                    vm.runCommand("Mando") { CtlClient.padTest(5) }
                }
                if (state.padTests.isNotEmpty()) {
                    Spacer(Modifier.height(10.dp))
                    for (t in state.padTests.take(5)) {
                        Text(
                            "• ${t.name.ifEmpty { "mando" }} — ${t.hz} Hz · prom ${t.avg} ms · máx ${t.max} ms",
                            fontSize = 12.5.sp, color = NeuColors.Muted
                        )
                    }
                } else {
                    Text("Aún no hay pruebas. Conecta el mando y toca Probar.", fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 10.dp))
                }
            }
        }

        // Qué ve el módulo
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Qué ve el módulo")
                SectionSub("Todos los dispositivos de entrada y si los reconoce como mando (por nombre, fabricante o botones). Si tu mando no aparece como reconocido, guarda el informe y envíamelo.")
                Spacer(Modifier.height(10.dp))
                if (state.padScan.isEmpty()) {
                    Text("Sin escaneo todavía.", fontSize = 13.sp, color = NeuColors.Muted)
                } else {
                    for (s in state.padScan) {
                        Text(
                            "• ${s.name} (${s.transport})${if (s.recommended) " — recomendado" else ""}${if (s.why.isNotEmpty()) " · ${s.why}" else ""}",
                            fontSize = 12.5.sp, color = NeuColors.Muted
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    NeuButton("Escanear", modifier = Modifier.weight(1f)) {
                        vm.runRaw("Mando") {
                            val out = CtlClient.padScan()
                            scanText = out.ifEmpty { "Sin dispositivos" }
                            out
                        }
                    }
                    NeuButton("Guardar informe", modifier = Modifier.weight(1f)) {
                        vm.runCommand("Mando") { CtlClient.padDump() }
                    }
                }
                scanText?.let { Text(it.take(1500), fontSize = 11.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 10.dp)) }
            }
        }

        // Diagnóstico
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Diagnóstico")
                SectionSub("Si el mando no se activa, mira el registro.")
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    NeuButton("Ver registro", modifier = Modifier.weight(1f)) {
                        onOpenLog(CtlClient.log(60))
                    }
                    NeuButton("Actualizar", modifier = Modifier.weight(1f)) {
                        vm.refreshFull()
                    }
                }
            }
        }

        item { Spacer(Modifier.height(32.dp)) }
    }
}
