import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../app_config.dart';
import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../data/domain_kit.dart';
import '../../data/services/services.dart';
import '../../data/video/video_encoder.dart';
import '../../design/design.dart';
import '../../domain/memories/trailer.dart';
import '../../router/app_router.dart';
import 'trailer_renderer.dart';

String trackName(AppLocalizations l, TrailerTrack t) => switch (t) {
  TrailerTrack.warm => l.memoriesTrackWarm,
  TrailerTrack.wander => l.memoriesTrackWander,
  TrailerTrack.light => l.memoriesTrackLight,
};

/// Living Memories: a live preview of the trailer, then an on-device MP4
/// to share or save.
class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  TrailerAssets? _assets;
  Object? _prepareError;
  TrailerAspect _aspect = TrailerAspect.portrait;
  TrailerTrack? _track;
  late final Ticker _ticker = createTicker(_onTick);
  final _time = ValueNotifier<double>(0);
  double? _progress;
  String? _videoPath;
  VideoPlayerController? _player;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    unawaited(_player?.dispose());
    _assets?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final a = _assets;
    if (a == null) return;
    final length = TrailerTimeline(
      spreads: a.spreads.length,
      heroes: a.heroes.length,
    ).duration;
    _time.value = (elapsed.inMicroseconds / 1e6) % length;
  }

  Future<void> _prepare() async {
    try {
      final album = await ref
          .read(albumRepositoryProvider)
          .load(widget.albumId);
      final kit = await ref.read(domainKitProvider.future);
      if (album == null || !mounted) return;
      final assets = await prepareTrailer(
        album: album,
        fonts: kit.fonts,
        photoImages: ref.read(photoImagesProvider),
        motion: ref.read(motionProviderProvider),
      );
      if (!mounted) {
        assets.dispose();
        return;
      }
      final existing = album.flags.videoPath;
      setState(() {
        _assets = assets;
        _track ??= TrailerTrack.forOccasion(album.occasion);
      });
      if (existing != null && File(existing).existsSync()) {
        await _showVideo(existing);
      } else if (!Motion.reduced(context)) {
        unawaited(_ticker.start());
      }
    } on Object catch (e, st) {
      await ref.read(crashReporterProvider).report(e, st);
      if (mounted) setState(() => _prepareError = e);
    }
  }

  TrailerPainter _painter(TrailerAssets a) {
    final l = lookupAppLocalizations(Locale(a.album.language));
    return TrailerPainter(
      a,
      _aspect,
      madeWith: l.memoriesMadeWith(AppConfig.brandName),
      brand: AppConfig.brandName,
    );
  }

  Future<void> _make() async {
    final a = _assets;
    if (a == null || _progress != null) return;
    _ticker.stop();
    await _player?.pause();
    setState(() {
      _progress = 0;
      _failed = false;
    });
    final encoder = VideoEncoder();
    try {
      final painter = _painter(a);
      final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'memories'),
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final out = p.join(dir.path, '${a.album.id}_${_aspect.name}_$stamp.mp4');
      // The music goes to the encoder as a file.
      final wav = File(p.join((await getTemporaryDirectory()).path, 'bed.wav'));
      final bytes = await rootBundle.load(_track!.asset);
      await wav.writeAsBytes(bytes.buffer.asUint8List());

      await encoder.start(
        path: out,
        width: _aspect.width,
        height: _aspect.height,
        fps: kTrailerFps,
      );
      final frames = painter.timeline.frameCount;
      for (var i = 0; i < frames; i++) {
        if (!mounted) {
          await encoder.cancel();
          return;
        }
        await encoder.addFrame(await painter.frameRgba(i / kTrailerFps));
        if (i % 4 == 0) setState(() => _progress = i / frames);
      }
      final path = await encoder.finish(audioWavPath: wav.path);
      final repo = ref.read(albumRepositoryProvider);
      final latest = await repo.load(a.album.id) ?? a.album;
      final old = latest.flags.videoPath;
      await repo.save(
        latest.copyWith(flags: latest.flags.copyWith(videoPath: path)),
      );
      if (old != null && old != path) {
        try {
          File(old).deleteSync();
        } on Object catch (_) {}
      }
      ref.invalidate(albumByIdProvider(a.album.id));
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      setState(() => _progress = null);
      await _showVideo(path);
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

  Future<void> _showVideo(String path) async {
    final old = _player;
    final c = VideoPlayerController.file(File(path));
    await c.initialize();
    await c.setLooping(true);
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _videoPath = path;
      _player = c;
    });
    await old?.dispose();
    await c.play();
  }

  Future<void> _share() async {
    final path = _videoPath;
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'video/mp4')],
        text: _assets?.album.title,
      ),
    );
  }

  Future<void> _save() async {
    final path = _videoPath;
    if (path == null) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await PhotoManager.editor.saveVideo(
        File(path),
        title: p.basename(path),
      );
      messenger.showSnackBar(SnackBar(content: Text(l.memoriesSaved)));
      assert(saved.id.isNotEmpty);
    } on Object catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.memoriesSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final a = _assets;
    final busy = _progress != null;
    final player = _player;

    Widget preview;
    if (_prepareError != null) {
      preview = Center(
        child: ErrorState(
          title: l.errorGenericTitle,
          body: l.errorGenericBody,
          retryLabel: l.commonRetry,
          onRetry: () {
            setState(() => _prepareError = null);
            unawaited(_prepare());
          },
        ),
      );
    } else if (a == null) {
      preview = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Space.sm),
            Text(l.memoriesPreparing, style: t.bodyMedium),
          ],
        ),
      );
    } else if (player != null && !busy) {
      preview = Center(
        child: AspectRatio(
          aspectRatio: player.value.aspectRatio,
          child: GestureDetector(
            onTap: () => setState(
              () => player.value.isPlaying ? player.pause() : player.play(),
            ),
            child: ClipRRect(
              borderRadius: Radii.cardAll,
              child: VideoPlayer(player),
            ),
          ),
        ),
      );
    } else {
      final painter = _painter(a);
      preview = Center(
        child: AspectRatio(
          aspectRatio: _aspect.width / _aspect.height,
          child: Semantics(
            label: l.memoriesPreviewLabel,
            image: true,
            child: ClipRRect(
              borderRadius: Radii.cardAll,
              child: FittedBox(
                child: SizedBox(
                  width: _aspect.width.toDouble(),
                  height: _aspect.height.toDouble(),
                  child: CustomPaint(painter: _LivePainter(painter, _time)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.editionVideoName)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                child: preview,
              ),
            ),
            if (busy)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: Space.xs),
                    Text(
                      l.memoriesRendering((_progress! * 100).round()),
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Text(
                  l.memoriesFailed,
                  style: t.bodyMedium?.copyWith(color: c.error),
                ),
              ),
            if (a != null && !busy) ...[
              if (_videoPath == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Text(l.memoriesIntro, style: t.bodyMedium),
                ),
                const SizedBox(height: Space.sm),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Row(
                  children: [
                    for (final asp in TrailerAspect.values) ...[
                      MemoriaChip(
                        label: asp == TrailerAspect.portrait
                            ? l.memoriesStories
                            : l.memoriesSquare,
                        selected: _aspect == asp,
                        onSelected: (_) => setState(() => _aspect = asp),
                      ),
                      const SizedBox(width: Space.xs),
                    ],
                    const SizedBox(width: Space.sm),
                    for (final tr in TrailerTrack.values) ...[
                      MemoriaChip(
                        label: trackName(l, tr),
                        icon: Icons.music_note_outlined,
                        selected: _track == tr,
                        onSelected: (_) => setState(() => _track = tr),
                      ),
                      const SizedBox(width: Space.xs),
                    ],
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                Space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_videoPath != null && !busy) ...[
                    PrimaryButton(
                      label: l.memoriesShare,
                      icon: Icons.ios_share_rounded,
                      onPressed: _share,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xxs),
                      child: Text(
                        l.memoriesShareHint,
                        textAlign: TextAlign.center,
                        style: t.bodySmall,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    SecondaryButton(
                      label: l.memoriesSave,
                      icon: Icons.download_rounded,
                      onPressed: _save,
                    ),
                    TextButton.icon(
                      onPressed: _make,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l.memoriesMakeAgain),
                    ),
                  ] else
                    PrimaryButton(
                      label: l.memoriesMake,
                      icon: Icons.movie_creation_outlined,
                      onPressed: a == null || busy ? null : _make,
                    ),
                  const SizedBox(height: Space.xs),
                  TextButton.icon(
                    onPressed: () =>
                        context.push(Routes.albumPreview(widget.albumId)),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(l.editionAlsoPrint),
                  ),
                  Text(
                    l.memoriesFreeNote,
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: c.textSecondary),
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

class _LivePainter extends CustomPainter {
  _LivePainter(this.trailer, this.time) : super(repaint: time);

  final TrailerPainter trailer;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / trailer.size.width);
    trailer.paint(canvas, time.value);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LivePainter old) =>
      old.trailer.aspect != trailer.aspect ||
      old.trailer.assets != trailer.assets;
}
