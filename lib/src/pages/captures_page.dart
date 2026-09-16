import 'package:flutter/material.dart';

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

class CapturesPage extends StatefulWidget {
  const CapturesPage({super.key});

  @override
  State<CapturesPage> createState() => _CapturesPageState();
}

class _CapturesPageState extends State<CapturesPage>
    with AutomaticKeepAliveClientMixin {
  int _columns = 4;

  @override
  bool get wantKeepAlive => true;

  List<Photo> _captures(List<Photo> photos) {
    final low = _captureKeywords.join('|').toLowerCase();
    return photos
        .where((p) => RegExp(low).hasMatch(p.name.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capturas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Menos columnas',
            onPressed: _columns > 2 ? () => setState(() => _columns--) : null,
          ),
          Text('$_columns', style: Theme.of(context).textTheme.labelLarge),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Más columnas',
            onPressed: _columns < 8 ? () => setState(() => _columns++) : null,
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
          if (controller.photos.isEmpty) {
            return const Center(child: Text('No hay fotos aún'));
          }
          final photos = _captures(controller.photos);
          if (photos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se encontraron capturas de pantalla usando los nombres esperados '
                  '(screenshot, captura, screen, pantalla...).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ThumbnailGrid(
            photos: photos,
            columns: _columns,
            onChanged: () => setState(() {}),
          );
        },
      ),
    );
  }
}