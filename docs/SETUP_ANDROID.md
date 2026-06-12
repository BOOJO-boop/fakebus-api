# Guía Android: construcción de APK y flujo básico de GitHub

Esta guía cubre cómo preparar y generar un APK para Android desde la terminal, así como cómo versionar los cambios y subirlos a GitHub.

## 1. Preparar el proyecto

1. Abre una terminal en la carpeta del proyecto.
2. Instala las dependencias de Flutter:

```bash
flutter pub get
```

3. Verifica que el SDK y el dispositivo estén listos:

```bash
flutter doctor
flutter devices
```

> Asegúrate de tener un emulador Android activo o un dispositivo físico conectado.

## 2. Ejecutar la app en Android

Para ejecutar la app en modo de desarrollo:

```bash
flutter run
```

Si quieres seleccionar un dispositivo específico:

```bash
flutter run -d <device-id>
```

## 3. Generar el APK de producción

Para crear un APK optimizado en modo release:

```bash
flutter build apk --release
```

El APK generado quedará en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Firma de APK

Este comando genera un APK no firmado para pruebas rápidas. Si necesitas publicar en Google Play, debes configurar la firma en `android/app/build.gradle` y el archivo `key.properties`.

## 4. Generar un APK de depuración

Para un APK de debug útil para pruebas internas:

```bash
flutter build apk --debug
```

El archivo quedará en la misma carpeta de salida de `build/app/outputs/flutter-apk/`.

## 5. Flujo básico de Git y GitHub

### Inicializar repositorio (solo si aún no existe)

```bash
git init
git add .
git commit -m "Inicio del proyecto FakeBus para Android"
```

### Añadir un remoto en GitHub

1. Crea un repositorio en GitHub.
2. Añade el remoto:

```bash
git remote add origin https://github.com/<tu-usuario>/<tu-repo>.git
```

### Subir cambios al repositorio

```bash
git add .
git commit -m "Agrega documentación de Android y correcciones"
git push -u origin main
```

> Cambia `main` por `master` si tu repositorio usa ese nombre de rama.

### Buenas prácticas de commits

- Usa mensajes claros y concisos.
- Haz commits atómicos: un cambio principal por commit.
- Actualiza `README.md` y documentación cuando agregues nuevas funciones.

## 6. Probar cambios rápidamente

Cuando hagas cambios en el código, usa:

```bash
flutter pub get
flutter run
```

o, si ya está abierto un emulador/dispositivo:

```bash
flutter run -d <device-id>
```

## 7. Recomendaciones adicionales

- Si necesitas compartir el APK con un tester, copia `build/app/outputs/flutter-apk/app-release.apk`.
- Usa `git status` para revisar los archivos modificados antes del commit.
- Si trabajas en una rama nueva:

```bash
git checkout -b feature/nueva-funcionalidad
```

- Para traer cambios remotos:

```bash
git pull origin main
```
