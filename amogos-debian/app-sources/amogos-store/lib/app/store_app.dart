// Application ownership keeps the browsing shell and queue alive across navigation.
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/controllers/store_controller.dart';
import '../core/services/store_service.dart';
import '../features/shell/store_shell.dart';
import 'store_theme.dart';

class StoreApp extends StatefulWidget {
  const StoreApp({super.key, required this.preview, this.controller});
  final bool preview;
  final StoreController? controller;
  @override
  State<StoreApp> createState() => _StoreAppState();
}

class _StoreAppState extends State<StoreApp> {
  late final StoreController controller;
  @override
  void initState() {
    super.initState();
    controller =
        widget.controller ??
        StoreController(service: StoreService(preview: widget.preview));
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller.darkTheme,
    child: StoreShell(controller: controller),
    builder: (context, dark, child) => MaterialApp(
      title: 'AmogOS App Store',
      debugShowCheckedModeBanner: false,
      theme: storeTheme(false),
      darkTheme: storeTheme(true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: child,
    ),
  );
}
