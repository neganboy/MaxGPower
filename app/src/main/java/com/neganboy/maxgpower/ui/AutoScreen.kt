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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

/**
 * Pestaña Auto, copiada de la WebUI (s-auto): modo inteligente,
 * reglas, impulso, apps, recientes, partidas, red y carga, DNS,
 * mantenimiento, batería, módulo y sonda.
 */
@Composable
fun AutoScreen(vm: MaxGViewModel, state: MaxGState, onOpenLog: (String) -> Unit, onRevertAll: () -> Unit) {
    var lowPct by remember(state.auto.lowPct) { mutableStateOf(state.auto.lowPct) }
    var boost by remember(state.auto.boost) { mutableStateOf(state.auto.boost) }
    var mboost by remember(state.autoMboost) { mutableStateOf(state.autoMboost) }
    var sondaText by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("maxg", android.content.Context.MODE_PRIVATE) }
    var bootApply by remember { mutableStateOf(prefs.getBoolean("boot_apply", true)) }

    LazyColumn(Modifier.padding(horizontal = 18.dp)) {
        // Modo inteligente
        item {
            NeuCard(Modifier.padding(top = 18.dp)) {
                RuleRow(
                    "Modo inteligente",
                    state.autoNow?.let { now ->
                        if (now.cat.isNotEmpty()) "Ahora: ${now.cat} → ${profileShort(now.prof)}${if (now.pkg.isNotEmpty()) " (${now.pkg})" else ""}"
                        else "Cambia solo de perfil según lo que estás haciendo: juegos, mapas, batería baja."
                    } ?: "Cambia solo de perfil según lo que estás haciendo: juegos, mapas, batería baja."
                ) {
                    NeuSwitch(state.auto.on) {
                        vm.runCommand("Auto") { if (!state.auto.on) CtlClient.autoOn() else CtlClient.autoOff() }
                    }
                }
                Text(
                    if (state.auto.alive) "Vigilante activo" else "Vigilante parado",
                    fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 8.dp)
                )
            }
        }

        // Qué perfil usar en cada caso
        item { GroupHeader("Qué perfil usar en cada caso") }
        item {
            NeuCard {
                SectionSub("Es temporal: al terminar vuelve al perfil que elegiste en la pestaña Perfiles, que nunca se cambia.")
                Spacer(Modifier.height(8.dp))
                ProfileRuleRow("En juegos", state.auto.game) { p ->
                    vm.runCommand("Auto") { CtlClient.autoSet("game", p) }
                }
                ProfileRuleRow("En mapas", state.auto.maps) { p ->
                    vm.runCommand("Auto") { CtlClient.autoSet("maps", p) }
                }
                ProfileRuleRow("Batería baja", state.auto.low) { p ->
                    vm.runCommand("Auto") { CtlClient.autoSet("low", p) }
                }
                ProfileRuleRow("Sin actividad", state.auto.off) { p ->
                    vm.runCommand("Auto") { CtlClient.autoSet("off", p) }
                }
                Spacer(Modifier.height(8.dp))
                SliderRow("Batería baja desde", lowPct, 5..50, { lowPct = it }, { "$it%" })
                NeuButton("Guardar $lowPct%") {
                    vm.runCommand("Auto") { CtlClient.autoSet("lowpct", lowPct.toString()) }
                }
            }
        }

        // Impulso de carga
        item { GroupHeader("Impulso de carga") }
        item {
            NeuCard {
                SectionSub("Al abrir un juego, los primeros segundos corren al máximo para que el mapa y los recursos carguen rápido; después pasa solo al perfil de juego, que es más fresco.")
                SliderRow("Impulso al abrir un juego", boost, 0..60, { boost = it }, { "$it s" })
                NeuButton("Guardar impulso $boost s") {
                    vm.runCommand("Auto") { CtlClient.autoSet("boost", boost.toString()) }
                }
                Spacer(Modifier.height(14.dp))
                Text("Impulso para mapas", fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                Text("Google Maps, Waze y similares: unos segundos en «Alto» para que el mapa cargue rápido; luego pasa al perfil de mapas.", fontSize = 12.5.sp, color = NeuColors.Muted)
                SliderRow("Impulso para mapas", mboost, 0..60, { mboost = it }, { "$it s" })
                NeuButton("Guardar impulso mapas $mboost s") {
                    vm.runCommand("Auto") { CtlClient.autoSet("mboost", mboost.toString()) }
                }
            }
        }

        // Apps detectadas
        item { GroupHeader("Apps detectadas") }
        item {
            NeuCard {
                SectionSub("Las apps instaladas de estas listas se reconocen solas, y cada una puede tener su propio perfil. Añade las que falten con su nombre de paquete.")
                Spacer(Modifier.height(8.dp))
                if (state.autoApps.isEmpty()) {
                    Text("Ninguna app configurada.", fontSize = 13.sp, color = NeuColors.Muted)
                } else {
                    for (app in state.autoApps) {
                        Text(
                            "• ${app.pkg} → ${app.cat}${if (app.profile.isNotEmpty()) " (${profileShort(app.profile)})" else ""}${if (!app.installed) " · no instalada" else ""}",
                            fontSize = 12.5.sp, color = NeuColors.Muted
                        )
                    }
                }
            }
        }

        // Vistas recientemente
        item { GroupHeader("Vistas recientemente") }
        item {
            NeuCard {
                SectionSub("Apps que abriste con el modo inteligente encendido y que todavía no están en ninguna lista. Un toque y quedan registradas.")
                Spacer(Modifier.height(8.dp))
                if (state.autoRecent.isEmpty()) {
                    Text("Nada reciente.", fontSize = 13.sp, color = NeuColors.Muted)
                } else {
                    for (r in state.autoRecent.take(8)) {
                        Text("• ${r.pkg}", fontSize = 12.5.sp, color = NeuColors.Muted)
                    }
                    Spacer(Modifier.height(12.dp))
                    NeuButton("Borrar recientes") {
                        vm.runCommand("Auto") { CtlClient.cmd("auto", "recent", "clear") }
                    }
                }
            }
        }

        // Partidas
        item { GroupHeader("Partidas") }
        item {
            NeuCard {
                if (state.sessions.isEmpty()) {
                    Text("Sin sesiones registradas.", fontSize = 13.sp, color = NeuColors.Muted)
                } else {
                    Text(
                        "${state.sessions.size} partida(s) registrada(s).",
                        fontSize = 13.sp, color = NeuColors.Muted
                    )
                    Spacer(Modifier.height(8.dp))
                    for (s in state.sessions.take(8)) {
                        Text(
                            "• ${s.pkg.ifEmpty { "sistema" }} — ${s.dur / 60} min · ${profileShort(s.prof)} · CPU ${s.cpuC}° · bat ${s.b0}%→${s.b1}%",
                            fontSize = 12.5.sp, color = NeuColors.Muted
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    NeuButton("Borrar historial") {
                        vm.runCommand("Sesiones") { CtlClient.sessClear() }
                    }
                }
            }
        }

        // Red y carga
        item { GroupHeader("Red y carga") }
        item {
            NeuCard {
                RuleRow("Red optimizada", null) {
                    NeuSwitch(state.tune.net) {
                        vm.runCommand("Ajustes") { CtlClient.tuneSet("net", if (!state.tune.net) "1" else "0") }
                    }
                }
                Spacer(Modifier.height(14.dp))
                RuleRow("Lectura anticipada (I/O)", null) {
                    NeuSwitch(state.tune.io) {
                        vm.runCommand("Ajustes") { CtlClient.tuneSet("io", if (!state.tune.io) "1" else "0") }
                    }
                }
                Spacer(Modifier.height(14.dp))
                RuleRow("Animaciones reducidas", null) {
                    NeuSwitch(state.tune.anim) {
                        vm.runCommand("Ajustes") { CtlClient.tuneSet("anim", if (!state.tune.anim) "1" else "0") }
                    }
                }
                Spacer(Modifier.height(14.dp))
                RuleRow("BBR (TCP)", null) {
                    NeuSwitch(state.tune.bbr) {
                        vm.runCommand("Ajustes") { CtlClient.tuneSet("bbr", if (!state.tune.bbr) "1" else "0") }
                    }
                }
                if (state.tune.ra.isNotEmpty()) Text("Read-ahead: ${state.tune.ra}", fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 10.dp))
            }
        }
        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("DNS privado")
                SectionSub("Un DNS rápido acelera el primer contacto con cada sitio (mapas, tiles, páginas). Opcional: quien lo ofrece ve los nombres de los sitios que visitas.")
                Spacer(Modifier.height(8.dp))
                Text(if (state.tune.dns.isNotEmpty()) "DNS actual: ${state.tune.dns}" else "DNS: el de tu red.", fontSize = 12.5.sp, color = NeuColors.Muted)
            }
        }

        // Mantenimiento
        item { GroupHeader("Mantenimiento") }
        item {
            NeuCard {
                RuleRow("Mantenimiento automático", "Limpieza y revisión automática.") {
                    NeuSwitch(state.maint.on) {
                        vm.runCommand("Mantenimiento") { if (!state.maint.on) CtlClient.maintOn() else CtlClient.maintOff() }
                    }
                }
                if (state.maint.last > 0) {
                    Text("Último: hace ${state.maint.last} min", fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 8.dp))
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Ejecutar ahora") {
                    vm.runCommand("Mantenimiento") { CtlClient.maintNow() }
                }
            }
        }

        // Estado de la batería
        item { GroupHeader("Estado de la batería") }
        item {
            NeuCard {
                Text(
                    "Batería ${if (state.info.batPct > 0) "${state.info.batPct}%" else "—"} · ${state.info.charging.ifEmpty { "sin cargar" }} · ${if (state.info.batTempC > 0) "%.1f°".format(state.info.batTempC) else ""}",
                    fontSize = 13.sp, color = NeuColors.Text
                )
                if (state.info.cycles > 0) Text("Ciclos: ${state.info.cycles}", fontSize = 12.5.sp, color = NeuColors.Muted)
                Text("Se actualiza al abrir esta pestaña.", fontSize = 12.5.sp, color = NeuColors.Muted)
            }
        }

        // Módulo
        item { GroupHeader("Módulo") }
        item {
            NeuCard {
                RuleRow("Aplicar perfil al encender", "MaxG se activa solo cuando enciendes el teléfono.") {
                    NeuSwitch(bootApply) {
                        bootApply = !bootApply
                        prefs.edit().putBoolean("boot_apply", bootApply).apply()
                    }
                }
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    NeuButton("Reaplicar todo", modifier = Modifier.weight(1f)) {
                        vm.runRaw("Reaplicar") { CtlClient.reapply() }
                    }
                    NeuButton("Ver registro", modifier = Modifier.weight(1f)) {
                        onOpenLog(CtlClient.log(60))
                    }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Guardar informe completo") {
                    vm.runCommand("Informe") { CtlClient.report() }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Revertir todo y detener MaxG") {
                    onRevertAll()
                }
            }
        }

        // Buscar mejoras (sonda)
        item { GroupHeader("Buscar mejoras") }
        item {
            NeuCard {
                SectionSub("Sonda de diagnóstico: mide y guarda un informe de tu teléfono para encontrar qué mejorar.")
                Spacer(Modifier.height(12.dp))
                NeuButton("Sonda rápida (rendimiento)", primary = true) {
                    vm.runCommand("Sonda") { CtlClient.sondaPerf() }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Sonda de hardware") {
                    vm.runCommand("Sonda") { CtlClient.sondaHw() }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Sonda profunda") {
                    vm.runCommand("Sonda") { CtlClient.sondaDeep() }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Ver hallazgos de la última sonda") {
                    sondaText = CtlClient.sondaFindings()
                }
                sondaText?.let { Text(it.take(2000), fontSize = 11.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 10.dp)) }
            }
        }

        item { Spacer(Modifier.height(32.dp)) }
    }
}

@Composable
private fun ProfileRuleRow(label: String, current: String, onSelect: (String) -> Unit) {
    val options = listOf("none" to "Ninguno") +
        MaxGState.PROFILES.map { it.first to it.second }
    Text(label, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = NeuColors.Text)
    Spacer(Modifier.height(6.dp))
    ChipFlow(options, current.ifEmpty { "none" }, onSelect)
    Spacer(Modifier.height(10.dp))
}
