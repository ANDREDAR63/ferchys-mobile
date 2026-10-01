/// Pruebas de la traduccion de errores del cliente HTTP.
///
/// LO QUE SE FIJA ACA ES EL MENSAJE QUE VE LA PERSONA, no el transporte. El
/// backend de Laravel contesta en ingles y nombrando sus rutas internas cuando
/// un endpoint no existe ("The route api/reports/sales-by-period could not be
/// found."). Ese texto no se puede mostrar en la pantalla del administrador: no
/// dice que hacer y deja a la vista una ruta que no le incumbe a quien usa la
/// app. Estas pruebas fijan que ese caso salga en espanol y que un 404 normal
/// (un recurso que no existe) conserve el mensaje del backend.
///
/// No se levanta un servidor: se falsea el cliente HTTP con `MockClient`, asi
/// que lo unico que corre es `_leerRespuesta` y `_extraerMensaje`.
library;

import 'dart:convert';

import 'package:ferchys_mobile/servicios/cliente_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  /// Cliente apuntado a un `MockClient` que responde siempre igual.
  ClienteApi apiQueResponde(int codigo, String cuerpo) {
    return ClienteApi(
      urlBase: 'http://localhost/api',
      clienteHttp: MockClient((_) async => http.Response(cuerpo, codigo)),
    );
  }

  test(
    'la ruta desconocida de Laravel se traduce a un aviso en espanol',
    () async {
      final api = apiQueResponde(
        404,
        jsonEncode({
          'message':
              'The route api/reports/sales-by-period could not be found.',
        }),
      );

      await expectLater(
        api.get('/reports/sales-by-period'),
        throwsA(
          isA<ErrorDeApi>()
              .having((error) => error.codigo, 'codigo', 404)
              .having(
                (error) => error.mensaje,
                'mensaje',
                contains('endpoint no encontrado'),
              )
              .having(
                (error) => error.mensaje,
                'mensaje',
                isNot(contains('The route')),
              ),
        ),
      );
    },
  );

  test('un 404 de recurso conserva el mensaje del backend', () async {
    // Un modelo que no existe tambien es 404, pero ahi el mensaje del backend
    // si es util ("No query results for model..."). Solo se traduce el caso de
    // la ruta, no todos los 404.
    final api = apiQueResponde(
      404,
      jsonEncode({'message': 'No query results for model [Product] 99'}),
    );

    await expectLater(
      api.get('/products/99'),
      throwsA(
        isA<ErrorDeApi>().having(
          (error) => error.mensaje,
          'mensaje',
          contains('No query results'),
        ),
      ),
    );
  });

  test('un 200 devuelve el JSON ya decodificado', () async {
    final api = apiQueResponde(200, jsonEncode({'ok': true}));

    expect(await api.get('/products'), {'ok': true});
  });

  test('un 404 sin cuerpo no queda vacio', () async {
    final api = apiQueResponde(404, '');

    await expectLater(
      api.get('/reports/orders-by-status'),
      throwsA(
        isA<ErrorDeApi>().having(
          (error) => error.mensaje,
          'mensaje',
          contains('no encontro'),
        ),
      ),
    );
  });

  test('un 401 sin cuerpo pide volver a iniciar sesion', () async {
    final api = apiQueResponde(401, '');

    await expectLater(
      api.get('/orders'),
      throwsA(
        isA<ErrorDeApi>().having(
          (error) => error.mensaje,
          'mensaje',
          contains('sesion expiro'),
        ),
      ),
    );
  });
}
