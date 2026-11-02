// Multiple AppImageHub listings remain selectable with their own compatible download choices.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';
import 'package:amogos_store/features/details/package_details.dart';

void main() {
  testWidgets('users can choose another AppImage listing and its build', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = StoreService(preview: true);
    await service.initialize();
    final first = service.samples.firstWhere((p) => p.source == 'appimage');
    final other = StorePackage({
      ...first.data,
      'id': '5555555',
      'name': 'Krita Classic',
      'version': '1.0',
      'downloads': [
        {...first.downloads.first, 'name': 'Krita-Classic-x86_64.AppImage'},
      ],
    });
    service.samples.add(other);
    final controller = StoreController(service: service);
    await tester.pumpWidget(
      MaterialApp(
        home: PackageDetails(controller: controller, initial: first),
      ),
    );
    await tester.pumpAndSettle();
    final picker = find.byKey(ValueKey('appimage-listing-${first.key}'));
    expect(picker, findsOneWidget);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Krita Classic · 1.0').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('appimage-listing-${other.key}')),
      findsOneWidget,
    );
    expect(find.text('Krita-Classic-x86_64.AppImage'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
