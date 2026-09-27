import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../data/domain_kit.dart';
import '../../data/photos/photo_library.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/illustration/character_sheet.dart';
import '../../domain/illustration/illustrated_edition.dart';
import '../../domain/model/album.dart';
import '../../router/app_router.dart';

String styleName(AppLocalizations l, IllustrationStyle s) => switch (s) {
  IllustrationStyle.watercolor => l.styleWatercolor,
  IllustrationStyle.inkSketch => l.styleInkSketch,
  IllustrationStyle.comic => l.styleComic,
  IllustrationStyle.caricature => l.styleCaricature,
  IllustrationStyle.animated3d => l.styleAnimated3d,
};

/// How many photos are redrawn at once (each runs in its own isolate).
const int _kParallel = 3;

/// Cartoon & Comic Edition: pick a style, see the character sheet, redraw
/// the album into a new illustrated book.
class IllustratedScreen extends ConsumerStatefulWidget {
  const IllustratedScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<IllustratedScreen> createState() => _IllustratedScreenState();
}

class _IllustratedScreenState extends ConsumerState<IllustratedScreen> {
  Album? _album;
  List<Uint8List>? _previews;
  IllustrationStyle _style = IllustrationStyle.watercolor;
  CharacterSheet? _sheet;
  IllustrationStyle? _sheetStyle;
  IllustrationScope _scope = IllustrationScope.wholeBook;
  bool _consent = false;
  (int, int)? _progress;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  PhotoImages get _images => ref.read(photoImagesProvider);

  Future<Uint8List?> _bytes(PhotoRef p, int size) async {
    final asset = p.localAssetId;
    if (asset == null) return null;
    return _images.libraryFor(asset).thumbnailBytes(asset, size);
  }

  Future<void> _load() async {
    final album = await ref.read(albumRepositoryProvider).load(widget.albumId);
    if (album == null || !mounted) return;
    setState(() => _album = album);
    final sources = characterSources(album);
    final preview = sources.isNotEmpty
        ? sources.first
        : album.photos[album.usedPhotoIds.first];
    if (preview != null) {
      final bytes = await _bytes(preview, 800);
      if (bytes != null) {
        final previews = await compute(stylePreviews, (
          bytes,
          preview.faces.isEmpty ? null : preview.faces.first,
        ));
        if (mounted) setState(() => _previews = previews);
      }
    }
    await _buildSheet();
  }

  Future<void> _buildSheet() async {
    final album = _album;
    if (album == null) return;
    final style = _style;
    final sources = <CharacterSource>[];
    for (final p in characterSources(album)) {
      final bytes = await _bytes(p, 1200);
      final face = p.faces.reduce((a, b) => a.w * a.h >= b.w * b.h ? a : b);
      if (bytes != null) sources.add(CharacterSource(bytes, face));
    }
    final sheet = await compute(buildCharacterSheet, (sources, style));
    if (mounted && _style == style) {
      setState(() {
        _sheet = sheet;
        _sheetStyle = style;
      });
    }
  }

  void _pick(IllustrationStyle s) {
    if (s == _style) return;
    setState(() {
      _style = s;
      _sheet = null;
    });
    unawaited(_buildSheet());
  }

