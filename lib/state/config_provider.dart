/// Estado de la URL del backend, configurable desde la propia app.
///
/// Es el unico provider que TIENE que existir antes que los demas, porque de
/// el sale el `ClienteApi` con el que hablan todos los servicios. Por eso lo
/// construye `main()` a mano en vez de crearlo dentro de un `Provider`.
///
/// La URL se guarda en el dispositivo con `SharedPreferences` para que no haya
/// que escribirla de nuevo cada vez que se abre la app. Cada quien apunta a un
/// servidor distinto: unos al emulador de Android, otros a una IP de la red
/// local, otros a un tunel de ngrok.
///
/// QUE NO ESTA PERMITIDO: adivinar la IP desde la que llega el servidor.
/// Flutter si podria, pero la IP publica de un celular cambia cada vez que el
/// wifi se reconecta, asi que fallaria de forma intermitente. Es mejor que la
/// persona la escriba una vez.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../servicios/cliente_api.dart';

class ConfigProvider extends ChangeNotifier {
  /// Cliente HTTP compartido. Se expone para inyectarlo en el resto de
  /// providers: todos hablan con el backend a traves de esta misma instancia,
  /// asi hay una sola conexion y un solo token.
  final ClienteApi api;

  String _urlApi;

  ConfigProvider({required String urlApiInicial})
    : _urlApi = urlApiInicial,
      api = ClienteApi(urlBase: urlApiInicial);

  String get urlApi => _urlApi;

  /// Cambia la URL y la persiste.
  ///
  /// Devuelve un texto de error si la URL no sirve, o `null` si se guardo bien.
  /// Se devuelve el mensaje en vez de lanzar porque el error se muestra en un
  /// `SnackBar` justo debajo del campo, y ahi conviene el texto tal cual.
  Future<String?> guardarUrl(String urlCruda) async {
    final normalizada = normalizarUrlApi(urlCruda);

    if (normalizada.isEmpty) {
      return 'Escribe la direccion del backend.';
    }

    if (!normalizada.startsWith('http://') &&
        !normalizada.startsWith('https://')) {
      return 'La direccion debe empezar con http:// o https://';
    }

    _urlApi = normalizada;
    api.actualizarUrlBase(normalizada);

    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(ClavesAlmacenamiento.urlBaseApi, normalizada);

    notifyListeners();
    return null;
  }

  /// Vuelve a la URL de ejemplo segun el dispositivo y la guarda.
  ///
  /// Sirve para desenchufarse de un ngrok caido: si el tunel murio, la app se
  /// queda sin servidor y esta funcion la devuelve al backend local.
  Future<void> usarUrlPorDefecto() async {
    await guardarUrl(UrlPorDefecto.emuladorAndroid);
  }

  /// Se llama al cerrar la app para no dejar el socket HTTP abierto.
  @override
  void dispose() {
    api.cerrar();
    super.dispose();
  }
}

/// Lee la URL guardada, o la de Tailscale si todavia no hay ninguna.
///
/// EL DEFAULT ES LA RED PRIVADA, NO EL EMULADOR. Antes caia en
/// [UrlPorDefecto.emuladorAndroid], que es un alias que SOLO existe en el
/// emulador de Android: en una tablet o un celular de verdad `10.0.2.2` es una
/// direccion de la nada, los paquetes se descartan en silencio y la peticion se
/// cuelga hasta que expira. El sintoma era "el servidor tardo demasiado en
/// responder" con el backend perfectamente encendido, que es el peor lugar para
/// estar un error.
///
/// No se detecta si el dispositivo es emulador o fisico porque en Dart puro no
/// hay forma fiable, y anadir una dependencia para eso seria pesar el build por
/// una sugerencia. En su lugar, la pantalla de configuracion ofrece las URLs
/// conocidas como botones y un boton que prueba la conexion.
///
/// Va fuera de la clase porque `main()` la necesita ANTES de que exista
/// ningun provider, y devuelve un valor simple en vez de estado.
Future<String> leerUrlGuardada() async {
  final preferencias = await SharedPreferences.getInstance();
  final guardada = preferencias.getString(ClavesAlmacenamiento.urlBaseApi);

  if (guardada == null || guardada.isEmpty) {
    return UrlPorDefecto.tailscale;
  }

  return guardada;
}
