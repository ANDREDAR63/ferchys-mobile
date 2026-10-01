/// Pruebas de la paleta clara y de que el modo oscuro no cambio.
library;

import 'package:ferchys_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemaFerchys.claro', () {
    test('usa los colores claros de index.css', () {
      final esquema = TemaFerchys.claro.colorScheme;

      expect(esquema.brightness, Brightness.light);
      expect(esquema.primary, TemaFerchys.rosaFresa);
      expect(esquema.onPrimary, TemaFerchys.blanco);
      expect(esquema.surface, TemaFerchys.blanco);
      expect(esquema.onSurface, TemaFerchys.chocolate);
      expect(esquema.secondaryContainer, TemaFerchys.rosaTierno);
      expect(esquema.onSurfaceVariant, TemaFerchys.textoSuave);
    });

    test('el fondo es blanco puro', () {
      expect(TemaFerchys.claro.scaffoldBackgroundColor, TemaFerchys.blanco);
    });

    test('la barra superior es blanca con texto chocolate', () {
      final barra = TemaFerchys.claro.appBarTheme;

      expect(barra.backgroundColor, TemaFerchys.blanco);
      expect(barra.foregroundColor, TemaFerchys.chocolate);
    });
  });

  group('TemaFerchys.oscuro', () {
    test('sigue siendo oscuro y no toma el blanco del modo claro', () {
      final esquema = TemaFerchys.oscuro.colorScheme;

      expect(esquema.brightness, Brightness.dark);
      expect(esquema.surface, isNot(TemaFerchys.blanco));
    });
  });
}
