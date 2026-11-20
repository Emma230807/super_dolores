import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/analitica.dart';
import 'package:super_dolores/dominio/eventos.dart';

void main() {
  late Analitica analitica;

  DateTime nov(int dia) => DateTime(2026, 11, dia);

  setUp(() {
    analitica = Analitica();

    void registrar(String usuario, Servicio servicio, int dia) {
      analitica.agregar(
        RegistroUso(usuario, servicio, DateTime(2026, 11, dia, 12)),
      );
    }

    registrar('A', Servicio.mensajeria, 1);
    registrar('A', Servicio.comercio, 2);
    registrar('A', Servicio.mensajeria, 8);

    registrar('B', Servicio.pagos, 1);

    registrar('C', Servicio.transporte, 1);
    registrar('C', Servicio.transporte, 2);

    registrar('D', Servicio.mensajeria, 2);
    registrar('D', Servicio.pagos, 9);

    registrar('E', Servicio.comercio, 2);
  });

  group('Analítica de retención', () {
    test('DAU, WAU y MAU', () {
      expect(analitica.dau(nov(2)), 4);
      expect(analitica.wau(nov(2)), 5);
      expect(analitica.mau(nov(2)), 5);

      expect(analitica.dau(nov(8)), 1);
      expect(analitica.wau(nov(8)), 4);
      expect(analitica.mau(nov(8)), 5);
    });

    test('stickiness = DAU / MAU', () {
      expect(analitica.stickiness(nov(2)), closeTo(0.8, 1e-9));

      expect(analitica.stickiness(nov(8)), closeTo(0.2, 1e-9));

      expect(Analitica().stickiness(nov(1)), 0);
    });

    test('cohortes de usuarios', () {
      expect(analitica.cohorte(nov(1)), {'A', 'B', 'C'});

      expect(analitica.cohorte(nov(2)), {'D', 'E'});

      expect(analitica.primerDia('D'), nov(2));

      expect(analitica.primerDia('nadie'), isNull);
    });

    test('retención D1 y D7', () {
      expect(analitica.retencion(nov(1), 1), closeTo(2 / 3, 1e-9));

      expect(analitica.retencion(nov(1), 7), closeTo(1 / 3, 1e-9));

      expect(analitica.retencion(nov(2), 7), closeTo(1 / 2, 1e-9));

      expect(analitica.retencion(nov(2), 1), 0);

      expect(analitica.retencion(nov(20), 1), 0);
    });

    test('servicios por usuario y porcentaje multiservicio', () {
      expect(analitica.serviciosPorUsuario(nov(1), nov(9)), closeTo(1.4, 1e-9));

      expect(
        analitica.porcentajeMultiservicio(nov(1), nov(9)),
        closeTo(0.4, 1e-9),
      );

      expect(analitica.porcentajeMultiservicio(nov(1), nov(9), minimo: 1), 1.0);
    });

    test('retención de semana 2 según servicios de semana 1', () {
      final resultado = analitica.retencionSemana2PorServicios(nov(1), nov(2));

      expect(resultado.nUno, 4);

      expect(resultado.unServicio, closeTo(0.25, 1e-9));

      expect(resultado.nMulti, 1);
      expect(resultado.multiservicio, 1.0);
    });

    test('los eventos pasivos no cuentan como actividad', () {
      final bus = BusEventos();
      final a = Analitica()..conectar(bus);

      bus.publicar(
        DineroRecibido('e1', 'u', nov(1), de: 'x', montoCentavos: 1),
      );

      bus.publicar(MensajeEnviado('e2', 'u', nov(1), para: 'x'));

      expect(a.registros.length, 1);
      expect(a.dau(nov(1)), 1);
    });
  });
}