  Future<void> _make() async {
    final album = _album;
    final sheet = _sheet;
    if (album == null || sheet == null || _progress != null) return;
    final kit = await ref.read(domainKitProvider.future);
    final styles = ref.read(styleProviderProvider);
    final pages = illustratedPages(album, _scope);
    final ids = photosToIllustrate(album, pages).toList();
    setState(() {
      _progress = (0, ids.length);
      _failed = false;
    });
    try {
      final artwork = <String, PhotoRef>{};
      var next = 0;
      Future<void> worker() async {
        while (next < ids.length) {
          final id = ids[next++];
          artwork[id] = await styles.stylize(
            album.photos[id]!,
            _style,
            palette: sheet.palette.isEmpty ? null : sheet.palette,
          );
          if (mounted) setState(() => _progress = (artwork.length, ids.length));
        }
      }

      await Future.wait([for (var i = 0; i < _kParallel; i++) worker()]);
      final ill = buildIllustratedAlbum(
        album: album,
        newId: const Uuid().v4(),
        artwork: artwork,
        pages: pages,
        style: _style,
        fonts: kit.fonts,
        now: DateTime.now().toUtc(),
      );
      await ref.read(albumRepositoryProvider).save(ill);
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      // The new book opens in the preview, with its editor underneath.
      context.go(Routes.albumPreview(ill.id));
    } on Object catch (e, st) {
      await ref.read(crashReporterProvider).report(e, st);
      if (mounted) {
        setState(() {
          _progress = null;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final previews = _previews;
    final progress = _progress;
    final busy = progress != null;
    return Scaffold(
      appBar: AppBar(title: Text(l.editionCartoonName)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  0,
                  Space.lg,
                  Space.md,
                ),
                children: [
                  Text(l.illustratedIntro, style: t.bodyMedium),
                  const SizedBox(height: Space.md),
                  SizedBox(
                    height: 196,
                    child: previews == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: Space.sm),
                                Text(
                                  l.illustratedPreparing,
                                  style: t.bodySmall,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: IllustrationStyle.values.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: Space.sm),
                            itemBuilder: (context, i) {
                              final s = IllustrationStyle.values[i];
                              final selected = s == _style;
                              return Semantics(
                                button: true,
                                selected: selected,
                                label: styleName(l, s),
                                child: GestureDetector(
                                  onTap: busy ? null : () => _pick(s),
                                  child: SizedBox(
                                    width: 132,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AnimatedContainer(
                                          duration: Motion.short,
                                          height: 150,
                                          decoration: BoxDecoration(
                                            borderRadius: Radii.cardAll,
                                            border: Border.all(
                                              color: selected
                                                  ? c.primary
                                                  : c.divider,
                                              width: selected ? 3 : 1,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Image.memory(
                                            previews[i],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            gaplessPlayback: true,
                                          ),
                                        ),
                                        const SizedBox(height: Space.xxs),
                                        Text(
                                          styleName(l, s),
                                          style: t.labelLarge,
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  _Header(l.characterSheetTitle),
                  Text(l.characterSheetBody, style: t.bodySmall),
                  const SizedBox(height: Space.sm),
                  SizedBox(
                    height: 100,
                    child: _sheet == null || _sheetStyle != _style
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  for (final face in _sheet!.portraits) ...[
                                    ClipOval(
                                      child: Image.memory(
                                        face,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: Space.sm),
                                  ],
                                ],
                              ),
                              const SizedBox(height: Space.xs),
                              Row(
                                children: [
                                  for (final col in _sheet!.palette.take(12))
                                    Container(
                                      width: 14,
                                      height: 14,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF000000 | col),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  _Header(l.illustratedScope),
                  RadioGroup<IllustrationScope>(
                    groupValue: _scope,
                    onChanged: (v) {
                      if (!busy && v != null) setState(() => _scope = v);
                    },
                    child: Column(
                      children: [
                        for (final s in IllustrationScope.values)
                          RadioListTile<IllustrationScope>(
                            contentPadding: EdgeInsets.zero,
                            value: s,
                            enabled: !busy,
                            title: Text(
                              s == IllustrationScope.wholeBook
                                  ? l.illustratedScopeWhole
                                  : l.illustratedScopeHybrid,
                              style: t.bodyLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _consent,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _consent = v ?? false),
                    title: Text(l.illustratedConsent, style: t.bodyMedium),
                  ),
                  Text(
                    l.illustratedPrintNote,
                    style: t.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.lg,
                Space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress != null) ...[
                    LinearProgressIndicator(
                      value: progress.$2 == 0
                          ? null
                          : progress.$1 / progress.$2,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      l.illustratedProgress(progress.$1, progress.$2),
                      textAlign: TextAlign.center,
                      style: t.bodyMedium,
                    ),
                    const SizedBox(height: Space.xs),
                  ],
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.xs),
                      child: Text(
                        l.illustratedFailed,
                        style: t.bodyMedium?.copyWith(color: c.error),
                      ),
                    ),
                  PrimaryButton(
                    label: l.illustratedMake,
                    icon: Icons.brush_outlined,
                    onPressed:
                        !_consent ||
                            busy ||
                            _sheet == null ||
                            _sheetStyle != _style
                        ? null
                        : _make,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
