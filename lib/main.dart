import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'app/nphotos_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  AppAppearance.setAccentColor(NColors.photosAccent);
  runApp(const NPhotosApp());
}
