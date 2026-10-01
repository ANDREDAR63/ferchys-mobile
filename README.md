# Ferchy's Postres — App Móvil

App móvil en Flutter para Ferchy's Postres: catálogo, carrito, pedidos y
dashboards por rol (Cliente, Admin, Cocinero, Repartidor). Es el tercer
cliente del mismo backend que ya usa la [web de Ferchy's](https://andredar63.github.io/WEB-FERCHYS)
(React + Laravel + Sanctum + MariaDB) — no lo reemplaza, lo consume.

## Stack

- **Flutter** / Dart
- **Provider** para estado global
- **http** para consumir la API REST del backend Laravel
- **Sanctum** (token Bearer) para autenticación — sin JWT, sin cookies
- **shared_preferences** para persistir sesión y configuración local

## Estructura del proyecto

```
lib/
  main.dart         → arranque, tema visual, cableado de providers
  app_config.dart    → claves de almacenamiento y constantes compartidas
  modelos/            → clases de dominio (Usuario, Producto, Pedido...)
  servicios/            → capa que habla con la API (una clase por dominio)
  state/                 → Providers (estado observable por las pantallas)
  screens/                → pantallas, organizadas por módulo
  widgets/                 → piezas de UI reutilizables
  utils/                    → funciones puras (formateo, validaciones)
```

Para una explicación detallada de cómo está armada cada capa y por qué,
ver [`GUIA_DE_ESTUDIO.md`](./GUIA_DE_ESTUDIO.md).

## Requisitos

- Flutter SDK (canal estable) — verificar con `flutter doctor`
- Un dispositivo Android/iOS físico o emulador conectado
- Acceso de red al backend (ver sección siguiente)

## Cómo correr el proyecto

```bash
flutter pub get
flutter run
```

Al elegir dispositivo, selecciona el físico/emulador conectado (no la
opción de desktop si aparece más de uno).

Comandos útiles con `flutter run` activo:

| Tecla | Acción |
|---|---|
| `r` | Hot reload (aplica cambios sin reiniciar la app) |
| `R` | Hot restart (reinicia la app completa) |
| `q` | Salir |

## Configurar la URL del backend

La app no trae la URL del backend fija en el código: se configura desde
la pantalla de **Configuración** dentro de la propia app y se guarda
localmente.

- Si tienes acceso a la red del equipo vía **Tailscale**, usa la IP
  correspondiente, por ejemplo: `http://100.x.x.x:8000/api`
- Si no, pide el dominio público de **ngrok** vigente a quien esté
  corriendo el backend (cambia entre reinicios en el plan gratuito, salvo
  que se use un dominio reservado).

No hace falta escribir el `/api` ni el esquema `http://` manualmente si
se te olvida — la app los completa automáticamente al guardar la URL.

## Generar un APK para compartir

```bash
flutter build apk --release
```

El instalable queda en `build/app/outputs/flutter-apk/app-release.apk`.

## Pruebas

```bash
flutter test
```

Cubren las funciones puras del proyecto: formateo de moneda y fechas,
normalización de la URL del backend, y la regla de validación de
contraseña.

## Proyecto relacionado

- [`WEB-FERCHYS`](https://github.com/ANDREDAR63/WEB-FERCHYS) — frontend
  React y backend Laravel que esta app consume.

## Autor

Andrés Ramírez — [ANDREDAR63](https://github.com/ANDREDAR63)
