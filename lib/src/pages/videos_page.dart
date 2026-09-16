import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../rust/api.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = await StoreController.instance();
      if (controller.videos.isEmpty && !controller.videosLoading) {
        controller.refreshVideos();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
            if (controller.videosLoading && controller.videos.isEmpty) {
              return const NPhotosLoadingState(label: 'Scanning videos…');
            }
            if (controller.videos.isEmpty) {
              return NPhotosEmptyState(
                icon: Icons.movie_outlined,
                title: 'No videos found',
                subtitle:
                    'Videos (.mp4, .mov…) in your personal folder '
                    'will appear here.',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                NXSpace.s24,
                NXSpace.s4,
                NXSpace.s24,
                NXSpace.s32,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: NXSpace.s14,
                crossAxisSpacing: NXSpace.s14,
                childAspectRatio: 0.75,
              ),
              itemCount: controller.videos.length,
              itemBuilder: (context, i) =>
                  NPhotosVideoCard(video: controller.videos[i]),
            );
          },
        );
      },
    );
  }
}

class NPhotosVideoCard extends StatefulWidget {
  const NPhotosVideoCard({super.key, required this.video});

  final VideoFile video;

  @override
  State<NPhotosVideoCard> createState() => _NPhotosVideoCardState();
}

class _NPhotosVideoCardState extends State<NPhotosVideoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final sizeMb = (widget.video.sizeBytes.toDouble() / 1048576)
        .toStringAsFixed(1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Playback coming soon')));
        },
        child: AnimatedContainer(
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          decoration: BoxDecoration(
            color: palette.elevated,
            borderRadius: BorderRadius.circular(NXRadius.radius14),
            border: Border.all(
              color: _hovered
                  ? NXColors.primary.withValues(alpha: 0.35)
                  : palette.border.withValues(alpha: 0.6),
            ),
            boxShadow: _hovered ? NXShadow.neutral(Theme.of(context)) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [NXColors.darkSurface, NXColors.darkBg],
                        ),
                      ),
                      child: Icon(
                        Icons.movie_outlined,
                        size: 46,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    Center(
                      child: AnimatedContainer(
                        duration: NXTransition.base,
                        width: _hovered ? 52 : 44,
                        height: _hovered ? 52 : 44,
                        decoration: const BoxDecoration(
                          color: NXColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _hovered
                              ? Icons.play_arrow_rounded
                              : Icons.play_arrow,
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(NXSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NXText.albumName(context),
                    ),
                    const SizedBox(height: NXSpace.s2),
                    Text(
                      '$sizeMb MB · ${widget.video.extension_.toUpperCase()}',
                      style: NXText.muted(context)
                          .copyWith(color: palette.textBody),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
