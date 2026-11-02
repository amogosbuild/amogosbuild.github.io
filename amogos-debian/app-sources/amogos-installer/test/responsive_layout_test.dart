// Every wizard step and compact music tab remains usable without overflowing the viewport.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_installer/app/installer_app.dart';
import 'package:amogos_installer/features/setup/setup_shell.dart';
import 'package:amogos_installer/features/music/source/models/track.dart';
import 'package:amogos_installer/core/models/install_models.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(640, 480),
    const Size(800, 600),
    const Size(1024, 600),
  ]) {
    testWidgets('all installer steps fit $size with enlarged text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const InstallerApp(preview: true)),
      );
      final shell = tester.widget<SetupShell>(find.byType(SetupShell)),
          c = shell.controller;
      await c.refreshHardware();
      for (final dark in [false, true]) {
        c.dark = dark;
        for (var step = 0; step < 7; step++) {
          c.change(() => c.step = step);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: '$size step $step');
          if (step < 6) {
            final list = find.byType(SingleChildScrollView).first;
            await tester.drag(list, const Offset(0, -1500));
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              tester.takeException(),
              isNull,
              reason: '$size scrolled step $step',
            );
          }
          if (step == 3) {
            for (final mode in InstallMode.values) {
              c.change(() {
                c.mode = mode;
                c.bootPlacement = 'custom';
              });
              await tester.pump(const Duration(milliseconds: 350));
              expect(
                tester.takeException(),
                isNull,
                reason: '$size storage $mode',
              );
            }
          }
        }
      }
      shell.music.queue.add(
        const Track(
          id: 'preview',
          title: 'Installer soundtrack',
          artist: 'AmogOS',
          source: MusicSource.youtube,
          sourceId: 'preview0000',
        ),
      );
      await tester.tap(find.byTooltip('Your soundtrack'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Player'), findsOneWidget);
      for (final tab in ['Player', 'Up next', 'Find music']) {
        await tester.tap(find.text(tab));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Close music player'));
      await tester.pump(const Duration(milliseconds: 400));
      c.change(() => c.step = 0);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));
      if (size.width == 640) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/previews/responsive-640x480.png')
            ..parent.createSync(recursive: true);
          file.writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
