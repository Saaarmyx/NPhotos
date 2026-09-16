import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core.dart';
import '../rust/api.dart';

class TrashItemTile extends StatefulWidget {
  const TrashItemTile({
    super.key,
    required this.entry,
    required this.onRestore,
    required this.onDeletePermanent,
  });

  final MovedEntry entry;
  final VoidCallback onRestore;
  final VoidCallback onDeletePermanent;

  @override
  State<TrashItemTile> createState() => _TrashItemTileState();
}

class _TrashItemTileState extends State<TrashItemTile> {
  @override
  Widget build(BuildContext context) {
    final sizeMb = (widget.entry.sizeBytes.toDouble() / 1048576)
        .toStringAsFixed(2);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _Thumb(path: widget.entry.path),
          ),
        ),
        title: Text(
          widget.entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$sizeMb MB\n${widget.entry.original}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restaurar',
              onPressed: widget.onRestore,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              tooltip: 'Eliminar definitivamente',
              onPressed: widget.onDeletePermanent,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({required this.path});

  final String path;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List?> _load() async {
    final controller = await StoreController.instance();
    return controller.thumbnail(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        return const ColoredBox(color: Color(0xFFE0E0E0));
      },
    );
  }
}
