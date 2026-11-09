package com.neganboy.maxgpower

/**
 * Modelo de estado de MaxG, portado del parse() de la WebUI del módulo.
 * Cada línea del protocolo de ctl.sh (SECT|...) se convierte en un campo.
 * Los valores de temperatura vienen en décimas (se dividen entre 10).
 */
data class DeviceInfo(
    val ok: Boolean = false,
    val name: String = "",
    val kernel: String = "",
    val build: String = "",
    val why: String = ""
)

data class ProfilePlan(
    val id: String,
    val perf: Int = 0,
    val prime: Int = 0,
    val gpu: Int = 0,
    val hl: Int = 0,
    val cpl: Int = 0,
    val swap: Int = 0,
    val hz: Int = 0
)

data class GpuState(
    val floor: Int = 0,
    val free: Boolean = false,
    val alive: Boolean = false,
    val target: Int = 0,
    val table: List<Int> = emptyList(),
    val level: String = "",
    val clk: Int = 0,
    val cap: Int = 0,
    val be: String = "",
    val um: Int = 0,
    val rm: Int = 0,
    val rl: Int = 0
)

data class RomLimit(val name: String, val cur: Int, val max: Int)

data class HeatState(
    val mode: String = "off",
    val level: Int = 0,
    val points: Int = 0,
    val cpuC: Float = 0f,
    val batC: Float = 0f,
    val screen: Boolean = false,
    val alive: Boolean = false,
    val skinC: Float = 0f
)

data class HeatX(
    val ant: Boolean = false,
    val burst: String = "off",
    val antOn: Boolean = false,
    val burstOn: Boolean = false,
    val pc: Int = 0,
    val pg: Int = 0
)

data class BtState(
    val fast: Boolean = false,
    val min: Int = 0,
    val max: Int = 0,
    val lat: String = "",
    val timeout: String = "",
    val on: Boolean = false
)

data class AutoState(
    val on: Boolean = false,
    val alive: Boolean = false,
    val game: String = "",
    val maps: String = "",
    val low: String = "",
    val lowPct: Int = 0,
    val off: String = "",
    val boost: Int = 0
)

data class AutoApp(val pkg: String, val cat: String, val installed: Boolean, val own: Boolean, val profile: String)
data class AutoRecent(val pkg: String, val t: Long)
data class AutoStatusNow(val cat: String, val prof: String, val fg: String, val boostEnd: Long, val lvl: Int, val screen: Boolean, val charging: Boolean, val pkg: String)

data class PadState(
    val on: Boolean = false,
    val alive: Boolean = false,
    val connected: Boolean = false,
    val qos: Boolean = false,
    val qosDev: Boolean = false,
    val name: String = "",
    val transport: String = "",
    val event: String = ""
)

data class PadOpt(val hz: Boolean = false, val wifi: Boolean = false, val qos: Int = 0, val maxHz: Int = 0)
data class PadTest(val t: Long, val mode: Boolean, val transport: String, val hz: Int, val avg: Int, val max: Int, val pc: Int, val name: String)
data class PadScan(val name: String, val transport: String, val event: String, val vid: String, val recommended: Boolean, val why: String)

data class ManualState(
    val on: Boolean = false,
    val has: Boolean = false,
    val perf: Int = 0,
    val prime: Int = 0,
    val gpu: Int = 0,
    val hl: Int = 0,
    val cpl: Int = 0,
    val swap: Int = 0,
    val gpuFloor: Int = 0,
    val gpuFree: Int = 0
)

data class TuneState(
    val net: Boolean = false,
    val io: Boolean = false,
    val dns: String = "",
    val anim: Boolean = false,
    val scan: Boolean = false,
    val cc: String = "",
    val bbr: Boolean = false,
    val ra: String = ""
)

