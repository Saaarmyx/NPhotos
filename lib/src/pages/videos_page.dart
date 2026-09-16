import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_button.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
import '../core.dart';
import '../rust/api.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage>
    with AutomaticKeepAliveClientMixin {
  List<VideoFile> _videos = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final controller = await StoreController.instance();
    if (mounted) setState(() => _loading = true);
    try {
      final videos = await controller.scanAllVideos();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
            title: 'Videos',
            subtitle:
                '${_videos.length} ${_videos.length == 1 ? 'clip' : 'clips'} on this device',
            padding: const EdgeInsets.fromLTRB(
              NXSpace.s24,
              0,
              NXSpace.s24,
              NXSpace.s16,
            ),
            trailing: NPhotosIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Rescan videos',
              onPressed: _load,
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const NPhotosLoadingState(label: 'Scanning videos…')
              : _error != null
                  ? NPhotosEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not scan videos',
                      subtitle: _error,
                      actionLabel: 'Retry',
                      onAction: _load,
                    )
                  : _videos.isEmpty
                      ? NPhotosEmptyState(
                          icon: Icons.movie_outlined,
                          title: 'No videos found',
                          subtitle:
                              'Videos (.mp4, .mov…) in your personal folder '
                              'will appear here.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            NXSpace.s24,
                            NXSpace.s4,
                            NXSpace.s24,
                            NXSpace.s32,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: NXSpace.s14,
                            crossAxisSpacing: NXSpace.s14,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _videos.length,
                          itemBuilder: (context, i) =>
                              NPhotosVideoCard(video: _videos[i]),
                        ),
        ),
      ],
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
    final sizeMb = (widget.video.sizeBytes.toDouble() / 1048576).toStringAsFixed(1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playback coming soon')),
          );
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
                          _hovered ? Icons.play_arrow_rounded : Icons.play_arrow,
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
                      style: NXText.muted(context).copyWith(color: palette.textBody),
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