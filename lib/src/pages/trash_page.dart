import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_button.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
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
  List<MovedEntry> _items = const [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

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
        const SnackBar(content: Text('Restored to your library')),
      );
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
            style: FilledButton.styleFrom(
              backgroundColor: NXColors.primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
        title: const Text('Empty Trash'),
        content: Text('${_items.length} items will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NXColors.primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty'),
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
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: NXSpace.s20),
          child: SectionHeader(
            title: 'Trash',
            subtitle: _items.isEmpty
                ? 'Deleted photos live here for 30 days'
                : '${_items.length} ${_items.length == 1 ? 'item' : 'items'} in Trash',
            padding: const EdgeInsets.fromLTRB(
              NXSpace.s24,
              0,
              NXSpace.s24,
              NXSpace.s16,
            ),
            trailing: _items.isNotEmpty
                ? NPhotosIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: 'Empty Trash',
                    onPressed: _emptyTrash,
                  )
                : null,
          ),
        ),
        Expanded(
          child: _loading
              ? const NPhotosLoadingState()
              : _items.isEmpty
                  ? NPhotosEmptyState(
                      icon: Icons.delete_outline_rounded,
                      title: 'Trash is empty',
                      subtitle:
                          'When you delete a photo, it stays here so you can '
                          'restore it later.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        NXSpace.s24,
                        NXSpace.s4,
                        NXSpace.s24,
                        NXSpace.s32,
                      ),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: NXSpace.s8),
                      itemBuilder: (context, i) => TrashItemTile(
                        entry: _items[i],
                        onRestore: () => _restore(_items[i]),
                        onDeletePermanent: () => _deletePermanent(_items[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}