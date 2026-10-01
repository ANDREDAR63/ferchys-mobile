/// Pruebas de las funciones puras del proyecto.
///
/// Solo se prueban las piezas que no necesitan red ni widgets: el formato de
/// dinero, la normalizacion de la URL del backend y la regla de contrasena.
/// Son las que mas se repiten en toda la app, asi que si una falla el error
/// se propaga a pantallas que ni imagined.
///
/// Se ejecutan con `flutter test`.
library;

import 'package:ferchys_mobile/app_config.dart';
import 'package:ferchys_mobile/servicios/servicio_autenticacion.dart';
import 'package:ferchys_mobile/utils/formateo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `DateFormat` con locale `es_CO` necesita este paso; sin el, las pruebas
  // de fecha fallan con LocaleDataException aunque el codigo de la app este
  // bien. En la app real lo hace `main()`.
  setUpAll(inicializarFormatos);

  group('normalizarUrlApi', () {
    test('agrega el esquema http cuando falta', () {
      expect(
        normalizarUrlApi('192.168.1.10:8000'),
        'http://192.168.1.10:8000/api',
      );
    });

    test('quita la barra final para no generar doble barra', () {
      expect(
        normalizarUrlApi('http://localhost:8000/'),
        'http://localhost:8000/api',
      );
    });

    test('respeta una URL que ya trae /api', () {
      final url = 'https://abc.ngrok-free.app/api';
      expect(normalizarUrlApi(url), url);
    });

    test('limpia espacios que el usuario haya pegado por error', () {
      expect(
        normalizarUrlApi('  http://localhost:8000  '),
        'http://localhost:8000/api',
      );
    });

    test('devuelve vacio si no hay nada escrito', () {
      expect(normalizarUrlApi('   '), '');
    });
  });

  group('formatearFecha', () {
    test('abrevia el mes en minuscula', () {
      expect(formatearFecha(DateTime(2026, 9, 30)), '30 sept 2026');
    });

    test('no falla cuando la fecha es nula', () {
      expect(formatearFecha(null), 'Sin fecha');
    });
  });

  group('formatearFechaHora', () {
    test('incluye la hora en formato de 12 horas', () {
      expect(
        formatearFechaHora(DateTime(2026, 9, 30, 15, 45)),
        '30 sept 2026, 3:45 p. m.',
      );
    });
  });

  group('formatearMoneda', () {
    test('usa el separador de miles colombiano con punto', () {
      expect(formatearMoneda(7000), r'$7.000');
    });

    test('formatea 40000 sin decimales', () {
      expect(formatearMoneda(40000), r'$40.000');
    });
  });

  group('formatearVariacion', () {
    test('antepone mas cuando la venta subio', () {
      expect(formatearVariacion(12.54), '+12.5%');
    });

    test('conserva el menos cuando bajo', () {
      expect(formatearVariacion(-8.3), '-8.3%');
    });

    test('muestra guion cuando no hay periodo anterior con que comparar', () {
      expect(formatearVariacion(null), '—');
    });
  });

  group('cumpleReglaDeContrasena', () {
    test('acepta una contrasena completa', () {
      expect(cumpleReglaDeContrasena('Ferchy123!'), isTrue);
    });

    test('rechaza una que no tenga simbolo', () {
      expect(cumpleReglaDeContrasena('Ferchy1234'), isFalse);
    });

    test('rechaza una que no tenga mayuscula', () {
      expect(cumpleReglaDeContrasena('ferchy123!'), isFalse);
    });

    test('rechaza una muy corta', () {
      expect(cumpleReglaDeContrasena('Fe1!'), isFalse);
    });
  });
}
