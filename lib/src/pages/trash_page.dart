import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/trash_item_tile.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = await StoreController.instance();
    await controller.refreshTrash();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _restore(MovedEntry entry) async {
    final controller = await StoreController.instance();
    await controller.restoreTrash(entry);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Restored to your library')));
    }
  }

  Future<void> _deletePermanent(MovedEntry entry) async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete forever'),
        content: Text('Delete "${entry.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NXColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteTrashItem(entry);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StoreController>(
      future: StoreController.instance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const NPhotosLoadingState();
        }
        final controller = snapshot.data!;
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (_loading && controller.trashItems.isEmpty) {
              return const NPhotosLoadingState();
            }
            if (controller.trashItems.isEmpty) {
              return NPhotosEmptyState(
                icon: Icons.delete_outline_rounded,
                title: 'Trash is empty',
                subtitle:
                    'When you delete a photo, it stays here so you can '
                    'restore it later.',
              );
            }
            final items = controller.trashItems;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                NXSpace.s24,
                NXSpace.s4,
                NXSpace.s24,
                NXSpace.s32,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: NXSpace.s8),
              itemBuilder: (context, i) => TrashItemTile(
                entry: items[i],
                onRestore: () => _restore(items[i]),
                onDeletePermanent: () => _deletePermanent(items[i]),
              ),
            );
          },
        );
      },
    );
  }
}
