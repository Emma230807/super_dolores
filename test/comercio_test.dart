import 'package:flutter_test/flutter_test.dart';

import 'package:super_dolores/dominio/comercio.dart';
import 'package:super_dolores/dominio/eventos.dart';
import 'package:super_dolores/dominio/excepciones.dart';
import 'package:super_dolores/dominio/monedero.dart';

void main() {
  final ahora = DateTime(2026, 11, 9, 10);

  late Monedero monedero;
  late BusEventos bus;
  late ServicioComercio comercio;
  late List<EventoApp> eventos;

  setUp(() {
    monedero = Monedero(reloj: () => ahora)
      ..abrirCuenta('ana')
      ..abrirCuenta('plataforma', sinLimites: true)
      ..abrirCuenta('dueno-tortilleria')
      ..abrirCuenta('dueno-cajeta')
      ..abrirCuenta('dueno-talavera');

    monedero.depositar('ana', 100000, clave: 'saldo-inicial');

    bus = BusEventos();
    eventos = [];

    bus.suscribir<EventoApp>((evento) => eventos.add(evento));

    final tiendas = [
      Tienda('tortilleria', 'Tortillería', '🌽', 'dueno-tortilleria', [
        ProductoTienda('kilo', 'Tortillas', 2800, 50),
      ]),
      Tienda('cajeta', 'Dulcería de cajeta', '🍬', 'dueno-cajeta', [
        ProductoTienda('cajeta', 'Cajeta', 8500, 20),
        ProductoTienda('alegrias', 'Alegrías', 1200, 30),
      ]),
      Tienda('talavera', 'Taller de talavera', '🏺', 'dueno-talavera', [
        ProductoTienda('taza', 'Taza', 15000, 6),
        ProductoTienda('jarron', 'Jarrón', 125000, 4),
      ]),
    ];

    comercio = ServicioComercio(monedero, bus, Ids(), () => ahora, tiendas);
  });

  group('Comercio', () {
    test('compra: comisión del 5% e inventario', () {
      final pedido = comercio.comprar(
        usuarioId: 'ana',
        tiendaId: 'tortilleria',
        items: {'kilo': 2},
        clave: 'p1',
      );

      expect(pedido.totalCentavos, 5600);
      expect(pedido.comisionCentavos, 280);

      expect(monedero.saldo('ana'), 94400);

      expect(monedero.saldo('dueno-tortilleria'), 5320);

      expect(monedero.saldo('plataforma'), 280);

      expect(comercio.tiendas.first.producto('kilo')!.existencias, 48);

      expect(comercio.pedidosDe('ana').single.id, pedido.id);
    });

    test('la suma total del dinero no cambia', () {
      const cuentas = [
        'ana',
        'plataforma',
        'dueno-tortilleria',
        'dueno-cajeta',
        'dueno-talavera',
      ];

      int dineroTotal() {
        return cuentas.fold<int>(0, (s, c) => s + monedero.saldo(c));
      }

      final antes = dineroTotal();

      comercio.comprar(
        usuarioId: 'ana',
        tiendaId: 'cajeta',
        items: {'cajeta': 3, 'alegrias': 1},
        clave: 'p1',
      );

      expect(dineroTotal(), antes);
    });

    test('IDEMPOTENCIA: doble toque no compra dos veces', () {
      final a = comercio.comprar(
        usuarioId: 'ana',
        tiendaId: 'tortilleria',
        items: {'kilo': 1},
        clave: 'p1',
      );

      final b = comercio.comprar(
        usuarioId: 'ana',
        tiendaId: 'tortilleria',
        items: {'kilo': 1},
        clave: 'p1',
      );

      expect(identical(a, b), isTrue);
      expect(monedero.saldo('ana'), 97200);

      expect(comercio.tiendas.first.producto('kilo')!.existencias, 49);

      expect(comercio.pedidosDe('ana').length, 1);
    });

    test('sin saldo no hay pedido ni cambio de inventario', () {
      expect(
        () => comercio.comprar(
          usuarioId: 'ana',
          tiendaId: 'talavera',
          items: {'jarron': 1},
          clave: 'p1',
        ),
        throwsA(isA<SaldoInsuficienteException>()),
      );

      expect(comercio.pedidosDe('ana'), isEmpty);

      expect(comercio.tiendas.last.producto('jarron')!.existencias, 4);

      expect(monedero.saldo('ana'), 100000);
    });

    test('validaciones del pedido', () {
      expect(
        () => comercio.comprar(
          usuarioId: 'ana',
          tiendaId: 'fantasma',
          items: {'kilo': 1},
          clave: 'a',
        ),
        throwsA(isA<PedidoInvalidoException>()),
      );

      expect(
        () => comercio.comprar(
          usuarioId: 'ana',
          tiendaId: 'tortilleria',
          items: {},
          clave: 'b',
        ),
        throwsA(isA<PedidoInvalidoException>()),
      );

      expect(
        () => comercio.comprar(
          usuarioId: 'ana',
          tiendaId: 'tortilleria',
          items: {'kilo': 0},
          clave: 'c',
        ),
        throwsA(isA<PedidoInvalidoException>()),
      );

      expect(
        () => comercio.comprar(
          usuarioId: 'ana',
          tiendaId: 'tortilleria',
          items: {'kilo': 11},
          clave: 'd',
        ),
        throwsA(isA<PedidoInvalidoException>()),
      );

      expect(
        () => comercio.comprar(
          usuarioId: 'ana',
          tiendaId: 'tortilleria',
          items: {'noexiste': 1},
          clave: 'e',
        ),
        throwsA(isA<PedidoInvalidoException>()),
      );
    });

    test('existencias insuficientes', () {
      expect(
        () => comercio.comprar(
          usuarioId: 'ana',
          tiendaId: 'talavera',
          items: {'taza': 10, 'jarron': 5},
          clave: 'k',
        ),
        throwsA(isA<ExistenciasInsuficientesException>()),
      );
    });

    test('una compra publica los tres eventos', () {
      final pedido = comercio.comprar(
        usuarioId: 'ana',
        tiendaId: 'tortilleria',
        items: {'kilo': 2},
        clave: 'p1',
      );

      expect(eventos.whereType<PagoRealizado>().length, 1);

      expect(eventos.whereType<PedidoCreado>().single.pedidoId, pedido.id);

      expect(eventos.whereType<DineroRecibido>().single.montoCentavos, 5320);

      expect(eventos.length, 3);
    });
  });
}
