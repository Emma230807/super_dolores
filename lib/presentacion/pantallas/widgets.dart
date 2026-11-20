import 'package:flutter/material.dart';

/// Muestra un mensaje de error cuando existe.
class Aviso extends StatelessWidget {
  final String? texto;

  const Aviso(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    if (texto == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(12), child: Text(texto!)),
    );
  }
}
