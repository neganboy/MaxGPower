package com.neganboy.maxgpower

import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/**
 * Ejecuta comandos como root (su). Todo MaxG pasa por aquí:
 * la WebUI llama a ctl.sh y el servicio de arranque corre service.sh.
 */
object RootShell {

    data class Result(val code: Int, val out: String, val err: String)

    /** Ejecuta un comando con tiempo límite. Devuelve código, stdout y stderr. */
    fun exec(cmd: String, timeoutMs: Long = 45_000): Result {
        return try {
            val proc = ProcessBuilder("su", "-c", cmd)
                .redirectErrorStream(false)
                .start()
            val outSb = StringBuilder()
            val errSb = StringBuilder()
            val outT = Thread { readInto(proc.inputStream, outSb) }.also { it.start() }
            val errT = Thread { readInto(proc.errorStream, errSb) }.also { it.start() }
            val finished = proc.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
            if (!finished) {
                proc.destroyForcibly()
                outT.join(500); errT.join(500)
                return Result(124, outSb.toString(), "tiempo de espera agotado")
            }
            outT.join(2000); errT.join(2000)
            Result(proc.exitValue(), outSb.toString(), errSb.toString())
        } catch (e: Exception) {
            Result(-1, "", e.message ?: "error al ejecutar su")
        }
    }

    /** Inicia un comando sin tiempo límite (para service.sh, que vive siempre). */
    fun startLong(cmd: String): Process? {
        return try {
            ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        } catch (e: Exception) {
            null
        }
    }

    /** ¿Tenemos root? */
    fun hasRoot(): Boolean {
        val r = exec("id")
        return r.code == 0 && r.out.contains("uid=0")
    }

    private fun readInto(stream: java.io.InputStream, sb: StringBuilder) {
        try {
            BufferedReader(InputStreamReader(stream)).use { br ->
                val buf = CharArray(4096)
                var n: Int
                while (br.read(buf).also { n = it } >= 0) {
                    sb.append(buf, 0, n)
                }
            }
        } catch (_: Exception) {
        }
    }
}
