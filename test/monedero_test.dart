import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/excepciones.dart';
import 'package:super_dolores/dominio/monedero.dart';

void main() {
  DateTime ahora = DateTime(2026, 11, 9, 10);

  Monedero monederoConCuentas() {
    final m = Monedero(reloj: () => ahora)
      ..abrirCuenta('ana')
      ..abrirCuenta('luis');

    return m;
  }

  setUp(() {
    ahora = DateTime(2026, 11, 9, 10);
  });

  group('Monedero (libro de movimientos)', () {
    test('el saldo es la suma de los movimientos', () {
      final m = monederoConCuentas();

      m.depositar('ana', 10000, clave: 'a');
      m.pagar('ana', 2500, 'Café', clave: 'b');

      expect(m.saldo('ana'), 7500);
      expect(m.movimientos('ana').length, 2);
      expect(m.movimientos('ana').first.concepto, 'Café');
    });

    test('no se puede pagar más de lo que hay', () {
      final m = monederoConCuentas()..depositar('ana', 1000, clave: 'a');

      expect(
        () => m.pagar('ana', 1001, 'x', clave: 'b'),
        throwsA(isA<SaldoInsuficienteException>()),
      );

      expect(m.saldo('ana'), 1000);
    });

    test('montos inválidos y tope por operación', () {
      final m = monederoConCuentas();

      expect(
        () => m.depositar('ana', 0, clave: 'a'),
        throwsA(isA<MontoInvalidoException>()),
      );

      expect(
        () => m.depositar('ana', -5, clave: 'b'),
        throwsA(isA<MontoInvalidoException>()),
      );

      expect(
        () => m.depositar('ana', Monedero.maxPorOperacion + 1, clave: 'c'),
        throwsA(isA<LimiteExcedidoException>()),
      );

      m.depositar('ana', Monedero.maxPorOperacion, clave: 'd');
    });

    test('transferir conserva la suma del dinero', () {
      final m = monederoConCuentas()..depositar('ana', 10000, clave: 'a');

      final antes = m.saldo('ana') + m.saldo('luis');

      m.transferir('ana', 'luis', 4000, 'Regalo', clave: 't1');

      expect(m.saldo('ana'), 6000);
      expect(m.saldo('luis'), 4000);

      expect(m.saldo('ana') + m.saldo('luis'), antes);
    });

    test('transferir es TODO o NADA', () {
      final m = monederoConCuentas()..depositar('ana', 1000, clave: 'a');

      expect(
        () => m.transferir('ana', 'luis', 5000, 'x', clave: 't'),
        throwsA(isA<SaldoInsuficienteException>()),
      );

      expect(m.movimientos('luis'), isEmpty);
      expect(m.movimientos('ana').length, 1);
    });

    test('no se puede transferir a uno mismo ni a cuenta inexistente', () {
      final m = monederoConCuentas()..depositar('ana', 1000, clave: 'a');

      expect(
        () => m.transferir('ana', 'ana', 100, 'x', clave: 't'),
        throwsA(isA<DestinatarioInvalidoException>()),
      );

      expect(
        () => m.transferir('ana', 'fantasma', 100, 'x', clave: 't'),
        throwsA(isA<CuentaNoExisteException>()),
      );
    });

    test('IDEMPOTENCIA: repetir la clave no cobra dos veces', () {
      final m = monederoConCuentas()..depositar('ana', 10000, clave: 'a');

      final a = m.pagar('ana', 3000, 'Taxi', clave: 'k1');

      final b = m.pagar('ana', 3000, 'Taxi', clave: 'k1');

      expect(identical(a, b), isTrue);
      expect(m.saldo('ana'), 7000);

      m.transferir('ana', 'luis', 1000, 'x', clave: 'k2');

      m.transferir('ana', 'luis', 1000, 'x', clave: 'k2');

      expect(m.saldo('luis'), 1000);
    });

    test('límite diario de salidas y renovación al día siguiente', () {
      final m = monederoConCuentas();

      for (var i = 0; i < 3; i++) {
        m.depositar('ana', 500000, clave: 'd$i');
      }

      m.pagar('ana', 500000, 'a', clave: 'p1');
      m.pagar('ana', 500000, 'b', clave: 'p2');

      expect(
        () => m.pagar('ana', 100, 'c', clave: 'p3'),
        throwsA(isA<LimiteExcedidoException>()),
      );

      expect(m.salidasDeHoy('ana'), 1000000);

      ahora = DateTime(2026, 11, 10, 9);

      m.pagar('ana', 100, 'c', clave: 'p3');
    });

    test('cuentas de la plataforma sin límite diario', () {
      final m = Monedero(reloj: () => ahora)
        ..abrirCuenta('plataforma', sinLimites: true)
        ..abrirCuenta('dueno');

      for (var i = 0; i < 5; i++) {
        m.depositar('plataforma', 500000, clave: 'd$i');
      }

      for (var i = 0; i < 5; i++) {
        m.transferir('plataforma', 'dueno', 500000, 'x', clave: 't$i');
      }

      expect(m.saldo('dueno'), 2500000);
    });

    test('reembolso devuelve dinero y valida monto', () {
      final m = monederoConCuentas();

      m.reembolsar('ana', 1000, 'Canje', clave: 'r');

      expect(m.saldo('ana'), 1000);

      expect(
        () => m.reembolsar('ana', 0, 'x', clave: 'r2'),
        throwsA(isA<MontoInvalidoException>()),
      );
    });
  });
}
