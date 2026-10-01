/// Pruebas de los modelos contra el JSON REAL que devuelve el backend.
///
/// ESTOS JSON NO SON INVENTADOS. Son copias literales de lo que respondio
/// `GET /api/products`, `GET /api/categories` y `GET /api/payment-methods` del
/// servidor. Esa distincion es el punto de todo el archivo.
///
/// EL BUG QUE ESTAS PRUEBAS CAZAN. El catalogo entero fallaba con "no pudimos
/// conectarnos" mientras el backend estaba perfectamente encendido. La causa:
/// `Product` y `Category` en Laravel no declaran `$casts`, asi que el `tinyint`
/// de MySQL sale crudo como `"active": 1`, y el modelo hacia
/// `json['active'] as bool?`. Un `int` no es un `bool`, Dart lanza `TypeError`, y
/// el provider traducia cualquier excepcion distinta de `ErrorDeApi` a un texto
/// sobre la direccion del backend. Dos bugs encimados: el parseo y el mensaje
/// que tapaba el parseo.
///
/// La razon de pegar el JSON real y no uno a mano es que los JSON inventados
/// suelen tener `true` donde la base tiene `1`, y con eso la prueba pasa y el
/// bug se cuela igual.
library;

import 'dart:convert';

import 'package:ferchys_mobile/modelos/carrito_item.dart';
import 'package:ferchys_mobile/modelos/categoria.dart';
import 'package:ferchys_mobile/modelos/pago.dart';
import 'package:ferchys_mobile/modelos/producto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respuesta cruda de `GET /api/products`, recortada a los dos primeros
/// productos para no llenar el archivo de datos que aqui no aportan.
const String _jsonProductos = '''
[
  {
    "id": 1,
    "name": "Suspiros",
    "description": "Deliciosos merengues para endulzar tu día.",
    "price": "3000.00",
    "category_id": 1,
    "image_url": null,
    "active": 1,
    "created_at": "2026-09-16T23:28:52.000000Z",
    "updated_at": "2026-09-16T23:29:41.000000Z",
    "category": {
      "id": 1,
      "name": "Horneados",
      "description": "Suspiros, profiteroles, alfajores y otros horneados artesanales",
      "created_at": "2026-09-16T23:28:52.000000Z",
      "updated_at": "2026-09-16T23:28:52.000000Z"
    }
  },
  {
    "id": 3,
    "name": "Alfajores",
    "description": "Dulce tradicional argentino elaborado con dos delicadas galletas rellenas de arequipe y coco.",
    "price": "5000.00",
    "category_id": 1,
    "image_url": null,
    "active": 1,
    "created_at": "2026-09-16T23:28:52.000000Z",
    "updated_at": "2026-09-16T23:29:41.000000Z",
    "category": {
      "id": 1,
      "name": "Horneados",
      "description": "Suspiros, profiteroles, alfajores y otros horneados artesanales",
      "created_at": "2026-09-16T23:28:52.000000Z",
      "updated_at": "2026-09-16T23:28:52.000000Z"
    }
  }
]
''';

/// Primer elemento de `GET /api/categories`. Se conserva el arreglo `products`
/// anidado porque es lo que hacia mas probable el bug: al leer la categoria se
/// parsean productos reales.
const String _jsonCategoria = '''
{
  "id": 1,
  "name": "Horneados",
  "description": "Suspiros, profiteroles, alfajores y otros horneados artesanales",
  "created_at": "2026-09-16T23:28:52.000000Z",
  "updated_at": "2026-09-16T23:28:52.000000Z",
  "products": [
    {
      "id": 1,
      "name": "Suspiros",
      "description": "Deliciosos merengues para endulzar tu día.",
      "price": "3000.00",
      "category_id": 1,
      "image_url": null,
      "active": 1,
      "created_at": "2026-09-16T23:28:52.000000Z",
      "updated_at": "2026-09-16T23:29:41.000000Z"
    }
  ]
}
''';

/// `GET /api/payment-methods`, completo. Tambien devuelve `"active": 1`.
const String _jsonMetodosPago = '''
[
  {"id": 1, "name": "efectivo-contraentrega", "active": 1},
  {"id": 2, "name": "Bre-b", "active": 1}
]
''';

