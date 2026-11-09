package com.neganboy.maxgpower.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.Conflict
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

@Composable
fun HomeScreen(vm: MaxGViewModel, state: MaxGState) {
    var scanResults by remember { mutableStateOf<List<Conflict>?>(null) }
    var manualPerf by remember { mutableStateOf(state.manual.perf) }
    var manualPrime by remember { mutableStateOf(state.manual.prime) }
    var manualGpu by remember { mutableStateOf(state.manual.gpu) }

    LazyColumn {
        if (state.safe) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                    colors = CardDefaults.cardColors(containerColor = BadRed.copy(alpha = 0.2f))
                ) {
                    Column(Modifier.padding(14.dp)) {
                        Text("Modo seguro activo", fontWeight = FontWeight.Bold, color = BadRed)
                        Text(
                            "El teléfono se reinició varias veces sin estabilizarse y MaxG no aplicó nada.",
                            fontSize = 13.sp
                        )
                        Spacer8()
                        OutlineActionButton("Desactivar modo seguro") {
                            vm.runCommand("Modo seguro") { CtlClient.safeClear() }
                        }
                    }
                }
            }
        }

        item {
            SectionCard("Estado") {
                StatRow(
                    listOf(
                        Triple("Batería", if (state.info.batPct > 0) "${state.info.batPct}%" else "—", state.info.charging.ifEmpty { null }),
                        Triple("CPU", if (state.heat.cpuC > 0) "%.1f°".format(state.heat.cpuC) else "—", null),
                        Triple("GPU", if (state.gpu.clk > 0) "${state.gpu.clk} MHz" else "—", null),
                        Triple("Perfil", profileShort(state.profile), null)
                    )
                )
                Spacer8()
                Text(
                    "Gobernador: ${state.govCur.ifEmpty { "—" }}  ·  Calor: ${MaxGState.HEAT_MODE_NAMES[state.heat.mode] ?: state.heat.mode}  ·  Mando: ${if (state.pad.on) "ON" else "OFF"}  ·  Auto: ${if (state.auto.on) "ON" else "OFF"}",
                    fontSize = 12.sp, color = MutedText
                )
            }
        }

        item {
            SectionCard(
                "Perfiles de energía y rendimiento",
                "Toca un perfil para aplicarlo al instante"
            ) {
                val rows = MaxGState.PROFILES.chunked(2)
                for (row in rows) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for ((id, short, desc) in row) {
                            val selected = state.profile == id
                            Card(
                                modifier = Modifier.weight(1f).clickable {
                                    vm.runCommand("Perfil $short") { CtlClient.applyProfile(id) }
                                },
                                colors = CardDefaults.cardColors(
                                    containerColor = if (selected) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.surfaceVariant
                                )
                            ) {
                                Column(Modifier.padding(10.dp)) {
                                    Text(
                                        short, fontWeight = FontWeight.Bold, fontSize = 14.sp,
                                        color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        desc, fontSize = 11.sp, lineHeight = 14.sp,
                                        color = if (selected) MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.85f) else MutedText
                                    )
                                }
                            }
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                    Spacer8()
                }
            }
        }

        item {
            SectionCard("Gobernador de CPU", "El plan de frecuencias del procesador") {
                val options = state.govList.map { it to it } +
                    listOf("stock" to "Original (ROM)")
                ChipFlow(options, state.govCur.ifEmpty { "stock" }) { id ->
                    vm.runCommand("Gobernador") { CtlClient.setGov(if (id == "stock") "stock" else id) }
                }
                if (state.govCfg != "none") {
                    Text("Guardado: ${state.govCfg}", fontSize = 12.sp, color = MutedText)
                }
            }
        }

        item {
            SectionCard(
                "Control manual",
                "Topes propios en vez de un perfil. Al activarlo no se aplican perfiles ni gobernador."
            ) {
                ToggleRow("Control manual", if (state.manual.on) "Activo" else "Apagado", state.manual.on) { on ->
                    vm.runCommand("Control manual") { if (on) CtlClient.manualOn() else CtlClient.manualOff() }
                }
                if (state.manual.on || state.manual.has) {
                    SliderRow("Rendimiento", manualPerf, 0..100, { manualPerf = it }, { "$it%" })
                    SliderRow("Núcleos prime", manualPrime, 0..100, { manualPrime = it }, { "$it%" })
                    SliderRow("GPU", manualGpu, 0..100, { manualGpu = it }, { "$it%" })
                    ActionButton("Aplicar ajustes manuales") {
                        vm.runCommand("Control manual") {
                            CtlClient.manualSet(manualPerf, manualPrime, manualGpu, state.manual.hl, state.manual.cpl, state.manual.swap)
                        }
                    }
                }
            }
        }

        item {
            SectionCard("Conflictos", "Otros módulos o el ahorro de Android que chocan con MaxG") {
                val who = state.conflicts
                if (who.isEmpty()) {
                    Text("Sin conflictos detectados.", fontSize = 13.sp, color = MutedText)
                } else {
                    for ((key, value) in who) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                            Text(
                                "${key.uppercase()}: ", fontSize = 13.sp, fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(end = 4.dp)
                            )
                            Text(value.second, fontSize = 13.sp)
                        }
                    }
                }
                Spacer8()
                OutlineActionButton("Escanear conflictos ahora") {
                    vm.runRaw("Conflictos") {
                        val items = CtlClient.conflictsScan()
                        scanResults = items
                        if (items.isEmpty()) "Sin conflictos" else "${items.size} conflicto(s)"
                    }
                }
                scanResults?.let { items ->
                    Spacer8()
                    for (c in items) {
                        Text("• [${c.level}] ${c.msg}", fontSize = 12.sp, modifier = Modifier.padding(vertical = 2.dp))
                    }
                }
            }
        }

        item { Spacer8() }
    }
}

private fun profileShort(id: String): String =
    MaxGState.PROFILES.firstOrNull { it.first == id }?.second ?: id.replaceFirstChar { it.uppercase() }
