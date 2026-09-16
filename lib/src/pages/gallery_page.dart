import 'package:flutter/material.dart';

import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';

enum SortMode { dateDesc, dateAsc, nameAsc, sizeDesc }

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage>
    with AutomaticKeepAliveClientMixin {
  SortMode _sort = SortMode.dateDesc;
  String _query = '';
  bool _searching = false;
  int _columns = 4;
  PhotoGroupBy _groupBy = PhotoGroupBy.none;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoad());
  }

  Future<void> _autoLoad() async {
    final controller = await StoreController.instance();
    if (controller.photos.isEmpty && !controller.loading) {
      await controller.scanAll();
      if (mounted) setState(() {});
    }
  }

  Future<void> _reload() async {
    final controller = await StoreController.instance();
    await controller.scanAll();
    if (mounted) setState(() {});
  }

  List<Photo> _sorted(List<Photo> photos) {
    final list = List<Photo>.from(photos);
    switch (_sort) {
      case SortMode.dateDesc:
        list.sort((a, b) {
          final ta = DateTime.tryParse(a.takenAt ?? '');
          final tb = DateTime.tryParse(b.takenAt ?? '');
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
      case SortMode.dateAsc:
        list.sort((a, b) {
          final ta = DateTime.tryParse(a.takenAt ?? '');
          final tb = DateTime.tryParse(b.takenAt ?? '');
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return ta.compareTo(tb);
        });
      case SortMode.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortMode.sizeDesc:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    }
    return list;
  }

  List<Photo> _filter(List<Photo> photos) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return photos;
    return photos.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StoreController>(
      future: StoreController.instance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final controller = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre...',
                      border: InputBorder.none,
                    ),
                  )
                : const Text(
                    'Todas las fotos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            actions: [
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: 'Menos columnas',
                onPressed: _columns > 2
                    ? () => setState(() => _columns--)
                    : null,
              ),
              Text('$_columns', style: Theme.of(context).textTheme.labelLarge),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Más columnas',
                onPressed: _columns < 8
                    ? () => setState(() => _columns++)
                    : null,
              ),
              const SizedBox(width: 4),
              PopupMenuButton<PhotoGroupBy>(
                icon: Icon(
                  switch (_groupBy) {
                    PhotoGroupBy.none => Icons.view_agenda_outlined,
                    PhotoGroupBy.year => Icons.calendar_today,
                    PhotoGroupBy.month => Icons.calendar_view_month,
                  },
                ),
                tooltip: 'Agrupar por',
                onSelected: (mode) => setState(() => _groupBy = mode),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: PhotoGroupBy.none,
                    child: Text('Sin agrupar'),
                  ),
                  PopupMenuItem(
                    value: PhotoGroupBy.year,
                    child: Text('Por año'),
                  ),
                  PopupMenuItem(
                    value: PhotoGroupBy.month,
                    child: Text('Por mes'),
                  ),
                ],
              ),
              IconButton(
                icon: _searching ? const Icon(Icons.close) : const Icon(Icons.search),
                tooltip: 'Buscar',
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query = '';
                }),
              ),
              PopupMenuButton<SortMode>(
                icon: const Icon(Icons.sort),
                tooltip: 'Ordenar',
                onSelected: (mode) => setState(() => _sort = mode),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: SortMode.dateDesc,
                    child: Text('Fecha · la más reciente'),
                  ),
                  PopupMenuItem(
                    value: SortMode.dateAsc,
                    child: Text('Fecha · la más antigua'),
                  ),
                  PopupMenuItem(
                    value: SortMode.nameAsc,
                    child: Text('Nombre (A-Z)'),
                  ),
                  PopupMenuItem(
                    value: SortMode.sizeDesc,
                    child: Text('Tamaño · el mayor primero'),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: _reload,
              ),
            ],
          ),
          body: Builder(builder: (context) {
            if (controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.errorText != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('No se pudo escanear: ${controller.errorText}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            if (controller.photos.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No se encontraron fotos en el equipo'),
                    SizedBox(height: 16),
                    Text(
                      'Se buscan en tu carpeta personal (archivos .jpg, .png, …)',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            final visible = _filter(_sorted(controller.photos));
            if (visible.isEmpty && _query.isNotEmpty) {
              return const Center(child: Text('Sin resultados para la búsqueda'));
            }
            return ThumbnailGrid(
              photos: visible,
              columns: _columns,
              groupBy: _groupBy,
              onChanged: () {
                if (mounted) setState(() {});
              },
            );
          }),
        );
      },
    );
  }
}