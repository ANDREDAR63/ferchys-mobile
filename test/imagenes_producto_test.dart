/// Pruebas del mapa de fotos empaquetadas de los productos.
library;

import 'package:ferchys_mobile/utils/imagenes_producto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Hace falta para poder leer del `rootBundle` en la ultima prueba.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rutaAssetDeProducto', () {
    test('encuentra la foto por el nombre exacto del producto', () {
      expect(
        rutaAssetDeProducto('Cheesecake de limón'),
        'assets/images/cheesecake_limon.png',
      );
      expect(
        rutaAssetDeProducto('Refractaria familiar de cheesecake'),
        'assets/images/cheesecakes-grandes.jpg',
      );
    });

    test('ignora tildes, mayusculas y espacios de mas', () {
      final esperado = 'assets/images/cheesecake_maracuya.png';

      expect(rutaAssetDeProducto('cheesecake de maracuya'), esperado);
      expect(rutaAssetDeProducto('  Cheesecake  DE  Maracuyá  '), esperado);
      expect(rutaAssetDeProducto('CHEESECAKE DE MARACUYA'), esperado);
    });

    test('los productos sin foto propia devuelven null', () {
      // Suspiros y Alfajores a proposito no tienen foto: antes usaban el
      // favicon generico como si fuera una imagen del postre.
      expect(rutaAssetDeProducto('Suspiros'), isNull);
      expect(rutaAssetDeProducto('Alfajores'), isNull);
    });

    test('devuelve null para un nombre desconocido o vacio', () {
      expect(rutaAssetDeProducto('Torta de arándanos'), isNull);
      expect(rutaAssetDeProducto('   '), isNull);
    });

    test('las rutas declaradas existen en el bundle de assets', () async {
      // Esta prueba es la que caza un archivo que falta o una ruta mal escrita
      // en el mapa o en pubspec: sin ella, el fallo solo se veria en el
      // dispositivo, como una inicial en vez de la foto.
      const rutas = [
        'assets/images/cheesecake_limon.png',
        'assets/images/cheesecake_maracuya.png',
        'assets/images/cheesecake_chocolate.png',
        'assets/images/cheesecake_arandano.png',
        'assets/images/cheesecake_papayuela.png',
        'assets/images/cheesecake_redvelvet.png',
        'assets/images/cheesecakes-grandes.jpg',
      ];

      for (final ruta in rutas) {
        final datos = await rootBundle.load(ruta);
        expect(datos.lengthInBytes, greaterThan(0), reason: 'falta $ruta');
      }
    });
  });
}