data class MaintState(val on: Boolean = false, val last: Long = 0, val running: Boolean = false, val result: List<String> = emptyList())
data class Session(val t: Long, val dur: Long, val pkg: String, val b0: Int, val b1: Int, val cpuC: Float, val batC: Float, val skinC: Float, val rises: Int, val prof: String, val pad: Boolean, val btFast: Boolean, val ma: Int, val charging: Boolean)
data class Conflict(val level: String, val con: String, val msg: String, val fix: String)
data class InfoState(val ramPct: Int = 0, val ramMb: Int = 0, val batPct: Int = 0, val batTempC: Float = 0f, val cpuTempC: Float = 0f, val currentMa: String = "", val cycles: Int = 0, val charging: String = "", val diskPct: Int = 0, val diskGb: Int = 0)

data class MaxGState(
    val device: DeviceInfo = DeviceInfo(),
    val profile: String = "stock",
    val safe: Boolean = false,
    val bootCount: Int = 0,
    val govCur: String = "",
    val govList: List<String> = emptyList(),
    val govCfg: String = "none",
    val gpu: GpuState = GpuState(),
    val romLimits: List<RomLimit> = emptyList(),
    val gpuMode: String = "auto",
    val gpuMaxPct: Int = 100,
    val gpuScope: String = "always",
    val cpuCaps: Map<String, Int> = emptyMap(),
    val heat: HeatState = HeatState(),
    val heatX: HeatX = HeatX(),
    val bt: BtState = BtState(),
    val btPrio: Boolean = false,
    val btScan: Boolean = false,
    val btNice: String = "-",
    val auto: AutoState = AutoState(),
    val autoNow: AutoStatusNow? = null,
    val autoApps: List<AutoApp> = emptyList(),
    val autoRecent: List<AutoRecent> = emptyList(),
    val autoBoostMethod: String = "",
    val autoBoostDesc: Boolean = false,
    val autoMboost: Int = 0,
    val pad: PadState = PadState(),
    val padOpt: PadOpt = PadOpt(),
    val padTests: List<PadTest> = emptyList(),
    val padScan: List<PadScan> = emptyList(),
    val manual: ManualState = ManualState(),
    val tune: TuneState = TuneState(),
    val maint: MaintState = MaintState(),
    val deluxe: Map<String, Boolean> = emptyMap(),
    val sessions: List<Session> = emptyList(),
    val plans: Map<String, ProfilePlan> = emptyMap(),
    val customProfiles: List<Pair<String, String>> = emptyList(),
    val freqs: Map<String, List<Int>> = emptyMap(),
    val conflicts: Map<String, Pair<String, String>> = emptyMap(),
    val info: InfoState = InfoState()
) {
    companion object {
        /** Descripciones de los 12 perfiles, iguales que en la WebUI. */
        val PROFILES = listOf(
            Triple("minimo", "Mín.", "Lo más bajo que permite el módulo: CPU y GPU casi al piso. El teléfono se siente lento; para estirar la batería al máximo (lectura, esperar una llamada)."),
            Triple("ultra", "Ultra", "CPU a ~1 GHz y GPU al mínimo. Chat, música y lectura gastando muy poco."),
            Triple("profundo", "Prof.", "Un escalón bajo «Ahorro fuerte»: núcleos a 1.4 GHz y GPU a 330 MHz. Redes, chat y video sin gastar de más."),
            Triple("ahorro", "Ahorro", "Topes muy bajos que todavía se sienten usables. Para pantalla apagada o batería crítica."),
            Triple("bateria", "Batería", "Topes bajos y subida tardía de frecuencia. Menos calor y más autonomía."),
            Triple("eco", "Eco", "Un punto medio entre batería y fluidez: redes, chat y video sin gastar de más."),
            Triple("juego", "Juego", "Frecuencias estables para jugar mucho tiempo sin que el calor te baje los fps."),
            Triple("medio", "Medio", "Fluido para casi todo, con margen para juegos ligeros. Calienta poco."),
            Triple("diario", "Fluido", "Para el día a día: respuesta inmediata sin los picos de frecuencia que solo calientan."),
            Triple("rendfresco", "Rend.", "Casi todo el rendimiento de tu chip, cortando el último tramo, que es el que más calienta."),
            Triple("alto", "Alto", "Apenas un 2-4 % por debajo del máximo: ideal para juegos pesados sin el pico final."),
            Triple("maximo", "Máx.", "Sin topes y con subida temprana de frecuencia. Para benchmarks o ratos cortos. Calienta.")
        )
        val HEAT_MODES = listOf("off", "suave", "normal", "estricto")
        val HEAT_MODE_NAMES = mapOf("off" to "Apagado", "suave" to "Suave", "normal" to "Normal", "estricto" to "Estricto")

        fun parse(out: String): MaxGState {
            var device = DeviceInfo()
            var profile = "stock"; var safe = false; var bootCount = 0
            var govCur = ""; var govList = emptyList<String>(); var govCfg = "none"
            var gpu = GpuState()
            var romLimits = emptyList<RomLimit>()
            var gpuMode = "auto"; var gpuMaxPct = 100; var gpuScope = "always"
            val cpuCaps = mutableMapOf<String, Int>()
            var heat = HeatState(); var heatX = HeatX()
            var bt = BtState(); var btPrio = false; var btScan = false; var btNice = "-"
            var auto = AutoState(); var autoNow: AutoStatusNow? = null
            val autoApps = mutableListOf<AutoApp>()
            val autoRecent = mutableListOf<AutoRecent>()
            var autoMboost = 0; var autoBoostMethod = ""; var autoBoostDesc = false
            var pad = PadState(); var padOpt = PadOpt()
            val padTests = mutableListOf<PadTest>()
            val padScan = mutableListOf<PadScan>()
            var manual = ManualState()
            var tune = TuneState(); var maint = MaintState()
            val deluxe = mutableMapOf<String, Boolean>()
            val sessions = mutableListOf<Session>()
            val plans = mutableMapOf<String, ProfilePlan>()
            val customProfiles = mutableListOf<Pair<String, String>>()
            val freqs = mutableMapOf<String, List<Int>>()
            val conflicts = mutableMapOf<String, Pair<String, String>>()
            var info = InfoState()

            for (raw in out.lines()) {
                val l = raw.trimEnd('\r')
                if (l.isEmpty()) continue
                val f = l.split('|')
                when (f[0]) {
                    "DEV" -> device = if (f.getOrNull(1) == "1") DeviceInfo(true, f.getOrElse(2) { "" }, f.getOrElse(3) { "" }, f.getOrElse(4) { "" }) else DeviceInfo(false, f.getOrElse(2) { "" }, why = f.getOrElse(3) { "" })
                    "CFG" -> { profile = f.getOrElse(1) { "stock" }; safe = f.getOrElse(2) { "0" } == "1"; bootCount = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0 }
                    "GOV" -> { govCur = f.getOrElse(1) { "" }; govList = f.getOrElse(2) { "" }.split(',').filter { it.isNotEmpty() }; govCfg = f.getOrElse(3) { "none" } }
                    "GPUCFG" -> gpu = GpuState(
                        floor = f.getOrElse(1) { "0" }.toIntOrNull() ?: 0,
                        free = f.getOrElse(2) { "0" } == "1",
                        alive = f.getOrElse(3) { "0" } == "1",
                        target = f.getOrElse(4) { "0" }.toIntOrNull() ?: 0,
                        table = f.getOrElse(9) { "" }.split(',').mapNotNull { it.toIntOrNull() },
                        level = f.getOrElse(6) { "" },
                        clk = f.getOrElse(7) { "0" }.toIntOrNull() ?: 0,
                        cap = f.getOrElse(8) { "0" }.toIntOrNull() ?: 0,
                        be = f.getOrElse(10) { "" },
                        um = f.getOrElse(11) { "0" }.toIntOrNull() ?: 0,
                        rm = f.getOrElse(12) { "0" }.toIntOrNull() ?: 0,
                        rl = f.getOrElse(13) { "0" }.toIntOrNull() ?: 0
                    )
                    "ROMLIM" -> romLimits = f.getOrElse(1) { "" }.split(',').filter { it.isNotEmpty() }.mapNotNull { x ->
                        val m = Regex("^(.*)=(\\d+)/(\\d+)$").find(x) ?: return@mapNotNull null
                        RomLimit(m.groupValues[1], m.groupValues[2].toIntOrNull() ?: 0, m.groupValues[3].toIntOrNull() ?: 0)
                    }
                    "GPUMODE" -> { gpuMode = f.getOrElse(1) { "auto" }; gpuMaxPct = f.getOrElse(2) { "100" }.toIntOrNull() ?: 100 }
                    "GPUSC" -> gpuScope = f.getOrElse(1) { "always" }
                    "CPUCAP" -> cpuCaps[f.getOrElse(1) { "" }] = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0
                    "HEAT" -> heat = HeatState(
                        mode = f.getOrElse(1) { "off" },
                        level = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0,
                        points = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0,
                        cpuC = (f.getOrElse(4) { "0" }.toIntOrNull() ?: 0) / 10f,
                        batC = (f.getOrElse(5) { "0" }.toIntOrNull() ?: 0) / 10f,
                        screen = f.getOrElse(6) { "0" } == "1",
                        alive = f.getOrElse(7) { "0" } == "1",
                        skinC = (f.getOrElse(8) { "0" }.toIntOrNull() ?: 0) / 10f
                    )
                    "HTX" -> heatX = HeatX(
                        ant = f.getOrElse(1) { "0" } == "1",
                        burst = f.getOrElse(2) { "off" },
                        antOn = f.getOrElse(3) { "0" } == "1",
                        burstOn = f.getOrElse(4) { "0" } == "1",
                        pc = f.getOrElse(5) { "0" }.toIntOrNull() ?: 0,
                        pg = f.getOrElse(6) { "0" }.toIntOrNull() ?: 0
                    )
                    "BT" -> bt = BtState(
                        fast = f.getOrElse(1) { "0" } == "1",
                        min = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0,
                        max = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0,
                        lat = f.getOrElse(4) { "" },
                        timeout = f.getOrElse(5) { "" },
                        on = f.getOrElse(6) { "0" } == "1"
                    )
                    "BTP" -> { btPrio = f.getOrElse(1) { "0" } == "1"; btScan = f.getOrElse(2) { "0" } == "1"; btNice = f.getOrElse(3) { "-" } }
                    "AUTOCFG" -> auto = AutoState(
                        on = f.getOrElse(1) { "0" } == "1",
                        alive = f.getOrElse(2) { "0" } == "1",
                        game = f.getOrElse(3) { "" },
                        maps = f.getOrElse(4) { "" },
                        low = f.getOrElse(5) { "" },
                        lowPct = f.getOrElse(6) { "0" }.toIntOrNull() ?: 0,
                        off = f.getOrElse(7) { "" },
                        boost = f.getOrElse(8) { "0" }.toIntOrNull() ?: 0
                    )
                    "AUTOST" -> autoNow = AutoStatusNow(
                        cat = f.getOrElse(1) { "" }, prof = f.getOrElse(2) { "" },
                        fg = f.getOrElse(3) { "" }, boostEnd = f.getOrElse(4) { "0" }.toLongOrNull() ?: 0,
                        lvl = f.getOrElse(5) { "0" }.toIntOrNull() ?: 0,
                        screen = f.getOrElse(6) { "0" } == "1",
                        charging = f.getOrElse(7) { "0" } == "1",
                        pkg = f.getOrElse(8) { "" }
                    )
                    "AUTOAPP" -> autoApps.add(AutoApp(f.getOrElse(1) { "" }, f.getOrElse(2) { "" }, f.getOrElse(3) { "0" } == "1", f.getOrElse(4) { "0" } == "1", f.getOrElse(5) { "" }))
                    "AUTOREC" -> autoRecent.add(AutoRecent(f.getOrElse(1) { "" }, f.getOrElse(2) { "0" }.toLongOrNull() ?: 0))
                    "AUTOX" -> { autoMboost = f.getOrElse(1) { "0" }.toIntOrNull() ?: 0; autoBoostMethod = f.getOrElse(2) { "" }; autoBoostDesc = f.getOrElse(3) { "0" } != "0" }
                    "PADCFG" -> pad = PadState(
                        on = f.getOrElse(1) { "0" } == "1", alive = f.getOrElse(2) { "0" } == "1",
                        connected = f.getOrElse(3) { "0" } == "1", qos = f.getOrElse(4) { "0" } == "1",
                        qosDev = f.getOrElse(5) { "0" } == "1", name = f.getOrElse(6) { "" },
                        transport = f.getOrElse(7) { "" }, event = f.getOrElse(8) { "" }
                    )
                    "PADOPT" -> padOpt = PadOpt(
                        hz = f.getOrElse(1) { "0" } == "1", wifi = f.getOrElse(2) { "0" } == "1",
                        qos = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0,
                        maxHz = f.getOrElse(4) { "0" }.toIntOrNull() ?: 0
                    )
                    "PADTEST" -> padTests.add(PadTest(
                        t = f.getOrElse(1) { "0" }.toLongOrNull() ?: 0,
                        mode = f.getOrElse(2) { "0" } == "1",
                        transport = f.getOrElse(3) { "" },
                        hz = f.getOrElse(4) { "0" }.toIntOrNull() ?: 0,
                        avg = f.getOrElse(5) { "0" }.toIntOrNull() ?: 0,
                        max = f.getOrElse(6) { "0" }.toIntOrNull() ?: 0,
                        pc = f.getOrElse(7) { "0" }.toIntOrNull() ?: 0,
                        name = f.getOrElse(8) { "" }
                    ))
                    "PADSCAN" -> padScan.add(PadScan(f.getOrElse(1) { "" }, f.getOrElse(2) { "" }, f.getOrElse(3) { "" }, f.getOrElse(4) { "" }, f.getOrElse(5) { "0" } == "1", f.getOrElse(6) { "" }))
                    "MANUAL" -> manual = ManualState(
                        on = f.getOrElse(1) { "0" } == "1", has = f.getOrElse(2) { "0" } == "1",
                        perf = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0,
                        prime = f.getOrElse(4) { "0" }.toIntOrNull() ?: 0,
                        gpu = f.getOrElse(5) { "0" }.toIntOrNull() ?: 0,
                        hl = f.getOrElse(6) { "0" }.toIntOrNull() ?: 0,
                        cpl = f.getOrElse(7) { "0" }.toIntOrNull() ?: 0,
                        swap = f.getOrElse(8) { "0" }.toIntOrNull() ?: 0,
                        gpuFloor = f.getOrElse(9) { "0" }.toIntOrNull() ?: 0,
                        gpuFree = f.getOrElse(10) { "0" }.toIntOrNull() ?: 0
                    )
                    "TUNE" -> tune = TuneState(
                        net = f.getOrElse(1) { "0" } == "1", io = f.getOrElse(2) { "0" } == "1",
                        dns = f.getOrElse(3) { "" }, anim = f.getOrElse(4) { "0" } == "1",
                        scan = f.getOrElse(5) { "0" } == "1", cc = f.getOrElse(6) { "" },
                        bbr = f.getOrElse(7) { "0" } == "1", ra = f.getOrElse(8) { "" }
                    )
                    "MAINT" -> maint = MaintState(
                        on = f.getOrElse(1) { "0" } == "1",
                        last = f.getOrElse(2) { "0" }.toLongOrNull() ?: 0,
                        running = f.getOrElse(3) { "0" } == "1",
                        result = f.drop(4)
                    )
                    "DLX" -> f.drop(1).forEach { x ->
                        val kv = x.split(':')
                        if (kv.size == 2) deluxe[kv[0]] = kv[1] == "1"
                    }
                    "SESS" -> sessions.add(Session(
                        t = f.getOrElse(1) { "0" }.toLongOrNull() ?: 0,
                        dur = f.getOrElse(2) { "0" }.toLongOrNull() ?: 0,
                        pkg = f.getOrElse(3) { "" },
                        b0 = f.getOrElse(4) { "0" }.toIntOrNull() ?: 0,
                        b1 = f.getOrElse(5) { "0" }.toIntOrNull() ?: 0,
                        cpuC = (f.getOrElse(6) { "0" }.toIntOrNull() ?: 0) / 10f,
                        batC = (f.getOrElse(7) { "0" }.toIntOrNull() ?: 0) / 10f,
                        skinC = (f.getOrElse(8) { "0" }.toIntOrNull() ?: 0) / 10f,
                        rises = f.getOrElse(9) { "0" }.toIntOrNull() ?: 0,
                        prof = f.getOrElse(10) { "" },
                        pad = f.getOrElse(11) { "0" } == "1",
                        btFast = f.getOrElse(12) { "0" } == "1",
                        ma = f.getOrElse(13) { "0" }.toIntOrNull() ?: 0,
                        charging = f.getOrElse(14) { "0" } == "1"
                    ))
                    "PLAN" -> {
                        val id = f.getOrElse(1) { "" }
                        val prev = plans[id]
                        plans[id] = (prev ?: ProfilePlan(id)).copy(
                            perf = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0,
                            prime = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0,
                            gpu = f.getOrElse(4) { "0" }.toIntOrNull() ?: 0
                        )
                    }
                    "PCT" -> {
                        val id = f.getOrElse(1) { "" }
                        val prev = plans[id]
                        plans[id] = (prev ?: ProfilePlan(id)).copy(
                            perf = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0,
                            prime = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0,
                            gpu = f.getOrElse(4) { "0" }.toIntOrNull() ?: 0,
                            hl = f.getOrElse(5) { "0" }.toIntOrNull() ?: 0,
                            cpl = f.getOrElse(6) { "0" }.toIntOrNull() ?: 0,
                            swap = f.getOrElse(7) { "0" }.toIntOrNull() ?: 0
                        )
                    }
                    "HZP" -> {
                        val id = f.getOrElse(1) { "" }
                        val prev = plans[id]
                        plans[id] = (prev ?: ProfilePlan(id)).copy(hz = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0)
                    }
                    "CUSTOM" -> customProfiles.add(f.getOrElse(1) { "" } to f.drop(2).joinToString("|"))
                    "FREQ" -> freqs[f.getOrElse(1) { "" }] = f.getOrElse(2) { "" }.split(',').mapNotNull { it.toIntOrNull() }
                    "WHO" -> conflicts[f.getOrElse(1) { "" }] = f.getOrElse(2) { "" } to f.drop(3).joinToString("|")
                    "I" -> when (f.getOrElse(1) { "" }) {
                        "ram" -> info = info.copy(ramPct = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0, ramMb = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0)
                        "bat" -> info = info.copy(batPct = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0, batTempC = (f.getOrElse(3) { "0" }.toIntOrNull() ?: 0) / 10f)
                        "cpu" -> info = info.copy(cpuTempC = (f.getOrElse(2) { "0" }.toIntOrNull() ?: 0) / 10f)
                        "cur" -> info = info.copy(currentMa = f.getOrElse(2) { "" })
                        "cyc" -> info = info.copy(cycles = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0)
                        "chg" -> info = info.copy(charging = f.getOrElse(2) { "" })
                        "disk" -> info = info.copy(diskPct = f.getOrElse(2) { "0" }.toIntOrNull() ?: 0, diskGb = f.getOrElse(3) { "0" }.toIntOrNull() ?: 0)
                    }
                }
            }
            return MaxGState(
                device = device, profile = profile, safe = safe, bootCount = bootCount,
                govCur = govCur, govList = govList, govCfg = govCfg, gpu = gpu,
                romLimits = romLimits, gpuMode = gpuMode, gpuMaxPct = gpuMaxPct,
                gpuScope = gpuScope, cpuCaps = cpuCaps, heat = heat, heatX = heatX,
                bt = bt, btPrio = btPrio, btScan = btScan, btNice = btNice,
                auto = auto, autoNow = autoNow, autoApps = autoApps,
                autoRecent = autoRecent, autoMboost = autoMboost,
                autoBoostMethod = autoBoostMethod, autoBoostDesc = autoBoostDesc,
                pad = pad, padOpt = padOpt, padTests = padTests, padScan = padScan,
                manual = manual, tune = tune, maint = maint, deluxe = deluxe,
                sessions = sessions, plans = plans, customProfiles = customProfiles,
                freqs = freqs, conflicts = conflicts, info = info
            )
        }
    }
}
