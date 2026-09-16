import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
import '../core.dart';
import '../widgets/photo_grid.dart';

/// Vista "Recently Added": las fotos más recientes de la biblioteca.
class RecentlyAddedView extends StatefulWidget {
  const RecentlyAddedView({super.key, this.limit = 60});

  final int limit;

  @override
  State<RecentlyAddedView> createState() => _RecentlyAddedViewState();
}

class _RecentlyAddedViewState extends State<RecentlyAddedView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = await StoreController.instance();
      if (controller.photos.isEmpty && !controller.loading) {
        await controller.scanAll();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: NXSpace.s20),
          child: FutureBuilder<StoreController>(
            future: StoreController.instance(),
            builder: (context, snapshot) {
              final count = snapshot.data?.photos.length ?? 0;
              return SectionHeader(
                title: 'Recently Added',
                subtitle:
                    'The latest ${widget.limit.clamp(1, count)} additions',
                padding: const EdgeInsets.fromLTRB(
                  NXSpace.s24,
                  0,
                  NXSpace.s24,
                  NXSpace.s16,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<StoreController>(
            future: StoreController.instance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final photos = snapshot.data!.photos;
              if (photos.isEmpty) {
                return NPhotosEmptyState(
                  icon: Icons.schedule_outlined,
                  title: 'Nothing new yet',
                  subtitle: 'Photos will appear here as your library grows.',
                );
              }
              return ValueListenableBuilder<String>(
                valueListenable: globalSearchQuery,
                builder: (context, query, _) {
                  final q = query.trim().toLowerCase();
                  final visible = q.isEmpty
                      ? photos
                      : photos.where((p) => p.name.toLowerCase().contains(q)).toList();
                  return ThumbnailGrid(
                    photos: visible.take(widget.limit).toList(),
                    onChanged: () {
                      if (mounted) setState(() {});
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}