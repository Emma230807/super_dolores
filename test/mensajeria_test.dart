import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/eventos.dart';
import 'package:super_dolores/dominio/excepciones.dart';
import 'package:super_dolores/dominio/mensajeria.dart';
import 'package:super_dolores/dominio/monedero.dart';

void main() {
  late Monedero monedero;
  late BusEventos bus;
  late ServicioMensajes mensajes;
  late List<EventoApp> eventos;

  final ahora = DateTime(2026, 11, 9, 10);

  setUp(() {
    monedero = Monedero(reloj: () => ahora)
      ..abrirCuenta('ana')
      ..abrirCuenta('luis')
      ..abrirCuenta('marta');

    monedero.depositar('ana', 100000, clave: 'inicial-ana');

    monedero.depositar('luis', 100000, clave: 'inicial-luis');

    bus = BusEventos();
    eventos = [];

    bus.suscribir<EventoApp>((evento) => eventos.add(evento));

    mensajes = ServicioMensajes(monedero, bus, Ids(), () => ahora);
  });

  group('Mensajería', () {
    test('valida mensajes vacíos, enormes y destinatarios', () {
      expect(
        () => mensajes.enviar('ana', 'luis', '   '),
        throwsA(isA<MensajeInvalidoException>()),
      );

      expect(
        () => mensajes.enviar('ana', 'luis', 'x' * 1001),
        throwsA(isA<MensajeInvalidoException>()),
      );

      mensajes.enviar('ana', 'luis', 'x' * 1000);

      expect(
        () => mensajes.enviar('ana', 'ana', 'hola'),
        throwsA(isA<DestinatarioInvalidoException>()),
      );

      expect(
        () => mensajes.enviar('ana', ServicioMensajes.sistema, 'hola'),
        throwsA(isA<DestinatarioInvalidoException>()),
      );
    });

    test('conversación en orden y mensajes no leídos', () {
      mensajes.enviar('ana', 'luis', 'Hola');
      mensajes.enviar('luis', 'ana', 'Qué tal');
      mensajes.enviar('ana', 'luis', 'Bien');

      expect(mensajes.conversacion('ana', 'luis').map((m) => m.texto), [
        'Hola',
        'Qué tal',
        'Bien',
      ]);

      expect(mensajes.noLeidos('luis'), 2);

      mensajes.marcarLeidos('luis', 'ana');

      expect(mensajes.noLeidos('luis'), 0);
      expect(mensajes.noLeidos('ana'), 1);
    });

    test('resúmenes: chat más reciente primero', () {
      mensajes.enviar('luis', 'ana', 'uno');
      mensajes.enviar('marta', 'ana', 'dos');
      mensajes.enviar('luis', 'ana', 'tres');

      final resumenes = mensajes.resumenes('ana');

      expect(resumenes.map((x) => x.con), ['luis', 'marta']);

      expect(resumenes.first.noLeidos, 2);
    });

    test('mensajes del sistema no generan eventos', () {
      mensajes.enviarSistema('ana', 'Bienvenida');

      expect(eventos, isEmpty);
      expect(mensajes.deSistema('ana').length, 1);
      expect(mensajes.deSistema('ana').single.tipo, TipoMensaje.sistema);
    });

    test('enviar dinero transfiere y publica eventos', () {
      final mensaje = mensajes.enviarDinero('ana', 'luis', 5000, clave: 'c1');

      expect(mensaje.tipo, TipoMensaje.dinero);

      expect(monedero.saldo('ana'), 95000);
      expect(monedero.saldo('luis'), 105000);

      expect(eventos.whereType<PagoRealizado>().length, 1);

      expect(eventos.whereType<DineroRecibido>().length, 1);

      expect(eventos.whereType<MensajeEnviado>().length, 1);

      expect(eventos.whereType<DineroRecibido>().single.cuentaComoUso, isFalse);
    });

    test('sin saldo no se envía dinero ni mensaje', () {
      mensajes.enviarDinero('ana', 'luis', 50000, clave: 'c1');

      expect(
        () => mensajes.enviarDinero('ana', 'luis', 60000, clave: 'c2'),
        throwsA(isA<SaldoInsuficienteException>()),
      );

      expect(mensajes.conversacion('ana', 'luis').length, 1);

      expect(monedero.saldo('ana'), 50000);
      expect(monedero.saldo('luis'), 150000);
    });
  });
}
