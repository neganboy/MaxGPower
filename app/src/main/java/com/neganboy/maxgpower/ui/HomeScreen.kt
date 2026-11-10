package com.neganboy.maxgpower.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.Conflict
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

/**
 * Pestaña Perfiles, copiada de la WebUI (s-perf): anillo principal,
 * quién manda, lista de perfiles por grupos, mis perfiles, calor,
 * gobernador e incluido siempre.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(vm: MaxGViewModel, state: MaxGState) {
    var scanResults by remember { mutableStateOf<List<Conflict>?>(null) }
    var govOpen by remember { mutableStateOf(false) }
    var includedOpen by remember { mutableStateOf(false) }
    var bgPkg by remember { mutableStateOf("") }

    val maxPlan = state.plans["maximo"]
    val maxPrime = maxPlan?.prime ?: 4320000
    val maxGpu = maxPlan?.gpu ?: 1100000000
    val curPlan = state.plans[state.profile]
    val curInfo = MaxGState.PROFILES.firstOrNull { it.first == state.profile }

    LazyColumn(Modifier.padding(horizontal = 18.dp)) {
        if (state.safe) {
            item {
                NeuCard(Modifier.padding(top = 18.dp)) {
                    Text("Modo seguro activo", fontWeight = FontWeight.Bold, color = NeuColors.Bad, fontSize = 16.sp)
                    SectionSub("El teléfono se reinició 3 veces seguidas sin estabilizarse, así que no se aplica nada al arrancar.")
                    Spacer(Modifier.height(12.dp))
                    NeuButton("Desactivar modo seguro", primary = true) {
                        vm.runCommand("Modo seguro") { CtlClient.safeClear() }
                    }
                }
            }
        }

        // El módulo no reconoce el dispositivo (DEV|0): se muestra el motivo.
        if (!state.device.ok && state.device.why.isNotEmpty()) {
            item {
                NeuCard(Modifier.padding(top = 18.dp)) {
                    Text("Revisar dispositivo", fontWeight = FontWeight.Bold, color = NeuColors.Warn, fontSize = 16.sp)
                    SectionSub(state.device.why)
                }
            }
        }

        // Anillo principal del perfil activo (compacto: anillo arriba, no centrado,
        // para que la tarjeta no se estire con un hueco vacío en medio).
        item {
            NeuCard(Modifier.padding(top = 18.dp)) {
                Row(verticalAlignment = Alignment.Top) {
                    if (curPlan != null) {
                        RingGauge(
                            pctA = curPlan.prime * 100f / maxPrime,
                            pctB = curPlan.gpu * 100f / maxGpu,
                            centerText = "${(curPlan.prime * 100 / maxPrime)}%",
                            centerSub = "potencia"
                        )
                    } else {
                        RingGauge(100f, 100f, "100%", "sin cambios")
                    }
                    Column(Modifier.weight(1f).padding(start = 18.dp)) {
                        Text(
                            curInfo?.second ?: if (state.profile == "stock") "Original" else state.profile,
                            fontSize = 19.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text
                        )
                        Text(
                            curInfo?.third ?: "Tu ROM tal cual: sin topes ni ajustes de MaxG Power.",
                            fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 4.dp)
                        )
                        // Los chips se envuelven (FlowRow): en una Row no cabían los 3
                        // en la columna angosta. Los valores son PORCENTAJES del perfil,
                        // no frecuencias (antes se mostraba "21 MHz" por error).
                        FlowRow(
                            Modifier.padding(top = 10.dp),
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            if (curPlan != null) {
                                InfoChip("Núcleos 0-5 · ${curPlan.perf}%")
                                InfoChip("Prime · ${curPlan.prime}%")
                                if (curPlan.gpu > 0) InfoChip("GPU · ${curPlan.gpu}%", gray = true)
                            } else {
                                InfoChip("Original", gray = true)
                            }
                        }
                        state.autoNow?.let { now ->
                            if (now.prof.isNotEmpty()) {
                                Row(Modifier.padding(top = 6.dp)) {
                                    InfoChip("Auto: ${profileShort(now.prof)}")
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(14.dp))
                Text(
                    "CPU: gobernador ${state.govCur.ifEmpty { "—" }} · calor ${MaxGState.HEAT_MODE_NAMES[state.heat.mode] ?: state.heat.mode}",
                    fontSize = 12.5.sp, color = NeuColors.Muted
                )
                Text(
                    "GPU: ${if (state.gpu.clk > 0) "${state.gpu.clk} MHz" else "—"} · piso ${if (state.gpu.floor > 0) "${state.gpu.floor} MHz" else "apagado"} · modo ${state.gpuMode}",
                    fontSize = 12.5.sp, color = NeuColors.Muted
                )
            }
        }

        // Quién manda ahora
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Quién manda ahora")
                SectionSub("Qué función tiene el control de la CPU, la GPU y el calor en este momento. Si dos chocan, lo ves aquí.")
                Spacer(Modifier.height(10.dp))
                WhoRow("CPU", if (state.manual.on) "Control manual" else profileShort(state.profile))
                WhoRow("GPU", when (state.gpuMode) { "max" -> "Máximo"; "manual" -> "Manual ${state.gpuMaxPct}%"; else -> "Automático" })
                WhoRow("Calor", MaxGState.HEAT_MODE_NAMES[state.heat.mode] ?: state.heat.mode)
                if (state.conflicts.isNotEmpty()) {
                    Spacer(Modifier.height(10.dp))
                    for ((key, value) in state.conflicts) {
                        Text("⚠ ${key.uppercase()}: ${value.second}", fontSize = 12.5.sp, color = NeuColors.Warn)
                    }
                }
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    NeuButton("Revisar choques") {
                        vm.runRaw("Conflictos") {
                            val items = CtlClient.conflictsScan()
                            scanResults = items
                            if (items.isEmpty()) "Sin conflictos" else "${items.size} conflicto(s)"
                        }
                    }
                }
                scanResults?.let { items ->
                    Spacer(Modifier.height(10.dp))
                    for (c in items) {
                        Text("• [${c.level}] ${c.msg}", fontSize = 12.sp, color = NeuColors.Muted, modifier = Modifier.padding(vertical = 2.dp))
                    }
                }
            }
        }

        // Lista de perfiles por grupos, igual que la WebUI
        val groups = listOf(
            "Sin cambios" to listOf("stock"),
            "Ahorrar batería" to listOf("minimo", "ultra", "profundo", "ahorro", "bateria", "eco"),
            "Equilibrio" to listOf("juego", "medio", "diario"),
            "Rendimiento" to listOf("rendfresco", "alto", "maximo")
        )
        for ((title, ids) in groups) {
            item { GroupHeader(title) }
            item {
                NeuCard {
                    var first = true
                    for (id in ids) {
                        if (id == "stock") {
                            ProfileRow(
                                selected = state.profile == "stock",
                                title = "Original",
                                desc = "Tu ROM tal cual: sin topes ni ajustes de MaxG Power.",
                                divider = !first
                            ) { vm.runCommand("Perfil Original") { CtlClient.applyProfile("stock") } }
                        } else {
                            val info = MaxGState.PROFILES.first { it.first == id }
                            val plan = state.plans[id]
                            ProfileRow(
                                selected = state.profile == id,
                                title = info.second,
                                desc = info.third,
                                right = plan?.let { "hasta ${it.prime}%" },
                                divider = !first
                            ) { vm.runCommand("Perfil ${info.second}") { CtlClient.applyProfile(id) } }
                        }
                        first = false
                    }
                }
            }
        }

        // Mis perfiles (propios)
        item { GroupHeader("Mis perfiles") }
        item {
            NeuCard {
                SectionSub("Los que guardes desde la pestaña Manual aparecen aquí. Toca uno para activarlo; se conservan al reiniciar.")
                Spacer(Modifier.height(8.dp))
                if (state.customProfiles.isEmpty() && !state.manual.has) {
                    Text("Todavía no guardaste ningún perfil propio.", fontSize = 13.sp, color = NeuColors.Muted)
                }
                if (state.manual.has) {
                    ProfileRow(
                        selected = state.profile == "u_manual",
                        title = "Manual (sin guardar)",
                        desc = "Tus ajustes manuales actuales.",
                        divider = false
                    ) { vm.runCommand("Manual") { CtlClient.manualOn() } }
                }
                var first = !state.manual.has
                for ((id, name) in state.customProfiles) {
                    ProfileRow(
                        selected = state.profile == id,
                        title = name,
                        desc = "Perfil propio",
                        divider = !first
                    ) { vm.runCommand("Perfil $name") { CtlClient.applyProfile(id) } }
                    first = false
                }
            }
        }

        // Control de calor
        item { GroupHeader("Control de calor") }
        item {
            NeuCard {
                SectionSub("Baja los topes de CPU y GPU en escalones cuando el teléfono se calienta y los devuelve solo cuando se enfría. Va por encima del perfil que elijas.")
                Spacer(Modifier.height(8.dp))
                val heatDescs = mapOf(
                    "off" to "Sin control de calor: el teléfono se calienta libre.",
                    "suave" to "Actúa tarde y suave, solo si hace mucho calor.",
                    "normal" to "El equilibrio recomendado: baja topes al calentarse.",
                    "estricto" to "Actúa pronto y fuerte; lo más fresco, algo más lento.",
                    "guardian" to "Siete niveles finos con objetivo de temperatura por perfil: recorta poco a poco y solo lo necesario."
                )
                var first = true
                for (mode in MaxGState.HEAT_MODES) {
                    ProfileRow(
                        selected = state.heat.mode == mode,
                        title = MaxGState.HEAT_MODE_NAMES[mode] ?: mode,
                        desc = heatDescs[mode] ?: "",
                        divider = !first
                    ) { vm.runCommand("Calor") { CtlClient.heatMode(mode) } }
                    first = false
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    "Ahora: CPU ${if (state.heat.cpuC > 0) "%.1f°".format(state.heat.cpuC) else "—"} · batería ${if (state.heat.batC > 0) "%.1f°".format(state.heat.batC) else "—"} · chasis ${if (state.heat.skinC > 0) "%.1f°".format(state.heat.skinC) else "—"} · nivel ${state.heat.level}/${state.heat.maxLevel}" +
                        if (state.heat.mode == "guardian") " · objetivo ${state.heat.target}°C" else "",
                    fontSize = 12.5.sp, color = NeuColors.Muted
                )
                if (state.heat.mode == "guardian") {
                    Spacer(Modifier.height(12.dp))
                    Text("Objetivos de temperatura", fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                    Text("A qué temperatura de batería empieza a recortar cada perfil (30-45 °C). Por defecto 35 °C en diario y 40 °C en juego y rendimiento.", fontSize = 12.5.sp, color = NeuColors.Muted)
                    Spacer(Modifier.height(6.dp))
                    for (info in MaxGState.PROFILES) {
                        val tgt = state.heatTargets[info.first]
                            ?: if (info.first in listOf("juego", "rendfresco", "alto", "maximo")) 40 else 35
                        TargetRow(info.second, tgt) { delta ->
                            val next = (tgt + delta).coerceIn(30, 45)
                            if (next != tgt) vm.runCommand("Calor") { CtlClient.heatTgt(info.first, next) }
                        }
                    }
                }
            }
        }
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                RuleRow(
                    "Ahorro con pantalla apagada",
                    "Con la pantalla apagada más de 10 s, los topes bajan al menos 35 %: sin calor en el bolsillo. Solo actúa si el control de calor está encendido."
                ) {
                    NeuSwitch(state.heat.screen) {
                        vm.runCommand("Calor") { CtlClient.heatScreen(!state.heat.screen) }
                    }
                }
            }
        }
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                RuleRow(
                    "Anticipación térmica",
                    "Actúa antes de llegar al límite, no después."
                ) {
                    NeuSwitch(state.heatX.antOn) {
                        vm.runCommand("Calor") { CtlClient.heatAnt(!state.heatX.antOn) }
                    }
                }
                Spacer(Modifier.height(14.dp))
                Text("Ráfaga sostenida", fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                Text("Cuánto mantiene el pico de rendimiento antes de bajar.", fontSize = 12.5.sp, color = NeuColors.Muted)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for ((id, label) in listOf("off" to "Apagada", "corta" to "Corta", "media" to "Media", "larga" to "Larga")) {
                        NeuChip(label, state.heatX.burst == id) {
                            vm.runCommand("Calor") { CtlClient.heatBurst(id) }
                        }
                    }
                }
            }
        }

        // Vigilante de topes
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                RuleRow(
                    "Vigilante de topes",
                    "Si la ROM u otra app sube un tope por encima de lo que pide tu perfil, lo devuelve al instante, sin esperar. Solo corrige hacia abajo: si el térmico baja un tope, se respeta."
                ) {
                    NeuSwitch(state.watch.on) {
                        vm.runCommand("Vigilante") {
                            if (!state.watch.on) CtlClient.watchOn() else CtlClient.watchOff()
                        }
                    }
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    when {
                        !state.watch.inotify -> "Este teléfono no tiene inotifyd: el vigilante no puede observar los topes."
                        state.watch.alive -> "Vigilando los topes ahora mismo."
                        state.watch.on -> "Encendido, esperando a que arranque el vigilante."
                        else -> "Apagado."
                    },
                    fontSize = 12.5.sp, color = NeuColors.Muted
                )
            }
        }

        // Gobernador (plegable, como <details> de la WebUI)
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                Row(
                    Modifier.fillMaxWidth().clickable { govOpen = !govOpen }.padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        SectionTitle("Gobernador de CPU")
                        SectionSub("Cómo decide el procesador cuándo subir y bajar de frecuencia. El de tu ROM ya viene ajustado; cámbialo solo si sabes lo que buscas.")
                    }
                    Text(if (govOpen) "▲" else "▼", color = NeuColors.Muted, fontSize = 14.sp,
                        modifier = Modifier.padding(start = 8.dp))
                }
                if (govOpen) {
                    Spacer(Modifier.height(12.dp))
                    val options = state.govList.map { it to it } + listOf("stock" to "Original (ROM)")
                    ChipFlow(options, state.govCur.ifEmpty { "stock" }) { id ->
                        vm.runCommand("Gobernador") { CtlClient.setGov(id) }
                    }
                    if (state.govCfg != "none") {
                        Text("Guardado: ${state.govCfg}", fontSize = 12.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 8.dp))
                    }
                }
            }
        }
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                Row(
                    Modifier.fillMaxWidth().clickable { includedOpen = !includedOpen }.padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        SectionTitle("Incluido siempre")
                    }
                    Text(if (includedOpen) "▲" else "▼", color = NeuColors.Muted, fontSize = 14.sp,
                        modifier = Modifier.padding(start = 8.dp))
                }
                if (includedOpen) {
                    SectionSub("Memoria con menos trabajo de zram y protección de las apps recientes. Además, estas apps no se ejecutan en segundo plano como antes: toca ✕ para quitar una, o añade otra. «Original» lo deja todo como estaba.")
                    Spacer(Modifier.height(10.dp))
                    if (state.bgapps.isEmpty()) {
                        Text("Ninguna app restringida.", fontSize = 13.sp, color = NeuColors.Muted)
                    }
                    for (app in state.bgapps) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(app.pkg, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = NeuColors.Text)
                                Text(
                                    buildString {
                                        if (app.ops) append("sin ejecución en segundo plano")
                                        if (app.bucket) {
                                            if (isNotEmpty()) append(" · ")
                                            append("en espera «rare»")
                                        }
                                        if (app.doze) {
                                            if (isNotEmpty()) append(" · ")
                                            append("fuera de la lista blanca de Doze")
                                        }
                                        if (isEmpty()) append("sin restricciones")
                                        if (!app.installed) append(" · no instalada")
                                    },
                                    fontSize = 12.sp, color = NeuColors.Muted
                                )
                            }
                            Text(
                                "✕", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = NeuColors.Bad,
                                modifier = Modifier.clickable {
                                    vm.runCommand("Segundo plano") { CtlClient.bgappsDel(app.pkg) }
                                }.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    OutlinedTextField(
                        value = bgPkg,
                        onValueChange = { bgPkg = it },
                        label = { Text("Añadir app (nombre del paquete)") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = NeuColors.CardTop,
                            unfocusedContainerColor = NeuColors.CardTop
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        NeuButton("Añadir en espera «rare»", primary = true, enabled = bgPkg.isNotBlank()) {
                            val pkg = bgPkg.trim()
                            vm.runCommand("Segundo plano") { CtlClient.bgappsAdd(pkg) }
                            bgPkg = ""
                        }
                    }
                    if (state.autoRecent.isNotEmpty()) {
                        Spacer(Modifier.height(12.dp))
                        Text("Apps recientes", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                        Spacer(Modifier.height(6.dp))
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            for (rec in state.autoRecent.take(8)) {
                                val already = state.bgapps.any { it.pkg == rec.pkg }
                                NeuChip(rec.pkg.substringAfterLast('.'), already) {
                                    if (!already) vm.runCommand("Segundo plano") { CtlClient.bgappsAdd(rec.pkg) }
                                }
                            }
                        }
                    }
                }
            }
        }

        item { Spacer(Modifier.height(32.dp)) }
    }
}

@Composable
private fun TargetRow(label: String, temp: Int, onStep: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, fontSize = 13.5.sp, color = NeuColors.Text, modifier = Modifier.weight(1f))
        Text(
            "−", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = NeuColors.Blue2,
            modifier = Modifier.clickable { onStep(-1) }.padding(horizontal = 10.dp, vertical = 2.dp)
        )
        Text("$temp °C", fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
        Text(
            "+", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = NeuColors.Blue2,
            modifier = Modifier.clickable { onStep(1) }.padding(horizontal = 10.dp, vertical = 2.dp)
        )
    }
}

@Composable
private fun WhoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text, modifier = Modifier.weight(1f))
        Text(value, fontSize = 13.sp, color = NeuColors.Muted)
    }
}

fun profileShort(id: String): String =
    MaxGState.PROFILES.firstOrNull { it.first == id }?.second
        ?: if (id == "stock") "Original" else id.replaceFirstChar { it.uppercase() }
