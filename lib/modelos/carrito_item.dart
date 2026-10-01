import 'producto.dart';
import '../utils/valores.dart';

/// Modelo de una linea del carrito.
///
/// Hay dos formas de obtenerlo y por eso el modelo es tolerante:
///   - Carrito de invitado: se armo en el dispositivo, tiene `id` de texto
///     (por ejemplo "invitado-7") y trae el producto completo embebido.
///   - Carrito autenticado: viene de la base de datos, `id` es un entero y el
///     producto llega en la relacion `product`.
///
/// El web storage usa la misma convencion de id de texto, asi que el
/// comportamiento se mantiene identico entre la version movil y la web.
class CarritoItem {
  /// Id del item. Texto cuando es invitado, entero cuando viene del servidor.
  final String id;
  final int productoId;
  final int cantidad;
  final Producto? producto;

  const CarritoItem({
    required this.id,
    required this.productoId,
    required this.cantidad,
    this.producto,
  });

  factory CarritoItem.desdeJson(Map<String, dynamic> json) {
    return CarritoItem(
      // El servidor manda `id` numerico; por eso se convierte a texto y el
      // widget no tiene que preguntar en que tipo viene.
      id: '${json['id']}',
      productoId: aEntero(json['product_id']),
      cantidad: aEntero(json['quantity'], porDefecto: 1),
      producto: json['product'] is Map<String, dynamic>
          ? Producto.desdeJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Construye la linea desde el carrito local de un invitado.
  ///
  /// El id se arma con el prefijo "invitado-" para que nunca choque con un id
  /// numerico real del servidor.
  factory CarritoItem.desdeInvitado({
    required Producto producto,
    required int cantidad,
  }) {
    return CarritoItem(
      id: 'invitado-${producto.id}',
      productoId: producto.id,
      cantidad: cantidad,
      producto: producto,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'product_id': productoId,
      'quantity': cantidad,
      // Guardamos el producto entero para poder pintar el carrito sin
      // volver a consultar el catalogo cuando la app se cierra y se abre.
      'product': {
        'id': producto!.id,
        'name': producto!.nombre,
        'description': producto!.descripcion,
        'price': producto!.precio,
        'image_url': producto!.imagenUrl,
      },
    };
  }

  /// Precio total de la linea: precio unitario por cantidad.
  ///
  /// Devuelve 0 si el producto no vino (por ejemplo tras leer un carrito
  /// guardado en disco de una version anterior) para no romper el total.
  double get subtotal {
    if (producto == null) return 0;
    return producto!.precio * cantidad;
  }

  /// Copia de la linea con otra cantidad, para los botones de + y -.
  CarritoItem conCantidad(int nuevaCantidad) {
    return CarritoItem(
      id: id,
      productoId: productoId,
      cantidad: nuevaCantidad,
      producto: producto,
    );
  }

  /// Indica si la linea vino del carrito local de un invitado.
  bool get esInvitado => id.startsWith('invitado-');
}
