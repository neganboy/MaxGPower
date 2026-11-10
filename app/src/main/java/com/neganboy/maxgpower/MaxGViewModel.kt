package com.neganboy.maxgpower

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Estado de la app: carga `state full` al abrir, luego sondea `state live`
 * + `info` cada 3 s (temperaturas, batería, frecuencias) y `state more`
 * cada 15 s. Los comandos se ejecutan en IO y refrescan el estado.
 */
sealed interface UpdateUiState {
    data object Idle : UpdateUiState
    data object Checking : UpdateUiState
    data class UpToDate(val version: String) : UpdateUiState
    data class Available(val release: AppUpdater.ReleaseInfo) : UpdateUiState
    data class Downloading(val progress: Int) : UpdateUiState
    data class Downloaded(val file: File) : UpdateUiState
    data class Error(val message: String) : UpdateUiState
}

class MaxGViewModel : ViewModel() {

    private val _state = MutableStateFlow(MaxGState())
    val state: StateFlow<MaxGState> = _state.asStateFlow()

    /** Estado del actualizador (revisar GitHub, descargar, instalar). */
    private val _update = MutableStateFlow<UpdateUiState>(UpdateUiState.Idle)
    val update: StateFlow<UpdateUiState> = _update.asStateFlow()

    private val _loading = MutableStateFlow(true)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    /** true cuando ctl.sh respondió con secciones SECT| (hay comunicación). */
    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    private var polling = false

    fun start() {
        if (polling) return
        polling = true
        viewModelScope.launch { refreshFull() }
        viewModelScope.launch {
            while (true) {
                delay(3_000)
                refreshLive()
            }
        }
        viewModelScope.launch {
            while (true) {
                delay(15_000)
                refreshMore()
            }
        }
    }

    fun consumeMessage() { _message.value = null }

    private fun mergeLive(live: MaxGState) {
        _state.update { cur ->
            cur.copy(
                // `state live` NO imprime DEV: si se copiara tal cual, el
                // dispositivo quedaría en "Sin respuesta" a los 3 s de abrir.
                device = if (live.device.ok) live.device else cur.device,
                profile = live.profile, safe = live.safe,
                bootCount = live.bootCount, govCur = live.govCur, govList = live.govList,
                govCfg = live.govCfg, gpu = live.gpu, romLimits = live.romLimits,
                gpuMode = live.gpuMode, gpuMaxPct = live.gpuMaxPct,
                gpuScope = live.gpuScope, cpuCaps = live.cpuCaps,
                heat = live.heat, heatX = live.heatX, heatTargets = live.heatTargets,
                watch = live.watch, manual = live.manual,
                conflicts = live.conflicts, autoNow = live.autoNow ?: cur.autoNow,
                info = live.info.copy(
                    ramPct = if (live.info.ramPct != 0) live.info.ramPct else cur.info.ramPct,
                    ramMb = if (live.info.ramMb != 0) live.info.ramMb else cur.info.ramMb,
                    batPct = if (live.info.batPct != 0) live.info.batPct else cur.info.batPct,
                    batTempC = if (live.info.batTempC != 0f) live.info.batTempC else cur.info.batTempC,
                    cpuTempC = if (live.info.cpuTempC != 0f) live.info.cpuTempC else cur.info.cpuTempC,
                    currentMa = live.info.currentMa.ifEmpty { cur.info.currentMa },
                    cycles = if (live.info.cycles != 0) live.info.cycles else cur.info.cycles,
                    charging = live.info.charging.ifEmpty { cur.info.charging },
                    diskPct = if (live.info.diskPct != 0) live.info.diskPct else cur.info.diskPct,
                    diskGb = if (live.info.diskGb != 0) live.info.diskGb else cur.info.diskGb
                )
            )
        }
    }

    private fun mergeMore(more: MaxGState) {
        _state.update { cur ->
            cur.copy(
                bt = more.bt, btPrio = more.btPrio, btScan = more.btScan, btNice = more.btNice,
                auto = more.auto, autoApps = more.autoApps, autoRecent = more.autoRecent,
                autoMboost = more.autoMboost, autoBoostMethod = more.autoBoostMethod,
                autoBoostDesc = more.autoBoostDesc, pad = more.pad, padOpt = more.padOpt,
                padTests = more.padTests, padScan = more.padScan,
                tune = more.tune, maint = more.maint, deluxe = more.deluxe,
                sessions = more.sessions, bgapps = more.bgapps
            )
        }
    }

