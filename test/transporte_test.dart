import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/eventos.dart';
import 'package:super_dolores/dominio/excepciones.dart';
import 'package:super_dolores/dominio/monedero.dart';
import 'package:super_dolores/dominio/transporte.dart';

void main() {
  final ahora = DateTime(2026, 11, 9, 10);

  const jardin = Punto(21.1561, -100.9333);
  const parroquia = Punto(21.1565, -100.9339);
  const utng = Punto(21.1325, -100.9267);

  late Monedero monedero;
  late BusEventos bus;
  late ServicioViajes viajes;
  late List<EventoApp> eventos;

  void preparar({bool conSaldo = true}) {
    monedero = Monedero(reloj: () => ahora)
      ..abrirCuenta('ana')
      ..abrirCuenta('luis')
      ..abrirCuenta('plataforma', sinLimites: true)
      ..abrirCuenta('conductor1');

    if (conSaldo) {
      monedero.depositar('ana', 100000, clave: 'inicial');
    }

    bus = BusEventos();
    eventos = [];

    bus.suscribir<EventoApp>((evento) => eventos.add(evento));

    viajes = ServicioViajes(monedero, bus, Ids(), () => ahora);
  }

  setUp(() => preparar());

  group('Distancias', () {
    test('un grado de longitud en el ecuador', () {
      expect(
        distanciaKm(const Punto(0, 0), const Punto(0, 1)),
        closeTo(111.195, 0.01),
      );
    });

    test('distancia cero y simetría', () {
      expect(distanciaKm(jardin, jardin), 0);

      expect(
        distanciaKm(jardin, utng),
        closeTo(distanciaKm(utng, jardin), 1e-9),
      );

      expect(distanciaKm(jardin, utng), closeTo(2.712, 0.01));
    });
  });

  group('Tarifas', () {
    test('tarifa base más kilómetros y minutos', () {
      expect(Tarifa.calcular(km: 5, minutos: 12), 8300);
    });

    test('tarifa dinámica respeta el mínimo y máximo', () {
      expect(Tarifa.calcular(km: 5, minutos: 12, multiplicador: 1.5), 12450);

      expect(Tarifa.calcular(km: 5, minutos: 12, multiplicador: 3), 16600);

      expect(Tarifa.calcular(km: 5, minutos: 12, multiplicador: 0.5), 8300);
    });

    test('viaje corto paga la tarifa mínima', () {
      expect(Tarifa.calcular(km: 0.5, minutos: 2), Tarifa.minimoCentavos);
    });

    test('minutos estimados a 25 km/h', () {
      expect(Tarifa.minutosEstimados(5), 12);
      expect(Tarifa.minutosEstimados(10), 24);
      expect(Tarifa.minutosEstimados(2.5), 6);
    });

    test('la estimación utiliza la distancia', () {
      expect(viajes.estimar(jardin, utng), 5720);

      expect(viajes.estimar(jardin, parroquia), Tarifa.minimoCentavos);
    });
  });

  group('Servicio de viajes', () {
    test('solicitar requiere saldo suficiente', () {
      preparar(conSaldo: false);

      expect(
        () => viajes.solicitar('ana', jardin, utng),
        throwsA(isA<SaldoInsuficienteException>()),
      );
    });

    test('viaje completo cobra y reparte comisión', () {
      final antes =
          monedero.saldo('ana') +
          monedero.saldo('plataforma') +
          monedero.saldo('conductor1');

      final viaje = viajes.solicitar('ana', jardin, utng);

      expect(viaje.estado, EstadoViaje.solicitado);
      expect(monedero.saldo('ana'), 100000);

      viajes.aceptar(viaje.id, 'conductor1');
      viajes.iniciar(viaje.id);

      final terminado = viajes.finalizar(viaje.id, kmReal: 5, minutosReal: 12);

      expect(terminado.estado, EstadoViaje.finalizado);
      expect(terminado.cobradoCentavos, 8300);

      expect(monedero.saldo('ana'), 91700);
      expect(monedero.saldo('conductor1'), 6640);
      expect(monedero.saldo('plataforma'), 1660);

      final despues =
          monedero.saldo('ana') +
          monedero.saldo('plataforma') +
          monedero.saldo('conductor1');

      expect(despues, antes);

      expect(eventos.whereType<PagoRealizado>().length, 1);
      expect(eventos.whereType<ViajeFinalizado>().length, 1);
    });

    test('transiciones inválidas no alteran el viaje', () {
      final viaje = viajes.solicitar('ana', jardin, utng);

      expect(
        () => viajes.iniciar(viaje.id),
        throwsA(isA<TransicionInvalidaException>()),
      );

      expect(
        () => viajes.finalizar(viaje.id, kmReal: 1, minutosReal: 1),
        throwsA(isA<TransicionInvalidaException>()),
      );

      expect(viajes.porId(viaje.id)!.estado, EstadoViaje.solicitado);

      viajes.aceptar(viaje.id, 'conductor1');
      viajes.iniciar(viaje.id);

      expect(
        () => viajes.cancelar(viaje.id),
        throwsA(isA<TransicionInvalidaException>()),
      );

      viajes.finalizar(viaje.id, kmReal: 3, minutosReal: 8);

      expect(
        () => viajes.finalizar(viaje.id, kmReal: 3, minutosReal: 8),
        throwsA(isA<TransicionInvalidaException>()),
      );
    });

    test('cancelar antes de aceptar es gratis', () {
      final viaje = viajes.solicitar('ana', jardin, utng);

      final cancelado = viajes.cancelar(viaje.id);

      expect(cancelado.estado, EstadoViaje.cancelado);
      expect(monedero.saldo('ana'), 100000);
    });

    test('cancelar después de aceptar cuesta 15 pesos', () {
      final viaje = viajes.solicitar('ana', jardin, utng);

      viajes.aceptar(viaje.id, 'conductor1');
      viajes.cancelar(viaje.id);

      expect(monedero.saldo('ana'), 98500);
      expect(monedero.saldo('conductor1'), 1500);
    });

    test('cancelación cobra solo el saldo disponible', () {
      preparar(conSaldo: false);

      monedero.depositar('ana', 5000, clave: 'd');

      final viaje = viajes.solicitar('ana', jardin, parroquia);

      viajes.aceptar(viaje.id, 'conductor1');

      monedero.transferir('ana', 'luis', 4000, 'x', clave: 't');

      viajes.cancelar(viaje.id);

      expect(monedero.saldo('ana'), 0);
      expect(monedero.saldo('conductor1'), 1000);
    });
  });
}
