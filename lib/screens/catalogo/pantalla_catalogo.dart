/// Catalogo de productos con filtro por categoria y buscador.
///
/// ES LA PANTALLA PRINCIPAL DE CUALQUIER VISITANTE, INCLUDINGO EL QUE TIENE
/// SESION DE CLIENTE. Por eso no pide la sesion para nada: se puede mirar y
/// agregar al carrito sin estar conectado, y el login se pide al pagar.
///
/// EL CATALOGO SE FILTRA EN EL DISPOSITIVO, NO EN EL BACKEND. Se pidio esta
/// decision a proposito y vale la pena explicarla: la lista son decenas de
/// productos, no miles, asi que una vez descargada se puede filtrar al instante
/// sin pedir nada otra vez. En un catalogo grande habria que mover el filtro al
/// servidor, pero aca seria agregar latencia sin ganar nada.
///
/// LOS PRODUCTOS INACTIVOS NO SE MUESTRAN. El backend los sigue devolviendo
/// porque el administrador los necesita para gestionarlos; la app los esconde
/// porque un cliente no puede comprarlos. El filtro es del lado del cliente a
/// proposito, asi no depende de que el backend lo aplique.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modelos/categoria.dart';
import '../../modelos/producto.dart';
import '../../modelos/promocion.dart';
import '../../state/carrito_provider.dart';
import '../../state/catalogo_provider.dart';
import '../../utils/formateo.dart';
import '../../widgets/estados_pantalla.dart';
import '../../widgets/imagen_producto.dart';
import '../configuracion/pantalla_configuracion_url.dart';
import 'detalle_producto.dart';

class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  @override
  void initState() {
    super.initState();

    // Se carga en el `initState` y no en el `build`: `build` corre muchas
    // veces (al girar, al cambiar de pestana) y pedir el catalogo cada vez
    // haria la app inutilizable. Ademas se posterga un frame porque durante el
    // `initState` todavia no se puede leer de un provider con `watch`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CatalogoProvider>().cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ferchy\'s Postres'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PantallaConfiguracionUrl(),
                ),
              );
            },
            icon: const Icon(Icons.settings_ethernet_rounded),
            tooltip: 'Direccion del backend',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              _Buscador(alBuscar: catalogo.buscar),
              const SizedBox(height: 8),
              _FiltroCategorias(
                categorias: catalogo.categorias,
                seleccionada: catalogo.categoriaSeleccionada,
                alSeleccionar: (id) => catalogo.seleccionarCategoria(id),
              ),
            ],
          ),
        ),
      ),
      body: _cuerpo(catalogo, tema),
    );
  }

  /// Decide entre los tres estados: cargando, vacio con filtro, o error.
  Widget _cuerpo(CatalogoProvider catalogo, ThemeData tema) {
    if (catalogo.cargando && catalogo.productosVisibles.isEmpty) {
      return const PantallaCargando(mensaje: 'Cargando el catalogo...');
    }

    if (catalogo.error != null) {
      return PantallaError(
        mensaje: catalogo.error!,
        alReintentar: () {
          catalogo.limpiarError();
          catalogo.cargar();
        },
        alConfigurarUrl: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const PantallaConfiguracionUrl(mostrarBotonCerrar: true),
            ),
          );
        },
      );
    }

    if (catalogo.productosVisibles.isEmpty) {
      // El mensaje cambia segun por que esta vacio: si busco algo que no
      // existe, la ayuda es quitar la busqueda, no "anade productos".
      final hayFiltro =
          catalogo.busqueda.isNotEmpty ||
          catalogo.categoriaSeleccionada != null;

      return PantallaVacia(
        icono: hayFiltro ? Icons.search_off_rounded : Icons.cake_outlined,
        titulo: hayFiltro ? 'Sin resultados' : 'Catalogo vacio',
        mensaje: hayFiltro
            ? 'Ningun postre coincide con lo que pediste.'
            : 'Aun no hay productos en el backend.',
        accion: hayFiltro
            ? OutlinedButton(
                onPressed: () {
                  catalogo.buscar('');
                  catalogo.seleccionarCategoria(null);
                },
                child: const Text('Quitar filtros'),
              )
            : null,
      );
    }

    return RefreshIndicator(
      // Bajar para recargar: la lista puede estar vieja si el admin creo
      // productos en otro lado.
      onRefresh: catalogo.cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: catalogo.productosVisibles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (contexto, indice) {
          final producto = catalogo.productosVisibles[indice];
          return _TarjetaProducto(
            producto: producto,
            promocion: catalogo.promocionDe(producto.id),
          );
        },
      ),
    );
  }
}

/// Campo de busqueda.
class _Buscador extends StatelessWidget {
  final ValueChanged<String> alBuscar;

  const _Buscador({required this.alBuscar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        onChanged: alBuscar,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar un postre...',
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            // Poner la X es un detalle chico que ayuda mucho: con el
            // filtro puesto no hay forma evidente de deshacerlo.
            onPressed: () {
              alBuscar('');
              // Se busca uno nuevo para tomar el foco del campo.
              FocusScope.of(context).unfocus();
            },
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Limpiar busqueda',
          ),
        ),
      ),
    );
  }
}

