/// Servicio de autenticacion: registro, login, logout y quien soy.
///
/// Cada metodo corresponde a un endpoint de AuthController. El servicio no
/// guarda nada en disco ni decide a que pantalla ir: eso es trabajo del
/// EstadoAutenticacion. Aqui solo se traduce HTTP a modelos.
library;

import '../modelos/usuario.dart';
import 'cliente_api.dart';

/// Resultado de un login exitoso.
///
/// Lo devuelve un objeto y no solo el [Usuario] porque el token tambien hace
/// falta, y se separa en dos campos en vez de mezclarlo todo en un Map.
class ResultadoLogin {
  final Usuario usuario;
  final String token;

  const ResultadoLogin({required this.usuario, required this.token});
}

class ServicioAutenticacion {
  final ClienteApi _api;

  ServicioAutenticacion(this._api);

  /// POST /register
  ///
  /// El backend no devuelve token en el registro, solo el usuario: queda
  /// iniciar sesion despues. [contrasenaConfirmada] viaja como
  /// `password_confirmation` porque la regla `confirmed` de Laravel lo exige.
  ///
  /// La validacion del backend es `min:8` sin exigir simbolos, pero la app
  /// pide una contraseña mas fuerte (ver [cumpleReglaDeContrasena]) para no
  /// dejar cuentas que despues no puedan iniciar sesion.
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required String contrasenaConfirmada,
    required String direccion,
    String? telefono,
  }) async {
    final datos = await _api.post(
      '/register',
      cuerpo: {
        'name': nombre,
        'email': correo,
        'password': contrasena,
        'password_confirmation': contrasenaConfirmada,
        'phone': telefono,
        // El registro exige direccion y crea una direccion por defecto.
        'address': direccion,
      },
    );

    return Usuario.desdeJson(datos as Map<String, dynamic>);
  }

  /// POST /login
  ///
  /// En error (correo o contraseña incorrectos) el backend responde 422 con
  /// un `errors.email`, y [ClienteApi] ya lo convierte en [ErrorDeApi] con un
  /// mensaje utilizable.
  Future<ResultadoLogin> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final datos = await _api.post(
      '/login',
      cuerpo: {'email': correo, 'password': contrasena},
    ) as Map<String, dynamic>;

    return ResultadoLogin(
      usuario: Usuario.desdeJson(datos['user'] as Map<String, dynamic>),
      token: datos['token'] as String,
    );
  }

  /// POST /logout
  ///
  /// Revoca el token en el servidor. Si falla (por ejemplo sin conexion) se
  /// ignora el error a proposito: el usuario igual debe quedar deslogueado
  /// localmente, que es lo que le importa.
  Future<void> cerrarSesion() async {
    try {
      await _api.post('/logout');
    } catch (_) {
      // Se ignora: la sesion local se limpia igual.
    }
  }

  /// GET /me
  ///
  /// Revalida el token guardado. Es la primera llamada al abrir la app: si el
  /// token sigue vivo, el usuario puede ver su sesion sin volver a escribir
  /// su contraseña.
  Future<Usuario> usuarioActual() async {
    final datos = await _api.get('/me');
    return Usuario.desdeJson(datos as Map<String, dynamic>);
  }
}

/// Valida la contraseña con la misma regla que usa la pantalla de login.
///
/// Minimo 6 caracteres, con al menos una mayuscula, una minuscula, un numero
/// y un simbolo. Se aplica tanto en el registro como en el login para que un
/// usuario nunca quede con una cuenta que la app le impida entrar.
///
/// Nota sobre el backend: su regla es solo `min:8` sin complejidad, asi que
/// esta funcion es MAS estricta. Es intencional (una contraseña debil es un
/// problema de seguridad), pero significa que una cuenta creada por otra via
/// con una contraseña simple no podria iniciar sesion desde la app.
bool cumpleReglaDeContrasena(String contrasena) {
  if (contrasena.length < 6) return false;
  if (!RegExp(r'[A-Z]').hasMatch(contrasena)) return false;
  if (!RegExp(r'[a-z]').hasMatch(contrasena)) return false;
  if (!RegExp(r'\d').hasMatch(contrasena)) return false;
  if (!RegExp(r'[@$!%*?&#._-]').hasMatch(contrasena)) return false;
  return true;
}
