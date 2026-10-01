import 'categoria.dart';
import '../utils/valores.dart';

/// Modelo de un producto del catalogo.
///
/// Refleja la tabla `products` de Laravel junto con la relacion `category`
/// que el backend incluye en el JSON de GET /products.
///
/// El precio llega como numero plano, pero el backend lo manda como string
/// porque la columna es `decimal(10,2)` en MySQL. Por eso [precio] se
/// convierte a double al construir: si dejamos el valor crudo terminariamos
/// multiplicando un double por un String.
class Producto {
  final int id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int? categoriaId;
  final String? imagenUrl;
  final bool activo;
  final Categoria? categoria;

  const Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    this.categoriaId,
    this.imagenUrl,
    this.activo = true,
    this.categoria,
  });

  /// Construye el modelo a partir del JSON que devuelve Laravel.
  ///
  /// Todos los campos son opcionales salvo los esenciales: el backend a
  /// veces omite `description` (viene null) y `image_url`, y un null
  /// inesperado no debe tumbar la pantalla completa.
  factory Producto.desdeJson(Map<String, dynamic> json) {
    return Producto(
      id: aEntero(json['id']),
      nombre: json['name'] as String? ?? 'Sin nombre',
      descripcion: json['description'] as String? ?? '',
      precio: aDoble(json['price']),
      categoriaId: aEntero(json['category_id']),
      imagenUrl: json['image_url'] as String?,
      activo: aBooleano(json['active'], porDefecto: true),
      categoria: json['category'] is Map<String, dynamic>
          ? Categoria.desdeJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Serializa el producto con las MISMAS claves que usa el backend, para que
  /// el carrito de invitado guardado en el dispositivo se pueda volver a leer
  /// con [desdeJson] sin ningun mapa intermedio.
  ///
  /// La categoria va como objeto anidado y no solo el id porque el carrito de
  /// invitado la muestra aunque no haya conexion para ir a buscarla.
  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'name': nombre,
      'description': descripcion,
      'price': precio,
      'category_id': categoriaId,
      'image_url': imagenUrl,
      'active': activo,
      'category': categoria?.aJson(),
    };
  }
}
