import 'producto.dart';
import '../utils/valores.dart';

/// Modelo de una categoria del catalogo (tabla `categories`).
///
/// El backend devuelve `products` embebido en GET /categories, pero en esta
/// app no se usa: el catalogo trabaja con la lista plana de productos y
/// filtra en memoria por categoria. Por eso la lista queda vacia en [productos]
/// y no la pedimos por separado.
class Categoria {
  final int id;
  final String nombre;
  final String descripcion;
  final List<Producto> productos;

  const Categoria({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.productos = const [],
  });

  factory Categoria.desdeJson(Map<String, dynamic> json) {
    return Categoria(
      id: aEntero(json['id']),
      nombre: json['name'] as String? ?? 'Sin nombre',
      descripcion: json['description'] as String? ?? '',
      productos: (json['products'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Producto.desdeJson)
          .toList(),
    );
  }

  /// Convierte el nombre a un identificador sin espacios y en minusculas.
  ///
  /// El catalogo compara el nombre de la categoria del producto contra el id
  /// del filtro activo. Normalizar aqui evita repetir el `.toLowerCase()` en
  /// cada filtro y que "Cheesecakes" y "cheesecakes" se traten distinto.
  String get identificador {
    return nombre.toLowerCase().replaceAll(' ', '_');
  }

  /// Serializa con las claves del backend.
  ///
  /// Los productos NO se incluyen a proposito: pueden ser decenas y el
  /// catalogo los pide por separado. Meterlos aqui duplicaria el peso de la
  /// categoria guardada en el carrito de invitado.
  Map<String, dynamic> aJson() {
    return {'id': id, 'name': nombre, 'description': descripcion};
  }
}
