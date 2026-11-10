package com.neganboy.maxgpower

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.security.MessageDigest

/**
 * Actualizaciones desde GitHub Releases.
 *
 *   1. Revisar: la API pública de GitHub dice cuál es el último release
 *      (versión, cambios y enlace de la APK). El repo es público: no hace
 *      falta cuenta ni token (60 consultas por hora sin autenticar).
 *      Si la API no conecta, hay un respaldo: la página de releases
 *      redirige a la última versión y de ahí sale el enlace de descarga.
 *   2. Descargar: la APK baja a la caché de la app, con progreso.
 *   3. Verificar: la APK tiene que ser de MaxG Power y estar firmada con
 *      la misma llave que la app instalada. El instalador de Android
 *      también lo exige, pero se revisa antes de abrirlo.
 *   4. Instalar: se abre el instalador de Android y el usuario confirma.
 *      La primera vez Android pide permitir "instalar apps desconocidas"
 *      para MaxG Power (una sola vez, en ajustes).
 */
object AppUpdater {

    private const val REPO = "neganboy/MaxGPower"
    private const val API_LATEST = "https://api.github.com/repos/$REPO/releases/latest"

    data class ReleaseInfo(
        val version: String,
        val notes: String,
        val apkUrl: String,
        val apkName: String,
        val sizeBytes: Long
    )

    sealed class CheckResult {
        data class Available(val release: ReleaseInfo) : CheckResult()
        data object UpToDate : CheckResult()
        data class Error(val message: String) : CheckResult()
    }

    /** Compara dos versiones "1.5" / "1.6.1": >0 si a es más nueva que b. */
    fun compareVersions(a: String, b: String): Int {
        val pa = a.split('.').map { it.filter { c -> c.isDigit() }.toIntOrNull() ?: 0 }
        val pb = b.split('.').map { it.filter { c -> c.isDigit() }.toIntOrNull() ?: 0 }
        val n = maxOf(pa.size, pb.size)
        for (i in 0 until n) {
            val d = (pa.getOrElse(i) { 0 }) - (pb.getOrElse(i) { 0 })
            if (d != 0) return d
        }
        return 0
    }

    fun installedVersion(context: Context): String {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        return info.versionName ?: "0"
    }

    /** Lee el último release de GitHub y dice si hay una versión más nueva que la instalada. */
    suspend fun checkLatest(context: Context): CheckResult = withContext(Dispatchers.IO) {
        val apiError = try {
            return@withContext checkViaApi(context)
        } catch (e: Exception) {
            e
        }
        // La API no conectó: segundo intento por la página de releases
        // (otro servidor, sin límite de consultas): redirige a la última versión.
        try {
            return@withContext checkViaRedirect(context)
        } catch (e: Exception) {
            return@withContext CheckResult.Error(
                "Sin conexión a GitHub: ${describe(apiError)} (el respaldo tampoco conectó: ${describe(e)})"
            )
        }
    }

    /** Qué pasó, en palabras simples, para mostrarlo si la revisión falla. */
    private fun describe(e: Exception): String = when (e) {
        is java.net.UnknownHostException -> "no se encontró el servidor"
        is java.net.ConnectException -> "no se pudo conectar"
        is java.net.SocketTimeoutException -> "tardó demasiado en responder"
        is javax.net.ssl.SSLException -> "problema de seguridad con la conexión"
        is IOException -> e.message ?: "error de red"
        else -> e.message ?: "error desconocido"
    }

    /** Revisión por la API pública de GitHub (trae versión, cambios y enlace de la APK). */
    private fun checkViaApi(context: Context): CheckResult {
        val json = JSONObject(get(API_LATEST))
        val tag = json.optString("tag_name", "").trim().removePrefix("v")
        if (tag.isEmpty()) throw IOException("GitHub no devolvió versión")
        val current = installedVersion(context)
        if (compareVersions(tag, current) <= 0) return CheckResult.UpToDate
        val assets = json.optJSONArray("assets")
        var apkUrl = ""
        var apkName = "MaxGPower.apk"
        var size = 0L
        if (assets != null) {
            for (i in 0 until assets.length()) {
                val a = assets.getJSONObject(i)
                if (a.optString("name", "").endsWith(".apk", ignoreCase = true)) {
                    apkUrl = a.optString("browser_download_url", "")
                    apkName = a.optString("name", apkName)
                    size = a.optLong("size", 0)
                    break
                }
            }
        }
        if (apkUrl.isEmpty()) throw IOException("El release $tag no trae APK")
        return CheckResult.Available(ReleaseInfo(tag, json.optString("body", ""), apkUrl, apkName, size))
    }

    /** Respaldo: la página de releases redirige a la última versión; el enlace de la APK se arma con el nombre que siempre se publica. */
    private fun checkViaRedirect(context: Context): CheckResult {
        val conn = (URL("https://github.com/$REPO/releases/latest").openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 15000
            setRequestProperty("User-Agent", "MaxGPower")
            instanceFollowRedirects = false
        }
        try {
            val code = conn.responseCode
            if (code !in 300..399) throw IOException("GitHub respondió $code")
            val loc = conn.getHeaderField("Location") ?: throw IOException("sin redirección")
            val tag = loc.substringAfterLast("/tag/", "").trim().removePrefix("v")
            if (tag.isEmpty()) throw IOException("no se leyó la versión")
            val current = installedVersion(context)
            if (compareVersions(tag, current) <= 0) return CheckResult.UpToDate
            val apkName = "MaxGPower-v$tag.apk"
            val apkUrl = "https://github.com/$REPO/releases/download/v$tag/$apkName"
            return CheckResult.Available(ReleaseInfo(tag, "", apkUrl, apkName, 0))
        } finally {
            conn.disconnect()
        }
    }

