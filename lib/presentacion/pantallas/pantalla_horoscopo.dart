import 'package:flutter/material.dart';

import '../../dominio/excepciones.dart';
import '../../dominio/plataforma.dart';

/// Mini-app de terceros usada para probar los permisos.
class PantallaHoroscopo extends StatefulWidget {
  final Plataforma plataforma;
  final String usuarioId;

  const PantallaHoroscopo({
    super.key,
    required this.plataforma,
    required this.usuarioId,
  });

  @override
  State<PantallaHoroscopo> createState() => _PantallaHoroscopoState();
}

class _PantallaHoroscopoState extends State<PantallaHoroscopo> {
  String? resultado;

  void _intentar(String accion, void Function() operacion) {
    String texto;

    try {
      operacion();

      texto =
          '⚠️ Se permitió $accion. '
          'Esto sería un fallo de seguridad.';
    } catch (e) {
      texto = '🛡️ $accion → ${mensajeSeguro(e)}';
    }

    setState(() {
      resultado = texto;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.plataforma.contextoPara(
      Plataforma.miniHoroscopo,
      widget.usuarioId,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('🔮 Horóscopo (tercero)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Hoy los astros dicen que tendrás un gran día. '
            'Mientras tanto, esta mini-app de terceros '
            'intentará acceder a funciones que no tiene '
            'autorizadas.',
          ),

          const SizedBox(height: 12),

          FilledButton(
            onPressed: () =>
                _intentar('leer tu saldo', () => ctx.monedero.saldo()),
            child: const Text('Intentar leer mi saldo'),
          ),

          FilledButton(
            onPressed: () => _intentar(
              'cobrarte',
              () => ctx.pagos.pagar(100, 'Premium', clave: 'x'),
            ),
            child: const Text('Intentar cobrarme'),
          ),

          FilledButton(
            onPressed: () =>
                _intentar('leer tus mensajes', () => ctx.mensajes.resumenes()),
            child: const Text('Intentar leer mis chats'),
          ),

          const SizedBox(height: 12),

          if (resultado != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(resultado!),
              ),
            ),
        ],
      ),
    );
  }
}
