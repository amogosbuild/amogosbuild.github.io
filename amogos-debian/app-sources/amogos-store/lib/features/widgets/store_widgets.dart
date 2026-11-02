// Shared app cards and source filters retain the reference design's simple rounded forms.
import 'package:flutter/material.dart';

import '../../app/store_theme.dart';
import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../details/package_details.dart';

const bundledIcons = {
  'org.videolan.VLC',
  'com.valvesoftware.Steam',
  'com.heroicgameslauncher.hgl',
  'com.discordapp.Discord',
  'com.thebrokenrail.MCPIReborn',
  'org.gimp.GIMP',
  'org.mozilla.firefox',
  'org.kde.krita',
  'org.libreoffice.LibreOffice',
};

class PackageIcon extends StatelessWidget {
  const PackageIcon(this.package, {super.key, this.size = 64});
  final StorePackage package;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(
        package.source == 'deb'
            ? Icons.inventory_2_rounded
            : package.source == 'appimage'
            ? Icons.rocket_launch_rounded
            : Icons.apps_rounded,
        size: size * .48,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    final image = bundledIcons.contains(package.iconId)
        ? Image.asset(
            'assets/catalog/${package.iconId}.png',
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(32, 256),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          )
        : package.icon.isNotEmpty
        ? Image.network(
            package.icon,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(32, 256),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
    return SizedBox(width: size, height: size, child: image);
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key});
  final String source;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      sourceLabels[source] ?? source,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    required this.controller,
    this.essential = false,
  });
  final StorePackage package;
  final StoreController controller;
  final bool essential;
  @override
  Widget build(BuildContext context) {
    final title = package.id == 'com.thebrokenrail.MCPIReborn'
        ? 'MCP Revived'
        : package.id == 'com.heroicgameslauncher.hgl'
        ? 'Heroic'
        : package.name;
    return Material(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showPackage(context, controller, package),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PackageIcon(package, size: essential ? 65 : 52),
              const SizedBox(height: 17),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: essential ? 19 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              if (!essential)
                Text(
                  package.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              SourceBadge(package.source),
            ],
          ),
        ),
      ),
    );
  }
}

class SourceFilters extends StatelessWidget {
  const SourceFilters({super.key, required this.controller});
  final StoreController controller;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final entry in sourceLabels.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: controller.source == entry.key,
          onSelected: (_) => controller.filterSource(entry.key),
          showCheckmark: false,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      if (controller.page != StorePage.installed &&
          controller.repositories.isNotEmpty &&
          (controller.source == 'deb' || controller.source == 'all'))
        SizedBox(
          width: (MediaQuery.sizeOf(context).width - 64).clamp(100, 260),
          child: DropdownButtonFormField<String>(
            key: ValueKey(controller.repo),
            initialValue: controller.repo,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'APT repository',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('All repositories'),
              ),
              for (final r in controller.repositories)
                DropdownMenuItem(
                  value: r['id'] as String,
                  child: Text(
                    r['name'] as String,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => controller.filterRepo(value ?? ''),
          ),
        ),
    ],
  );
}

class StoreNotice extends StatelessWidget {
  const StoreNotice(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.color = const Color(0xffd522e6),
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class AdaptiveFields extends StatelessWidget {
  const AdaptiveFields({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth < 560
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                if (child is Expanded)
                  child.child
                else if (child is Flexible)
                  child.child
                else if (child is SizedBox)
                  SizedBox(height: child.width ?? child.height ?? 12)
                else if (child is! Spacer)
                  child,
            ],
          )
        : Row(crossAxisAlignment: crossAxisAlignment, children: children),
  );
}
