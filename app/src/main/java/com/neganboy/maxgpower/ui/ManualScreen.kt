package com.neganboy.maxgpower.ui

import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.neganboy.maxgpower.CtlClient
import com.neganboy.maxgpower.MaxGState
import com.neganboy.maxgpower.MaxGViewModel

/**
 * Pestaña Manual, copiada de la WebUI (s-man): interruptor de control
 * manual, ajuste con deslizadores y guardar como perfil propio.
 */
@Composable
fun ManualScreen(vm: MaxGViewModel, state: MaxGState) {
    var perf by remember(state.manual.perf) { mutableStateOf(state.manual.perf) }
    var prime by remember(state.manual.prime) { mutableStateOf(state.manual.prime) }
    var gpu by remember(state.manual.gpu) { mutableStateOf(state.manual.gpu) }
    var name by remember { mutableStateOf("") }

    LazyColumn(Modifier.padding(horizontal = 18.dp)) {
        item {
            NeuCard(Modifier.padding(top = 18.dp)) {
                RuleRow(
                    "Control manual",
                    if (state.manual.on) "Activo: tus topes mandan, no el perfil." else "Apagado: manda el perfil elegido."
                ) {
                    NeuSwitch(state.manual.on) {
                        vm.runCommand("Control manual") {
                            if (!state.manual.on) CtlClient.manualOn() else CtlClient.manualOff()
                        }
                    }
                }
            }
        }

        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Ajuste manual")
                SectionSub("Mueve cada control y pulsa «Aplicar ahora» (enciende el control manual de arriba) para probar. Si te gusta, ponle nombre y guárdalo como perfil propio. Los topes nunca bajan de un mínimo seguro (40 % CPU, 30 % GPU), y «Original» lo deshace todo.")
                Spacer(Modifier.height(8.dp))
                SliderRow("Rendimiento (núcleos 0-5)", perf, 0..100, { perf = it }, { "$it%" })
                SliderRow("Núcleos prime", prime, 0..100, { prime = it }, { "$it%" })
                SliderRow("GPU", gpu, 0..100, { gpu = it }, { "$it%" })
                Spacer(Modifier.height(8.dp))
                Row {
                    NeuButton("Aplicar ahora", primary = true, modifier = Modifier.weight(1f)) {
                        vm.runCommand("Control manual") {
                            CtlClient.manualSet(perf, prime, gpu, state.manual.hl, state.manual.cpl, state.manual.swap)
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
                NeuButton("Volver a Original") {
                    vm.runCommand("Original") { CtlClient.applyProfile("stock") }
                }
            }
        }

        item {
            NeuCard(Modifier.padding(top = 20.dp)) {
                SectionTitle("Guardar como perfil propio")
                SectionSub("Se guarda con los valores de arriba (CPU, GPU, subida, memoria). Máximo 12 perfiles.")
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Nombre del perfil") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = NeuColors.CardTop,
                        unfocusedContainerColor = NeuColors.CardTop
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(12.dp))
                NeuButton("Guardar perfil", primary = true, enabled = name.isNotBlank()) {
                    val id = "u_" + name.trim().lowercase().replace(Regex("[^a-z0-9]+"), "_")
                    vm.runCommand("Guardar perfil") {
                        CtlClient.customSave(id, name.trim(), perf, prime, gpu, state.manual.hl, state.manual.cpl, state.manual.swap)
                    }
                    name = ""
                }
            }
        }

        item { Spacer(Modifier.height(32.dp)) }
    }
}
