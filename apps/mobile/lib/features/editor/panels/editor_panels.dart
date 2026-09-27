import 'package:material_ui/material_ui.dart';

import '../../../core/l10n.dart';
import '../../../design/design.dart';
import 'cover_panel.dart';
import 'format_panel.dart';
import 'pages_panel.dart';
import 'photos_panel.dart';
import 'theme_panel.dart';

/// Bottom tabs: Pages, Photos, Theme, Cover, Format (section 8.6).
class EditorPanels extends StatelessWidget {
  const EditorPanels({
    required this.albumId,
    required this.currentSpread,
    required this.onGoToPage,
    super.key,
  });

  final String albumId;
  final int currentSpread;
  final ValueChanged<int> onGoToPage;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final height = (MediaQuery.sizeOf(context).height * 0.3).clamp(
      190.0,
      300.0,
    );
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.sheetTop,
        ),
        child: DefaultTabController(
          length: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                tabs: [
                  Tab(text: l.tabPages),
                  Tab(text: l.tabPhotos),
                  Tab(text: l.tabTheme),
                  Tab(text: l.tabCover),
                  Tab(text: l.tabFormat),
                ],
              ),
              SizedBox(
                height: height,
                child: TabBarView(
                  children: [
                    PagesPanel(albumId: albumId, onGoToPage: onGoToPage),
                    PhotosPanel(albumId: albumId, currentSpread: currentSpread),
                    ThemePanel(albumId: albumId),
                    CoverPanel(albumId: albumId),
                    FormatPanel(albumId: albumId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
