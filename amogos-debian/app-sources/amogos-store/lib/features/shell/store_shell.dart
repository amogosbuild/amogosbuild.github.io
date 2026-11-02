// Compact windows use a drawer while large windows keep the animated rose sidebar.
import 'package:flutter/material.dart';

import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../browse/browse_page.dart';
import '../sources/sources_page.dart';
import '../updates/updates_page.dart';
import '../queue/queue_dialog.dart';
import 'store_sidebar.dart';

class StoreShell extends StatelessWidget {
  const StoreShell({super.key, required this.controller});
  final StoreController controller;
  Widget _page() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: KeyedSubtree(
      key: ValueKey(controller.page),
      child: switch (controller.page) {
        StorePage.updates => UpdatesPage(controller: controller),
        StorePage.sources => SourcesPage(controller: controller),
        _ => BrowsePage(controller: controller),
      },
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _build(context),
  );
  Widget _build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 1000 || box.maxHeight < 680;
      return Scaffold(
        appBar: compact
            ? AppBar(
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: StoreSearchField(controller: controller),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Installation queue',
                    onPressed: () => showQueue(context, controller),
                    icon: Badge(
                      isLabelVisible: controller.waitingCount > 0,
                      label: Text('${controller.waitingCount}'),
                      child: const Icon(Icons.downloading_rounded),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Change theme',
                    onPressed: controller.toggleTheme,
                    icon: Icon(
                      controller.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                ],
              )
            : null,
        drawer: compact
            ? Drawer(
                width: (box.maxWidth - 32).clamp(240, 300),
                child: SafeArea(
                  child: Builder(
                    builder: (context) => StoreSidebar(
                      controller: controller,
                      width: double.infinity,
                      onNavigate: () => Navigator.pop(context),
                    ),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: compact
                ? _page()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StoreSidebar(
                        controller: controller,
                        width: box.maxWidth < 1100 ? 220 : 258,
                      ),
                      SizedBox(width: box.maxWidth < 1100 ? 25 : 38),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18, right: 12),
                          child: _page(),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
