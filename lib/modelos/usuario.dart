/// Modelo del usuario autenticado (tabla `users`).
///
/// El campo `role` decide a que dashboard entra la persona y es el mismo dato
/// que el backend valida con su RoleMiddleware. Guardarlo aqui evita pegarle
/// la cadena de texto ('admin', 'cook'...) por toda la app.

library;

import '../utils/valores.dart';

class Usuario {
  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final String? telefono;
  final bool activo;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.telefono,
    this.activo = true,
  });

  /// Roles validos. Coinciden con el enum de la migracion
  /// `add_role_to_users_table` y con el middleware del backend.
  static const String rolAdmin = 'admin';
  static const String rolCliente = 'client';
  static const String rolCocinero = 'cook';
  static const String rolRepartidor = 'courier';

  factory Usuario.desdeJson(Map<String, dynamic> json) {
    return Usuario(
      id: aEntero(json['id']),
      nombre: json['name'] as String? ?? '',
      correo: json['email'] as String? ?? '',
      rol: json['role'] as String? ?? rolCliente,
      telefono: json['phone'] as String?,
      activo: aBooleano(json['active'], porDefecto: true),
    );
  }

  /// Convierte el usuario a JSON para guardarlo en disco.
  ///
  /// `toJson` es el metodo que Dart usa al llamar a `jsonEncode`, asi que
  /// implementarlo permite cachear la sesion sin mapearla a mano.
  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'name': nombre,
      'email': correo,
      'role': rol,
      'phone': telefono,
      'active': activo,
    };
  }

  bool get esAdmin => rol == rolAdmin;
  bool get esCliente => rol == rolCliente;
  bool get esCocinero => rol == rolCocinero;
  bool get esRepartidor => rol == rolRepartidor;

  /// Nombre corto para mostrar en la barra superior: "Andres D." en vez del
  /// nombre completo, que en movil no cabe junto al boton de cerrar sesion.
  ///
  /// Se usan variables intermedias en vez de encadenar llamadas dentro de la
  /// interpolacion para que se lea paso a paso: primero se parte el nombre,
  /// despues se toma la inicial.
  String get nombreCorto {
    final partes = nombre.trim().split(' ');

    if (partes.length < 2) {
      return nombre;
    }

    final inicial = partes[1].substring(0, 1).toUpperCase();
    return '${partes.first} $inicial.';
  }

  /// Ruta del dashboard segun el rol.
  ///
  /// El cliente no tiene dashboard propio en la app movil: su seccion de
  /// pedidos vive en la barra de navegacion inferior. Por eso devuelve null
  /// y quien llame debe manejar ese caso.
  String? get rutaDashboard {
    if (esAdmin) return '/dashboard/admin';
    if (esCocinero) return '/dashboard/cocina';
    if (esRepartidor) return '/dashboard/repartidor';
    return null;
  }
}
