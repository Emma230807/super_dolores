import 'package:flutter/foundation.dart';

import '../../dominio/comercio.dart';
import '../../dominio/contexto.dart';
import '../../dominio/excepciones.dart';

/// ViewModel de la tienda y el carrito de compras.
class TiendaViewModel extends ChangeNotifier {
  final ContextoMiniApp _contexto;
  final VoidCallback? alCambiar;

  TiendaViewModel(this._contexto, {this.alCambiar});

  Tienda? tienda;

  final Map<String, int> carrito = {};

  String? error;
  Pedido? ultimoPedido;
  bool ocupado = false;

  String? _claveActual;

  List<Tienda> get tiendas => _contexto.comercio.tiendas();

  /// Selecciona una tienda.
  void elegirTienda(Tienda seleccionada) {
    tienda = seleccionada;
    carrito.clear();
    _claveActual = null;
    ultimoPedido = null;

    notifyListeners();
  }

  /// Regresa a la selección de tiendas.
  void volver() {
    tienda = null;
    carrito.clear();
    _claveActual = null;

    notifyListeners();
  }

  /// Calcula el importe del carrito.
  int get total {
    final seleccionada = tienda;

    if (seleccionada == null) {
      return 0;
    }

    var suma = 0;

    carrito.forEach((id, cantidad) {
      suma += (seleccionada.producto(id)?.precioCentavos ?? 0) * cantidad;
    });

    return suma;
  }

  /// Aumenta o disminuye la cantidad de un producto.
  void cambiar(String productoId, int delta) {
    final nuevo = (carrito[productoId] ?? 0) + delta;

    if (nuevo <= 0) {
      carrito.remove(productoId);
    } else {
      carrito[productoId] = nuevo;
    }

    _claveActual = null;

    notifyListeners();
  }

  /// Confirma la compra y actualiza el carrito.
  Future<void> comprar() async {
    if (ocupado || tienda == null) {
      return;
    }

    ocupado = true;
    error = null;

    notifyListeners();

    _claveActual ??= 'pedido-${DateTime.now().microsecondsSinceEpoch}';

    try {
      ultimoPedido = _contexto.comercio.comprar(
        tienda!.id,
        Map.of(carrito),
        clave: _claveActual!,
      );

      carrito.clear();
      _claveActual = null;

      alCambiar?.call();
    } catch (e) {
      error = mensajeSeguro(e);
    }

    ocupado = false;
    notifyListeners();
  }
}
