package com.neganboy.maxgpower

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

/**
 * Estado de la app: carga `state full` al abrir, luego sondea `state live`
 * + `info` cada 3 s (temperaturas, batería, frecuencias) y `state more`
 * cada 15 s. Los comandos se ejecutan en IO y refrescan el estado.
 */
class MaxGViewModel : ViewModel() {

    private val _state = MutableStateFlow(MaxGState())
    val state: StateFlow<MaxGState> = _state.asStateFlow()

    private val _loading = MutableStateFlow(true)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

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
                device = live.device, profile = live.profile, safe = live.safe,
                bootCount = live.bootCount, govCur = live.govCur, govList = live.govList,
                govCfg = live.govCfg, gpu = live.gpu, romLimits = live.romLimits,
                gpuMode = live.gpuMode, gpuMaxPct = live.gpuMaxPct,
                gpuScope = live.gpuScope, cpuCaps = live.cpuCaps,
                heat = live.heat, heatX = live.heatX, manual = live.manual,
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
                sessions = more.sessions
            )
        }
    }

    fun refreshFull() {
        viewModelScope.launch {
            _loading.value = true
            val full = withContext(Dispatchers.IO) {
                runCatching { CtlClient.state("full") }.getOrNull()
            }
            if (full != null) _state.value = full
            val info = withContext(Dispatchers.IO) {
                runCatching { CtlClient.info() }.getOrNull()
            }
            if (info != null) _state.update { it.copy(info = info.info) }
            _loading.value = false
        }
    }

    private suspend fun refreshLive() {
        val live = withContext(Dispatchers.IO) {
            runCatching { CtlClient.state("live") }.getOrNull()
        } ?: return
        val info = withContext(Dispatchers.IO) {
            runCatching { CtlClient.info() }.getOrNull()
        }
        mergeLive(live)
        if (info != null) _state.update { it.copy(info = info.info) }
    }

    private suspend fun refreshMore() {
        val more = withContext(Dispatchers.IO) {
            runCatching { CtlClient.state("more") }.getOrNull()
        } ?: return
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
