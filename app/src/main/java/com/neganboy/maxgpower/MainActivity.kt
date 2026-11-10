package com.neganboy.maxgpower

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.neganboy.maxgpower.ui.AutoScreen
import com.neganboy.maxgpower.ui.GpuScreen
import com.neganboy.maxgpower.ui.HomeScreen
import com.neganboy.maxgpower.ui.ManualScreen
import com.neganboy.maxgpower.ui.MaxGTheme
import com.neganboy.maxgpower.ui.NavIcon
import com.neganboy.maxgpower.ui.NavIconKind
import com.neganboy.maxgpower.ui.NeuColors
import com.neganboy.maxgpower.ui.PadScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * MaxG Power — interfaz NATIVA (Jetpack Compose + Material 3) con el
 * DISEÑO de la WebUI del módulo: tema claro neumórfico, cabecera con
 * píldora de conexión y navegación superior de 5 pestañas
 * (Perfiles, Manual, GPU, Mando, Auto). Nada de WebView.
 */
class MainActivity : ComponentActivity() {

    private val vm: MaxGViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaxGApp() }
        askNotificationPermission()
    }

    @Composable
    private fun MaxGApp() {
        val state by vm.state.collectAsState()
        val loading by vm.loading.collectAsState()
        val connected by vm.connected.collectAsState()
        val busy by vm.busy.collectAsState()
        val message by vm.message.collectAsState()
        val snackbarHostState = remember { SnackbarHostState() }
        var tab by remember { mutableStateOf(Tab.Perfiles) }
        var showNoRoot by remember { mutableStateOf(false) }
        var showModuleConflict by remember { mutableStateOf(false) }
        var showBattery by remember { mutableStateOf(false) }
        var logText by remember { mutableStateOf<String?>(null) }
        var showRevert by remember { mutableStateOf(false) }

        LaunchedEffect(Unit) {
            prepare(
                onNoRoot = { showNoRoot = true },
                onModuleConflict = { showModuleConflict = true },
                onBattery = { showBattery = true }
            )
        }

        LaunchedEffect(message) {
            message?.let {
                snackbarHostState.showSnackbar(it)
                vm.consumeMessage()
            }
        }

        MaxGTheme {
            Scaffold(
                containerColor = NeuColors.Bg,
                snackbarHost = { SnackbarHost(snackbarHostState) }
            ) { padding ->
                Column(Modifier.fillMaxSize().padding(padding)) {
                    // Cabecera como la WebUI: título + subtítulo + píldora de conexión
                    Row(
                        Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 18.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("MaxG ", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
                                Text("Power", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = NeuColors.Blue2)
                                if (state.safe) {
                                    Text(
                                        "MODO SEGURO", color = NeuColors.Bad, fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 8.dp)
                                    )
                                }
                            }
                            Text(
                                "v1.4 · por Neganboy · hecho para tu Poco F8 Pro",
                                fontSize = 12.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 2.dp)
                            )
                        }
                        if (busy) {
                            CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp, color = NeuColors.Blue2)
                        }
                        // Píldora de conexión
                        Box(
                            Modifier.padding(start = 8.dp)
                                .shadow(4.dp, RoundedCornerShape(99.dp))
                                .background(Brush.verticalGradient(listOf(NeuColors.CardTop, NeuColors.CardBottom)), RoundedCornerShape(99.dp))
                                .padding(horizontal = 14.dp, vertical = 8.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                val dot = when {
                                    loading -> NeuColors.Warn
                                    connected -> NeuColors.Ok
                                    else -> NeuColors.Bad
                                }
                                Box(Modifier.size(8.dp).background(dot, CircleShape))
                                Text(
                                    when {
                                        loading -> "Conectando…"
                                        connected -> "Conectado"
                                        else -> "Sin respuesta"
                                    },
                                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = NeuColors.Muted,
                                    modifier = Modifier.padding(start = 8.dp)
                                )
                            }
                        }
                    }

                    // Navegación superior de 5 pestañas (como .nav de la WebUI)
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 18.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        for (t in Tab.values()) {
                            val selected = t == tab
                            Column(
                                Modifier.weight(1f).height(74.dp)
                                    .shadow(if (selected) 6.dp else 0.dp, RoundedCornerShape(26.dp))
                                    .then(
                                        if (selected) Modifier.background(
                                            Brush.verticalGradient(listOf(Color.White, Color(0xFFEEF2F7))),
                                            RoundedCornerShape(26.dp)
                                        ) else Modifier
                                    )
                                    .clickable { tab = t },
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                NavIcon(t.icon, if (selected) NeuColors.Blue2 else NeuColors.Muted)
                                Spacer(Modifier.height(5.dp))
                                Text(
                                    t.label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                                    color = if (selected) NeuColors.Blue2 else NeuColors.Muted,
                                    textAlign = TextAlign.Center
                                )
                            }
                        }
                    }

                    // Contenido
                    Box(Modifier.fillMaxSize()) {
                        if (loading) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    CircularProgressIndicator(color = NeuColors.Blue2)
                                    Text(
                                        "Leyendo el estado de MaxG…",
                                        color = NeuColors.Muted,
                                        modifier = Modifier.padding(top = 12.dp)
                                    )
                                }
                            }
                        } else {
                            when (tab) {
                                Tab.Perfiles -> HomeScreen(vm, state)
                                Tab.Manual -> ManualScreen(vm, state)
                                Tab.Gpu -> GpuScreen(vm, state)
                                Tab.Mando -> PadScreen(vm, state, onOpenLog = { logText = it })
                                Tab.Auto -> AutoScreen(
                                    vm, state,
                                    onOpenLog = { logText = it },
                                    onRevertAll = { showRevert = true }
                                )
                            }
                        }
                    }
                }
            }

            if (showNoRoot) {
                AlertDialog(
                    onDismissRequest = {},
                    title = { Text("Sin acceso root") },
                    text = { Text("MaxG Power necesita root para cambiar CPU, GPU y calor.\n\nOtorga el permiso en KernelSU Next y vuelve a abrir la app.") },
                    confirmButton = { TextButton(onClick = { showNoRoot = false }) { Text("Entendido") } }
                )
            }

            if (showModuleConflict) {
                AlertDialog(
                    onDismissRequest = {},
                    title = { Text("El módulo MaxG sigue instalado") },
                    text = { Text("La app y el módulo escriben los mismos ajustes y se pelean. Desactiva el módulo (se puede volver a activar) y reinicia para que la app tome el control.") },
                    confirmButton = {
                        TextButton(onClick = {
                            showModuleConflict = false
                            Thread {
                                if (ScriptsInstaller.disableModule()) RootShell.exec("reboot")
                            }.start()
                        }) { Text("Desactivar y reiniciar") }
                    },
                    dismissButton = {
                        TextButton(onClick = {
                            showModuleConflict = false
                            startSupervisor()
                        }) { Text("Ahora no") }
                    }
                )
            }

            if (showBattery) {
                AlertDialog(
                    onDismissRequest = { showBattery = false },
                    title = { Text("Que el supervisor no se duerma") },
                    text = { Text("Android puede matar el supervisor que mantiene tu perfil aplicado. Quita la optimización de batería para MaxG Power.") },
                    confirmButton = {
                        TextButton(onClick = {
                            showBattery = false
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                        .setData(Uri.parse("package:$packageName"))
                                )
                            } catch (_: Exception) {
                            }
                        }) { Text("Quitar optimización") }
                    },
                    dismissButton = {
                        TextButton(onClick = { showBattery = false }) { Text("Ahora no") }
                    }
                )
            }

            logText?.let { text ->
                AlertDialog(
                    onDismissRequest = { logText = null },
                    title = { Text("Registro de MaxG") },
                    text = {
                        Text(
                            text,
                            fontSize = 11.sp,
                            modifier = Modifier.verticalScroll(rememberScrollState())
                        )
                    },
                    confirmButton = { TextButton(onClick = { logText = null }) { Text("Cerrar") } }
                )
            }

            if (showRevert) {
                AlertDialog(
                    onDismissRequest = { showRevert = false },
                    title = { Text("Revertir todo") },
                    text = { Text("Detiene los vigilantes y devuelve CPU, GPU y calor a como los tenía la ROM. ¿Seguro?") },
                    confirmButton = {
                        TextButton(onClick = {
                            showRevert = false
                            Thread {
                                CtlClient.revertAll()
                                stopService(Intent(this@MainActivity, MaxGService::class.java))
                            }.start()
                            vm.refreshFull()
                        }) { Text("Sí, revertir") }
                    },
                    dismissButton = {
                        TextButton(onClick = { showRevert = false }) { Text("Cancelar") }
                    }
                )
            }
        }
    }

    private enum class Tab(val label: String, val icon: NavIconKind) {
        Perfiles("Perfiles", NavIconKind.Bolt),
        Manual("Manual", NavIconKind.Sliders),
        Gpu("GPU", NavIconKind.Chip),
        Mando("Mando", NavIconKind.Gamepad),
        Auto("Auto", NavIconKind.Sparkle)
    }

    /** Root, scripts, módulo en conflicto y servicio supervisor. */
    private suspend fun prepare(
        onNoRoot: () -> Unit,
        onModuleConflict: () -> Unit,
        onBattery: () -> Unit
    ) {
        val hasRoot = withContext(Dispatchers.IO) { RootShell.hasRoot() }
        if (!hasRoot) {
            onNoRoot()
            vm.start()
            return
        }
        val installed = withContext(Dispatchers.IO) { ScriptsInstaller.ensureInstalled(this@MainActivity) }
        if (!installed) {
            // La interfaz carga igual y muestra el error; sin scripts nada aplica.
            vm.start()
            vm.runRaw("Scripts") { "No pude instalar los scripts de MaxG" }
            return
        }
        val module = withContext(Dispatchers.IO) { ScriptsInstaller.moduleInstalled() }
        if (module) onModuleConflict() else startSupervisor()
        vm.start()
        val prefs = getSharedPreferences("maxg", MODE_PRIVATE)
        if (!prefs.getBoolean("battery_asked", false)) {
            prefs.edit().putBoolean("battery_asked", true).apply()
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) onBattery()
        }
    }

    private fun startSupervisor() {
        val svc = Intent(this, MaxGService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(svc)
        } else {
            startService(svc)
        }
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1
            )
        }
    }
}
