/// Conversion de los valores que llegan del backend a numeros de Dart.
///
/// ESTE ARCHIVO EXISTE POR UNA RAZON MUY CONCRETA: en MySQL las columnas
/// `decimal(10,2)` (los precios, los totales, los promedios) NO son numeros
/// JSON, son cadenas. Laravel las devuelve tal cual, asi que el mismo endpoint
/// puede mandar `"price": 4500` un dia y `"price": "4500.00" al siguiente,
/// segun como se haya escrito el dato en la base.
///
/// Si el codigo hace `json['price'] as double`, la app funciona con algunos
/// productos y revienta con otros, y el error aparece en produccion y no en
/// desarrollo. Por eso TODO numero que venga del JSON pasa por [aDoble] o
/// [aEntero], que aceptan las dos formas sin lanzar excepcion.
///
/// [aDoble] tolera ademas el formato que usa Laravel cuando un `decimal` se
/// serializa con notacion cientifica o con separador de miles.
library;

/// Convierte cualquier valor JSON a `double`, sin lanzar excepcion.
///
/// Devuelve [porDefecto] si el valor no es convertible, que es preferible a
/// que la app se caiga: un precio ilegible se muestra como 0 y se nota, pero
/// una exception tumba la pantalla completa.
///
/// Casos que cubre:
/// - `null`, ausente o texto vacio -> `porDefecto`
/// - `4500` (int de JSON) -> `4500.0`
/// - `"4500.00"` (decimal de MySQL) -> `4500.0`
/// - `"1,500.50"` (separador de miles) -> `1500.5`
/// - `"abc"` -> `porDefecto`
double aDoble(dynamic valor, {double porDefecto = 0}) {
  if (valor == null) return porDefecto;

  if (valor is num) {
    if (valor.isNaN || valor.isInfinite) return porDefecto;
    return valor.toDouble();
  }

  if (valor is String) {
    final texto = valor.trim();
    if (texto.isEmpty) return porDefecto;

    // `NumberFormat` de intl y algunos joins de MySQL dejan el separador de
    // miles pegado ("1,500.50"). Se quitan las comas antes de convertir.
    final sinSeparadores = texto.replaceAll(',', '');

    return double.tryParse(sinSeparadores) ?? porDefecto;
  }

  return porDefecto;
}

/// Igual que [aDoble] pero devuelve un `int` ya redondeado.
///
/// Se usa para cantidades y conteos, donde un 2.7 no tiene sentido: dos
/// unidades redondean a 3.
int aEntero(dynamic valor, {int porDefecto = 0}) {
  if (valor == null) return porDefecto;

  if (valor is int) return valor;

  if (valor is double || valor is num) {
    if (valor.isNaN || valor.isInfinite) return porDefecto;
    return valor.round();
  }

  if (valor is String) {
    return aDoble(valor, porDefecto: porDefecto.toDouble()).round();
  }

  return porDefecto;
}

/// Convierte un valor JSON a `bool`.
///
/// Laravel devuelve `is_default` como `0`/`1` cuando viene de MySQL y como
/// `true`/`false` cuando se acaba de crear. Los dos casos ocurren en la misma
/// app, asi que se aceptan los dos.
///
/// POR QUE EXISTE ESTE PARAMETRO. Un `as bool?` sobre `"active": 1` revienta:
/// `int` no es `bool`, y el `TypeError` terminaba bowledo con un mensaje de
/// error de red que no tenia nada que ver. El defecto va aqui y no en cada
/// modelo porque el valor "si la clave no viene" NO es el mismo en todos: para
/// `Producto.activo` tiene que ser `true` (un producto sin el campo esta
/// activo) y para `Direccion.esPredeterminada` es `false`. Con [porDefecto] cada
/// modelo declara su caso una vez y no puede olvidarse de reescribirlo despues.
bool aBooleano(dynamic valor, {bool porDefecto = false}) {
  if (valor == null) return porDefecto;
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;
  if (valor is String) {
    final texto = valor.trim().toLowerCase();
    return texto == 'true' || texto == '1' || texto == 'yes';
  }
  return porDefecto;
}

/// Lee una fecha del backend sin romperse.
///
/// Laravel puede mandar `"2026-09-30 15:45:00"` (con espacio) o ISO
/// `"2026-09-30T15:45:00.000000Z"` (con `T` y milisegundos). `DateTime.parse`
/// solo entiende el segundo formato, asi que se cambia el espacio por `T`.
/// Si aun asi no se puede leer, se devuelve `null` en vez de lanzar.
DateTime? aFecha(dynamic valor) {
  if (valor == null) return null;

  if (valor is DateTime) return valor;

  if (valor is String) {
    final texto = valor.trim();
    if (texto.isEmpty) return null;

    final normalizado = texto.contains('T')
        ? texto
        : texto.replaceFirst(' ', 'T');

    return DateTime.tryParse(normalizado) ?? DateTime.tryParse(texto);
  }

  return null;
}
