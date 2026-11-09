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
fun PadScreen(vm: MaxGViewModel, state: MaxGState) {
    var qosUs by remember(state.padOpt.qos) { mutableStateOf(state.padOpt.qos) }

    LazyColumn {
        item {
            SectionCard(
                "Modo mando de baja latencia",
                "Prioriza el mando Bluetooth: menos retraso entre que mueves y responde el juego"
            ) {
                ToggleRow(
                    "Modo mando",
                    if (state.pad.alive) "Vigilante activo" else "Vigilante parado",
                    state.pad.on
                ) { on ->
                    vm.runCommand("Mando") { if (on) CtlClient.padOn() else CtlClient.padOff() }
                }
                Spacer8()
                StatRow(
                    listOf(
                        Triple("Mando", if (state.pad.connected) "Conectado" else "Sin conectar", state.pad.name.ifEmpty { null }),
                        Triple("Transporte", state.pad.transport.ifEmpty { "—" }, null),
                        Triple("QoS", if (state.pad.qos) "Activo" else "Apagado", null)
                    )
                )
            }
        }

        item {
            SectionCard("Prueba de latencia", "Mide el retraso real de tu mando durante 5 segundos") {
                ActionButton("Probar mando 5 s") {
                    vm.runCommand("Mando") { CtlClient.padTest(5) }
                }
                Spacer8()
                if (state.padTests.isEmpty()) {
                    Text("Aún no hay pruebas. Conecta el mando y toca Probar.", fontSize = 13.sp, color = MutedText)
                } else {
                    for (t in state.padTests.take(5)) {
                        Text(
                            "• ${t.name.ifEmpty { "mando" }} — ${t.hz} Hz · prom ${t.avg} ms · máx ${t.max} ms",
                            fontSize = 12.sp
                        )
                    }
                }
            }
        }

        item {
            SectionCard("Ajustes finos") {
                SliderRow("Reposo de CPU (QoS)", qosUs, 0..2000, { qosUs = it }, { "$it µs" })
                ActionButton("Aplicar reposo $qosUs µs") {
                    vm.runCommand("Mando") { CtlClient.padQos(qosUs) }
                }
                Spacer8()
                ToggleRow(
                    "Frecuencia alta del mando",
                    "Pide al mando que reporte más veces por segundo",
                    state.padOpt.hz
                ) { on -> vm.runCommand("Mando") { CtlClient.padOpt("hz", if (on) "on" else "off") } }
                ToggleRow(
                    "Wi-Fi en segundo plano",
                    "Mantiene el Wi-Fi despierto mientras juegas con mando",
                    state.padOpt.wifi
                ) { on -> vm.runCommand("Mando") { CtlClient.padOpt("wifi", if (on) "on" else "off") } }
            }
        }

        item {
            SectionCard("Informe") {
                OutlineActionButton("Guardar informe del mando") {
                    vm.runCommand("Mando") { CtlClient.padDump() }
                }
                Spacer8()
                if (state.padScan.isNotEmpty()) {
                    for (s in state.padScan) {
                        Text("• ${s.name} (${s.transport}) ${if (s.recommended) "— recomendado" else ""}", fontSize = 12.sp)
                    }
                }
            }
        }

        item { Spacer8() }
    }
}
