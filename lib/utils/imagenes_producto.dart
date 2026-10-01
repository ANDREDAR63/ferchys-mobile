/// Fotos empaquetadas de los productos.
///
/// DE DONDE SALEN. Son las mismas imagenes que usa la version web
/// (`WEB-FERCHYS/frontend/src/assets/`), copiadas a `assets/images/`. La web no
/// sube fotos a la base: el campo `products.image_url` esta vacio y las
/// imagenes se asignan por NOMBRE de producto en el codigo (ver
/// `imagenesPorProducto` en `catalogo.jsx`). Aqui se replica esa idea para que
/// el catalogo movil se vea como el web.
///
/// POR QUE UN MAPA Y NO `image_url`. Porque la base no tiene URLs de imagen que
/// usar. [rutaAssetDeProducto] es el respaldo local; si algun dia `image_url`
/// trae un valor, `ImagenProducto` le da prioridad y este mapa queda de sobra.
///
/// SUSPIROS Y ALFAJORES NO TIENEN ENTRADA A PROPOSITO. En el web esas dos usan
/// el favicon generico como si fuera la foto del producto. Eso no es una imagen
/// del postre, es un parche, y arrastrarlo aqui solo agregaria una fila que
/// miente sobre lo que representa. Hasta que exista una foto real, esos dos
/// productos muestran su inicial.
library;

/// Normaliza el nombre para que la busqueda no dependa de tildes, mayusculas ni
/// espacios de mas.
///
/// Hace falta porque el nombre viene de la base y cualquiera puede escribirlo
/// como quiera: "Cheesecake de limón" y "cheesecake de limon" tienen que caer en
/// la misma foto. Sin esto, un acento distinto dejaria el producto sin imagen.
String _clave(String nombre) {
  final minusculas = nombre.trim().toLowerCase();
  final sinTildes = minusculas
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
  // Varios espacios seguidos se vuelven uno: "cheesecake  de  limon".
  return sinTildes.replaceAll(RegExp(r'\s+'), ' ');
}

/// Mapa de nombre normalizado a ruta del asset.
const Map<String, String> _archivoPorProducto = {
  'cheesecake de limon': 'assets/images/cheesecake_limon.png',
  'cheesecake de maracuya': 'assets/images/cheesecake_maracuya.png',
  'cheesecake de chocolate': 'assets/images/cheesecake_chocolate.png',
  'cheesecake de arandano': 'assets/images/cheesecake_arandano.png',
  'cheesecake de papayuela': 'assets/images/cheesecake_papayuela.png',
  'cheesecake de red velvet': 'assets/images/cheesecake_redvelvet.png',
  'refractaria familiar de cheesecake': 'assets/images/cheesecakes-grandes.jpg',
};

/// Devuelve la ruta de la foto empaquetada del producto, o `null` si no tiene.
///
/// El `null` es intencional y esperado: no todos los productos tienen foto, y
/// quien llama debe caer a la inicial en vez de asumir que siempre hay imagen.
String? rutaAssetDeProducto(String nombre) {
  if (nombre.trim().isEmpty) return null;
  return _archivoPorProducto[_clave(nombre)];
}
