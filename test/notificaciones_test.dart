import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/notificaciones.dart';
import 'package:super_dolores/dominio/plataforma.dart';
import 'package:super_dolores/dominio/transporte.dart';

void main() {
  DateTime dia(int n, [int hora = 10]) {
    return DateTime(2026, 11, 9 + n, hora);
  }

  Notificacion promo(DateTime fecha, {String usuario = 'u1'}) {
    return Notificacion(
      usuario,
      TipoNotificacion.promocional,
      'Oferta',
      '...',
      fecha,
    );
  }

  Notificacion trans(DateTime fecha) {
    return Notificacion(
      'u1',
      TipoNotificacion.transaccional,
      'Aviso',
      '...',
      fecha,
    );
  }

  group('Notificaciones éticas', () {
    test('máximo 2 promociones por día', () {
      final n = Notificador();

      expect(n.intentar(promo(dia(0, 9))), isTrue);
      expect(n.intentar(promo(dia(0, 12))), isTrue);
      expect(n.intentar(promo(dia(0, 15))), isFalse);

      expect(n.intentar(promo(dia(1, 9))), isTrue);
    });

    test('horario de silencio de 22:00 a 08:00', () {
      final n = Notificador();

      expect(n.intentar(promo(dia(0, 22))), isFalse);
      expect(n.intentar(promo(dia(0, 23))), isFalse);
      expect(n.intentar(promo(dia(0, 7))), isFalse);

      expect(n.intentar(promo(dia(0, 8))), isTrue);
      expect(n.intentar(promo(dia(0, 21))), isTrue);
    });

    test('las notificaciones transaccionales pasan siempre', () {
      final n = Notificador();

      for (var i = 0; i < 5; i++) {
        expect(n.intentar(trans(dia(0, 3))), isTrue);
      }

      expect(n.de('u1').length, 5);
    });

    test('se pueden desactivar las promociones', () {
      final n = Notificador()..configurarPromociones('u1', activas: false);

      expect(n.intentar(promo(dia(0, 12))), isFalse);
      expect(n.intentar(trans(dia(0, 12))), isTrue);

      n.configurarPromociones('u1', activas: true);

      expect(n.intentar(promo(dia(0, 12))), isTrue);
    });

    test('el límite de promociones es por persona', () {
      final n = Notificador();

      n.intentar(promo(dia(0, 9)));
      n.intentar(promo(dia(0, 10)));

      expect(n.intentar(promo(dia(0, 11), usuario: 'u2')), isTrue);
    });
  });

  group('Integración con Plataforma', () {
    test('una compra genera aviso para el comprador', () {
      final p = Plataforma(reloj: () => DateTime(2026, 11, 9, 10))
        ..cargarDatosDemo();

      p.comercio.comprar(
        usuarioId: 'ana',
        tiendaId: 'tortilleria',
        items: {'kilo': 2},
        clave: 'compra-1',
      );

      expect(p.notificador.de('ana').single.titulo, 'Pedido confirmado');

      expect(
        p.notificador.de('dueno-tortilleria').single.titulo,
        'Te llegó dinero',
      );
    });

    test('enviar dinero genera aviso al destinatario', () {
      final p = Plataforma(reloj: () => DateTime(2026, 11, 9, 10))
        ..cargarDatosDemo();

      p.mensajes.enviarDinero('ana', 'luis', 5000, clave: 'envio-1');

      expect(p.notificador.de('luis').single.titulo, 'Te llegó dinero');

      expect(p.notificador.de('luis').single.cuerpo, contains(r'$50.00'));
    });

    test('finalizar un viaje genera un aviso', () {
      final p = Plataforma(reloj: () => DateTime(2026, 11, 9, 10))
        ..cargarDatosDemo();

      final viaje = p.viajes.solicitar(
        'ana',
        const Punto(21.1561, -100.9333),
        const Punto(21.1325, -100.9267),
      );

      p.viajes.aceptar(viaje.id, 'conductor1');
      p.viajes.iniciar(viaje.id);

      p.viajes.finalizar(viaje.id, kmReal: 5, minutosReal: 12);

      expect(p.notificador.de('ana').single.titulo, 'Viaje finalizado');
    });
  });
}
