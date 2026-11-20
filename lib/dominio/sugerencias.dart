import 'eventos.dart';

/// Recomendación de un servicio.
class Sugerencia {
  final Servicio servicio;
  final String razon;

  const Sugerencia(this.servicio, this.razon);
}

/// Recomienda un servicio según la hora y el uso reciente.
Sugerencia sugerirServicio({
  required Map<Servicio, int> usosUltimos30Dias,
  required DateTime ahora,
}) {
  final hora = ahora.hour;

  final orden = switch (hora) {
    >= 6 && < 11 => [
      Servicio.transporte,
      Servicio.mensajeria,
      Servicio.comercio,
      Servicio.pagos,
    ],
    >= 11 && < 16 => [
      Servicio.comercio,
      Servicio.pagos,
      Servicio.mensajeria,
      Servicio.transporte,
    ],
    >= 16 && < 22 => [
      Servicio.mensajeria,
      Servicio.comercio,
      Servicio.transporte,
      Servicio.pagos,
    ],
    _ => [
      Servicio.mensajeria,
      Servicio.pagos,
      Servicio.comercio,
      Servicio.transporte,
    ],
  };

  // Recomendar primero un servicio no utilizado.
  for (final servicio in orden) {
    if ((usosUltimos30Dias[servicio] ?? 0) == 0) {
      return Sugerencia(
        servicio,
        'Aún no pruebas ${servicio.nombre}. '
        '¡Descúbrelo!',
      );
    }
  }

  // Si ya conoce todos, elegir el menos utilizado.
  var menor = orden.first;

  for (final servicio in orden) {
    if ((usosUltimos30Dias[servicio] ?? 0) < (usosUltimos30Dias[menor] ?? 0)) {
      menor = servicio;
    }
  }

  return Sugerencia(
    menor,
    'Vuelve a ${menor.nombre}: '
    'es el que menos usas.',
  );
}
