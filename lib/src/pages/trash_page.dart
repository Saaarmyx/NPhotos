import 'package:flutter/material.dart';

import '../core.dart';
import '../rust/api.dart';
import '../widgets/trash_item_tile.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<MovedEntry> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final controller = await StoreController.instance();
    final items = await controller.listTrash();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _restore(MovedEntry entry) async {
    final controller = await StoreController.instance();
    await controller.restoreTrash(entry);
    await controller.rescan();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurada')),
      );
    }
  }

  Future<void> _deletePermanent(MovedEntry entry) async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar definitivamente'),
        content: Text('¿Borrar "${entry.name}" sin posibilidad de recuperarlo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteTrashItem(entry);
    await _load();
  }

  Future<void> _emptyTrash() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar papelera'),
        content: Text(
          'Se borrarán definitivamente ${_items.length} elemento(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.emptyTrash();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Vaciar papelera',
              onPressed: _emptyTrash,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('La papelera está vacía'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (context, i) => TrashItemTile(
                    entry: _items[i],
                    onRestore: () => _restore(_items[i]),
                    onDeletePermanent: () => _deletePermanent(_items[i]),
                  ),
                ),
    );
  }
}