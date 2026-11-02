// Featured software and four essentials anchor searchable catalogs from all three formats.
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/store_theme.dart';
import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../details/package_details.dart';
import '../widgets/store_widgets.dart';

class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key, required this.controller});
  final StoreController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final home =
        c.page == StorePage.home &&
        c.query.isEmpty &&
        c.source == 'all' &&
        c.category.isEmpty;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return ListView(
      padding: const EdgeInsets.only(bottom: 35),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                home
                    ? '$greeting, ${c.name}!'
                    : c.query.isNotEmpty
                    ? 'Results for “${c.query}”'
                    : c.page == StorePage.installed
                    ? 'Installed software'
                    : c.page == StorePage.fresh
                    ? 'Fresh on the shelves.'
                    : 'Find your next favourite.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (c.preview && MediaQuery.sizeOf(context).width > 600)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'WINDOWS PREVIEW',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          home
              ? 'A few favourites. A whole world to explore.'
              : c.page == StorePage.installed
              ? 'All installed APT packages, Flatpak applications and runtimes, and AppImages managed by this store.'
              : c.page == StorePage.fresh
              ? 'Recently added on Flathub and AppImageHub.'
              : 'Great software, from the source you choose.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        if (home) ...[
          if (c.featured != null)
            FeaturedBanner(package: c.featured!, controller: c)
          else
            const SizedBox(
              height: 210,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          const SizedBox(height: 30),
          SectionHeading(
            'AmogOS Essentials',
            action: 'Explore all',
            onAction: () => c.selectPage(StorePage.categories),
          ),
          const SizedBox(height: 19),
          LayoutBuilder(
            builder: (context, box) => GridView.count(
              crossAxisCount: _columns(box.maxWidth),
              mainAxisSpacing: 16,
              crossAxisSpacing: 18,
              mainAxisExtent:
                  198 + (MediaQuery.textScalerOf(context).scale(100) - 100),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final p in c.essentials)
                  PackageCard(package: p, controller: c, essential: true),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.fromLTRB(23, 16, 23, 16),
            decoration: BoxDecoration(
              color: cardColor(context),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/characters/wideshopper.png',
                  width: MediaQuery.sizeOf(context).width < 600 ? 70 : 140,
                  height: 66,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Something for every kind of you.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Play, create, code, or just make life a little easier.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => c.selectPage(StorePage.categories),
                  tooltip: 'Browse categories',
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeading('Browse the shelves', color: Color(0xff25c985)),
          const SizedBox(height: 17),
        ],
        if (c.page == StorePage.categories) ...[
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ChoiceChip(
                label: const Text('Everything'),
                selected: c.category.isEmpty,
                onSelected: (_) => c.filterCategory(''),
                showCheckmark: false,
              ),
              for (final cat in categoryLabels.entries)
                ChoiceChip(
                  label: Text(cat.value),
                  selected: c.category == cat.key,
                  onSelected: (_) => c.filterCategory(cat.key),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        SourceFilters(controller: c),
        const SizedBox(height: 21),
        if (c.source == 'flatpak' && !c.flatpakAvailable) ...[
          const StoreNotice(
            'Flatpak needs to be installed to install apps from this source.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => c.selectPage(StorePage.sources),
              child: const Text('Install Flatpak in Sources'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (c.error != null) ...[
          StoreNotice(c.error!, onRetry: c.loadCatalog),
          const SizedBox(height: 16),
        ],
        for (final warning in c.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StoreNotice(
              '${sourceLabels[warning['source']] ?? warning['source']}: ${warning['message']}',
            ),
          ),
        if (c.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (!c.loading && c.packages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 35),
            child: Column(
              children: [
                Image.asset(
                  'assets/characters/sillyshopper.png',
                  width: 150,
                  height: 145,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Nothing in this aisle yet.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try a different name, format, or repository.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        if (c.packages.isNotEmpty)
          LayoutBuilder(
            builder: (context, box) => GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns(box.maxWidth),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent:
                    220 + (MediaQuery.textScalerOf(context).scale(140) - 140),
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: c.packages.length,
              itemBuilder: (context, i) =>
                  PackageCard(package: c.packages[i], controller: c),
            ),
          ),
        if (!c.loading && (c.hasMore || c.catalogPage > 0))
          Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (c.catalogPage > 0)
                  OutlinedButton(
                    onPressed: () =>
                        c.loadCatalog(targetPage: c.catalogPage - 1),
                    child: const Text('Previous page'),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Page ${c.catalogPage + 1}'),
                ),
                if (c.hasMore)
                  OutlinedButton(
                    onPressed: () => c.loadCatalog(more: true),
                    child: const Text('Next page'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class FeaturedBanner extends StatelessWidget {
  const FeaturedBanner({
    super.key,
    required this.package,
    required this.controller,
  });
  final StorePackage package;
  final StoreController controller;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(27),
    child: Stack(
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Image.asset(
              'assets/catalog/vlc-banner.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xf01c2120),
                  Color(0xbb262d29),
                  Color(0xcd171b1a),
                ],
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 620;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '● FEATURED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xfff0ee26),
                  ),
                ),
                const SizedBox(height: 13),
                const Text(
                  'VLC Media Player',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Your movies. Your music. All together.',
                  style: TextStyle(fontSize: 14, color: Color(0xffe3e6e2)),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Open source. Endlessly versatile.',
                  style: TextStyle(fontSize: 10, color: Color(0xffbac3bc)),
                ),
              ],
            );
            final button = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff1bd276),
                foregroundColor: const Color(0xff092f1c),
                padding: const EdgeInsets.symmetric(
                  horizontal: 23,
                  vertical: 21,
                ),
                shape: const StadiumBorder(),
              ),
              onPressed: () => showPackage(context, controller, package),
              icon: const Icon(Icons.download_rounded, size: 21),
              label: const Text('Install'),
            );
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 214),
              child: Padding(
                padding: EdgeInsets.all(compact ? 22 : 31),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [copy, const SizedBox(height: 18), button],
                      )
                    : Row(
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 16),
                          button,
                        ],
                      ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

int _columns(double width) => width < 320
    ? 1
    : width < 600
    ? 2
    : width < 840
    ? 3
    : 4;
