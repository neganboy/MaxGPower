package com.neganboy.maxgpower

/**
 * Cliente nativo contra ctl.sh del módulo. Habla su protocolo de texto:
 *   - `ctl.sh state full|live|more|static` -> líneas SECT|... que se
 *     convierten en MaxGState (ver MaxGState.parse).
 *   - `ctl.sh <comando> ...` -> RESULT|cmd|ok|detalle (o texto libre).
 * Todo se ejecuta como root a través de RootShell.
 */
object CtlClient {

    private val bin get() = ScriptsInstaller.BIN_DIR

    data class CmdResult(val ok: Boolean, val detail: String, val raw: String)

    /** Escapa un argumento para sh (igual que el q() de la WebUI). */
    private fun q(s: String): String = "'" + s.replace("'", "'\\''") + "'"

    fun run(vararg args: String): String {
        val cmd = "sh " + q("$bin/ctl.sh") + " " + args.joinToString(" ") { q(it) }
        return RootShell.exec(cmd).out
    }

    fun runRaw(cmd: String): String = RootShell.exec(cmd).out

    fun state(kind: String = "full"): MaxGState = MaxGState.parse(run("state", kind))

    /**
     * Ejecuta `state <kind>`; null si no llegó ninguna sección SECT|
     * (ctl.sh no respondió). Evita que un vacío borre el estado bueno.
     */
    fun stateOrNull(kind: String = "full"): MaxGState? {
        val out = run("state", kind)
        return if (out.contains("SECT|")) MaxGState.parse(out) else null
    }

    fun info(): MaxGState = MaxGState.parse(run("info"))

    /** Ejecuta un comando y extrae el RESULT|... si lo hay. */
    fun cmd(vararg args: String): CmdResult {
        val out = run(*args)
        val m = Regex("RESULT\\|([^|]*)\\|([^|]*)\\|(.*)", RegexOption.DOT_MATCHES_ALL).find(out)
        return if (m != null) {
            CmdResult(m.groupValues[2] == "ok", m.groupValues[3].trim(), out)
        } else {
            CmdResult(out.isNotBlank(), out.trim(), out)
        }
    }

    fun applyProfile(id: String) = cmd("profile", id)
    fun setGov(gov: String) = cmd("gov", gov)
    fun gpuFloor(mhz: Int) = cmd("gpu", "floor", mhz.toString())
    fun gpuFree(on: Boolean) = cmd("gpu", "free", if (on) "on" else "off")
    fun gpuMode(mode: String) = cmd("gpu", "mode", mode)
    fun gpuManual(pct: Int) = cmd("gpu", "manual", pct.toString())
    fun gpuScope(scope: String) = cmd("gpu", "scope", scope)
    fun gpuOff() = cmd("gpu", "off")
    fun heatMode(mode: String) = cmd("heat", "mode", mode)
    fun heatTgt(profile: String, temp: Int) = cmd("heat", "tgt", profile, temp.toString())
    fun heatAnt(on: Boolean) = cmd("heat", "ant", if (on) "on" else "off")
    fun heatBurst(v: String) = cmd("heat", "burst", v)
    fun heatScreen(on: Boolean) = cmd("heat", "screen", if (on) "1" else "0")
    fun watchOn() = cmd("watch", "on")
    fun watchOff() = cmd("watch", "off")
    fun bgappsAdd(pkg: String) = cmd("bgapps", "add", pkg)
    fun bgappsDel(pkg: String) = cmd("bgapps", "del", pkg)
    fun padOn() = cmd("pad", "on")
    fun padOff() = cmd("pad", "off")
    fun padTest(seconds: Int = 5) = cmd("pad", "test", seconds.toString())
    fun padQos(us: Int) = cmd("pad", "qos", us.toString())
    fun padOpt(key: String, value: String) = cmd("pad", "opt", key, value)
    fun padDump() = cmd("pad", "dump")
    fun padScan() = run("pad", "scan")
    fun autoOn() = cmd("auto", "on")
    fun autoOff() = cmd("auto", "off")
    fun autoSet(key: String, value: String) = cmd("auto", "set", key, value)
    fun autoAppAdd(pkg: String, cat: String, profile: String) = cmd("auto", "app", "add", pkg, cat, profile)
    fun autoAppDel(pkg: String) = cmd("auto", "app", "del", pkg)
    fun btFast(on: Boolean) = cmd("bt", "fast", if (on) "on" else "off")
    fun btPrio(v: String) = cmd("bt", "prio", v)
    fun btRestart() = cmd("bt", "restart")
    fun tuneSet(key: String, value: String) = cmd("tune", key, value)
    fun maintOn() = cmd("maint", "on")
    fun maintOff() = cmd("maint", "off")
    fun maintNow() = cmd("maint", "now")
    fun deluxeOn() = cmd("deluxe", "on")
    fun safeClear() = cmd("safe", "clear")
    fun reapply() = run("reapply")
    fun log(lines: Int = 60): String = run("log", lines.toString())
    fun conflictsScan(): List<Conflict> {
        val out = run("conflicts", "scan")
        val items = mutableListOf<Conflict>()
        for (l in out.lines()) {
            val f = l.split('|')
            if (f[0] == "CONFLICT" && f.size >= 4) {
                items.add(Conflict(f[1], f[2], f[3], f.getOrElse(4) { "" }))
            }
        }
        return items
    }
    fun report(): CmdResult = cmd("report")
    fun sondaFindings(): String = run("sonda", "findings")
    fun sondaList(): String = run("sonda", "list")
    fun sondaShow(name: String): String = run("sonda", "show", name)
    fun sondaPerf() = cmd("sonda", "perf")
    fun sondaHw() = cmd("sonda", "hw")
    fun sondaDeep() = cmd("sonda", "deep")
    fun sondaUse(seconds: Int) = cmd("sonda", "use", seconds.toString())
    fun sessClear() = cmd("sess", "clear")
    fun manualOn() = cmd("manual", "on")
    fun manualOff() = cmd("manual", "off")
    fun manualSet(perf: Int, prime: Int, gpu: Int, hl: Int, cpl: Int, swap: Int) =
        cmd("manual", "set", perf.toString(), prime.toString(), gpu.toString(), hl.toString(), cpl.toString(), swap.toString())
    fun customSave(id: String, name: String, perf: Int, prime: Int, gpu: Int, hl: Int, cpl: Int, swap: Int) =
        cmd("custom", "save", id, name, perf.toString(), prime.toString(), gpu.toString(), hl.toString(), cpl.toString(), swap.toString())
    fun customDel(id: String) = cmd("custom", "del", id)
    fun revertAll(): String {
        // Lo que hacía uninstall.sh del módulo: detener vigilantes y devolver todo.
        return RootShell.exec("sh ${q("$bin/uninstall.sh")}").out
    }
}
