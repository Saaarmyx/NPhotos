import 'package:flutter/material.dart';

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
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  Future<void> _load() async {
    final controller = await StoreController.instance();
    final root = controller.rootPath;
    if (root == null) {
      setState(() {
        _videos = const [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await controller.scanVideos(root);
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loading = false;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: FutureBuilder<StoreController>(
        future: StoreController.instance(),
        builder: (context, snapshot) {
          final controller = snapshot.data;
          if (controller == null || controller.rootPath == null) {
            return const Center(child: Text('Abre primero una carpeta en Galería'));
          }
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(child: Text('Error: $_error'));
          }
          if (_videos.isEmpty) {
            return const Center(child: Text('No se encontraron videos'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: _videos.length,
            itemBuilder: (context, i) => _VideoCard(video: _videos[i]),
          );
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});

  final VideoFile video;

  @override
  Widget build(BuildContext context) {
    final sizeMb = (video.sizeBytes.toDouble() / 1048576).toStringAsFixed(1);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reproducción aún no disponible'),
                  ),
                );
              },
              child: Container(
                color: Colors.black87,
                child: const Icon(Icons.movie, size: 48, color: Colors.white70),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeMb MB · ${video.extension_.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}