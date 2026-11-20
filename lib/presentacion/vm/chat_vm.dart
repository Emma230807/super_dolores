import 'package:flutter/foundation.dart';

import '../../dominio/contexto.dart';
import '../../dominio/excepciones.dart';
import '../../dominio/mensajeria.dart';

/// ViewModel de conversaciones.
class ChatViewModel extends ChangeNotifier {
  final ContextoMiniApp _contexto;
  final VoidCallback? alCambiar;

  ChatViewModel(this._contexto, {this.alCambiar});

  String? con;
  String? error;

  List<ResumenConversacion> get resumenes => _contexto.mensajes.resumenes();

  List<Mensaje> get mensajes {
    if (con == null) {
      return [];
    }

    return _contexto.mensajes.conversacion(con!);
  }

  /// Abre una conversación.
  void abrir(String otro) {
    con = otro;

    _contexto.mensajes.marcarLeidos(otro);

    error = null;

    alCambiar?.call();
    notifyListeners();
  }

  /// Cierra la conversación actual.
  void cerrar() {
    con = null;
    notifyListeners();
  }

  /// Envía un mensaje de texto.
  void enviar(String texto) {
    final destino = con;

    if (destino == null) {
      return;
    }

    try {
      _contexto.mensajes.enviar(destino, texto);

      error = null;
    } catch (e) {
      error = mensajeSeguro(e);
    }

    alCambiar?.call();
    notifyListeners();
  }

  /// Envía dinero dentro de la conversación.
  void enviarDinero(int montoCentavos) {
    final destino = con;

    if (destino == null) {
      return;
    }

    try {
      _contexto.pagos.enviarDinero(
        destino,
        montoCentavos,
        clave: 'chat-${DateTime.now().microsecondsSinceEpoch}',
      );

      error = null;
    } catch (e) {
      error = mensajeSeguro(e);
    }

    alCambiar?.call();
    notifyListeners();
  }
}