/// Fila horizontal de categorias, con "Todas" al principio.
class _FiltroCategorias extends StatelessWidget {
  final List<Categoria> categorias;
  final int? seleccionada;
  final ValueChanged<int?> alSeleccionar;

  const _FiltroCategorias({
    required this.categorias,
    required this.seleccionada,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    // Sin categorias todavia no se muestra la fila: dejaria un hueco vacio
    // arriba del catalogo mientras se cargan.
    if (categorias.isEmpty) return const SizedBox(height: 8);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Pastilla(
            texto: 'Todas',
            activa: seleccionada == null,
            alTocar: () => alSeleccionar(null),
          ),
          for (final categoria in categorias)
            _Pastilla(
              texto: categoria.nombre,
              activa: seleccionada == categoria.id,
              alTocar: () => alSeleccionar(categoria.id),
            ),
        ],
      ),
    );
  }
}

/// Un boton del filtro de categorias.
class _Pastilla extends StatelessWidget {
  final String texto;
  final bool activa;
  final VoidCallback alTocar;

  const _Pastilla({
    required this.texto,
    required this.activa,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: activa,
        onSelected: (_) => alTocar(),
      ),
    );
  }
}

/// Fila de un producto en el catalogo.
class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final Promocion? promocion;

  const _TarjetaProducto({required this.producto, this.promocion});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final carrito = context.watch<CarritoProvider>();

    // El precio con descuento se calcula aca y no se guarda en el modelo, para
    // que `Producto.precio` siga siendo el precio real de la base y no un
    // valor que cambia segun el dia.
    final precioFinal = promocion == null
        ? producto.precio
        : producto.precio - (promocion!.descuentoSobre(producto.precio));

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          context.read<CatalogoProvider>().abrirProducto(producto.id);
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DetalleProducto()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImagenProducto(
                urlImagen: producto.imagenUrl,
                nombreProducto: producto.nombre,
                tamano: 84,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    if (producto.descripcion.isNotEmpty)
                      Text(
                        producto.descripcion,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 8),
                    _FilaPrecio(
                      precio: producto.precio,
                      precioFinal: precioFinal,
                      tieneDescuento: promocion != null,
                      porcentaje: promocion?.porcentajeDescuento,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              _BotonAgregar(
                producto: producto,
                // Se deshabilita mientras viaja la peticion, para que un
                // doble toque no agregue dos lineas del mismo producto.
                ocupado: carrito.cargando,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Precio normal, tachado si hay descuento, y el precio final.
class _FilaPrecio extends StatelessWidget {
  final double precio;
  final double precioFinal;
  final bool tieneDescuento;
  final double? porcentaje;

  const _FilaPrecio({
    required this.precio,
    required this.precioFinal,
    required this.tieneDescuento,
    this.porcentaje,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (tieneDescuento)
          Text(
            formatearMoneda(precio),
            style: tema.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        Text(
          formatearMoneda(precioFinal),
          style: tema.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: tieneDescuento ? tema.colorScheme.primary : null,
          ),
        ),
        if (tieneDescuento && porcentaje != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tema.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '-${porcentaje!.toStringAsFixed(0)}%',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

/// Boton de agregar al carrito con la cantidad a la vez.
///
/// Se pide la cantidad en un `showModalBottomSheet` en vez de sumar de a uno con
/// toques repetidos: en un carrito de postres, elegir "3 brownies" a la primera
/// es lo normal, y obligar a tocar tres veces molesta.
class _BotonAgregar extends StatelessWidget {
  final Producto producto;
  final bool ocupado;

  const _BotonAgregar({required this.producto, required this.ocupado});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: ocupado ? null : () => _elegirCantidad(context),
      icon: const Icon(Icons.add_shopping_cart_rounded),
      tooltip: 'Agregar al carrito',
    );
  }

  Future<void> _elegirCantidad(BuildContext context) async {
    final cantidad = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => _HojaCantidad(producto: producto),
    );

    // `null` significa que se cerro sin elegir nada.
    if (cantidad == null || !context.mounted) return;

    await context.read<CarritoProvider>().agregar(producto, cantidad: cantidad);
  }
}

/// Hoja inferior para elegir la cantidad.
class _HojaCantidad extends StatefulWidget {
  final Producto producto;

  const _HojaCantidad({required this.producto});

  @override
  State<_HojaCantidad> createState() => _HojaCantidadState();
}

class _HojaCantidadState extends State<_HojaCantidad> {
  int _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      // El `padding` de abajo es el `SafeArea`: sin el, en un telefono con
      // barra de gestos el boton de "Agregar" queda debajo del gesto del
      // sistema y no se puede tocar.
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.producto.nombre,
            style: tema.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            formatearMoneda(widget.producto.precio),
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cantidad', style: tema.textTheme.titleSmall),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _cantidad > 1
                        ? () => setState(() => _cantidad--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$_cantidad',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleMedium,
                    ),
                  ),
                  IconButton.outlined(
                    // Tope de 99 porque es lo maximo que se puede pedir de una
                    // vez sin que sea un error de dedo.
                    onPressed: _cantidad < 99
                        ? () => setState(() => _cantidad++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_cantidad),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(
              'Agregar ${formatearMoneda(widget.producto.precio * _cantidad)}',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
