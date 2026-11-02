// Queue notices stay centred above dialog barriers, refresh their timer, and dismiss after four seconds.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/services/store_service.dart';
import 'package:amogos_store/features/widgets/notification_pill.dart';

void main() {
  for (final width in [400.0, 1280.0]) {
    testWidgets('notification floats above dialogs at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = StoreController(service: StoreService(preview: true));
      var opened = 0;
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => NotificationPillHost(
            controller: controller,
            onViewQueue: () => opened++,
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      showDialog<void>(
        context: page,
        builder: (context) => const AlertDialog(title: Text('App details')),
      );
      await tester.pumpAndSettle();
      controller.showNotification('GIMP added to your queue', showQueue: true);
      await tester.pumpAndSettle();
      final pill = find.byKey(const ValueKey('notification-pill'));
      final rect = tester.getRect(pill);
      expect(rect.center.dx, closeTo(width / 2, .1));
      expect(rect.bottom, lessThanOrEqualTo(784));
      await tester.tap(find.text('View queue'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(pill, findsNothing);
      expect(find.text('App details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  testWidgets(
    'new message replaces old message and timer without getting stuck',
    (tester) async {
      final controller = StoreController(service: StoreService(preview: true));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => NotificationPillHost(
            controller: controller,
            onViewQueue: () {},
            child: child!,
          ),
          home: const Scaffold(),
        ),
      );
      controller.showNotification('First');
      await tester.pump(const Duration(seconds: 3));
      controller.showNotification('Second');
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Second'), findsOneWidget);
      expect(controller.notification.value?.message, 'Second');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('notification-pill')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
