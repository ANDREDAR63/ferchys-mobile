/// Estado de la sesion: quien esta conectado y con que token.
///
/// Guarda tres cosas y las mantiene sincronizadas entre si:
///   - el `Usuario` que se muestra en la app,
///   - el token de Sanctum que viaja en cada peticion,
///   - y la copia en disco, para no pedir el login otra vez al abrir.
///
/// EL PUNTO QUE MAS CUESTA ENTENDER: el token NO se guarda aqui para que el
/// provider sea la unica fuente de verdad. Se copia a `ClienteApi.token` en
/// cuanto se obtiene, porque `ClienteApi` es el que arma la cabecera
/// `Authorization` y no debe saber nada de `SharedPreferences`.
///
/// Si alguien cierra sesion desde otra parte de la app, hay que llamar a
/// [cerrarSesion] y no solo borrar el usuario: si no, el token sigue pegado al
/// cliente HTTP y las peticiones siguientes pasarian como si hubiera sesion.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../modelos/usuario.dart';
import '../servicios/cliente_api.dart';
import '../servicios/servicio_autenticacion.dart';

class AuthProvider extends ChangeNotifier {
  final ServicioAutenticacion _servicio;
  final ClienteApi _api;

  Usuario? _usuario;

  /// `true` mientras se valida una credencial o se restaura la sesion.
  ///
  /// La app lo usa para no mostrar el boton "Entrar" deshabilitado sin
  /// explicacion: mientras carga, el boton muestra un indicador.
  bool _cargando = false;

  /// Ultimo error de autenticacion, para mostrarlo en la pantalla de login.
  ///
  /// Vive en el provider y no en el `State` de la pantalla porque el error
  /// viene de la red: asi el mismo mensaje se ve igual en login, registro y
  /// cambio de contrasena sin repetir el `try/catch` tres veces.
  String? _error;

  /// Cuantas veces se HA INICIADO SESION DE VERDAD en esta ejecucion.
  ///
  /// No cuenta `restaurarSesion`, y esa distincion es lo que importa: al abrir
  /// la app con una sesion vigente no hay nada local que fusionar con el
  /// servidor, mientras que en un ingreso manual si. El carrito usa este
  /// contador para saber exactamente cuando tiene que fusionar una vez.
  int _ingresos = 0;

  AuthProvider({
    required ServicioAutenticacion servicio,
    required ClienteApi api,
  }) : _servicio = servicio,
       _api = api;

  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get estaAutenticado => _usuario != null;
  int get ingresos => _ingresos;

  /// Atajo para las validaciones del backend. Si se manda algo que no cumple,
  /// Laravel responde 422 y el mensaje llega tal cual.
  bool get esAdmin => _usuario?.esAdmin ?? false;
  bool get esCocinero => _usuario?.esCocinero ?? false;
  bool get esRepartidor => _usuario?.esRepartidor ?? false;

  /// Nombre para la cabecera. Vacio si no hay sesion, para no tener que
  /// preguntar por `usuario` en cada pantalla.
  String get nombreUsuario => _usuario?.nombreCorto ?? '';

  /// Inicia sesion y deja el token listo para las siguientes peticiones.
  Future<bool> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    _prepararPeticion();

