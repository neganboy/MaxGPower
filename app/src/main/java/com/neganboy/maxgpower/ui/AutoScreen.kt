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
fun AutoScreen(vm: MaxGViewModel, state: MaxGState) {
    var lowPct by remember(state.auto.lowPct) { mutableStateOf(state.auto.lowPct) }
    var boost by remember(state.auto.boost) { mutableStateOf(state.auto.boost) }

    LazyColumn {
        item {
            SectionCard(
                "Modo inteligente",
                "Cambia solo de perfil según lo que estás haciendo: juegos, mapas, batería baja"
            ) {
                ToggleRow(
                    "Modo inteligente",
                    if (state.auto.alive) "Vigilante activo" else "Vigilante parado",
                    state.auto.on
                ) { on ->
                    vm.runCommand("Auto") { if (on) CtlClient.autoOn() else CtlClient.autoOff() }
                }
                state.autoNow?.let { now ->
                    Spacer8()
                    Text(
                        "Ahora: ${now.cat.ifEmpty { "—" }} → ${now.prof.ifEmpty { "—" }}${if (now.pkg.isNotEmpty()) " (${now.pkg})" else ""}",
                        fontSize = 13.sp
                    )
                }
            }
        }

        item {
            SectionCard("Reglas por situación", "Qué perfil pone en cada caso") {
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
                Spacer8()
                SliderRow("Batería baja desde", lowPct, 5..50, { lowPct = it }, { "$it%" })
                ActionButton("Guardar $lowPct%") {
                    vm.runCommand("Auto") { CtlClient.autoSet("lowpct", lowPct.toString()) }
                }
                Spacer8()
                SliderRow("Impulso al abrir un juego", boost, 0..60, { boost = it }, { "$it s" })
                ActionButton("Guardar impulso $boost s") {
                    vm.runCommand("Auto") { CtlClient.autoSet("boost", boost.toString()) }
                }
            }
        }

        item {
            SectionCard("Apps con perfil propio", "Estas apps fuerzan su perfil al abrirse") {
                if (state.autoApps.isEmpty()) {
                    Text("Ninguna app configurada.", fontSize = 13.sp, color = MutedText)
                } else {
                    for (app in state.autoApps) {
                        Text(
                            "• ${app.pkg} → ${app.cat}${if (app.profile.isNotEmpty()) " (${app.profile})" else ""}",
                            fontSize = 12.sp
                        )
                    }
                }
                Spacer8()
                Text(
                    "Para agregar una app, ábrela y vuelve aquí: aparece en recientes.",
                    fontSize = 12.sp, color = MutedText
                )
                if (state.autoRecent.isNotEmpty()) {
                    Spacer8()
                    for (r in state.autoRecent.take(8)) {
                        Text("• ${r.pkg}", fontSize = 12.sp)
                    }
                    Spacer8()
                    OutlineActionButton("Borrar recientes") {
                        vm.runCommand("Auto") { CtlClient.cmd("auto", "recent", "clear") }
                    }
                }
            }
        }

        item { Spacer8() }
    }
}

@Composable
private fun ProfileRuleRow(label: String, current: String, onSelect: (String) -> Unit) {
    val options = listOf("none" to "Ninguno") +
        MaxGState.PROFILES.map { it.first to it.second }
    Text(label, fontSize = 13.sp)
    ChipFlow(options, current.ifEmpty { "none" }, onSelect)
    Spacer8()
}
