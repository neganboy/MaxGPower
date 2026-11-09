# MaxG Power

App con root para el Poco F8 Pro (Snapdragon 8 Elite) con los perfiles manuales de energía y rendimiento y el modo mando de baja latencia del módulo MaxG Power, ahora con interfaz nativa de Android.

- 12 perfiles: mínimo, ultra, profundo, ahorro, batería, eco, juego, medio, diario, rendfresco, alto y máximo
- Gobernador de CPU, control manual, GPU (modo, tope, piso), control de calor, modo inteligente (Auto) y modo mando
- Sonda de diagnóstico, detector de conflictos y modo seguro
- Interfaz nativa (Jetpack Compose + Material 3). Nada de WebView.

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
