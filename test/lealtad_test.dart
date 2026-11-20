import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/eventos.dart';
import 'package:super_dolores/dominio/excepciones.dart';
import 'package:super_dolores/dominio/lealtad.dart';
import 'package:super_dolores/dominio/monedero.dart';
import 'package:super_dolores/dominio/plataforma.dart';

final lunes = DateTime(2026, 11, 9, 10);

DateTime dia(int n, [int h = 10]) => DateTime(2026, 11, 9 + n, h);

int _n = 0;

String id() => 'e${++_n}';

EventoApp compra(DateTime fecha, int total, {String u = 'u1'}) =>
    PedidoCreado(id(), u, fecha, pedidoId: 'p', totalCentavos: total);

EventoApp viaje(DateTime fecha, int monto, {String u = 'u1'}) =>
    ViajeFinalizado(id(), u, fecha, viajeId: 'v', montoCentavos: monto);

EventoApp mensaje(DateTime fecha, {String u = 'u1'}) =>
    MensajeEnviado(id(), u, fecha, para: 'x');

EventoApp pago(DateTime fecha, {String u = 'u1'}) => PagoRealizado(
  id(),
  u,
  fecha,
  montoCentavos: 100,
  concepto: 'x',
  origen: Servicio.pagos,
);

Lealtad nueva() {
  final monedero = Monedero()..abrirCuenta('u1');

  return Lealtad(monedero);
}

void main() {
  setUp(() => _n = 0);

  group('Lealtad: puntos por gasto', () {
    test('1 punto por cada 10 pesos en compras y viajes', () {
      final l = nueva()
        ..alEvento(compra(lunes, 5600))
        ..alEvento(viaje(lunes, 8300));

      // 5 por compra + 8 por viaje + 50 por variedad.
      expect(l.puntos('u1'), 5 + 8 + 50);
    });

    test('un evento repetido no premia dos veces', () {
      final l = nueva();
      final e = compra(lunes, 10000);

      l.alEvento(e);
      l.alEvento(e);

      expect(l.puntos('u1'), 10);
    });

    test('mensajes y pagos no dan puntos por gasto', () {
      final l = nueva()
        ..alEvento(mensaje(lunes))
        ..alEvento(pago(lunes));

      expect(l.puntos('u1'), 50);
    });

    test('recibir dinero no genera puntos ni racha', () {
      final l = nueva()
        ..alEvento(
          DineroRecibido(id(), 'u1', lunes, de: 'x', montoCentavos: 999999),
        );

      expect(l.puntos('u1'), 0);
      expect(l.racha('u1'), 0);
    });
  });

  group('Lealtad: niveles', () {
    test('Bronce, Plata y Oro', () {
      final l = nueva()..alEvento(compra(lunes, 499000));

      expect(l.puntos('u1'), 499);
      expect(l.nivel('u1'), NivelLealtad.bronce);

      l.alEvento(compra(lunes, 1000));

      expect(l.puntos('u1'), 500);
      expect(l.nivel('u1'), NivelLealtad.plata);

      l.alEvento(compra(lunes, 1500000));

      expect(l.nivel('u1'), NivelLealtad.oro);
    });

    test('Plata obtiene 125 por ciento de puntos', () {
      final l = nueva()..alEvento(compra(lunes, 500000));

      l.alEvento(compra(lunes, 10000));

      expect(l.puntos('u1'), 512);
    });
  });

  group('Lealtad: bono semanal', () {
    test('2, 3 y 4 servicios generan bonos', () {
      final l = nueva()
        ..alEvento(mensaje(dia(0)))
        ..alEvento(compra(dia(1), 1000))
        ..alEvento(viaje(dia(2), 1000))
        ..alEvento(pago(dia(3)));

      expect(l.puntos('u1'), 1 + 50 + 1 + 100 + 200);
    });

    test('repetir un servicio no duplica el bono', () {
      final l = nueva()
        ..alEvento(mensaje(dia(0)))
        ..alEvento(pago(dia(0)))
        ..alEvento(mensaje(dia(1)))
        ..alEvento(pago(dia(1)));

      expect(l.puntos('u1'), 50);
    });

    test('la semana siguiente permite otro bono', () {
      final l = nueva()
        ..alEvento(mensaje(dia(0)))
        ..alEvento(pago(dia(1)))
        ..alEvento(mensaje(dia(7)))
        ..alEvento(pago(dia(8)));

      expect(l.puntos('u1'), 100);
    });

    test('domingo y lunes son semanas distintas', () {
      final l = nueva()
        ..alEvento(mensaje(dia(6)))
        ..alEvento(pago(dia(7)));

      expect(l.puntos('u1'), 0);
    });
  });

  group('Lealtad: rachas', () {
    test('7 días consecutivos generan 70 puntos', () {
      final l = nueva();

      for (var d = 0; d < 7; d++) {
        l.alEvento(mensaje(dia(d)));
      }

      expect(l.racha('u1'), 7);
      expect(l.puntos('u1'), 70);
    });

    test('varios eventos del mismo día cuentan una vez', () {
      final l = nueva()
        ..alEvento(mensaje(dia(0, 8)))
        ..alEvento(mensaje(dia(0, 20)));

      expect(l.racha('u1'), 1);
    });

    test('saltar un día reinicia la racha', () {
      final l = nueva()
        ..alEvento(mensaje(dia(0)))
        ..alEvento(mensaje(dia(1)))
        ..alEvento(mensaje(dia(3)));

      expect(l.racha('u1'), 1);
    });

    test('un evento atrasado no rompe la racha', () {
      final l = nueva()
        ..alEvento(mensaje(dia(1)))
        ..alEvento(mensaje(dia(0)));

      expect(l.racha('u1'), 1);
    });
  });

  group('Lealtad: canje', () {
    test('100 puntos equivalen a 10 pesos', () {
      final monedero = Monedero()..abrirCuenta('u1');

      final l = Lealtad(monedero)..alEvento(compra(lunes, 300000));

      final centavos = l.canjear('u1', 200);

      expect(centavos, 2000);
      expect(monedero.saldo('u1'), 2000);
      expect(l.puntos('u1'), 100);
    });

    test('solo múltiplos de 100 y saldo de puntos suficiente', () {
      final l = nueva()..alEvento(compra(lunes, 300000));

      expect(
        () => l.canjear('u1', 250),
        throwsA(isA<CanjeInvalidoException>()),
      );

      expect(() => l.canjear('u1', 0), throwsA(isA<CanjeInvalidoException>()));

      expect(
        () => l.canjear('u1', 400),
        throwsA(isA<CanjeInvalidoException>()),
      );

      expect(l.puntos('u1'), 300);
    });
  });

  group('Integración con Plataforma', () {
    test('la compra genera puntos automáticamente', () {
      final p = Plataforma(reloj: () => lunes)..cargarDatosDemo();

      final pedido = p.comercio.comprar(
        usuarioId: 'ana',
        tiendaId: 'tortilleria',
        items: {'kilo': 2},
        clave: 'compra-1',
      );

      expect(pedido.totalCentavos, 5600);
      expect(p.lealtad.puntos('ana'), 5);
    });

    test('usar chat y pagos genera bono por variedad', () {
      final p = Plataforma(reloj: () => lunes)..cargarDatosDemo();

      p.mensajes.enviar('ana', 'luis', 'Hola');

      p.mensajes.enviarDinero('ana', 'luis', 1000, clave: 'envio-1');

      expect(p.lealtad.puntos('ana'), 50);
      expect(p.lealtad.puntos('luis'), 0);
    });
  });
}
