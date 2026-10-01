/// Configuracion global de la app, en especial la direccion del backend.
///
/// Existe como archivo aparte para que la URL del backend sea el unico dato
/// que tengas que tocar si cambias de servidor. El resto del codigo nunca
/// escribe URLs a mano: todas pasan por [urlBaseDeLaApi].
///
/// La URL se guarda en disco, asi que puedes cambiarla desde la app en
/// Configuracion sin necesidad de recompilar. Esto importa porque el backend
/// se expone con un tunel ngrok y esa URL cambia cada vez que reinicias ngrok.
library;

/// Claves de las preferencias guardadas. Se centralizan aqui para no repetir
/// cadenas de texto magicas por la app y evitar typos sutiles.
class ClavesAlmacenamiento {
  ClavesAlmacenamiento._();

  /// URL del backend, por ejemplo https://abc-123.ngrok-free.app/api
  static const String urlBaseApi = 'ferchys-url-api';

  /// Token de Sanctum que devuelve POST /login.
  static const String token = 'ferchys-token';

  /// Usuario autenticado completo, en JSON. Permite pintar la UI de inmediato
  /// mientras se revalida el token contra GET /me.
  static const String usuario = 'ferchys-user';

  /// Carrito de invitado, en JSON. Permite comprar sin cuenta y fusionar
  /// el carrito al iniciar sesion, igual que hace la version web.
  static const String carritoInvitado = 'ferchys-carrito';
}

/// Direcciones por defecto segun donde se ejecute la app.
///
/// Nota sobre ngrok: el tunel entrega una URL publica que cambia en cada
/// reinicio (plan gratuito). Si no usas ngrok y el backend corre en tu
/// maquina, usa las direcciones de abajo.
class UrlPorDefecto {
  UrlPorDefecto._();

  /// Emulador de Android. `10.0.2.2` es el alias que el emulador usa para
  /// apuntar al `localhost` de tu computador, donde corre `php artisan serve`.
  static const String emuladorAndroid = 'http://10.0.2.2:8000/api';

  /// iOS Simulator: si el backend corre en la misma Mac, `localhost` funciona.
  static const String simuladorIos = 'http://localhost:8000/api';

  /// Dispositivo fisico en la misma red WiFi: reemplaza IP_LOCAL_POR_LA_TUYA.
  static const String dispositivoFisico =
      'http://IP_LOCAL_POR_LA_TUYA:8000/api';

  /// Tailscale (red privada segura). Usado cuando el dispositivo fisico esta
  /// conectado a Tailscale y el backend corre en el nodo del servidor.
  static const String tailscale = 'http://100.101.83.22:8000/api';

  /// Tunel ngrok, que es como se expone el backend en produccion.
  /// Reemplaza ESTE_SUBDOMINIO por el que ngrok imprima al arrancar.
  static const String tunelNgrok = 'https://ESTE_SUBDOMINIO.ngrok-free.app/api';
}

/// Normaliza una URL escrita por el usuario.
///
/// Hace tres cosas para que el resto de la app no tenga que defenderse:
/// recorta espacios, quita la barra final (para no generar `//orders`) y
/// agrega `/api` si el usuario se lo olvido. Devolver la URL ya normalizada
/// desde un solo punto evita bugs repetidos en cada peticion.
String normalizarUrlApi(String urlCruda) {
  var url = urlCruda.trim();

  if (url.isEmpty) {
    return '';
  }

  // Sin esquema no hay host que resolver, asi que asumimos http.
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'http://$url';
  }

  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }

  if (!url.endsWith('/api')) {
    url = '$url/api';
  }

  return url;
}
