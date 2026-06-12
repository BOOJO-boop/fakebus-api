# FakeBus

Aplicación Flutter de monitoreo y control de unidades de transporte en tiempo real.

## Descripción

`FakeBus` es una app móvil que muestra la ubicación en vivo de autobuses y la ocupación de cada unidad. Incluye:

- Autenticación de usuario mediante correo y contraseña.
- Rol de pasajero: visualiza la flota en un mapa con estado de ocupación.
- Rol de conductor: actualiza la ubicación GPS y el estado de ruta.
- Visualización de rutas mediante polilíneas y marcadores en Google Maps.

## Características principales

- Login con endpoint remoto.
- Dashboard para pasajeros con:
  - Mapa en tiempo real.
  - Indicadores de disponibilidad de unidades: disponible, moderado, saturado.
  - Rutas trazadas con `Polyline`.
- Panel del conductor con:
  - Envío de ubicación GPS al backend.
  - Activación / finalización de ruta.
  - Consulta periódica del conteo de pasajeros.

## Tecnologías

- Flutter
- Dart
- Google Maps Flutter (`google_maps_flutter`)
- Geolocator (`geolocator`)
- HTTP (`http`)

## Requisitos

- Flutter SDK 3.12 o superior
- Dispositivo o emulador Android con Google Play Services y permisos de ubicación
- Conexión a internet
- Backend disponible en `https://fakebus-api-production.up.railway.app`

## Configuración y ejecución

1. Clonar el repositorio.
2. Abrir el proyecto en Android Studio o VS Code.
3. Ejecutar:

```bash
flutter pub get
flutter run
```

> Actualmente la app está enfocada en Android. Si usas Google Maps, verifica la configuración de la clave para Android.

## Endpoints usados

La app se conecta al backend remoto en Railway a través de los siguientes endpoints:

- `POST /login` — autenticación de usuario.
- `GET /camiones` — obtiene la lista de vehículos y sus rutas.
- `GET /pasajeros/{idAutobus}` — obtiene el conteo de pasajeros del conductor.
- `POST /cambiar_estado_ruta` — activa o cierra la ruta.
- `POST /actualizar_ubicacion` — actualiza la posición GPS del autobús.

## Estructura del proyecto

- `lib/main.dart` — punto de entrada y login.
- `lib/home_page.dart` — pantalla principal de pasajero con mapa.
- `lib/driver_page.dart` — panel de conductor.
- `lib/ruta_service.dart` — servicio de rutas y OSRM.
- `lib/app_theme.dart` — tema y estilos de la app.

## Siguientes pasos sugeridos

- Agregar validación de campos en el login.
- Manejar tokens o sesiones de forma segura.
- Mejorar gestión de errores y mensajes de usuario.
- Añadir documentación de instalación específica para Android/iOS.

## Notas

El proyecto está basado en una estructura inicial, pero ya contiene la lógica principal para una app de monitoreo de flota y conteo de pasajeros. Para avanzar, conviene completar la documentación del backend y los requisitos de Google Maps.

## Guía adicional

- `docs/SETUP_ANDROID.md` — instrucciones para construir el APK desde la terminal y subir cambios a GitHub.
