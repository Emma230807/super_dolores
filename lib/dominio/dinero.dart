// Dinero expresado en centavos enteros.
// Ejemplo: $1,250.00 = 125000 centavos.

String formatearPesos(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();

  final pesos = (abs ~/ 100).toString();
  final cents = (abs % 100).toString().padLeft(2, '0');

  final conComas = pesos.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  return '${negativo ? '-' : ''}\$$conComas.$cents';
}

/// Calcula porcentajes utilizando números enteros.
int porcentaje(int centavos, int pct) => (centavos * pct + 50) ~/ 100;

/// Elimina la información de hora de una fecha.
DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

/// Obtiene el lunes de la semana de una fecha.
DateTime lunesDe(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Suma días a una fecha.
DateTime masDias(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
