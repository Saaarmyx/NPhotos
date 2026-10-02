// lib/widgets/selection_action_bar.dart
//
// Barra inferior de acciones en modo selección: reemplaza la bottom bar
// de destinos mientras hay algo seleccionado.
//
// La presentación vive en el kit (`NActionBar`); este archivo solo la
// conecta con el `SelectionController` de la app.
import 'package:flutter/material.dart';
import 'package:NexoraUi/NexoraUi.dart';

import '../controllers/selection_controller.dart';

/// Acciones disponibles según el tipo de selección.
class SelectionActionBar extends StatelessWidget {
  final SelectionController selection;
  final VoidCallback onShare;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  /// Menú "más": acciones que no caben en la barra (renombrar, carátula…).
  /// Null en selecciones donde no aplica (fotos).
  final VoidCallback? onMore;

  const SelectionActionBar({
    super.key,
    required this.selection,
    required this.onShare,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onClear,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return NActionBar(
      count: selection.count,
      onClear: onClear,
      actions: [
        NActionBarItem(
          icon: Icons.share_outlined,
          tooltip: 'Compartir',
          onTap: onShare,
        ),
        if (onMore != null)
          NActionBarItem(
            icon: Icons.more_horiz,
            tooltip: 'Más acciones',
            onTap: onMore!,
          ),
        NActionBarItem(
          icon: Icons.favorite_border,
          tooltip: 'Favoritos',
          onTap: onToggleFavorite,
        ),
        NActionBarItem(
          icon: Icons.delete_outline,
          tooltip: 'Eliminar',
          onTap: onDelete,
          destructive: true,
        ),
      ],
    );
  }
}
