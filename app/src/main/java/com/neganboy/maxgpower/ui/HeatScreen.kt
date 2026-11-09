package com.neganboy.maxgpower.ui

import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

@Composable
fun HeatScreen(vm: MaxGViewModel, state: MaxGState) {
    LazyColumn {
        item {
            SectionCard("Temperatura ahora") {
                StatRow(
                    listOf(
                        Triple("CPU", if (state.heat.cpuC > 0) "%.1f°".format(state.heat.cpuC) else "—", null),
                        Triple("Batería", if (state.heat.batC > 0) "%.1f°".format(state.heat.batC) else "—", null),
                        Triple("Chasis", if (state.heat.skinC > 0) "%.1f°".format(state.heat.skinC) else "—", null),
                        Triple("Nivel", "${state.heat.level}", if (state.heat.alive) "vigilante activo" else "vigilante parado")
                    )
                )
                Spacer8()
                Text(
                    "Puntos térmicos: ${state.heat.points}  ·  Anticipación: ${if (state.heatX.antOn) "ON" else "OFF"}  ·  Ráfaga: ${state.heatX.burst}",
                    fontSize = 12.sp, color = MutedText
                )
            }
        }

        item {
            SectionCard(
                "Control de calor",
                "Baja las frecuencias antes de que el teléfono se caliente demasiado"
            ) {
                ChipFlow(
                    MaxGState.HEAT_MODES.map { it to (MaxGState.HEAT_MODE_NAMES[it] ?: it) },
                    state.heat.mode
                ) { mode ->
                    vm.runCommand("Calor") { CtlClient.heatMode(mode) }
                }
                Spacer8()
                ToggleRow(
                    "Anticipación térmica",
                    "Actúa antes de llegar al límite, no después",
                    state.heatX.antOn
                ) { on -> vm.runCommand("Calor") { CtlClient.heatAnt(on) } }
                ToggleRow(
                    "Ahorro con pantalla apagada",
                    "Baja el consumo mientras la pantalla está apagada",
                    state.heat.screen
                ) { on -> vm.runCommand("Calor") { CtlClient.heatScreen(on) } }
            }
        }

        item {
            SectionCard("Ráfaga sostenida", "Cuánto tiempo mantiene el pico de rendimiento antes de bajar") {
                ChipFlow(
                    listOf("off" to "Apagada", "corta" to "Corta", "media" to "Media", "larga" to "Larga"),
                    state.heatX.burst
                ) { v ->
                    vm.runCommand("Calor") { CtlClient.heatBurst(v) }
                }
            }
        }

        item { Spacer8() }
    }
}
