import 'excepciones.dart';

/// Capacidades disponibles para las mini-apps.
enum Permiso {
  identidad,
  monederoLeer,
  monederoPagar,
  mensajesLeer,
  mensajesEscribir,
  ubicacion,
}

/// Representa una mini-app registrada.
class MiniApp {
  final String id;
  final String nombre;
  final String emoji;
  final Set<Permiso> permisos;

  const MiniApp(this.id, this.nombre, this.emoji, this.permisos);
}

/// Catálogo de mini-apps con interruptor de emergencia.
class RegistroMiniApps {
  final Map<String, MiniApp> _apps = {};
  final Set<String> _apagadas = {};

  /// Registra una mini-app nueva.
  void registrar(MiniApp app) {
    if (_apps.containsKey(app.id)) {
      throw ArgumentError('Ya existe la mini-app ${app.id}');
    }

    _apps[app.id] = app;
  }

  /// Busca una mini-app por su identificador.
  MiniApp? porId(String id) => _apps[id];

  /// Devuelve únicamente las mini-apps activas.
  List<MiniApp> get activas {
    return _apps.values.where((a) => !_apagadas.contains(a.id)).toList();
  }

  /// Verifica si una mini-app está activa.
  bool estaActiva(String id) {
    return _apps.containsKey(id) && !_apagadas.contains(id);
  }

  /// Desactiva una mini-app.
  void apagar(String id) {
    _apagadas.add(id);
  }

  /// Activa nuevamente una mini-app.
  void encender(String id) {
    _apagadas.remove(id);
  }

  /// Bloquea el acceso a una mini-app inactiva.
  void exigeActiva(String id) {
    if (!estaActiva(id)) {
      throw const MiniAppNoDisponibleException();
    }
  }
}
