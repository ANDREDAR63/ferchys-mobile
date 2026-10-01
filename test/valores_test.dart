/// Pruebas de la conversion de valores del backend.
///
/// ESTAS PRUEBAS EXISTEN POR UN BUG REAL. En MySQL las columnas `decimal(10,2)`
/// (precios, totales, promedios) se devuelven como STRING en el JSON, no como
/// numero. Con un `json['price'] as double` la app funcionaba con algunos
/// productos y se caia con otros, y el fallo aparecia en produccion.
///
/// Si alguien "simplifica" estas funciones y vuelve a usar `as double`, estas
/// pruebas fallan y avisan del problema antes de que llegue a un cliente.
///
/// Se ejecutan con `flutter test`.
library;

import 'package:ferchys_mobile/utils/valores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aDoble', () {
    test('convierte un entero de JSON', () {
      expect(aDoble(4500), 4500.0);
    });

    test('convierte un decimal de MySQL que llega como texto', () {
      // Este es el caso que motivó el archivo.
      expect(aDoble('4500.00'), 4500.0);
    });

    test('acepta un numero ya en double', () {
      expect(aDoble(12.5), 12.5);
    });

    test('devuelve el valor por defecto ante null', () {
      expect(aDoble(null), 0.0);
      expect(aDoble(null, porDefecto: -1), -1.0);
    });

    test('devuelve el valor por defecto ante texto no numerico', () {
      expect(aDoble('no es un numero'), 0.0);
      expect(aDoble('no es un numero', porDefecto: 7), 7.0);
    });

    test('tolera el separador de miles', () {
      expect(aDoble('1,500.50'), 1500.5);
    });

    test('tolera espacios alrededor', () {
      expect(aDoble('  99.90  '), 99.90);
    });

    test('rechaza NaN e infinito sin propagarlos', () {
      expect(aDoble(double.nan, porDefecto: 0), 0.0);
      expect(aDoble(double.infinity, porDefecto: 0), 0.0);
    });
  });

  group('aEntero', () {
    test('convierte un entero de JSON', () {
      expect(aEntero(7), 7);
    });

    test('redondea un decimal MySQL', () {
      expect(aEntero('7'), 7);
      expect(aEntero(7.6), 8);
    });

    test('acepta el valor por defecto', () {
      expect(aEntero(null, porDefecto: 1), 1);
    });
  });

  group('aBooleano', () {
    test('acepta el booleano de JSON', () {
      expect(aBooleano(true), isTrue);
    });

    test('acepta el 0 y 1 que devuelve MySQL para un bit', () {
      expect(aBooleano(1), isTrue);
      expect(aBooleano(0), isFalse);
    });

    test('acepta el texto "true"', () {
      expect(aBooleano('true'), isTrue);
    });

    test('trata null como falso', () {
      expect(aBooleano(null), isFalse);
    });
  });

  group('aFecha', () {
    test('lee el formato ISO que usa Laravel', () {
      expect(aFecha('2026-09-30T15:45:00.000000Z'), isNotNull);
    });

    test('convierte el espacio al formato ISO', () {
      // `DateTime.parse` NO entiende "2026-09-30 15:45:00" sin este cambio.
      final fecha = aFecha('2026-09-30 15:45:00');
      expect(fecha, isNotNull);
      expect(fecha!.year, 2026);
      expect(fecha.month, 9);
      expect(fecha.day, 30);
    });

    test('devuelve null en vez de lanzar si la fecha es basura', () {
      expect(aFecha('ayer'), isNull);
      expect(aFecha(null), isNull);
      expect(aFecha(''), isNull);
    });
  });
}
