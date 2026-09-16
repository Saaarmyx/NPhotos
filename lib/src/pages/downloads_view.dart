import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';

/// Vista "Downloads": fotos localizadas dentro de la carpeta Downloads.
class DownloadsView extends StatefulWidget {
  const DownloadsView({super.key});

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView>
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

  bool _isDownload(Photo p) {
    final path = p.path.toLowerCase();
    return path.contains('/downloads/') || path.contains('\\downloads\\');
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
              final controller = snapshot.data;
              final count =
                  controller == null ? 0 : controller.photos.where(_isDownload).length;
              return SectionHeader(
                title: 'Downloads',
                subtitle: '$count ${count == 1 ? 'file' : 'files'} in Downloads',
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
              final downloads =
                  snapshot.data!.photos.where(_isDownload).toList();
              if (downloads.isEmpty) {
                return NPhotosEmptyState(
                  icon: Icons.download_outlined,
                  title: 'No downloads folder yet',
                  subtitle: 'Photos you download on this device will appear here.',
                );
              }
              return ValueListenableBuilder<String>(
                valueListenable: globalSearchQuery,
                builder: (context, query, _) {
                  final q = query.trim().toLowerCase();
                  final visible = q.isEmpty
                      ? downloads
                      : downloads
                          .where((p) => p.name.toLowerCase().contains(q))
                          .toList();
                  return ThumbnailGrid(
                    photos: visible,
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