    /**
     * Carga completa en partes, como la WebUI: `state boot` trae el núcleo
     * + el dispositivo + las tablas de perfiles (rápido, sin pm/dumpsys),
     * `state more` trae Mando/Auto (lento) y `info` los datos del sistema.
     * Si boot no responde, se junta `live` + `static` para no quedarse en
     * blanco. Un `state full` único es lento y frágil en este teléfono.
     */
    fun refreshFull() {
        viewModelScope.launch {
            _loading.value = true
            val boot = withContext(Dispatchers.IO) {
                runCatching { CtlClient.stateOrNull("boot") }.getOrNull()
            }
            val more = withContext(Dispatchers.IO) {
                runCatching { CtlClient.stateOrNull("more") }.getOrNull()
            }
            val info = withContext(Dispatchers.IO) {
                runCatching { CtlClient.info() }.getOrNull()
            }
            var s: MaxGState? = boot
            if (s == null) {
                val live = withContext(Dispatchers.IO) {
                    runCatching { CtlClient.stateOrNull("live") }.getOrNull()
                }
                val static = withContext(Dispatchers.IO) {
                    runCatching { CtlClient.stateOrNull("static") }.getOrNull()
                }
                if (live != null) {
                    s = live.copy(
                        plans = static?.plans ?: emptyMap(),
                        freqs = static?.freqs ?: emptyMap(),
                        customProfiles = static?.customProfiles ?: emptyList()
                    )
                }
            }
            if (s != null) {
                _connected.value = true
                if (more != null) {
                    s = s.copy(
                        bt = more.bt, btPrio = more.btPrio, btScan = more.btScan,
                        btNice = more.btNice, auto = more.auto, autoApps = more.autoApps,
                        autoRecent = more.autoRecent, autoMboost = more.autoMboost,
                        autoBoostMethod = more.autoBoostMethod,
                        autoBoostDesc = more.autoBoostDesc, pad = more.pad,
                        padOpt = more.padOpt, padTests = more.padTests,
                        padScan = more.padScan, tune = more.tune, maint = more.maint,
                        deluxe = more.deluxe, sessions = more.sessions,
                        bgapps = more.bgapps
                    )
                }
                if (info != null) s = s.copy(info = info.info)
                _state.value = s
            } else {
                _connected.value = false
            }
            _loading.value = false
        }
    }

    private suspend fun refreshLive() {
        val live = withContext(Dispatchers.IO) {
            runCatching { CtlClient.stateOrNull("live") }.getOrNull()
        } ?: return
        _connected.value = true
        val info = withContext(Dispatchers.IO) {
            runCatching { CtlClient.info() }.getOrNull()
        }
        mergeLive(live)
        if (info != null) _state.update { it.copy(info = info.info) }
    }

    private suspend fun refreshMore() {
        val more = withContext(Dispatchers.IO) {
            runCatching { CtlClient.stateOrNull("more") }.getOrNull()
        } ?: return
        _connected.value = true
        mergeMore(more)
    }

    /** Ejecuta un comando de ctl.sh, muestra el resultado y refresca. */
    fun runCommand(label: String, block: () -> CtlClient.CmdResult) {
        viewModelScope.launch {
            _busy.value = true
            val res = withContext(Dispatchers.IO) { runCatching(block).getOrNull() }
            _busy.value = false
            if (res == null) {
                _message.value = "$label: no se pudo ejecutar"
            } else {
                _message.value = res.detail.ifEmpty { "$label: ${if (res.ok) "listo" else "falló"}" }
            }
            refreshFull()
        }
    }

    /** Revisa en GitHub si hay una versión más nueva que la instalada. */
    fun checkUpdates(context: Context) {
        if (_update.value is UpdateUiState.Checking) return
        viewModelScope.launch {
            _update.value = UpdateUiState.Checking
            when (val r = AppUpdater.checkLatest(context.applicationContext)) {
                is AppUpdater.CheckResult.Available -> _update.value = UpdateUiState.Available(r.release)
                is AppUpdater.CheckResult.UpToDate -> _update.value = UpdateUiState.UpToDate(AppUpdater.installedVersion(context))
                is AppUpdater.CheckResult.Error -> _update.value = UpdateUiState.Error(r.message)
            }
        }
    }

    /** Revisa solo si pasaron más de 24 h desde la última revisión (al abrir la app). */
    fun checkUpdatesIfDue(context: Context) {
        val prefs = context.getSharedPreferences("maxg", Context.MODE_PRIVATE)
        val last = prefs.getLong("update_last_check", 0)
        if (System.currentTimeMillis() - last < 24 * 60 * 60 * 1000L) return
        prefs.edit().putLong("update_last_check", System.currentTimeMillis()).apply()
        checkUpdates(context)
    }

    /** Descarga la APK del release disponible (verifica paquete y firma antes de avisar que está lista). */
    fun downloadUpdate(context: Context) {
        val release = (_update.value as? UpdateUiState.Available)?.release ?: return
        viewModelScope.launch {
            _update.value = UpdateUiState.Downloading(0)
            try {
                val file = AppUpdater.downloadApk(context.applicationContext, release) { p ->
                    _update.value = UpdateUiState.Downloading(p)
                }
                _update.value = UpdateUiState.Downloaded(file)
            } catch (e: Exception) {
                _update.value = UpdateUiState.Error(e.message ?: "No se pudo descargar")
            }
        }
    }

    fun runRaw(label: String, block: () -> String) {
        viewModelScope.launch {
            _busy.value = true
            val out = withContext(Dispatchers.IO) { runCatching(block).getOrNull() }
            _busy.value = false
            _message.value = out?.trim()?.take(200) ?: "$label: sin respuesta"
            refreshFull()
        }
    }
}
