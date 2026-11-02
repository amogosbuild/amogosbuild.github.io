// The selection dot moves behind bold navigation labels and the queue lives above the footer.
import 'package:flutter/material.dart';

import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../queue/queue_dialog.dart';

class StoreSidebar extends StatelessWidget {
  const StoreSidebar({
    super.key,
    required this.controller,
    required this.width,
    this.onNavigate,
  });
  final StoreController controller;
  final double width;
  final VoidCallback? onNavigate;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xffa35453),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(
                    height: 148,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(color: const Color(0xff702729)),
                        ),
                        Positioned(
                          left: 23,
                          top: 29,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AmogOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'App Store',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: -8,
                          bottom: -12,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Image.asset(
                              'assets/characters/${c.shopper}',
                              key: ValueKey(c.shopper),
                              width: 150,
                              height: 118,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        if (c.shopperRoll < .10)
                          Positioned(
                            left: 23,
                            bottom: 15,
                            child: Text(
                              c.shopperRoll < .02
                                  ? 'A very rare visitor!'
                                  : 'A little lucky today.',
                              style: const TextStyle(
                                color: Color(0xfff7c7b8),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xffa35453),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(13, 15, 13, 20),
                          child: StoreSearchField(controller: c, rose: true),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: SizedBox(
                            height: StorePage.values.length * 51.0 + 10,
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  key: const ValueKey('navigation-dot'),
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.easeInOutCubic,
                                  left: 9,
                                  top: c.page.index * 51.0 + 12,
                                  width: 22,
                                  height: 22,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: .28,
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    for (final p in StorePage.values)
                                      SizedBox(
                                        height: 51,
                                        width: double.infinity,
                                        child: Semantics(
                                          selected: c.page == p,
                                          button: true,
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.only(
                                                left: 22,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                            ),
                                            onPressed: () {
                                              c.selectPage(p);
                                              onNavigate?.call();
                                            },
                                            child: AnimatedDefaultTextStyle(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 22,
                                                fontWeight: c.page == p
                                                    ? FontWeight.w800
                                                    : FontWeight.w400,
                                                color: Colors.white,
                                              ),
                                              child: Text(pageLabels[p.index]),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Material(
                            color: Colors.white.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(17),
                            child: InkWell(
                              key: const ValueKey('queue-button'),
                              borderRadius: BorderRadius.circular(17),
                              onTap: () => showQueue(context, c),
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Row(
                                  children: [
                                    Badge(
                                      isLabelVisible: c.waitingCount > 0,
                                      label: Text(c.waitingCount.toString()),
                                      child: const Icon(
                                        Icons.downloading_rounded,
                                        color: Colors.white,
                                        size: 23,
                                      ),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Queue',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            c.currentJob != null
                                                ? 'Installing now'
                                                : c.waitingCount > 0
                                                ? 'Waiting to install'
                                                : 'Make room for something new',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xfff1d1cc),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xfff1d1cc),
                                      size: 17,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (c.currentJob != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 9, 22, 0),
                            child: LinearProgressIndicator(
                              value: c.currentJob!.progress,
                              color: const Color(0xfffdc8ba),
                              backgroundColor: Colors.white12,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 13, 12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'A little more AmogOS.',
                                  style: TextStyle(
                                    color: Color(0xfff0c6bf),
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: c.toggleTheme,
                                tooltip: c.dark
                                    ? 'Switch to light mode'
                                    : 'Switch to dark mode',
                                icon: Icon(
                                  c.dark
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StoreSearchField extends StatefulWidget {
  const StoreSearchField({
    super.key,
    required this.controller,
    this.rose = false,
  });
  final StoreController controller;
  final bool rose;
  @override
  State<StoreSearchField> createState() => _StoreSearchFieldState();
}

class _StoreSearchFieldState extends State<StoreSearchField> {
  late final text = TextEditingController(text: widget.controller.query);
  @override
  void didUpdateWidget(covariant StoreSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (text.text != widget.controller.query) {
      text.value = TextEditingValue(
        text: widget.controller.query,
        selection: TextSelection.collapsed(
          offset: widget.controller.query.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: text,
    onChanged: widget.controller.search,
    style: TextStyle(color: widget.rose ? Colors.white : null, fontSize: 12),
    decoration: InputDecoration(
      hintText: 'Search mate',
      isDense: true,
      hintStyle: TextStyle(color: widget.rose ? const Color(0xfff3d7d3) : null),
      fillColor: widget.rose ? Colors.white.withValues(alpha: .23) : null,
      suffixIcon: Icon(
        Icons.search_rounded,
        color: widget.rose ? Colors.white : null,
        size: 21,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(19),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    ),
  );
}
