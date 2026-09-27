import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';

/// Height of the floating navigation, and its distance from the edges.
const double kNavHeight = 68;
const double kNavMargin = 16;

/// Bottom space a scrolling tab screen leaves for the floating navigation.
double navClearance(BuildContext context) =>
    kNavHeight + kNavMargin * 2 + MediaQuery.paddingOf(context).bottom;

/// Floating pill navigation with four destinations: Home, Books, Orders,
/// Settings.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.home_outlined, Icons.home_rounded, l.navHome),
      (Icons.auto_stories_outlined, Icons.auto_stories_rounded, l.navBooks),
      (
        Icons.local_shipping_outlined,
        Icons.local_shipping_rounded,
        l.navOrders,
      ),
      (Icons.tune_outlined, Icons.tune_rounded, l.navSettings),
    ];
    final c = MemoriaColors.of(context);
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          shell,
          // Keeps scrolled content from running under the status bar.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: MediaQuery.paddingOf(context).top,
            child: ColoredBox(color: c.background.withValues(alpha: 0.94)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          kNavMargin,
          0,
          kNavMargin,
          kNavMargin,
        ),
        child: _FloatingNav(
          index: shell.currentIndex,
          items: items,
          onTap: (i) {
            HapticFeedback.selectionClick();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
        ),
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.items,
    required this.onTap,
  });

  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Radii.pillAll,
          boxShadow: Shadows.raised(c),
        ),
        child: ClipRRect(
          borderRadius: Radii.pillAll,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: kNavHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: c.navBar,
                borderRadius: Radii.pillAll,
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        label: items[i].$3,
                        child: InkWell(
                          borderRadius: Radii.pillAll,
                          onTap: () => onTap(i),
                          child: ExcludeSemantics(
                            child: AnimatedContainer(
                              duration: Motion.short,
                              curve: Motion.curve,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: i == index
                                    ? c.surfaceTint
                                    : Colors.transparent,
                                borderRadius: Radii.pillAll,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    i == index ? items[i].$2 : items[i].$1,
                                    size: 22,
                                    color: i == index
                                        ? c.primary
                                        : c.textSecondary,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    items[i].$3,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.labelSmall?.copyWith(
                                      color: i == index
                                          ? c.primary
                                          : c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