/// Primer producto del listado, como mapa suelto.
///
/// Devuelve una copia nueva en cada llamada porque varias pruebas le quitan o le
/// cambian `active`, y compartir el mapa haria que una prueba ensuciara a la
/// siguiente segun el orden en que corran.
Map<String, dynamic> _productoJson() {
  final lista = jsonDecode(_jsonProductos) as List<dynamic>;
  return Map<String, dynamic>.from(lista.first as Map<String, dynamic>);
}

Map<String, dynamic> _categoriaJson() =>
    jsonDecode(_jsonCategoria) as Map<String, dynamic>;

void main() {
  group('Producto.desdeJson con el JSON real', () {
    test('lee el producto sin lanzar, con "active" como 1', () {
      final producto = Producto.desdeJson(_productoJson());

      expect(producto.id, 1);
      expect(producto.nombre, 'Suspiros');
      // El precio llega como texto porque en MySQL es un decimal. Si aqui se
      // perdiera el parseo, el catalogo mostraria $0 en todos los productos.
      expect(producto.precio, 3000);
      expect(
        producto.activo,
        isTrue,
        reason: '"active": 1 tiene que leerse como true, no reventar',
      );
    });

    test('parsea la categoria anidada', () {
      final producto = Producto.desdeJson(_productoJson());

      expect(producto.categoria?.nombre, 'Horneados');
      expect(producto.categoriaId, 1);
    });

    test('"active": 0 significa inactivo', () {
      final datos = _productoJson()..['active'] = 0;

      expect(Producto.desdeJson(datos).activo, isFalse);
    });

    test('si la clave no viene, el producto se toma como activo', () {
      final datos = _productoJson()..remove('active');

      expect(
        Producto.desdeJson(datos).activo,
        isTrue,
        reason:
            'sin el campo un producto esta activo: por eso el defecto es true',
      );
    });

    test('tampoco se rompe con "active" ya en booleano', () {
      // Pasa al crear un producto: Laravel devuelve el atributo recien asignado
      // y ahi si viene como bool de verdad.
      final datos = _productoJson()..['active'] = true;

      expect(Producto.desdeJson(datos).activo, isTrue);
    });

    test('la descripcion nula no rompe el listado', () {
      final datos = _productoJson()..['description'] = null;

      expect(Producto.desdeJson(datos).descripcion, '');
    });
  });

  group('Categoria.desdeJson con el JSON real', () {
    test('lee la categoria que trae productos anidados', () {
      final categoria = Categoria.desdeJson(_categoriaJson());

      expect(categoria.id, 1);
      expect(categoria.nombre, 'Horneados');
    });
  });

  group('MetodoPago.desdeJson con el JSON real', () {
    test('lee el nombre y el activo con "active": 1', () {
      final metodos = (jsonDecode(_jsonMetodosPago) as List<dynamic>)
          .map((dato) => MetodoPago.desdeJson(dato as Map<String, dynamic>))
          .toList();

      expect(metodos.length, 2);
      expect(metodos.first.nombre, 'efectivo-contraentrega');
      expect(
        metodos.first.activo,
        isTrue,
        reason: 'si esto falla, el checkout no ofrece metodos de pago',
      );
    });
  });

  group('CarritoItem del invitado', () {
    // ESTE ES EL SEGUNDO LUGAR DONDE EL MISMO BUG SE ESCONDIA. El carrito de
    // invitado se guarda en disco como JSON y al releerlo pasa por
    // `Producto.desdeJson`. Con el `as bool?` de antes, un carrito guardado
    // tiraba la excepcion al abrir la app.
    test('vuelve a leer un producto guardado, con "active" como 1', () {
      final item = CarritoItem.desdeJson({
        'id': 'invitado-1',
        'product_id': 1,
        'quantity': 2,
        // El carrito guarda el producto anidado con las claves del backend.
        'product': _productoJson(),
      });

      expect(item.id, 'invitado-1');
      expect(item.productoId, 1);
      expect(item.cantidad, 2);
      expect(item.producto?.nombre, 'Suspiros');
      expect(item.producto?.activo, isTrue);
    });

    test('el viaje de ida y vuelta por disco no pierde el activo', () {
      // Se serializa con `aJson()` y se vuelve a leer, igual que cuando la app
      // se cierra y se vuelve a abrir con el carrito a medio armar. Es el mismo
      // camino que corrompia el carrito guardado antes del arreglo.
      final original = Producto.desdeJson(_productoJson());
      final guardado = original.aJson();

      expect(guardado['active'], isTrue);
      expect(Producto.desdeJson(guardado).activo, isTrue);
    });
  });
}
