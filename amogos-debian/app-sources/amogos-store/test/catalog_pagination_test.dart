// Failed catalog requests keep the last successful page so retrying cannot skip APT packages.
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/services/store_service.dart';

class PagedCatalog extends StoreService {
  PagedCatalog() : super(preview: false);
  final pages = <int>[];
  bool fail = false;

  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    final page = body['page'] as int;
    pages.add(page);
    if (fail) {
      fail = false;
      throw StateError('Temporary catalog error');
    }
    return {
      'items': [
        for (var i = 0; i < 24; i++)
          {'id': 'package-${page * 24 + i}', 'source': 'deb', 'repo': 'main'},
      ],
      'warnings': [],
      'totals': {'deb': 70000},
    };
  }
}

void main() {
  test('APT load more retries the same page after a failed request', () async {
    final service = PagedCatalog();
    final controller = StoreController(service: service);
    await controller.loadCatalog();
    expect(controller.hasMore, isTrue);
    expect(controller.packages.length, 24);
    service.fail = true;
    await controller.loadCatalog(more: true);
    expect(controller.catalogPage, 0);
    expect(controller.error, contains('Temporary catalog error'));
    await controller.loadCatalog(more: true);
    expect(service.pages, [0, 1, 1]);
    expect(controller.catalogPage, 1);
    expect(controller.packages.length, 24);
    expect(controller.packages.first.id, 'package-24');
    await controller.loadCatalog(targetPage: 0);
    expect(controller.packages.first.id, 'package-0');
    controller.dispose();
  });
}
