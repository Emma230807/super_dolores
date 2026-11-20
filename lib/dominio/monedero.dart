import 'dinero.dart';
import 'excepciones.dart';

enum TipoMovimiento {
  deposito,
  pago,
  transferenciaEnviada,
  transferenciaRecibida,
  reembolso,
}

/// Representa un movimiento del monedero.
class Movimiento {
  final String id;
  final String cuentaId;
  final TipoMovimiento tipo;
  final int montoCentavos;
  final String concepto;
  final DateTime fecha;
  final String? contraparte;

  const Movimiento(
    this.id,
    this.cuentaId,
    this.tipo,
    this.montoCentavos,
    this.concepto,
    this.fecha, {
    this.contraparte,
  });
}

/// Monedero basado en un libro de movimientos.
/// El saldo se calcula sumando sus movimientos.
class Monedero {
  static const int maxPorOperacion = 500000;
  static const int maxSalidasDiarias = 1000000;

  final DateTime Function() _reloj;

  final Map<String, List<Movimiento>> _libro = {};
  final Map<String, Movimiento> _porClave = {};

  final Set<String> _sinLimites = {};

  int _sec = 0;

  Monedero({DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  /// Crea una cuenta si todavía no existe.
  void abrirCuenta(String id, {bool sinLimites = false}) {
    _libro.putIfAbsent(id, () => []);

    if (sinLimites) {
      _sinLimites.add(id);
    }
  }

  /// Verifica si una cuenta existe.
  bool existe(String id) => _libro.containsKey(id);

  /// Calcula el saldo a partir de los movimientos.
  int saldo(String id) {
    return _cuenta(id).fold(0, (s, m) => s + m.montoCentavos);
  }

  /// Devuelve los movimientos más recientes primero.
  List<Movimiento> movimientos(String id) {
    return _cuenta(id).reversed.toList();
  }

  /// Calcula cuánto dinero salió de una cuenta hoy.
  int salidasDeHoy(String id) {
    final hoy = soloFecha(_reloj());

    return _cuenta(id)
        .where(
          (m) =>
              m.montoCentavos < 0 &&
              (m.tipo == TipoMovimiento.pago ||
                  m.tipo == TipoMovimiento.transferenciaEnviada) &&
              soloFecha(m.fecha) == hoy,
        )
        .fold(0, (s, m) => s + (-m.montoCentavos));
  }

  /// Recupera el libro de movimientos de una cuenta.
  List<Movimiento> _cuenta(String id) {
    return _libro[id] ?? (throw const CuentaNoExisteException());
  }

  /// Registra un movimiento nuevo.
  Movimiento _registrar(
    String cuenta,
    TipoMovimiento tipo,
    int monto,
    String concepto, {
    String? contraparte,
  }) {
    final m = Movimiento(
      'mov-${++_sec}',
      cuenta,
      tipo,
      monto,
      concepto,
      _reloj(),
      contraparte: contraparte,
    );

    _libro[cuenta]!.add(m);

    return m;
  }

  /// Verifica que un monto sea válido.
  void _validarMonto(int monto) {
    if (monto <= 0) {
      throw const MontoInvalidoException();
    }

    if (monto > maxPorOperacion) {
      throw LimiteExcedidoException(
        'máximo ${formatearPesos(maxPorOperacion)} por operación',
      );
    }
  }

  /// Verifica el saldo disponible y el límite diario.
  void _validarSalida(String cuenta, int monto) {
    if (saldo(cuenta) < monto) {
      throw const SaldoInsuficienteException();
    }

    if (!_sinLimites.contains(cuenta) &&
        salidasDeHoy(cuenta) + monto > maxSalidasDiarias) {
      throw LimiteExcedidoException(
        'máximo ${formatearPesos(maxSalidasDiarias)} '
        'de salidas por día',
      );
    }
  }

  /// Deposita dinero en una cuenta.
  Movimiento depositar(
    String cuenta,
    int monto, {
    required String clave,
    String concepto = 'Recarga',
  }) {
    final previo = _porClave['$cuenta|$clave'];

    if (previo != null) {
      return previo;
    }

    _cuenta(cuenta);
    _validarMonto(monto);

    return _porClave['$cuenta|$clave'] = _registrar(
      cuenta,
      TipoMovimiento.deposito,
      monto,
      concepto,
    );
  }

  /// Realiza un pago utilizando el saldo disponible.
  Movimiento pagar(
    String cuenta,
    int monto,
    String concepto, {
    required String clave,
  }) {
    final previo = _porClave['$cuenta|$clave'];

    if (previo != null) {
      return previo;
    }

    _cuenta(cuenta);
    _validarMonto(monto);
    _validarSalida(cuenta, monto);

    return _porClave['$cuenta|$clave'] = _registrar(
      cuenta,
      TipoMovimiento.pago,
      -monto,
      concepto,
    );
  }

  /// Transfiere dinero entre dos cuentas.
  /// Valida todo antes de registrar movimientos.
  Movimiento transferir(
    String de,
    String a,
    int monto,
    String concepto, {
    required String clave,
  }) {
    final previo = _porClave['$de|$clave'];

    if (previo != null) {
      return previo;
    }

    _cuenta(de);
    _cuenta(a);

    if (de == a) {
      throw const DestinatarioInvalidoException();
    }

    _validarMonto(monto);
    _validarSalida(de, monto);

    final salida = _registrar(
      de,
      TipoMovimiento.transferenciaEnviada,
      -monto,
      concepto,
      contraparte: a,
    );

    _registrar(
      a,
      TipoMovimiento.transferenciaRecibida,
      monto,
      concepto,
      contraparte: de,
    );

    return _porClave['$de|$clave'] = salida;
  }

  /// Devuelve dinero a una cuenta.
  Movimiento reembolsar(
    String cuenta,
    int monto,
    String concepto, {
    required String clave,
  }) {
    final previo = _porClave['$cuenta|$clave'];

    if (previo != null) {
      return previo;
    }

    _cuenta(cuenta);

    if (monto <= 0) {
      throw const MontoInvalidoException();
    }

    return _porClave['$cuenta|$clave'] = _registrar(
      cuenta,
      TipoMovimiento.reembolso,
      monto,
      concepto,
    );
  }
}
