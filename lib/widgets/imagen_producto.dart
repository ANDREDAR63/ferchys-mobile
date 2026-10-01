/// Imagen de un producto con dos respaldos en cascada.
///
/// EL ORDEN DE RESOLUCION ES: `urlImagen` -> foto empaquetada -> inicial.
///   1. Si el backend manda `image_url`, se usa esa (red). Hoy casi nunca
///      viene, pero el dia que el servidor sirva fotos funciona sin tocar nada.
///   2. Si no, se busca la foto empaquetada por nombre de producto
///      (`lib/utils/imagenes_producto.dart`), que es como las asigna el web.
///   3. Si tampoco hay, se dibuja la inicial del producto.
///
/// NO SE USA UN PAQUETE DE IMAGENES A PROPOSITO. `Image.network` y
/// `Image.asset` ya vienen en Flutter y alcanzan: agregar
/// `cached_network_image` traeria una dependencia mas que mantener, y en un
/// catalogo de postres con pocas fotos no compensa.
///
/// LOS RESPALDOS SON LO IMPORTANTE DE ESTE WIDGET. `image_url` esta vacio en
/// buena parte de los productos y las fotos solo cubren algunos nombres. Sin
/// respaldo, cada producto sin foto mostraria el cuadriculado rojo de Flutter,
/// que parece un error de la app.
library;

import 'package:flutter/material.dart';

import '../utils/imagenes_producto.dart';

class ImagenProducto extends StatelessWidget {
  final String? urlImagen;

  /// Nombre del producto, para buscar su foto empaquetada.
  final String? nombreProducto;

  final double tamano;
  final double radio;

  /// Texto del respaldo. Si no se pasa, se usa la inicial del producto: repetir
  /// "Sin imagen" en cada tarjeta pesa mas de lo que aporta.
  final String? textoRespaldo;

  const ImagenProducto({
    super.key,
    required this.urlImagen,
    this.nombreProducto,
    this.tamano = 80,
    this.radio = 12,
    this.textoRespaldo,
  });

  /// Ruta de la foto empaquetada, o `null` si el producto no tiene.
  String? get _rutaAsset {
    final nombre = nombreProducto;
    if (nombre == null) return null;
    return rutaAssetDeProducto(nombre);
  }

  @override
  Widget build(BuildContext context) {
    if (urlImagen != null && urlImagen!.isNotEmpty) {
      return _enmarcar(_porRed(context));
    }

    final asset = _rutaAsset;
    if (asset != null) {
      return _enmarcar(_porAsset(context, asset));
    }

    return _inicial(context);
  }

  /// Imagen que viene de una URL del backend.
  Widget _porRed(BuildContext context) {
    return Image.network(
      urlImagen!,
      width: tamano,
      height: tamano,
      fit: BoxFit.cover,
      // Sin esto, mientras baja la imagen se ve un hueco del tamano de la foto
      // y las tarjetas "bailan" al cargar.
      loadingBuilder: _alCargar,
      // Si la URL existe pero el servidor esta caido o la imagen ya no esta,
      // se cae a la foto empaquetada y, si no hay, a la inicial.
      errorBuilder: (contexto, error, pila) {
        final asset = _rutaAsset;
        if (asset != null) return _porAsset(contexto, asset);
        return _inicial(contexto);
      },
    );
  }

  /// Foto que viene empaquetada en la app.
  Widget _porAsset(BuildContext context, String ruta) {
    return Image.asset(
      ruta,
      width: tamano,
      height: tamano,
      fit: BoxFit.cover,
      errorBuilder: (contexto, error, pila) => _inicial(contexto),
    );
  }

  /// Envuelve la imagen para redondear las esquinas.
  Widget _enmarcar(Widget hijo) {
    return ClipRRect(borderRadius: BorderRadius.circular(radio), child: hijo);
  }

  /// Marco del color del tema mientras la imagen baja.
  Widget _alCargar(
    BuildContext contexto,
    Widget hijo,
    ImageChunkEvent? progreso,
  ) {
    // `progreso` llega en null cuando la imagen ya estaba en la cache.
    if (progreso == null) return hijo;

    return Container(
      width: tamano,
      height: tamano,
      color: Theme.of(contexto).colorScheme.surfaceContainerHighest,
    );
  }

  /// Cuadro con la inicial del producto.
  Widget _inicial(BuildContext context) {
    final tema = Theme.of(context);
    final nombre = nombreProducto?.trim() ?? '';
    final texto =
        textoRespaldo ??
        (nombre.isEmpty ? '?' : nombre.substring(0, 1).toUpperCase());

    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(radio),
      ),
      alignment: Alignment.center,
      child: Text(
        texto,
        style: tema.textTheme.titleLarge?.copyWith(
          color: tema.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
