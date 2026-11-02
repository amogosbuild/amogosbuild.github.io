// The native Linux store and Windows design preview share the same Flutter interface.
import 'dart:io';

import 'package:flutter/material.dart';

import 'app/store_app.dart';

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSize = 64
    ..maximumSizeBytes = 16 * 1024 * 1024;
  runApp(
    StoreApp(preview: !Platform.isLinux || arguments.contains('--preview')),
  );
}
