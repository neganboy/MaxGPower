package com.neganboy.maxgpower.ui

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

@Composable
fun GpuScreen(vm: MaxGViewModel, state: MaxGState) {
    var maxPct by remember(state.gpuMaxPct) { mutableStateOf(state.gpuMaxPct) }
    val gpuFreqs = state.freqs["gpu"] ?: emptyList()

    LazyColumn {
        item {
            SectionCard("Estado de la GPU") {
                StatRow(
                    listOf(
                        Triple("Reloj", if (state.gpu.clk > 0) "${state.gpu.clk} MHz" else "—", null),
                        Triple("Nivel", state.gpu.level.ifEmpty { "—" }, null),
                        Triple("Piso", if (state.gpu.floor > 0) "${state.gpu.floor} MHz" else "Apagado", null),
                        Triple("Vigilante", if (state.gpu.alive) "Activo" else "Parado", null)
                    )
                )
                Spacer8()
                Text(
                    "Modo: ${state.gpuMode}  ·  Tope: ${state.gpuMaxPct}%  ·  Ámbito: ${if (state.gpuScope == "game") "solo en juegos" else "siempre"}" +
                        if (state.gpu.free) "  ·  Tope de la ROM liberado" else "",
                    fontSize = 12.sp, color = MutedText
                )
                if (state.romLimits.isNotEmpty()) {
                    Spacer8()
                    for (rl in state.romLimits) {
                        Text("Límite ROM ${rl.name}: ${rl.cur}/${rl.max}", fontSize = 12.sp, color = MutedText)
                    }
                }
            }
        }

        item {
            SectionCard("Modo de GPU", "Cómo se comporta la GPU con el perfil activo") {
                ChipFlow(
                    listOf("auto" to "Automático", "max" to "Máximo", "manual" to "Manual %"),
                    state.gpuMode
                ) { mode ->
                    if (mode == "manual") {
                        vm.runCommand("GPU") { CtlClient.gpuManual(maxPct) }
                    } else {
                        vm.runCommand("GPU") { CtlClient.gpuMode(mode) }
                    }
                }
                Spacer8()
                SliderRow("Tope de GPU", maxPct, 10..100, { maxPct = it }, { "$it%" })
                ActionButton("Aplicar tope $maxPct%") {
                    vm.runCommand("GPU") { CtlClient.gpuManual(maxPct) }
                }
            }
        }

        item {
            SectionCard("Piso de GPU", "Frecuencia mínima que la GPU no baja (vigilante activo)") {
                val options = listOf(0 to "Apagado") + gpuFreqs.map { it to "$it MHz" }
                ChipFlow(options.map { (v, l) -> v.toString() to l }, state.gpu.floor.toString()) { v ->
                    vm.runCommand("GPU") { CtlClient.gpuFloor(v.toIntOrNull() ?: 0) }
                }
                Spacer8()
                ToggleRow(
                    "Liberar tope de la ROM",
                    "Quita el límite que pone la ROM, con protección de temperatura",
                    state.gpu.free
                ) { on -> vm.runCommand("GPU") { CtlClient.gpuFree(on) } }
                ToggleRow(
                    "Piso solo en juegos",
                    "El piso de GPU aplica únicamente mientras juegas",
                    state.gpuScope == "game"
                ) { on -> vm.runCommand("GPU") { CtlClient.gpuScope(if (on) "game" else "always") } }
            }
        }

        item {
            SectionCard("Acciones") {
                OutlineActionButton("Probar GPU (sonda rápida)") {
                    vm.runRaw("GPU") { CtlClient.run("gpu", "probe") }
                }
                Spacer8()
                OutlineActionButton("Devolver GPU a la ROM") {
                    vm.runCommand("GPU") { CtlClient.gpuOff() }
                }
            }
        }

        item { Spacer8() }
    }
}
