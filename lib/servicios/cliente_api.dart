/// Cliente HTTP que habla con la API de Laravel.
///
/// Es la unica pieza de la app que hace peticiones de red. Concentrar todo
/// aqui tiene dos ventajas: el token se agrega en un solo lugar, y los errores
/// de Laravel se traducen a excepciones con un mensaje que se pueda pintar
/// directamente en la UI, sin que cada pantalla tenga que entender la
/// estructura de un 422.
///
/// Analogia con la web: es el equivalente de `apiRequest` en
/// `frontend/src/services/api.js`, con dos diferencias: aqui se puede cambiar
/// la URL base en caliente, y se envuelven los fallos en [ErrorDeApi].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Excepcion que representa cualquier error de la API.
///
/// Se lanza con un mensaje listo para mostrar. Las pantallas hacen
/// `catch (e) { setError(e.toString()) }` y no necesitan inspeccionar el
/// codigo HTTP ni la forma del JSON de error.
class ErrorDeApi implements Exception {
  /// Mensaje en espanol, ya listo para pintar.
  final String mensaje;

  /// Codigo HTTP, util para distinguir 401 (sesion expirada) de otros.
  final int? codigo;

  const ErrorDeApi(this.mensaje, {this.codigo});

  @override
  String toString() => mensaje;
}

/// Cliente de la API.
///
/// Se crea una sola vez desde main.dart y se inyecta a los servicios con
/// Provider. [urlBase] es mutable a proposito: cuando el usuario cambia la URL
/// en la pantalla de Configuracion, se actualiza aqui y todas las peticiones
/// siguientes ya van al backend nuevo.
class ClienteApi {
  /// URL base, sin barra final. Ej: `https://abc.ngrok-free.app/api`.
  String urlBase;

  /// Token de Sanctum. Se envia en `Authorization: Bearer <token>`.
  String? token;

  /// Cabecera de Laravel. Se define aca para no repetirla en cada peticion.
  static const String _nombreToken = 'Accept';
  static const String _valorToken = 'application/json';
  static const String _nombreAutorizacion = 'Authorization';

  /// La web envia `ngrok-skip-browser-warning` porque ngrok muestra una
  /// pagina de advertencia al navegador. Flutter no es un navegador, asi que
  /// aqui no es necesaria; se conserva solo para que quede documentado que el
  /// problema ya no aplica en movil.
  final http.Client _http;

  ClienteApi({required this.urlBase, http.Client? clienteHttp})
    : _http = clienteHttp ?? http.Client();

  /// Cambia la URL destino. No cierra nada ni reinicia estado: a partir de
  /// este momento las siguientes peticiones usan la nueva URL.
  void actualizarUrlBase(String nuevaUrl) {
    urlBase = nuevaUrl;
  }

  /// Cierra el cliente HTTP. Debe llamarse al descartar el provider.
  void cerrar() {
    _http.close();
  }

  /// GET. [ruta] es relativa a [urlBase], por ejemplo `/products`.
  Future<dynamic> get(String ruta, {Map<String, String>? query}) async {
    return _enviar('GET', ruta, query: query);
  }

