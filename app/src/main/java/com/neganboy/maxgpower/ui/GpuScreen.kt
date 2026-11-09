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
 * Pestaña GPU, copiada de la WebUI (s-gpu): anillo de la GPU,
 * modo, velocidad máxima y mínima, ámbito, freno de la ROM,
 * grabar sesión y prueba de compatibilidad.
 */
@Composable
fun GpuScreen(vm: MaxGViewModel, state: MaxGState) {
    var maxPct by remember(state.gpuMaxPct) { mutableStateOf(state.gpuMaxPct) }
    var probeText by remember { mutableStateOf<String?>(null) }
    var recText by remember { mutableStateOf<String?>(null) }

    val top = state.gpu.table.maxOrNull() ?: 1200
    val gpuFreqs = state.freqs["gpu"] ?: emptyList()

    LazyColumn(Modifier.padding(horizontal = 18.dp)) {
        // Anillo de la GPU
        item {
            NeuCard(Modifier.padding(top = 18.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RingGauge(
                        pctA = if (top > 0) state.gpu.clk * 100f / top else 0f,
                        pctB = if (top > 0) state.gpu.cap * 100f / top else 0f,
                        centerText = "${state.gpu.clk}",
                        centerSub = "MHz ahora"
                    )
                    Column(Modifier.weight(1f).padding(start = 18.dp)) {
                        Text("GPU Adreno 830", fontSize = 19.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                        Text(
                            "Ahora trabaja a ${state.gpu.clk} MHz." +
                                (if (state.gpu.cap > 0) " Límite activo: ${state.gpu.cap} MHz." else "") +
                                " (máximo posible: $top MHz).",
                            fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 4.dp)
                        )
                        Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            if (state.gpu.alive && (state.gpu.floor > 0 || state.gpu.free)) InfoChip("Control activo")
                            if (state.gpu.free) InfoChip("Freno liberado", gray = true)
                        }
                    }
                }
                if (state.romLimits.isNotEmpty()) {
                    Spacer(Modifier.height(12.dp))
                    for (rl in state.romLimits) {
                        Text("Límite ROM ${rl.name}: ${rl.cur}/${rl.max}", fontSize = 12.5.sp, color = NeuColors.Muted)
                    }
                }
            }
        }

        // ¿Cómo quieres que trabaje la GPU?
        item { GroupHeader("¿Cómo quieres que trabaje la GPU?") }
        item {
            NeuCard {
                SectionSub("Elige uno. Manda sobre el perfil de CPU y se conserva al reiniciar.")
                Spacer(Modifier.height(8.dp))
                val modes = listOf(
                    Triple("auto", "Automático", "La GPU sigue al perfil que elegiste."),
                    Triple("max", "Máximo", "La GPU siempre al máximo que permite el perfil."),
                    Triple("manual", "Manual %", "Tú pones el tope exacto en porcentaje.")
                )
                var first = true
                for ((id, title, desc) in modes) {
                    ProfileRow(
                        selected = state.gpuMode == id,
                        title = title,
                        desc = desc,
                        divider = !first
                    ) {
                        if (id == "manual") vm.runCommand("GPU") { CtlClient.gpuManual(maxPct) }
                        else vm.runCommand("GPU") { CtlClient.gpuMode(id) }
                    }
                    first = false
                }
            }
        }

        // Velocidad máxima
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Velocidad máxima")
                SectionSub("Pon tú el límite exacto de la GPU.")
                SliderRow("Tope de GPU", maxPct, 10..100, { maxPct = it }, { "$it%" })
                NeuButton("Aplicar tope $maxPct%", primary = true) {
                    vm.runCommand("GPU") { CtlClient.gpuManual(maxPct) }
                }
            }
        }

        // Velocidad mínima
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Velocidad mínima")
                SectionSub("La GPU no bajará de aquí mientras juegas: más fluidez estable, pero más calor y batería.")
                Spacer(Modifier.height(10.dp))
                val floorOpts = listOf(0) + gpuFreqs.filter { it in 300..800 }.sorted()
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (n in floorOpts) {
                        NeuChip(if (n == 0) "Normal (ROM)" else "$n MHz", state.gpu.floor == n) {
                            vm.runCommand("GPU") { CtlClient.gpuFloor(n) }
                        }
                    }
                }
            }
        }

        // Ámbito
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Ámbito del piso de GPU")
                SectionSub("¿El piso aplica siempre o solo mientras juegas?")
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    NeuChip("Siempre", state.gpuScope == "always") {
                        vm.runCommand("GPU") { CtlClient.gpuScope("always") }
                    }
                    NeuChip("Solo en juegos", state.gpuScope == "game") {
                        vm.runCommand("GPU") { CtlClient.gpuScope("game") }
                    }
                }
            }
        }

        // Quitar el freno de la ROM
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                RuleRow(
                    "Quitar el freno de la ROM",
                    "Tu ROM frena la GPU aunque esté fría. Activado, corre libre hasta 62 °C; si se calienta, vuelve a la normalidad sola."
                ) {
                    NeuSwitch(state.gpu.free) {
                        vm.runCommand("GPU") { CtlClient.gpuFree(!state.gpu.free) }
                    }
                }
            }
        }

        // Grabar una sesión
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Grabar una sesión")
                SectionSub("Pulsa «Grabar», abre tu juego y juega hasta que termine. Anota cada segundo la frecuencia de la GPU, cuánto trabaja y la temperatura, y te dice si se queda lenta estando ocupada.")
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    NeuButton("Grabar 60 s", primary = true, modifier = Modifier.weight(1f)) {
                        vm.runRaw("Grabación") {
                            val r = CtlClient.cmd("rec", "start", "60")
                            recText = r.detail.ifEmpty { if (r.ok) "Grabando 60 s" else "No se pudo grabar" }
                            recText ?: ""
                        }
                    }
                    NeuButton("Detener", modifier = Modifier.weight(1f)) {
                        vm.runRaw("Grabación") {
                            val r = CtlClient.cmd("rec", "stop")
                            recText = r.detail.ifEmpty { "Detenida" }
                            recText ?: ""
                        }
                    }
                }
                recText?.let { Text(it, fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 10.dp)) }
            }
        }

        // ¿Qué acepta tu GPU?
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("¿Qué acepta tu GPU?")
                SectionSub("Prueba segura: no cambia nada, solo comprueba qué controles deja usar tu kernel.")
                Spacer(Modifier.height(12.dp))
                NeuButton("Probar") {
                    vm.runRaw("GPU") {
                        val out = CtlClient.run("gpu", "probe")
                        probeText = out.ifEmpty { "Sin respuesta" }
                        out
                    }
                }
                probeText?.let {
                    Text(it.take(2000), fontSize = 11.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 10.dp))
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Devolver GPU a la ROM") {
                    vm.runCommand("GPU") { CtlClient.gpuOff() }
                }
            }
        }

        item { Spacer(Modifier.height(32.dp)) }
    }
}
