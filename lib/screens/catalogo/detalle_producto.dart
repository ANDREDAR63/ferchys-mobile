/// Detalle de un producto, con la cantidad y el boton de agregar.
///
/// SE ABRE COMO PANTALLA COMPLETA Y NO COMO MODAL CON PARTE DE ABAJO, porque el
/// producto lleva descripcion larga y la nota de "`sin gluten`", "`contains
/// nuts`" que la web guarda en la descripcion. En un modal de 300 pixeles de
/// alto habia que hacer scroll dentro de un scroll, que en Android da problemas.
///
/// El producto NO se vuelve a pedir al backend: se lee del catalogo que ya esta
/// cargado ([CatalogoProvider.productoEnDetalle]). El JSON de
/// `GET /products/{id}` trae lo mismo que el que ya hay en la lista, asi que
/// pedirlo seria una ida y vuelta sin ningun dato nuevo.
///
/// Si el producto se borro del catalogo mientras esta pantalla abierta,
/// [CatalogoProvider.productoEnDetalle] devuelve `null` y se muestra el estado
/// vacio en vez de una pantalla en blanco.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modelos/producto.dart';
import '../../state/carrito_provider.dart';
import '../../state/catalogo_provider.dart';
import '../../utils/formateo.dart';
import '../../widgets/estados_pantalla.dart';
import '../../widgets/imagen_producto.dart';

class DetalleProducto extends StatefulWidget {
  const DetalleProducto({super.key});

  @override
  State<DetalleProducto> createState() => _DetalleProductoState();
}

class _DetalleProductoState extends State<DetalleProducto> {
  int _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();
    final producto = catalogo.productoEnDetalle;

    // El producto se "cierra" al salir, para que al volver al catalogo la lista
    // no quede con una tarjeta marcada.
    return PopScope(
      onPopInvokedWithResult: (_, _) {
        context.read<CatalogoProvider>().abrirProducto(null);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(producto?.nombre ?? 'Producto')),
        body: _cuerpo(producto, catalogo),
      ),
    );
  }

  Widget _cuerpo(Producto? producto, CatalogoProvider catalogo) {
    if (producto == null) {
      return const PantallaVacia(
        icono: Icons.no_food_rounded,
        titulo: 'Producto no disponible',
        mensaje: 'Este producto ya no esta en el catalogo.',
      );
    }

    final tema = Theme.of(context);
    final promocion = catalogo.promocionDe(producto.id);
    final precioFinal = promocion == null
        ? producto.precio
        : producto.precio - promocion.descuentoSobre(producto.precio);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ImagenProducto(
            urlImagen: producto.imagenUrl,
            nombreProducto: producto.nombre,
            tamano: 200,
            radio: 20,
          ),
        ),
        const SizedBox(height: 24),

        Text(
          producto.nombre,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        if (promocion != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: tema.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 20,
                  color: tema.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${promocion.nombre}: -${promocion.porcentajeDescuento.toStringAsFixed(0)}% '
                    'en este producto',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Row(
          children: [
            if (promocion != null)
              Text(
                formatearMoneda(producto.precio),
                style: tema.textTheme.titleMedium?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              formatearMoneda(precioFinal),
              style: tema.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: tema.colorScheme.primary,
              ),
            ),
          ],
        ),

        if (producto.descripcion.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Descripcion', style: tema.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(producto.descripcion, style: tema.textTheme.bodyMedium),
        ],

        if (producto.categoria != null) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.category_outlined, size: 16),
                label: Text(producto.categoria!.nombre),
              ),
            ],
          ),
        ],

        const SizedBox(height: 28),
        _SelectorCantidad(
          cantidad: _cantidad,
          alCambiar: (valor) => setState(() => _cantidad = valor),
        ),
        const SizedBox(height: 16),

        _BotonAgregar(
          producto: producto,
          cantidad: _cantidad,
          precioTotal: precioFinal * _cantidad,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Fila con los botones de mas y menos.
class _SelectorCantidad extends StatelessWidget {
  final int cantidad;
  final ValueChanged<int> alCambiar;

  const _SelectorCantidad({required this.cantidad, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Cantidad', style: tema.textTheme.titleSmall),
        Row(
          children: [
            IconButton.outlined(
              onPressed: cantidad > 1 ? () => alCambiar(cantidad - 1) : null,
              icon: const Icon(Icons.remove_rounded),
              tooltip: 'Quitar uno',
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$cantidad',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge,
              ),
            ),
            IconButton.outlined(
              onPressed: cantidad < 99 ? () => alCambiar(cantidad + 1) : null,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Agregar uno',
            ),
          ],
        ),
      ],
    );
  }
}

/// Boton de agregar, con el total de la cantidad elegida.
class _BotonAgregar extends StatelessWidget {
  final Producto producto;
  final int cantidad;
  final double precioTotal;

  const _BotonAgregar({
    required this.producto,
    required this.cantidad,
    required this.precioTotal,
  });

  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoProvider>();

    return FilledButton.icon(
      onPressed: carrito.cargando ? null : () => _agregar(context),
      icon: carrito.cargando
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_shopping_cart_rounded),
      label: Text('Agregar ${formatearMoneda(precioTotal)}'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }

  Future<void> _agregar(BuildContext context) async {
    final provider = context.read<CarritoProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await provider.agregar(producto, cantidad: cantidad);

    if (!context.mounted) return;

    // El aviso lo arma el provider, asi el mismo texto sale aca y desde la
    // tarjeta del catalogo. Se muestra antes de salir de la pantalla, porque
    // un `SnackBar` desaparece si el widget que lo lanzo se desmonta.
    messenger.showSnackBar(
      SnackBar(content: Text(provider.aviso ?? 'Agregado al carrito')),
    );

    if (context.mounted) Navigator.of(context).pop();
  }
}
