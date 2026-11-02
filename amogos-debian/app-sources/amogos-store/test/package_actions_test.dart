// Install failures, empty reviews, repairs, and operation labels remain visible to the user.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';
import 'package:amogos_store/features/details/package_details.dart';

class ActionService extends StoreService {
  ActionService({this.fail = false, this.installed = false})
    : super(preview: true);
  final bool fail, installed;
  Map<String, dynamic>? plan;
  Map<String, dynamic> get item => {
    'id': 'gimp',
    'name': 'GIMP',
    'source': 'deb',
    'repo': 'deb.debian.org|stable|main',
    'installed': installed,
  };
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (action == 'details') return item;
    if (action == 'alternatives') {
      return {
        'items': [item],
      };
    }
    if (action == 'apt-plan') {
      plan = body;
      if (fail) {
        throw StateError('Repository dependency failure');
      }
      return {'changes': []};
    }
    return {};
  }
}

void main() {
  for (final fail in [true, false]) {
    testWidgets(
      'install shows ${fail ? 'the actual error' : 'an already satisfied review'}',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = ActionService(fail: fail);
        final controller = StoreController(service: service);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PackageDetails(
                controller: controller,
                initial: StorePackage(service.item),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Install preview'));
        await tester.pumpAndSettle();
        expect(
          find.text('Package changes could not be prepared'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            fail
                ? 'Repository dependency failure'
                : 'No package changes are needed.',
          ),
          findsWidgets,
        );
        expect(service.plan?['id'], 'gimp');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
  testWidgets('installed APT app offers a repair review', (tester) async {
    final service = ActionService(installed: true);
    final controller = StoreController(service: service);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackageDetails(
            controller: controller,
            initial: StorePackage(service.item),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repair'));
    await tester.pumpAndSettle();
    expect(service.plan?['operation'], 'repair');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  test('queue activity distinguishes removals, repair, update and install', () {
    StoreJob job(String op) => StoreJob(
      title: 'App',
      source: 'deb',
      operation: op,
      request: {},
      review: {},
    );
    expect(job('remove').activity, 'Uninstalling');
    expect(job('repair').activity, 'Repairing');
    expect(job('update-selected').activity, 'Updating');
    expect(job('install').activity, 'Installing');
  });
}
