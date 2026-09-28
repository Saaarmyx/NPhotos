// lib/screens/trash/trash_screen.dart
//
// Pantalla dedicada de Papelera (se abre desde Álbumes: pin o fila).
// Funcional: restaurar, eliminar definitivamente, vaciar y seleccionar
// varios elementos para borrarlos de una vez.
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../controllers/selection_controller.dart';
import '../../widgets/trash_grid.dart';

class TrashScreen extends StatefulWidget {
  final GalleryController controller;
  final SelectionController? selection;

  const TrashScreen({super.key, required this.controller, this.selection});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final SelectionController _selection =
      widget.selection ?? SelectionController();

  @override
  void dispose() {
    if (widget.selection == null) _selection.dispose();
    super.dispose();
  }

  /// Ids seleccionados que siguen en la papelera: si un elemento se
  /// restauró o borró, deja de ser válido.
  List<String> get _validIds => _selection.ids
      .where((id) => widget.controller.trash.any((t) => t.photo.id == id))
      .toList();

  Future<void> _deleteSelected() async {
    final ids = _validIds;
    if (ids.isEmpty) return;
    final confirmed = await showNConfirmDialog(
      context,
      title: 'Eliminar',
      message: 'Se borrarán ${ids.length} '
          '${ids.length == 1 ? 'archivo' : 'archivos'} de forma '
          'permanente. No se puede deshacer.',
      confirmLabel: 'OK',
    );
    if (!confirmed || !mounted) return;
    await widget.controller.deletePermanentlyBatch(ids);
    _selection.clear();
  }

  Future<void> _restoreSelected() async {
    final ids = _validIds;
    if (ids.isEmpty) return;
    await widget.controller.restoreFromTrashBatch(ids);
    _selection.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _selection]),
      builder: (context, _) {
        final trash = widget.controller.trash;
        if (trash.isEmpty) {
          return Scaffold(
            appBar: const NSecondaryTopBar(title: 'Papelera'),
            body: const NEmptyState(
              icon: Icons.delete_outline,
              title: 'Papelera vacía',
            ),
          );
        }
        return Scaffold(
          appBar: NSecondaryTopBar(
            title: _selection.isActive
                ? '${_selection.count} '
                    '${_selection.count == 1 ? 'seleccionado' : 'seleccionados'}'
                : 'Papelera',
            actions: [
              if (!_selection.isActive) ...[
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Seleccionar',
                  onPressed: () => _selection.selectAll(
                    trash.map((t) => t.photo.id),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Vaciar papelera',
                  onPressed: () async {
                    final confirmed = await showNConfirmDialog(
                      context,
                      title: 'Vaciar papelera',
                      message:
                          'Se eliminarán definitivamente todas las fotos '
                          'de la papelera.',
                      confirmLabel: 'OK',
                    );
                    if (confirmed) await widget.controller.emptyTrash();
                  },
                ),
              ] else
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancelar selección',
                  onPressed: _selection.clear,
                ),
            ],
          ),
          body: TrashGrid(controller: widget.controller, selection: _selection),
          // En selección la barra inferior ofrece restaurar o borrar.
          bottomNavigationBar: _selection.isActive
              ? _TrashSelectionBar(
                  onRestore: _restoreSelected,
                  onDelete: _deleteSelected,
                  onClear: _selection.clear,
                )
              : null,
        );
      },
    );
  }
}

/// Barra de acciones específica de la papelera: restaurar o eliminar.
class _TrashSelectionBar extends StatelessWidget {
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const _TrashSelectionBar({
    required this.onRestore,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NButton(
              label: 'Restaurar',
              icon: Icons.restore_from_trash_outlined,
              isFullWidth: false,
              borderRadius: BorderRadius.circular(30),
              onPressed: onRestore,
            ),
            const SizedBox(width: NSpacing.spaceSm),
            NButton(
              label: 'Eliminar',
              icon: Icons.delete_forever_outlined,
              customColor: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(30),
              onPressed: onDelete,
            ),
            const SizedBox(width: NSpacing.spaceSm),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar',
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
