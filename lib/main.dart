import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/nphotos_app.dart';
import 'services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final store = await LocalStore.load();
  store.applyAppearance();
  runApp(NPhotosApp(store: store));
}
