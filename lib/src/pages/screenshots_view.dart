import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';

const _captureKeywords = [
  'screenshot',
  'captura',
  'screen',
  'screencap',
  'pantalla',
  'capture',
];

/// Vista "Screenshots": fotos filtradas por nombres habituales de captura.
class ScreenshotsView extends StatefulWidget {
  const ScreenshotsView({super.key});

  @override
  State<ScreenshotsView> createState() => _ScreenshotsViewState();
}

class _ScreenshotsViewState extends State<ScreenshotsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _autoLoad() async {
    final controller = await StoreController.instance();
    if (controller.photos.isEmpty && !controller.loading) {
      await controller.scanAll();
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoad());
  }

  List<Photo> _captures(List<Photo> photos) {
    final low = _captureKeywords.join('|').toLowerCase();
    return photos.where((p) => RegExp(low).hasMatch(p.name.toLowerCase())).toList();
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
              final count = snapshot.data == null
                  ? 0
                  : _captures(snapshot.data!.photos).length;
              return SectionHeader(
                title: 'Screenshots',
                subtitle: '$count ${count == 1 ? 'capture' : 'captures'} found',
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
              final controller = snapshot.data!;
              if (controller.photos.isEmpty) {
                return NPhotosEmptyState(
                  icon: Icons.crop_original_outlined,
                  title: 'No photos in your archive',
                  subtitle: 'Scan your library first to find screenshots.',
                );
              }
              final screenshots = _captures(controller.photos);
              if (screenshots.isEmpty) {
                return NPhotosEmptyState(
                  icon: Icons.crop_original_outlined,
                  title: 'No screenshots found',
                  subtitle:
                      'Looked for files named like screenshot, captura, screen '
                      'or pantalla. Your captures will appear here.',
                );
              }
              return ValueListenableBuilder<String>(
                valueListenable: globalSearchQuery,
                builder: (context, query, _) {
                  final q = query.trim().toLowerCase();
                  final visible = q.isEmpty
                      ? screenshots
                      : screenshots
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