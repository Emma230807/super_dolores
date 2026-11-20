import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/excepciones.dart';
import 'package:super_dolores/dominio/plataforma.dart';
import 'package:super_dolores/dominio/transporte.dart';

void main() {
  DateTime ahora = DateTime(2026, 11, 9, 10);

  const jardin = Punto(21.1561, -100.9333);
  const parroquia = Punto(21.1565, -100.9339);

  Plataforma nueva() {
    return Plataforma(reloj: () => ahora)..cargarDatosDemo();
  }

  setUp(() {
    ahora = DateTime(2026, 11, 9, 10);
  });

  group('Mini-apps, permisos y kill switch', () {
    test('no se puede registrar dos veces la misma mini-app', () {
      final p = nueva();

      expect(
        () => p.registro.registrar(Plataforma.miniChat),
        throwsArgumentError,
      );
    });

    test('una mini-app de terceros no accede a servicios privados', () {
      final p = nueva();
      final ctx = p.contextoPara(Plataforma.miniHoroscopo, 'ana');

      expect(() => ctx.monedero, throwsA(isA<PermisoDenegadoException>()));

      expect(() => ctx.pagos, throwsA(isA<PermisoDenegadoException>()));

      expect(() => ctx.mensajes, throwsA(isA<PermisoDenegadoException>()));

      expect(() => ctx.comercio, throwsA(isA<PermisoDenegadoException>()));

      expect(() => ctx.viajes, throwsA(isA<PermisoDenegadoException>()));
    });

    test('el chat puede enviar dinero pero no consultar saldo', () {
      final p = nueva();
      final ctx = p.contextoPara(Plataforma.miniChat, 'ana');

      expect(() => ctx.monedero, throwsA(isA<PermisoDenegadoException>()));

      ctx.pagos.enviarDinero('luis', 1000, clave: 'x');

      expect(p.monedero.saldo('ana'), 99000);
      expect(p.monedero.saldo('luis'), 101000);
    });

    test('las operaciones quedan asociadas al usuario', () {
      final p = nueva();
      final ctx = p.contextoPara(Plataforma.miniMonedero, 'ana');

      expect(ctx.monedero.saldo(), p.monedero.saldo('ana'));

      ctx.pagos.pagar(1000, 'Algo', clave: 'k');

      expect(p.monedero.saldo('ana'), 99000);
      expect(p.monedero.saldo('luis'), 100000);
    });

    test('kill switch: apagar bloquea y encender restaura', () {
      final p = nueva();
      final ctx = p.contextoPara(Plataforma.miniChat, 'ana');

      p.registro.apagar('chat');

      expect(p.registro.activas.map((a) => a.id), isNot(contains('chat')));

      expect(() => ctx.mensajes, throwsA(isA<MiniAppNoDisponibleException>()));

      p.registro.encender('chat');

      expect(() => ctx.mensajes, returnsNormally);
    });

    test('una mini-app no modifica viajes de otro usuario', () {
      final p = nueva();

      final ana = p.contextoPara(Plataforma.miniViajes, 'ana').viajes;

      final luis = p.contextoPara(Plataforma.miniViajes, 'luis').viajes;

      final viaje = ana.solicitar(jardin, parroquia);

      expect(
        () => luis.cancelar(viaje.id),
        throwsA(isA<PedidoInvalidoException>()),
      );
    });

    test('apagar una mini-app bloquea una API ya obtenida', () {
      final p = nueva();
      final ctx = p.contextoPara(Plataforma.miniMonedero, 'ana');

      final api = ctx.monedero;
      p.registro.apagar('monedero');

      expect(() => api.saldo(), throwsA(isA<MiniAppNoDisponibleException>()));
    });
  });
}