    private fun get(url: String): String {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 15000
            setRequestProperty("Accept", "application/vnd.github+json")
            setRequestProperty("User-Agent", "MaxGPower")
        }
        try {
            val code = conn.responseCode
            if (code != 200) throw IOException("GitHub respondió $code")
            return conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    /** Descarga la APK a la caché de la app. onProgress recibe 0..100. */
    suspend fun downloadApk(
        context: Context,
        release: ReleaseInfo,
        onProgress: (Int) -> Unit
    ): File = withContext(Dispatchers.IO) {
        val dir = File(context.cacheDir, "updates").apply { mkdirs() }
        val file = File(dir, release.apkName)
        val conn = (URL(release.apkUrl).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 30000
            setRequestProperty("User-Agent", "MaxGPower")
            instanceFollowRedirects = true
        }
        try {
            val code = conn.responseCode
            if (code != 200) throw IOException("La descarga respondió $code")
            val total = conn.contentLengthLong
            conn.inputStream.use { input ->
                FileOutputStream(file).use { out ->
                    val buf = ByteArray(64 * 1024)
                    var read: Int
                    var done = 0L
                    while (input.read(buf).also { read = it } != -1) {
                        out.write(buf, 0, read)
                        done += read
                        if (total > 0) onProgress(((done * 100) / total).toInt().coerceIn(0, 100))
                    }
                }
            }
            onProgress(100)
        } finally {
            conn.disconnect()
        }
        // La APK tiene que ser MaxG Power y estar firmada con la misma llave
        // que la app instalada (el instalador de Android también lo exige).
        val archive = context.packageManager.getPackageArchiveInfo(
            file.absolutePath, PackageManager.GET_SIGNING_CERTIFICATES
        ) ?: throw IOException("El archivo descargado no es una APK válida")
        if (archive.packageName != context.packageName) {
            throw IOException("Esa APK no es MaxG Power")
        }
        if (!sameSigner(context, archive)) {
            throw IOException("Esa APK no está firmada con la llave de MaxG Power")
        }
        file
    }

    /** ¿La APK descargada está firmada con la misma llave que la app instalada? */
    private fun sameSigner(context: Context, archive: PackageInfo): Boolean {
        return try {
            val pm = context.packageManager
            val installed = pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            val a = installed.signingInfo?.apkContentsSigners
                ?.map { sha256(it.toByteArray()) }?.toSet() ?: return false
            val b = archive.signingInfo?.apkContentsSigners
                ?.map { sha256(it.toByteArray()) }?.toSet() ?: return false
            a.intersect(b).isNotEmpty()
        } catch (_: Exception) {
            false
        }
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }

    /** ¿Android deja que MaxG Power instale APKs? Si no, hay que activarlo en ajustes (una sola vez). */
    fun canInstall(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    /** Resultado de la prueba de conexión: qué red hay, si Android la valida, si los nombres de GitHub resuelven y si la página responde. */
    data class NetDiag(
        val network: String,
        val internetValidated: Boolean,
        val dnsGithub: String,
        val dnsApi: String,
        val httpGithub: String
    )

    /** Prueba la conexión paso a paso, para saber si el problema es la red, el DNS o GitHub. */
    suspend fun diagnose(context: Context): NetDiag = withContext(Dispatchers.IO) {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val net = cm.activeNetwork
        val caps = net?.let { cm.getNetworkCapabilities(it) }
        val network = when {
            net == null -> "Sin red"
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "Wi-Fi"
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Datos móviles"
            else -> "Otra red"
        }
        val validated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        fun resolve(host: String): String = try {
            InetAddress.getByName(host).hostAddress ?: "?"
        } catch (e: Exception) {
            "no resolvió (${e.javaClass.simpleName})"
        }
        val http = try {
            val conn = (URL("https://github.com").openConnection() as HttpURLConnection).apply {
                connectTimeout = 10000
                readTimeout = 10000
                setRequestProperty("User-Agent", "MaxGPower")
                instanceFollowRedirects = true
            }
            try {
                "HTTP ${conn.responseCode}"
            } finally {
                conn.disconnect()
            }
        } catch (e: Exception) {
            "falló: ${describe(e)}"
        }
        NetDiag(network, validated, resolve("github.com"), resolve("api.github.com"), http)
    }

    fun unknownSourcesIntent(context: Context): Intent =
        Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
            .setData(Uri.parse("package:${context.packageName}"))

    /** Intent para instalar la APK descargada con el instalador de Android. */
    fun installIntent(context: Context, apk: File): Intent {
        val uri = FileProvider.getUriForFile(
            context, "${context.packageName}.fileprovider", apk
        )
        return Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }
}
