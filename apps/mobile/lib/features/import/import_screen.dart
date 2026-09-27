import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/domain_kit.dart';
import '../../data/photos/photo_library.dart';
import '../../data/services/photo_permission.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/geo/geo_data.dart';
import '../../router/app_router.dart';
import '../create/creation_controller.dart';

/// A suggested cluster of photos ("A trip? 312 photos from Zanzibar").
class PhotoCluster {
  const PhotoCluster(this.photos, this.place);

  final List<SourcePhoto> photos;
  final String? place;

  DateTime get start => photos.last.takenAt!;
  DateTime get end => photos.first.takenAt!;
  bool get singleDay => DateUtils.isSameDay(start, end);
}

/// Largest recent run of photos without a 36 h gap (newest-first input).
PhotoCluster? suggestCluster(
  List<SourcePhoto> photos,
  GeoData? geo,
  String lang,
  DateTime now,
) {
  final dated = photos.where((p) => p.takenAt != null).toList();
  if (dated.length < 15) return null;
  final clusters = <List<SourcePhoto>>[];
  for (final p in dated) {
    if (clusters.isEmpty ||
        clusters.last.last.takenAt!.difference(p.takenAt!).inHours > 36) {
      clusters.add([p]);
    } else {
      clusters.last.add(p);
    }
  }
  final recent = clusters
      .where(
        (c) => now.difference(c.first.takenAt!).inDays < 550 && c.length >= 15,
      )
      .toList();
  if (recent.isEmpty) return null;
  recent.sort((a, b) => b.length.compareTo(a.length));
  final best = recent.first;
  String? place;
  final geotagged = best.where((p) => p.lat != null && p.lng != null).toList();
  if (geo != null && geotagged.isNotEmpty) {
    final lat =
        geotagged.map((p) => p.lat!).reduce((a, b) => a + b) / geotagged.length;
    final lng =
        geotagged.map((p) => p.lng!).reduce((a, b) => a + b) / geotagged.length;
    place =
        geo.islandAt(lng, lat)?.nameIn(lang) ??
        geo.nearestPlace(lat, lng, maxKm: 80)?.nameIn(lang) ??
        geo.countryAt(lng, lat)?.name;
  }
  return PhotoCluster(best, place);
}

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  PhotoAccess? _access;
  List<SourcePhoto>? _photos;
  List<LibraryAlbum> _albums = const [];
  String? _albumId;
  DateTimeRange? _range;
  final Set<String> _selected = {};
  final Map<int, GlobalKey> _tileKeys = {};
  int? _dragStart;
  Set<String> _dragBase = {};
  PhotoCluster? _cluster;
  bool _clusterDismissed = false;

  PhotoLibrary get _library =>
      ref.read(creationControllerProvider).library ??
      ref.read(photoLibraryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final permission = ref.read(photoPermissionProvider);
    var access = await permission.current();
    if (access == PhotoAccess.notDetermined) {
      access = await permission.request();
    }
    if (!mounted) return;
    setState(() => _access = access);
    if (access == PhotoAccess.granted || access == PhotoAccess.limited) {
      final albums = await _library.albums();
      if (mounted) setState(() => _albums = albums);
      await _load();
    }
  }

  Future<void> _load() async {
    final photos = await _library.photos(
      albumId: _albumId,
      from: _range?.start,
      to: _range?.end.add(const Duration(days: 1)),
    );
    if (!mounted) return;
    final kit = ref.read(domainKitProvider).value;
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _photos = photos;
      _tileKeys.clear();
      _cluster = _clusterDismissed
          ? null
          : suggestCluster(photos, kit?.geo, lang, DateTime.now());
    });
  }

  void _toggle(SourcePhoto p) {
    HapticFeedback.selectionClick();
    setState(
      () => _selected.contains(p.assetId)
          ? _selected.remove(p.assetId)
          : _selected.add(p.assetId),
    );
  }

  int? _indexAt(Offset global) {
    for (final e in _tileKeys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final local = box.globalToLocal(global);
      if ((Offset.zero & box.size).contains(local)) return e.key;
    }
    return null;
  }

  void _dragTo(Offset global) {
    final start = _dragStart;
    final photos = _photos;
    if (start == null || photos == null) return;
    final i = _indexAt(global);
    if (i == null) return;
    final lo = i < start ? i : start, hi = i < start ? start : i;
    setState(() {
      _selected
        ..clear()
        ..addAll(_dragBase)
        ..addAll([for (var k = lo; k <= hi; k++) photos[k].assetId]);
    });
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _range,
    );
    if (range == null) return;
    setState(() => _range = range);
    await _load();
  }

  Future<void> _pickAlbum() async {
    final l = context.l10n;
    final picked = await showMemoriaSheet<String?>(
      context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l.importAllPhotos),
              leading: const Icon(Icons.photo_library_outlined),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final a in _albums)
              ListTile(
                title: Text(a.name),
                trailing: Text('${a.count}'),
                leading: const Icon(Icons.folder_outlined),
                onTap: () => Navigator.pop(ctx, a.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _albumId = picked.isEmpty ? null : picked);
    await _load();
  }

  void _continue() {
    final photos = _photos ?? const [];
    final chosen = photos.where((p) => _selected.contains(p.assetId)).toList();
    final notifier = ref.read(creationControllerProvider.notifier)
      ..setSelection(chosen);
    context.push(Routes.importProgress);
    unawaited(notifier.analyse());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final access = _access;
    final photos = _photos;
    final locale = Localizations.localeOf(context).toLanguageTag();

    Widget body;
    if (access == PhotoAccess.denied) {
      final permission = ref.read(photoPermissionProvider);
      // Without photo access the sample book is the way in; settings second.
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmptyState(
                title: l.permissionTitle,
                body: l.permissionSampleBody,
              ),
              const SizedBox(height: Space.md),
              PrimaryButton(
                label: l.homeTrySample,
                icon: Icons.auto_stories_outlined,
                onPressed: () async {
                  context.pushReplacement(Routes.importProgress);
                  await ref
                      .read(creationControllerProvider.notifier)
                      .startSample('travel');
                },
              ),
              TextButton(
                onPressed: permission.openSystemSettings,
                child: Text(l.permissionOpenSettings),
              ),
            ],
          ),
        ),
      );
    } else if (photos == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (photos.isEmpty) {
      body = EmptyState(title: l.importEmptyTitle, body: l.importEmptyBody);
    } else {
      body = _grid(photos, locale);
    }

    final count = _selected.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.importTitle),
        actions: [
          if (_albums.length > 1)
            LabeledIconButton(
              icon: Icons.folder_outlined,
              label: l.importAlbums,
              onPressed: _pickAlbum,
            ),
          LabeledIconButton(
            icon: Icons.date_range_outlined,
            label: l.importDates,
            onPressed: _pickDates,
          ),
        ],
      ),
      body: Column(
        children: [
          if (access == PhotoAccess.limited)
            MaterialBanner(
              content: Text(l.permissionLimitedBody, style: t.bodyMedium),
              backgroundColor: c.surface,
              actions: [
                TextButton(
                  onPressed: () async {
                    await ref.read(photoPermissionProvider).selectMore();
                    await _load();
                  },
                  child: Text(l.permissionSelectMore),
                ),
              ],
            ),
          if (_range != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Space.md,
                top: Space.xs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(
                  label: Text(
                    '${DateFormat.yMMMd(locale).format(_range!.start)} – ${DateFormat.yMMMd(locale).format(_range!.end)}',
                  ),
                  onDeleted: () async {
                    setState(() => _range = null);
                    await _load();
                  },
                  deleteButtonTooltipMessage: l.importClearDates,
                ),
              ),
            ),
          if (_cluster != null) _suggestion(_cluster!, locale),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: photos == null || photos.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.xs,
                  Space.md,
                  Space.md,
                ),
                child: Row(
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.md,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: Radii.pillAll,
                        ),
                        child: Text(
                          l.importSelectedCount(count),
                          style: t.labelMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Tooltip(
                        message: count < kMinPhotosForBook
                            ? l.importMinPhotos(kMinPhotosForBook)
                            : '',
                        child: PrimaryButton(
                          label: l.commonContinue,
                          onPressed: count >= kMinPhotosForBook
                              ? _continue
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _suggestion(PhotoCluster cluster, String locale) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final df = DateFormat.MMMd(locale);
    final text = !cluster.singleDay && cluster.place != null
        ? l.importSuggestionTrip(
            cluster.photos.length,
            cluster.place!,
            '${df.format(cluster.start)} – ${df.format(cluster.end)}',
          )
        : l.importSuggestionDay(
            cluster.photos.length,
            DateFormat.yMMMMd(locale).format(cluster.start),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: MemoriaCard(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Space.md,
          Space.xs,
          Space.xs,
          Space.xs,
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: c.accent),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(text, style: t.bodyMedium)),
            TextButton(
              onPressed: () => setState(() {
                _selected.addAll(cluster.photos.map((p) => p.assetId));
                _cluster = null;
                _clusterDismissed = true;
              }),
              child: Text(l.importSuggestionSelect),
            ),
            LabeledIconButton(
              icon: Icons.close_rounded,
              label: l.commonClose,
              onPressed: () => setState(() {
                _cluster = null;
                _clusterDismissed = true;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<SourcePhoto> photos, String locale) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final dayFormat = DateFormat.yMMMMEEEEd(locale);
    // Group consecutive photos by day, keeping global indexes for dragging.
    final sections = <(DateTime?, int, int)>[];
    for (var i = 0; i < photos.length; i++) {
      final d = photos[i].takenAt;
      final day = d == null ? null : DateUtils.dateOnly(d);
      if (sections.isEmpty || sections.last.$1 != day) {
        sections.add((day, i, i + 1));
      } else {
        sections[sections.length - 1] = (
          sections.last.$1,
          sections.last.$2,
          i + 1,
        );
      }
    }
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              LongPressGestureRecognizer.new,
              (r) => r
                ..onLongPressStart = (d) {
                  final i = _indexAt(d.globalPosition);
                  if (i == null) return;
                  HapticFeedback.lightImpact();
                  _dragStart = i;
                  _dragBase = {..._selected};
                  _dragTo(d.globalPosition);
                }
                ..onLongPressMoveUpdate = ((d) => _dragTo(d.globalPosition))
                ..onLongPressEnd = ((_) => _dragStart = null),
            ),
      },
      child: CustomScrollView(
        slivers: [
          for (final (day, start, end) in sections) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Space.md,
                  Space.md,
                  Space.xs,
                  Space.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          day == null ? '—' : dayFormat.format(day),
                          style: t.titleSmall,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final ids = [
                          for (var i = start; i < end; i++) photos[i].assetId,
                        ];
                        final all = ids.every(_selected.contains);
                        return TextButton(
                          onPressed: () => setState(
                            () => all
                                ? _selected.removeAll(ids)
                                : _selected.addAll(ids),
                          ),
                          child: Text(
                            all ? l.importClearDay : l.importSelectDay,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate((context, k) {
                  final i = start + k;
                  final p = photos[i];
                  return _PhotoTile(
                    key: _tileKeys.putIfAbsent(i, GlobalKey.new),
                    photo: p,
                    library: _library,
                    selected: _selected.contains(p.assetId),
                    label: p.takenAt == null
                        ? ''
                        : l.photoSemantics(
                            DateFormat.yMMMMd(locale).format(p.takenAt!),
                          ),
                    onTap: () => _toggle(p),
                  );
                }, childCount: end - start),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.library,
    required this.selected,
    required this.label,
    required this.onTap,
    super.key,
  });

  final SourcePhoto photo;
  final PhotoLibrary library;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: c.surface,
              child: Image(
                image: library.imageProvider(photo.assetId, size: 256),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            AnimatedContainer(
              duration: Motion.short,
              decoration: BoxDecoration(
                border: selected
                    ? Border.all(color: c.primary, width: 3)
                    : null,
                color: selected
                    ? c.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
            ),
            PositionedDirectional(
              top: 6,
              end: 6,
              child: AnimatedContainer(
                duration: Motion.short,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? c.primary
                      : Colors.black.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 14, color: c.onPrimary)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
