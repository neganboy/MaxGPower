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
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.neganboy.maxgpower.ui.AutoScreen
import com.neganboy.maxgpower.ui.GpuScreen
import com.neganboy.maxgpower.ui.HeatScreen
import com.neganboy.maxgpower.ui.HomeScreen
import com.neganboy.maxgpower.ui.MaxGTheme
import com.neganboy.maxgpower.ui.MoreScreen
import com.neganboy.maxgpower.ui.PadScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * MaxG Power — interfaz NATIVA (Jetpack Compose + Material 3).
 * Nada de WebView: la UI habla directamente con ctl.sh por su protocolo.
 */
class MainActivity : ComponentActivity() {

    private val vm: MaxGViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaxGApp() }
        askNotificationPermission()
    }

    @OptIn(ExperimentalMaterial3Api::class)
    @Composable
    private fun MaxGApp() {
        val state by vm.state.collectAsState()
        val loading by vm.loading.collectAsState()
        val busy by vm.busy.collectAsState()
        val message by vm.message.collectAsState()
        val snackbarHostState = remember { SnackbarHostState() }
        var tab by remember { mutableStateOf(Tab.Home) }
        var showNoRoot by remember { mutableStateOf(false) }
        var showModuleConflict by remember { mutableStateOf(false) }
        var showBattery by remember { mutableStateOf(false) }
        var logText by remember { mutableStateOf<String?>(null) }
        var showRevert by remember { mutableStateOf(false) }

        LaunchedEffect(Unit) { prepare(
            onNoRoot = { showNoRoot = true },
            onModuleConflict = { showModuleConflict = true },
            onBattery = { showBattery = true }
        ) }

        LaunchedEffect(message) {
            message?.let {
                snackbarHostState.showSnackbar(it)
                vm.consumeMessage()
            }
        }

        MaxGTheme {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = {
                            Text("MaxG Power", fontWeight = FontWeight.Bold)
                        },
                        actions = {
                            if (busy) CircularProgressIndicator(modifier = Modifier.padding(end = 16.dp))
                            else if (state.safe) Text(
                                "MODO SEGURO", color = MaterialTheme.colorScheme.error,
                                fontSize = 12.sp, fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(end = 16.dp)
                            )
                        },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = MaterialTheme.colorScheme.background
                        )
                    )
                },
                bottomBar = {
                    Row(
                        Modifier.fillMaxWidth()
                            .background(MaterialTheme.colorScheme.surface)
                            .padding(vertical = 4.dp)
                    ) {
                        for (t in Tab.values()) {
                            Text(
                                t.label,
                                modifier = Modifier.weight(1f).clickable { tab = t }
                                    .padding(vertical = 10.dp),
                                textAlign = TextAlign.Center,
                                fontSize = 12.sp,
                                fontWeight = if (t == tab) FontWeight.Bold else FontWeight.Normal,
                                color = if (t == tab) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                },
                snackbarHost = { SnackbarHost(snackbarHostState) }
            ) { padding ->
                Box(Modifier.fillMaxSize().padding(padding)) {
                    if (loading) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                CircularProgressIndicator()
                                Text("Leyendo el estado de MaxG…", modifier = Modifier.padding(top = 12.dp))
                            }
                        }
                    } else {
                        when (tab) {
                            Tab.Home -> HomeScreen(vm, state)
                            Tab.Gpu -> GpuScreen(vm, state)
                            Tab.Heat -> HeatScreen(vm, state)
                            Tab.Pad -> PadScreen(vm, state)
                            Tab.Auto -> AutoScreen(vm, state)
                            Tab.More -> MoreScreen(vm, state,
                                onOpenLog = { logText = it },
                                onRevertAll = { showRevert = true })
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

    private enum class Tab(val label: String) {
        Home("Inicio"), Gpu("GPU"), Heat("Calor"), Pad("Mando"), Auto("Auto"), More("Más")
    }

    /** Root, scripts, módulo en conflicto y servicio supervisor. */
    private suspend fun prepare(
        onNoRoot: () -> Unit,
        onModuleConflict: () -> Unit,
        onBattery: () -> Unit
    ) {
        val hasRoot = withContext(Dispatchers.IO) { RootShell.hasRoot() }
        if (!hasRoot) { onNoRoot(); return }
        val installed = withContext(Dispatchers.IO) { ScriptsInstaller.ensureInstalled(this@MainActivity) }
        if (!installed) return
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
