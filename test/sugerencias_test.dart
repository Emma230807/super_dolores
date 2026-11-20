import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/eventos.dart';
import 'package:super_dolores/dominio/sugerencias.dart';

void main() {
  DateTime hora(int h) => DateTime(2026, 11, 9, h);

  group('Sugerencias', () {
    test('recomienda servicios según la hora', () {
      expect(
        sugerirServicio(usosUltimos30Dias: {}, ahora: hora(9)).servicio,
        Servicio.transporte,
      );

      expect(
        sugerirServicio(usosUltimos30Dias: {}, ahora: hora(13)).servicio,
        Servicio.comercio,
      );

      expect(
        sugerirServicio(usosUltimos30Dias: {}, ahora: hora(19)).servicio,
        Servicio.mensajeria,
      );

      expect(
        sugerirServicio(usosUltimos30Dias: {}, ahora: hora(23)).servicio,
        Servicio.mensajeria,
      );

      expect(
        sugerirServicio(usosUltimos30Dias: {}, ahora: hora(3)).servicio,
        Servicio.mensajeria,
      );
    });

    test('omite los servicios que ya utiliza', () {
      final sugerencia = sugerirServicio(
        usosUltimos30Dias: {Servicio.transporte: 5},
        ahora: hora(9),
      );

      expect(sugerencia.servicio, Servicio.mensajeria);
    });

    test('recomienda el menos usado cuando conoce todos', () {
      final sugerencia = sugerirServicio(
        usosUltimos30Dias: {
          Servicio.transporte: 5,
          Servicio.mensajeria: 3,
          Servicio.comercio: 1,
          Servicio.pagos: 2,
        },
        ahora: hora(9),
      );

      expect(sugerencia.servicio, Servicio.comercio);
    });
  });
}