  /// POST con cuerpo JSON. [cuerpo] se serializa con `jsonEncode`.
  Future<dynamic> post(
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
  }) async {
    return _enviar('POST', ruta, cuerpo: cuerpo, query: query);
  }

  /// PUT con cuerpo JSON. Se usa para actualizar recursos (carrito, estado).
  Future<dynamic> put(String ruta, {Object? cuerpo}) async {
    return _enviar('PUT', ruta, cuerpo: cuerpo);
  }

  /// PATCH con cuerpo JSON. El backend lo usa para cambiar el rol de un usuario.
  Future<dynamic> patch(String ruta, {Object? cuerpo}) async {
    return _enviar('PATCH', ruta, cuerpo: cuerpo);
  }

  /// DELETE. Sin cuerpo.
  Future<dynamic> delete(String ruta) async {
    return _enviar('DELETE', ruta);
  }

  /// Arma y ejecuta la peticion, y traduce la respuesta.
  ///
  /// Todo el manejo de errores vive aqui a proposito: las pantallas solo
  /// esperan un valor o una excepcion [ErrorDeApi].
  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
  }) async {
    // Sin URL configurada fallamos temprano con un mensaje claro, en vez de
    // dejar que http lance un error de formato de URL que nadie entiende.
    if (urlBase.isEmpty) {
      throw const ErrorDeApi(
        'No hay direccion del backend configurada. Abrir Configuracion para Ingressarla.',
      );
    }

    var uri = Uri.parse('$urlBase$ruta');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final cabeceras = <String, String>{
      _nombreToken: _valorToken,
      'ngrok-skip-browser-warning': 'true',
    };
    if (cuerpo != null) {
      cabeceras['Content-Type'] = 'application/json';
    }
    if (token != null && token!.isNotEmpty) {
      cabeceras[_nombreAutorizacion] = 'Bearer $token';
    }

    try {
      // Un body de tipo Map se convierte a JSON; un String se manda tal cual.
      final cuerpoPeticion = cuerpo == null ? null : jsonEncode(cuerpo);
      final peticion = http.Request(metodo, uri)..headers.addAll(cabeceras);
      if (cuerpoPeticion != null) {
        peticion.body = cuerpoPeticion;
      }

      // `send` en vez de `get`/`post` porque todos los metodos comparten la
      // misma logica y solo cambia el verbo. `send` devuelve un
      // `StreamedResponse` (el cuerpo llega como stream), por eso despues se
      // lee con `Response.fromStream` para poder trabajar con un body String.
      final respuestaEnviada = await _http
          .send(peticion)
          .timeout(const Duration(seconds: 20));

      // `fromStream` es asincrono porque tiene que leer el cuerpo completo
      // del stream, asi que se espera con await antes de usar el resultado.
      final respuesta = await http.Response.fromStream(respuestaEnviada);

      return _leerRespuesta(respuesta);
      // Cada fallo de red dice QUE FALLO y DONDE. Antes todos terminaban en el
      // mismo "el servidor tardo demasiado en responder", sin nombrar la
      // direccion, y lo unico que se podia hacer era adivinar. Nombrar el host
      // convierte el mensaje en algo accionable: uno mira la URL de la pantalla y
      // sabe si le esta hablando al sitio equivocado.
    } on SocketException {
      // Hay dos causas muy distintas aqui y Dart las reporta igual: que no haya
      // nada escuchando (conexion rechazada) o que la direccion no exista en la
      // red en la que se esta (los paquetes se descartan). Las dos se
      // corrigen en la pantalla de configuracion.
      throw ErrorDeApi(
        'No hay ningun servidor en ${uri.host}. Revisa la direccion en '
        'Configuracion y que el backend este encendido.',
      );
    } on TimeoutException {
      // El sintoma clasico de una IP que no existe en esta red: no rechaza, no
      // contesta y la peticion se queda esperando hasta expirar.
      throw ErrorDeApi(
        '${uri.host} no respondio a tiempo. Si es un celular o tablet, revisa '
        'que la direccion sea alcanzable desde el dispositivo.',
      );
    } on HandshakeException {
      // Se llega aqui al pedir https contra un servidor que habla http: casi
      // siempre es un `https://` escrito de mas en la configuracion.
      throw ErrorDeApi(
        '${uri.host} no usa HTTPS. Prueba con http:// en la direccion.',
      );
    } on FormatException {
      throw const ErrorDeApi('La URL del backend no tiene un formato valido.');
    } on http.ClientException {
      throw ErrorDeApi(
        'Se corto la conexion con ${uri.host} antes de terminar la peticion.',
      );
    }
  }

  /// Convierte la respuesta HTTP en un valor de Dart o lanza [ErrorDeApi].
  ///
  /// Laravel devuelve 204 sin cuerpo en los DELETE, asi que se maneja aparte.
  /// Para los errores usa la misma logica que el `apiRequest` de la web: si
  /// hay `message` usa ese, si no busca el primer valor de `errors` (que es lo
  /// que produce la validacion de los 422).
  dynamic _leerRespuesta(http.Response respuesta) {
    if (respuesta.statusCode == 204) {
      return null;
    }

    dynamic datos;
    if (respuesta.body.isNotEmpty) {
      try {
        datos = jsonDecode(respuesta.body);
      } on FormatException {
        // El servidor respondio algo que no es JSON (por ejemplo la pagina de
        // error de ngrok o de PHP). No se puede parsear, asi que se avisa.
        datos = null;
      }
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return datos;
    }

    throw ErrorDeApi(
      _extraerMensaje(datos, respuesta.statusCode),
      codigo: respuesta.statusCode,
    );
  }

  /// Saca un mensaje legible de un cuerpo de error de Laravel.
  String _extraerMensaje(dynamic datos, int codigo) {
    if (datos is Map<String, dynamic>) {
      // Formato de validacion: {"errors": {"email": ["El correo ya existe"]}}
      final errores = datos['errors'];
      if (errores is Map<String, dynamic> && errores.isNotEmpty) {
        final primeraClave = errores.keys.first;
        final mensajes = errores[primeraClave];
        if (mensajes is List && mensajes.isNotEmpty) {
          return mensajes.first.toString();
        }
      }

      // Formato de excepcion de Laravel: {"message": "..."}
      final mensaje = datos['message'];
      if (mensaje is String && mensaje.isNotEmpty) {
        return _traducirMensaje(mensaje, codigo);
      }
    }

    // Sin cuerpo interpretable. Se distingue el 401 y el 404 porque tienen una
    // accion clara asociada.
    if (codigo == 401) {
      return 'Tu sesion expiro. Inicia sesion de nuevo.';
    }
    if (codigo == 403) {
      return 'No tienes permiso para hacer eso.';
    }
    if (codigo == 404) {
      return 'El servidor no encontro ese recurso.';
    }
    if (codigo == 422) {
      return 'Los datos enviados no son validos.';
    }
    return 'Ocurrio un error inesperado (codigo $codigo).';
  }

  /// Traduce mensajes tecnicos de Laravel a un texto que se pueda mostrar.
  ///
  /// Cuando la ruta no existe, Laravel contesta en ingles nombrando el endpoint
  /// interno ("The route api/reports/sales-by-period could not be found."). Ese
  /// texto no le dice nada a quien usa la app y ademas revela rutas internas.
  /// Casi siempre significa que el backend desplegado es mas viejo que la app,
  /// asi que se cambia por un aviso accionable en espanol.
  String _traducirMensaje(String mensaje, int codigo) {
    final esRutaNoEncontrada =
        codigo == 404 &&
        mensaje.startsWith('The route ') &&
        mensaje.contains('could not be found');

    if (esRutaNoEncontrada) {
      return 'El servidor no tiene habilitada esa funcion todavia '
          '(endpoint no encontrado). Puede que el backend necesite actualizarse.';
    }

    return mensaje;
  }
}
