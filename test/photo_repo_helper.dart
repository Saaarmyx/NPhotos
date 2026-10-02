import 'package:NexoraCore/NexoraCore.dart';
import 'package:NPhotos/services/photo_repository.dart';

/// Repositorio de fotos para tests, con `MediaRepository` inyectado.
///
/// # Por qué el isolate va apagado
///
/// El de producción usa `DartFsScanner(useIsolate: true)`, que es lo
/// correcto: recorrer el almacenamiento en el isolate principal congela
/// la UI. Pero `compute` lanza un isolate real y bajo el reloj falso de
/// `testWidgets` no termina a tiempo, así que el escaneo devuelve
/// **parcial** y el fallo se manifiesta como "faltan álbumes", que no
/// apunta al problema.
///
/// Con `useIsolate: false` el recorrido es determinista. Lo que se sigue
/// probando es lo que importa: que el controlador consume el repositorio,
/// no qué tan rápido escanea.
PhotoRepository testPhotoRepository({String? root}) =>
    PhotoRepository(
      media: DefaultMediaRepository(
        scanners: FsScannerRegistry(
          scanners: const [DartFsScanner(useIsolate: false)],
        ),
      ),
      roots: root == null ? null : [root],
    );
