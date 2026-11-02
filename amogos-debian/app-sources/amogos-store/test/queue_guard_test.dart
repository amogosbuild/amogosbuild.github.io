// Queue revalidation permits already-satisfied dependencies and refuses newly introduced changes.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';

class ChangedPackages extends StoreService {
  ChangedPackages(this.changes) : super(preview: true);
  final List<Map<String, dynamic>> changes;
  int applications = 0;
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (action == 'apt-plan') {
      return {
        'changes': changes,
        'token': 'new-review',
        'fingerprint': 'changed-installed-state',
      };
    }
    if (action == 'catalog') return {'items': [], 'warnings': [], 'totals': {}};
    if (action == 'details') throw StateError('Not needed for this queue test');
    return {};
  }

  @override
  Stream<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> body,
  ) async* {
    applications++;
    yield {'done': true, 'progress': 1, 'message': 'Installed'};
  }
}

void main() {
  Future<void> finish(StoreController c) async {
    for (var i = 0; i < 20 && c.queueRunning; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  const wanted = {
    'id': 'wanted',
    'action': 'install',
    'version': '1',
    'fromVersion': '',
  };
  const dependency = {
    'id': 'dependency',
    'action': 'install',
    'version': '2',
    'fromVersion': '',
  };
  test('a dependency installed by the previous queue item does not require another approval', () async {
    final service = ChangedPackages([wanted]);
    final controller = StoreController(service: service);
    final job = StoreJob(
      title: 'Wanted',
      source: 'deb',
      operation: 'install',
      request: {'id': 'wanted'},
      review: {
        'fingerprint': 'old-state',
        'changes': [wanted, dependency],
      },
    );
    await controller.enqueue(job);
    await finish(controller);
    expect(job.status, JobStatus.completed);
    expect(service.applications, 1);
    controller.dispose();
  });
  test('additional unreviewed dependencies stop a queued install', () async {
    final service = ChangedPackages([wanted, dependency]);
    final controller = StoreController(service: service);
    final job = StoreJob(
      title: 'Wanted',
      source: 'deb',
      operation: 'install',
      request: {'id': 'wanted'},
      review: {
        'changes': [wanted],
      },
    );
    await controller.enqueue(job);
    await finish(controller);
    expect(job.status, JobStatus.failed);
    expect(service.applications, 0);
    expect(job.message, contains('Review it again'));
    controller.dispose();
  });
}
