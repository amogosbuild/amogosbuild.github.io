// Compact views retain navigation, installed inventory, source selection and update review controls.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/app/store_app.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';
import 'package:amogos_store/features/details/package_details.dart';
import 'package:amogos_store/features/queue/queue_dialog.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(640, 480),
    const Size(800, 600),
    const Size(1024, 600),
  ]) {
    testWidgets('all store pages fit $size with enlarged text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      final c = StoreController(service: StoreService(preview: true));
      await tester.runAsync(c.initialize);
      c.service.samples = [
        for (final p in c.service.samples)
          StorePackage({...p.data, 'installed': true}),
      ];
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: StoreApp(preview: true, controller: c),
        ),
      );
      await tester.pumpAndSettle();
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffold.openDrawer();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Installed'));
      await tester.tap(find.text('Installed'));
      await tester.pumpAndSettle();
      expect(c.page, StorePage.installed);
      expect(find.text('Installed software'), findsOneWidget);
      expect(c.packages.every((p) => p.installed), isTrue);
      for (final dark in [true, false]) {
        c.dark = dark;
        for (final page in StorePage.values) {
          c.selectPage(page);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $page dark=$dark',
          );
          final scroll = find
              .descendant(
                of: find.byKey(const ValueKey('updates-list')),
                matching: find.byType(Scrollable),
              )
              .first;
          if (page == StorePage.updates) {
            c.selectAllUpdates('appimage', true);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('AppImage updates'),
              200,
              scrollable: scroll,
            );
            await tester.pumpAndSettle();
            expect(find.text('Review selected (1)'), findsOneWidget);
          } else if (page == StorePage.home) {
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        }
      }
      final context = tester.element(find.byType(Scaffold).first);
      showQueue(context, c);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close queue'));
      await tester.pumpAndSettle();
      showPackage(context, c, c.service.samples.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close app details'));
      await tester.pumpAndSettle();
      c.selectPage(StorePage.home);
      await tester.pumpAndSettle();
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
      c.dispose();
    });
  }
}