    try {
      final resultado = await _servicio.iniciarSesion(
        correo: correo,
        contrasena: contrasena,
      );
      await _guardarSesion(resultado.usuario, resultado.token);
      return true;
    } catch (error) {
      _error = _aTexto(error);
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Registra y entra de una vez, igual que la web: pedir el login
  /// inmediatamente despues de registrarse es una molestia innecesaria.
  ///
  /// [contrasenaConfirmada] y [direccion] no son opcionales porque el backend
  /// los exige: la contrasena por la regla `confirmed` de Laravel, y la
  /// direccion porque el registro crea una direccion por defecto, que es la
  /// que despues se ofrece como predeterminada al pagar.
  Future<bool> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required String contrasenaConfirmada,
    required String direccion,
    String? telefono,
  }) async {
    _prepararPeticion();

    try {
      await _servicio.registrar(
        nombre: nombre,
        correo: correo,
        contrasena: contrasena,
        contrasenaConfirmada: contrasenaConfirmada,
        direccion: direccion,
        telefono: telefono,
      );

      // El backend responde 201 con el usuario recien creado pero SIN token, y
      // con el rol que le toco por defecto (`client`). Se entra con esa misma
      // cuenta para no dejar a la persona a medio camino.
      return await iniciarSesion(correo: correo, contrasena: contrasena);
    } catch (error) {
      _error = _aTexto(error);
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  /// Cierra sesion en el dispositivo.
  ///
  /// NO se avisa al backend a proposito: el token es un token de Sanctum sin
  /// estado, asi que revocar cada salida haria la app mas lenta sin ganar nada
  /// de seguridad real. Se borra local, que es lo unico que importa para que
  /// el proximo usuario de este telefono no vea la sesion anterior.
  Future<void> cerrarSesion() async {
    await _servicio.cerrarSesion();

    _usuario = null;
    _api.token = null;
    _error = null;

    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(ClavesAlmacenamiento.token);
    await preferencias.remove(ClavesAlmacenamiento.usuario);

    notifyListeners();
  }

  /// Recupera la sesion guardada al abrir la app.
  ///
  /// Se leen el token y el usuario de disco y se confirman contra `GET /me`.
  /// La confirmacion importa: el token pudo expirar, o el usuario pudo ser
  /// desactivado o cambiado de rol mientras la app estaba cerrada. Confiar solo
  /// en lo que hay en disco dejaria mostrar un dashboard de admin a alguien que
  /// ya no es admin.
  ///
  /// Si la confirmacion falla, se limpia todo y la app arranca como invitado.
  Future<void> restaurarSesion() async {
    final preferencias = await SharedPreferences.getInstance();
    final token = preferencias.getString(ClavesAlmacenamiento.token);
    final usuarioGuardado = preferencias.getString(
      ClavesAlmacenamiento.usuario,
    );

    if (token == null || token.isEmpty || usuarioGuardado == null) {
      return;
    }

    _api.token = token;

    try {
      final usuario = await _servicio.usuarioActual();
      _usuario = usuario;
    } catch (_) {
      // Token vencido o usuario desactivado: se empieza de cero.
      _api.token = null;
      await preferencias.remove(ClavesAlmacenamiento.token);
      await preferencias.remove(ClavesAlmacenamiento.usuario);
    }

    notifyListeners();
  }

  /// Limpia el error antes de que la pantalla muestre otro formulario, para que
  /// el mensaje de "correo invalido" no siga flotando en la pantalla de registro.
  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _prepararPeticion() {
    _cargando = true;
    _error = null;
    notifyListeners();
  }

  /// Guarda usuario y token, y pega el token en el cliente HTTP.
  ///
  /// El orden importa: primero se escribe el token en `ClienteApi`, porque si
  /// algo fallara al guardar en disco, al menos las peticiones de esta sesion
  /// saldrán bien; y al reiniciar, `restaurarSesion` lo volverá a leer.
  Future<void> _guardarSesion(Usuario usuario, String token) async {
    _usuario = usuario;
    _api.token = token;
    _ingresos++;

    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(ClavesAlmacenamiento.token, token);
    await preferencias.setString(
      ClavesAlmacenamiento.usuario,
      jsonEncode(usuario.aJson()),
    );
  }

  /// Convierte cualquier error en texto mostrable.
  ///
  /// Los errores del cliente HTTP ya son [ErrorDeApi] con un mensaje pensado
  /// para leerse. Cualquier otra excepcion (un bug, un null inesperado) se
  /// muestra generica, porque el detalle tecnico no le sirve a la persona que
  /// esta intentando iniciar sesion.
  String _aTexto(Object error) {
    if (error is ErrorDeApi) return error.mensaje;
    return 'No se pudo completar la operacion. Intenta de nuevo.';
  }
}
