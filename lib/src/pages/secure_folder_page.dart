import 'package:flutter/material.dart';

import '../core.dart';
import '../rust/api.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/trash_item_tile.dart';

class SecureFolderPage extends StatefulWidget {
  const SecureFolderPage({super.key});

  @override
  State<SecureFolderPage> createState() => _SecureFolderPageState();
}

class _SecureFolderPageState extends State<SecureFolderPage>
    with AutomaticKeepAliveClientMixin {
  bool? _pinSet;
  bool _unlocked = false;
  List<MovedEntry> _items = const [];
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final controller = await StoreController.instance();
    final pinSet = await controller.pinIsSet();
    if (!mounted) return;
    setState(() => _pinSet = pinSet);
    if (!pinSet) return;
    final pin = await showPinDialog(context, title: 'Desbloquear carpeta segura');
    if (!mounted) return;
    if (pin == null) return;
    final ok = await controller.verifyPin(pin);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN incorrecto')),
      );
      return;
    }
    setState(() => _unlocked = true);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final controller = await StoreController.instance();
    final items = await controller.listSecure();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _setupPin() async {
    final first = await showPinDialog(context, title: 'Crear PIN');
    if (first == null || !mounted) return;
    final second = await showPinDialog(context, title: 'Repite el PIN');
    if (second == null || !mounted) return;
    if (first != second) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los PIN no coinciden')),
        );
      }
      return;
    }
    final controller = await StoreController.instance();
    await controller.setPin(first);
    if (mounted) {
      setState(() {
        _pinSet = true;
        _unlocked = true;
      });
      await _load();
    }
  }

  Future<void> _changePin() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final current = await showPinDialog(context, title: 'PIN actual');
    if (current == null || !mounted) return;
    if (!await controller.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN incorrecto')),
        );
      }
      return;
    }
    if (!mounted) return;
    final next = await showPinDialog(context, title: 'Nuevo PIN');
    if (next == null || !mounted) return;
    await controller.setPin(next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN actualizado')),
      );
    }
  }

  Future<void> _clearPin() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final current = await showPinDialog(context, title: 'PIN actual');
    if (current == null) return;
    if (!await controller.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN incorrecto')),
        );
      }
      return;
    }
    await controller.clearPin();
    if (mounted) {
      setState(() {
        _pinSet = false;
        _unlocked = true;
      });
    }
  }

  Future<void> _restore(MovedEntry entry) async {
    final controller = await StoreController.instance();
    await controller.restoreSecure(entry);
    await controller.rescan();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurada')),
      );
    }
  }

  Future<void> _delete(MovedEntry entry) async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar de carpeta segura'),
        content: Text('¿Borrar "${entry.name}" definitivamente?'),
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
    await controller.deleteSecureItem(entry);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carpeta segura'),
        actions: [
          if (_pinSet == true)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'change':
                    _changePin();
                  case 'clear':
                    _clearPin();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'change', child: Text('Cambiar PIN')),
                PopupMenuItem(value: 'clear', child: Text('Desactivar PIN')),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_pinSet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pinSet == false) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Protege tus fotos con un PIN'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('Configurar PIN'),
              onPressed: _setupPin,
            ),
          ],
        ),
      );
    }
    if (!_unlocked) {
      return const Center(
        child: Text('Carpeta bloqueada. Reabre la sección para desbloquearla.'),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Carpeta vacía.\nMueve fotos desde Galería con el menú contextual.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _items.length,
      itemBuilder: (context, i) => TrashItemTile(
        entry: _items[i],
        onRestore: () => _restore(_items[i]),
        onDeletePermanent: () => _delete(_items[i]),
      ),
    );
  }
}