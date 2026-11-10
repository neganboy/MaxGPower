# MaxG Power

App con root para el **Poco F8 Pro (Snapdragon 8 Elite)** con los perfiles manuales de energía y rendimiento y el modo mando de baja latencia del módulo MaxG Power, ahora con interfaz nativa de Android.

> ⚠️ **Solo para el Poco F8 Pro (annibale). No es para ningún otro modelo**, aunque podría funcionar en otros teléfonos con el mismo chip, sin ninguna garantía.
>
> ⚠️ **Para ROMs AOSP.** Probado en AOSP con Android 16 (kernel 6.6.77). En otros modelos la app se instala, pero los perfiles **no se aplican**: la comprobación del dispositivo los bloquea.

- 12 perfiles: mínimo, ultra, profundo, ahorro, batería, eco, juego, medio, diario, rendfresco, alto y máximo
- Gobernador de CPU, control manual, GPU (modo, tope, piso), control de calor, modo inteligente (Auto) y modo mando
- **Guardián térmico (v1.5):** 7 niveles finos con objetivo de temperatura editable por perfil (30-45 °C), sensores de batería, carcasa y chip, y piso de nivel con la pantalla apagada
- **Vigilante de topes (v1.5):** si la ROM u otra app sube un tope por encima del perfil, lo devuelve al instante
- **Apps en segundo plano (v1.5):** lista editable de apps restringidas (sin ejecución en segundo plano, en espera «rare» o fuera de Doze)
- **I/O, memoria y scheduler por perfil (v1.5):** lectura anticipada, peticiones y presión de caché según el perfil; ajustes del scheduler al arrancar
- **Red TCP (v1.5):** mejor algoritmo disponible (bbr3/bbr2/bbrplus/bbr/…), sack y baja latencia, con interruptor propio
- **Actualizaciones dentro de la app (v1.6, mejorado en v1.7 y v1.8):** revisa GitHub Releases, descarga la APK y la instala desde la app (verifica paquete y firma antes de instalar); si la API no conecta, usa la página de releases como respaldo; si falla, muestra una prueba de conexión (red, DNS y página) con el motivo exacto
- Sonda de diagnóstico, detector de conflictos y modo seguro
- Interfaz nativa (Jetpack Compose + Material 3). Nada de WebView.

## Requisitos

- **Poco F8 Pro (annibale)** con **ROM AOSP** (probado en Android 16)
- Root con **KernelSU Next**
- Android 8 o superior

## Instalación

Descarga la APK desde [Releases](../../releases), instálala y otorga el permiso de root en KernelSU Next. La app aplica tu perfil al encender el teléfono y mantiene un supervisor en segundo plano.

> La app reemplaza al módulo de KernelSU: no uses los dos a la vez, se pelean por los mismos ajustes. Al abrir la app por primera vez te ofrece desactivar el módulo.

## Compilar desde el código

Necesitas JDK 17, Android SDK 36 y Gradle 8.13:

```bash
bash ../build.sh debug     # APK de prueba
bash ../build.sh release   # APK firmada (necesita las claves en ~/.gradle/gradle.properties)
```

## Licencia

MIT — © 2026 neganboy
