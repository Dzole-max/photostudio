import 'dart:math' as math;

import '../art/icon_pack.dart';
import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/spec_data.dart';
import '../text/text_layout.dart';
import 'map_composer.dart';
import 'ornaments.dart';
import 'page_composer.dart';
import 'smart_crop.dart';
import 'templates.dart';
import 'type_kit.dart';

/// Spine text is printed only when the spine is at least this wide.
const double kMinSpineTextMm = 6;

class CoverTemplate {
  const CoverTemplate(
    this.id, {
    this.needsHero = false,
    this.gridPhotos = 0,
    this.stub = false,
  });

  final String id;
  final bool needsHero;
  final int gridPhotos;

  /// Illustrated edition cover (feature-flagged stub).
  final bool stub;

  static const all = [
    CoverTemplate('cover_wedding_monogram'),
    CoverTemplate('cover_wedding_fullbleed', needsHero: true),
    CoverTemplate('cover_wedding_midnight_frame', needsHero: true),
    CoverTemplate('cover_travel_coordinates', needsHero: true),
    CoverTemplate('cover_travel_mapstamp'),
    CoverTemplate('cover_travel_stamp'),
    CoverTemplate('cover_map'),
    CoverTemplate('cover_travel_postcard', needsHero: true),
    CoverTemplate('cover_baby_cloud', needsHero: true),
    CoverTemplate('cover_birthday_confetti'),
    CoverTemplate('cover_year_grid', gridPhotos: 9),
    CoverTemplate('cover_illustrated', needsHero: true),
  ];

  static CoverTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}

/// Placeholder spine width until the print provider returns the real one
/// (section 6.1): 0.06 mm per inner page + 2 mm.
double fakeSpineMm(int innerPages) => 0.06 * innerPages + 2;

const String _white = '#FFFFFF';
const String _black = '#000000';

/// Resolves a cover template into primitives for front, spine and back.
CoverDesign composeCover({
  required String templateId,
  required CoverSlots slots,
  required ComposeEnv env,
  required double spineMm,
  String? spineText,
  String? backText,
  String backMark = 'MEMORIA',
}) {
  final w = env.format.trimWMm, h = env.format.trimHMm;
  final kit = env.kit;
  final s = kit.scale;
  final theme = env.theme;
  final accent = env.accent;
  final frames = <PhotoFrame>[];
  final texts = <TextBlock>[];
  final ornaments = <Ornament>[];
  var bg = theme.background;
  final hero = slots.heroPhotoId == null ? null : env.photos[slots.heroPhotoId];

  PhotoFrame photoFrame(
    String id,
    PhotoRef? p,
    RectMm rect, {
    double border = 0,
    double rotation = 0,
    double radius = 0,
  }) {
    final inner = border > 0 ? rect.deflate(border) : rect;
    return PhotoFrame(
      id: id,
      photoId: p?.id,
      rectMm: rect,
      crop: p == null ? CropRect.full : smartCrop(p, inner.aspect).crop,
      borderMm: border,
      rotationDeg: rotation,
      cornerRadiusMm: radius,
    );
  }

  // Front photos bleed on top, bottom and the outer edge, not into the spine.
  final bleedFront = RectMm(
    x: 0,
    y: -kBleedMm,
    w: w + kBleedMm,
    h: h + 2 * kBleedMm,
  );
  final title = slots.title ?? '';
  final names = slots.names ?? title;

  switch (templateId) {
    case 'cover_wedding_monogram':
      // Ivory linen: a faint woven texture.
      final weave = StringBuffer();
      for (double x = 0; x <= w; x += 1.6) {
        weave.write(
          'M${x.toStringAsFixed(1)} 0 L${x.toStringAsFixed(1)} ${h.toStringAsFixed(1)} ',
        );
      }
      for (double y = 0; y <= h; y += 1.6) {
        weave.write(
          'M0 ${y.toStringAsFixed(1)} L${w.toStringAsFixed(1)} ${y.toStringAsFixed(1)} ',
        );
      }
      ornaments.add(
        Ornament(
          type: OrnamentType.path,
          path: weave.toString().trim(),
          color: '#B9A98E',
          opacity: 0.12,
          strokePt: 0.25,
        ),
      );
      final d = 60 * s;
      final cx = w / 2, cy = h * 0.40;
      ornaments.add(
        Ornament(
          type: OrnamentType.monogramRing,
          params: {'cx': cx, 'cy': cy, 'r': d / 2},
          color: accent,
          strokePt: 0.5,
        ),
      );
      texts.add(
        kit.script(
          'monogram',
          slots.monogram ?? '',
          RectMm(x: cx - d * 0.42, y: cy - d * 0.32, w: d * 0.84, h: d * 0.6),
          sizePt: 44,
        ),
      );
      final ny = cy + d / 2 + 14 * s;
      texts.add(
        kit.meta(
          'names',
          names,
          RectMm(x: w * 0.08, y: ny, w: w * 0.84, h: 12 * s + 2),
          sizePt: 11 * s,
          trackingPct: 20,
          role: TextRole.title,
        ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: ny + 12 * s + 10, w: w * 0.8, h: 6),
          color: accent,
        ),
      );
      _settle(
        texts,
        ['names', 'date'],
        env,
        top: ny,
        maxBottom: h - kSafeOuterMm,
        minTop: cy + d / 2 + 4,
        gapMm: 9 * s + 2,
      );
      final namesRect = texts.firstWhere((t) => t.id == 'names').rectMm;
      final dateRect = texts.firstWhere((t) => t.id == 'date').rectMm;
      ornaments.add(
        Ornaments.divider(cx, (namesRect.bottom + dateRect.y) / 2, 14, accent),
      );
    case 'cover_wedding_fullbleed':
      frames.add(photoFrame('cover_hero', hero, bleedFront));
      ornaments.add(
        _gradient(
          RectMm(x: 0, y: h * 0.65, w: w + kBleedMm, h: h * 0.35 + kBleedMm),
          0,
          0.55,
        ),
      );
      texts.add(
        kit
            .display(
              'names',
              names,
              RectMm(x: w * 0.08, y: h * 0.72, w: w * 0.84, h: 30 * s + 8),
              sizePt: 30,
              color: _white,
              fit: false,
              vAlign: VerticalAlignKind.bottom,
            )
            .copyWith(
              fontFamily: 'CormorantGaramond',
              weight: 600,
              uppercase: false,
              trackingPct: 0,
            ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: h * 0.72 + 30 * s + 12, w: w * 0.8, h: 6),
          color: _white,
        ),
      );
      _settle(
        texts,
        ['names', 'date'],
        env,
        top: h * 0.7,
        maxBottom: h - kSafeOuterMm - 4 * s,
        minTop: h * 0.55,
        gapMm: 4 * s + 1,
      );
    case 'cover_wedding_midnight_frame':
      bg = theme.background;
      final photo = fitAspect(
        RectMm(x: w * 0.2, y: h * 0.1, w: w * 0.6, h: h * 0.5),
        0.8,
        ay: 0,
      );
      frames.add(photoFrame('cover_hero', hero, photo));
      ornaments.add(Ornaments.frame(photo.inflate(2), accent, strokePt: 0.5));
      final ty = photo.bottom + 12 * s;
      texts.add(
        kit
            .display(
              'title',
              title.isEmpty ? env.strings.ourWedding : title,
              RectMm(x: w * 0.08, y: ty, w: w * 0.84, h: 26 * s + 6),
              sizePt: 26,
            )
            .copyWith(uppercase: false),
      );
      texts.add(
        kit.meta(
          'names',
          names,
          RectMm(x: w * 0.1, y: ty + 26 * s + 10, w: w * 0.8, h: 7),
          sizePt: 9,
          role: TextRole.subtitle,
        ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: ty + 26 * s + 19, w: w * 0.8, h: 6),
          color: accent,
        ),
      );
      _settle(
        texts,
        ['title', 'names', 'date'],
        env,
        top: ty,
        maxBottom: h - kSafeOuterMm,
        minTop: photo.bottom + 4,
        gapMm: 3 * s + 1,
      );
    case 'cover_illustrated':
      // The painting mounted on watercolour paper, title set below.
      bg = '#F7F1E6';
      final rng = math.Random(env.seed + 7);
      final fibres = StringBuffer();
      for (var i = 0; i < 90; i++) {
        final x = rng.nextDouble() * w, y = rng.nextDouble() * h;
        final a = rng.nextDouble() * math.pi;
        final len = 1.5 + rng.nextDouble() * 4;
        fibres.write(
          'M${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)} L${(x + math.cos(a) * len).toStringAsFixed(1)} ${(y + math.sin(a) * len).toStringAsFixed(1)} ',
        );
      }
      final art = fitAspect(
        RectMm(x: w * 0.1, y: h * 0.08, w: w * 0.8, h: h * 0.62),
        hero?.aspect ?? 1.3,
        minA: 0.8,
        maxA: 1.5,
        ay: 0,
      );
      frames.add(photoFrame('cover_hero', hero, art));
      ornaments.add(
        Ornaments.frame(
          art.inflate(2.2),
          theme.text,
          strokePt: 0.3,
        ).copyWith(opacity: 0.45),
      );
      ornaments.add(
        Ornament(
          type: OrnamentType.path,
          path: fibres.toString().trim(),
          color: '#8C7A5E',
          opacity: 0.16,
          strokePt: 0.3,
        ),
      );
      final ty = art.bottom + 9 * s;
      texts.add(
        kit
            .display(
              'title',
              title,
              RectMm(x: w * 0.08, y: ty, w: w * 0.84, h: 40 * s + 4),
              sizePt: 40,
              maxLines: 1,
            )
            .copyWith(
              fontFamily: 'Nunito',
              weight: 700,
              uppercase: false,
              trackingPct: 0,
            ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: ty + 40 * s + 8, w: w * 0.8, h: 6),
          color: accent,
        ),
      );
      _settle(
        texts,
        ['title', 'date'],
        env,
        top: ty,
        maxBottom: h - kSafeOuterMm,
        minTop: art.bottom + 3,
        gapMm: 2 * s + 1,
      );
    case 'cover_travel_coordinates':
      frames.add(photoFrame('cover_hero', hero, bleedFront));
      ornaments.add(
        _gradient(
          RectMm(x: 0, y: -kBleedMm, w: w + kBleedMm, h: h * 0.36),
          0.38,
          0,
        ),
      );
      ornaments.add(
        _gradient(
          RectMm(x: 0, y: h * 0.76, w: w + kBleedMm, h: h * 0.24 + kBleedMm),
          0,
          0.4,
        ),
      );
      final titleBlock = TextBlock(
        id: 'title',
        role: TextRole.title,
        text: title,
        fontFamily: 'Manrope',
        sizePt: 100,
        weight: 700,
        color: _white,
        align: TextAlignKind.center,
        rectMm: RectMm(x: w * 0.1, y: h * 0.09, w: w * 0.8, h: h * 0.2),
        uppercase: true,
        trackingPct: 40,
        lineHeight: 1.05,
        maxLines: 1,
      );
      texts.add(
        titleBlock.copyWith(sizePt: _fitWidth(titleBlock, env, maxPt: 110 * s)),
      );
      final coords = slots.coordinates;
      final bottomY = h - 22 * s;
      if (coords != null && coords.isNotEmpty) {
        texts.add(
          kit.meta(
            'coordinates',
            coords,
            RectMm(x: w * 0.1, y: bottomY, w: w * 0.8, h: 5),
            color: _white,
            sizePt: 8,
            caps: false,
            trackingPct: 12,
            role: TextRole.label,
          ),
        );
      }
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: bottomY + 6, w: w * 0.8, h: 5),
          color: _white,
          sizePt: 8,
        ),
      );
      _settle(
        texts,
        ['coordinates', 'date'],
        env,
        top: bottomY,
        maxBottom: h - kSafeOuterMm,
        minTop: h * 0.7,
        gapMm: 1.5,
      );
    case 'cover_travel_stamp':
      // Passport stamps on sand-coloured paper.
      bg = '#EFE4D0';
      final rng = math.Random(env.seed);
      final fibres = StringBuffer();
      for (var i = 0; i < 70; i++) {
        final x = rng.nextDouble() * w, y = rng.nextDouble() * h;
        final a = rng.nextDouble() * math.pi;
        final len = 2 + rng.nextDouble() * 5;
        fibres.write(
          'M${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)} L${(x + math.cos(a) * len).toStringAsFixed(1)} ${(y + math.sin(a) * len).toStringAsFixed(1)} ',
        );
      }
      ornaments.add(
        Ornament(
          type: OrnamentType.path,
          path: fibres.toString().trim(),
          color: '#8A6A45',
          opacity: 0.18,
          strokePt: 0.3,
        ),
      );
      final r = math.min(w, h) * 0.3;
      final cx = w / 2, cy = h * 0.48;
      ornaments.add(Ornaments.stamp(cx, cy, r, accent, opacity: 0.92));
      ornaments.add(
        Ornament(
          type: OrnamentType.circle,
          params: {'cx': cx, 'cy': cy, 'r': r * 0.6},
          color: accent,
          opacity: 0.7,
          strokePt: 0.5,
        ),
      );
      for (final dx in [-1.0, 1.0]) {
        ornaments.add(
          iconOrnament(
            'plane',
            cx + dx * r * 0.78,
            cy,
            r * 0.16,
            accent,
            strokePt: 0.5,
          ),
        );
      }
      texts.add(
        kit.meta(
          'stamp_country',
          (slots.details ?? slots.location ?? '').toUpperCase(),
          RectMm(x: cx - r * 0.7, y: cy - r * 0.84, w: r * 1.4, h: 7),
          sizePt: 9 * s,
          color: accent,
          trackingPct: 30,
          role: TextRole.label,
        ),
      );
      final titleBox = TextBlock(
        id: 'title',
        role: TextRole.title,
        text: title,
        fontFamily: 'Manrope',
        sizePt: 60,
        weight: 700,
        color: accent,
        align: TextAlignKind.center,
        vAlign: VerticalAlignKind.middle,
        rectMm: RectMm(
          x: cx - r * 0.56,
          y: cy - r * 0.3,
          w: r * 1.12,
          h: r * 0.6,
        ),
        uppercase: true,
        trackingPct: 12,
        lineHeight: 1,
        maxLines: 1,
      );
      texts.add(
        titleBox.copyWith(sizePt: _fitWidth(titleBox, env, maxPt: 40 * s)),
      );
      texts.add(
        kit.meta(
          'age',
          slots.age ?? '',
          RectMm(x: cx - r * 0.5, y: cy + r * 0.62, w: r, h: 7),
          sizePt: 10 * s,
          color: accent,
          trackingPct: 30,
          role: TextRole.label,
        ),
      );
      // Two smaller visa stamps, one per chapter place.
      final places = env.chapters
          .map((c) => c.placeName)
          .whereType<String>()
          .toSet()
          .take(2)
          .toList();
      for (var i = 0; i < places.length; i++) {
        final sr = r * 0.34;
        final sx = i == 0 ? w * 0.2 : w * 0.8,
            sy = i == 0 ? h * 0.16 : h * 0.84;
        ornaments.add(Ornaments.stamp(sx, sy, sr, theme.text, opacity: 0.45));
        texts.add(
          kit
              .meta(
                'visa_$i',
                places[i].toUpperCase(),
                RectMm(x: sx - sr, y: sy - 3, w: sr * 2, h: 6),
                sizePt: 8,
                color: theme.text,
                trackingPct: 8,
                role: TextRole.label,
                opacity: 0.6,
                vAlign: VerticalAlignKind.middle,
              )
              .copyWith(rotationDeg: i == 0 ? -14 : 11),
        );
      }
    case 'cover_map':
      texts.add(
        kit.display(
          'title',
          title,
          RectMm(x: w * 0.08, y: h * 0.07, w: w * 0.84, h: 30 * s + 4),
          sizePt: 30,
          maxLines: 1,
        ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: h * 0.07 + 30 * s + 8, w: w * 0.8, h: 6),
          color: accent,
        ),
      );
      final geo = env.geo;
      final lat =
          slots.lat ??
          env.chapters
              .firstWhere(
                (c) => c.lat != null,
                orElse: () => const Chapter(id: '', title: ''),
              )
              .lat;
      final lng =
          slots.lng ??
          env.chapters
              .firstWhere(
                (c) => c.lng != null,
                orElse: () => const Chapter(id: '', title: ''),
              )
              .lng;
      if (geo != null && lat != null && lng != null) {
        final stops = stopsFromChapters(env.chapters);
        final icons = [
          for (final stop in stops)
            () {
              final ch = env.chapters.firstWhere(
                (c) => (c.placeName ?? c.title) == stop.name,
              );
              final photos = env.photos.values
                  .where((p) => p.placeName == ch.placeName)
                  .toList();
              return iconForPlace(ch.placeId, ch.placeName, photos);
            }(),
        ];
        final drawing = composeCoverMap(
          rect: RectMm(x: w * 0.1, y: h * 0.25, w: w * 0.8, h: h * 0.58),
          lat: lat,
          lng: lng,
          stops: stops.length >= 2 ? stops : const [],
          geo: geo,
          lineColor: theme.text,
          accent: accent,
          fonts: env.fonts,
          icons: icons,
          heart: stops.length < 2,
        );
        ornaments.addAll(drawing.ornaments);
        texts.addAll(drawing.texts);
      }
      if (slots.location != null) {
        texts.add(
          kit.meta(
            'stamp_place',
            slots.location!,
            RectMm(x: w * 0.1, y: h * 0.86, w: w * 0.8, h: 6),
            sizePt: 9,
            color: theme.text,
            role: TextRole.label,
          ),
        );
      }
    case 'cover_travel_mapstamp':
      texts.add(
        kit.display(
          'title',
          title,
          RectMm(x: w * 0.08, y: h * 0.08, w: w * 0.84, h: 30 * s + 4),
          sizePt: 30,
          maxLines: 1,
        ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: h * 0.08 + 30 * s + 8, w: w * 0.8, h: 6),
          color: accent,
        ),
      );
      final geo = env.geo;
      final place = env.chapters.firstWhere(
        (c) => c.lat != null,
        orElse: () => const Chapter(id: '', title: ''),
      );
      if (geo != null && place.lat != null) {
        ornaments.addAll(
          destinationOutline(
            rect: RectMm(x: w * 0.14, y: h * 0.26, w: w * 0.72, h: h * 0.5),
            lat: place.lat!,
            lng: place.lng!,
            geo: geo,
            color: theme.text,
          ),
        );
      }
      final r = 15 * s + 3;
      final scx = w * 0.78, scy = h * 0.82;
      ornaments.add(Ornaments.stamp(scx, scy, r, accent));
      texts.add(
        kit.meta(
          'stamp_place',
          slots.location ?? title,
          RectMm(x: scx - r * 0.8, y: scy - 5, w: r * 1.6, h: 5),
          sizePt: 8,
          color: accent,
          trackingPct: 10,
          role: TextRole.label,
          vAlign: VerticalAlignKind.bottom,
        ),
      );
      texts.add(
        kit.meta(
          'stamp_year',
          slots.age ?? '',
          RectMm(x: scx - r * 0.8, y: scy + 0.5, w: r * 1.6, h: 5),
          sizePt: 8,
          color: accent,
          role: TextRole.label,
        ),
      );
    case 'cover_travel_postcard':
      final photo = fitAspect(
        RectMm(x: w * 0.1, y: h * 0.1, w: w * 0.8, h: h * 0.6),
        1.4,
        ay: 0.2,
      );
      frames.add(
        photoFrame('cover_hero', hero, photo, border: 6, rotation: -2),
      );
      final stamp = RectMm(
        x: photo.right - 20 * s,
        y: photo.y - 8 * s,
        w: 16 * s,
        h: 20 * s,
      );
      ornaments.add(Ornaments.frame(stamp, accent, strokePt: 0.6));
      ornaments.add(Ornaments.frame(stamp.deflate(1.5), accent, strokePt: 0.3));
      for (var i = 0; i < 3; i++) {
        final y = stamp.y + stamp.h * (0.3 + i * 0.2);
        ornaments.add(
          Ornament(
            type: OrnamentType.path,
            path:
                'M${(stamp.x - 10 * s).toStringAsFixed(2)} ${y.toStringAsFixed(2)} Q${(stamp.x - 5 * s).toStringAsFixed(2)} ${(y - 2).toStringAsFixed(2)} ${stamp.x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Q${(stamp.x + 5 * s).toStringAsFixed(2)} ${(y + 2).toStringAsFixed(2)} ${(stamp.x + 10 * s).toStringAsFixed(2)} ${y.toStringAsFixed(2)}',
            color: theme.text,
            opacity: 0.5,
            strokePt: 0.4,
          ),
        );
      }
      final caption = [
        title,
        slots.date,
      ].where((e) => e != null && e.isNotEmpty).join(', ');
      texts.add(
        kit.body(
          'caption',
          caption,
          RectMm(
            x: w * 0.1,
            y: photo.bottom + 10 * s,
            w: w * 0.8,
            h: 16 * s + 4,
          ),
          sizePt: 16 * s,
          italic: true,
          align: TextAlignKind.center,
          role: TextRole.title,
          maxLines: 2,
        ),
      );
    case 'cover_baby_cloud':
      final d = math.min(w, h) * 0.55;
      final photo = RectMm(x: (w - d) / 2, y: h * 0.12, w: d, h: d);
      frames.add(photoFrame('cover_hero', hero, photo, radius: d / 2));
      final ny = photo.bottom + 10 * s;
      texts.add(
        kit.display(
          'title',
          title,
          RectMm(x: w * 0.1, y: ny, w: w * 0.8, h: 28 * s + 6),
          sizePt: 28,
        ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: ny + 28 * s + 9, w: w * 0.8, h: 6),
          color: accent,
        ),
      );
      if (slots.details != null && slots.details!.isNotEmpty) {
        texts.add(
          kit.meta(
            'details',
            slots.details!,
            RectMm(x: w * 0.1, y: ny + 28 * s + 17, w: w * 0.8, h: 6),
            caps: false,
            trackingPct: 4,
            weight: 400,
            role: TextRole.subtitle,
          ),
        );
      }
      _settle(
        texts,
        ['title', 'date', 'details'],
        env,
        top: ny,
        maxBottom: h - kSafeOuterMm,
        minTop: photo.bottom + 3,
        gapMm: 3 * s + 1,
      );
    case 'cover_birthday_confetti':
      ornaments.addAll(
        Ornaments.confetti(
          RectMm(x: 8, y: 8, w: w - 16, h: h * 0.18),
          env.seed,
          [accent, '#F2B84B', '#6FA8A0', '#E8A0B4'],
        ),
      );
      ornaments.addAll(
        Ornaments.confetti(
          RectMm(x: 8, y: h * 0.8, w: w - 16, h: h * 0.14),
          env.seed + 1,
          [accent, '#F2B84B', '#6FA8A0', '#E8A0B4'],
        ),
      );
      texts.add(
        TextBlock(
          id: 'age',
          role: TextRole.title,
          text: slots.age ?? '',
          fontFamily: 'Nunito',
          sizePt: 150 * s,
          weight: 800,
          color: accent,
          align: TextAlignKind.center,
          vAlign: VerticalAlignKind.bottom,
          rectMm: RectMm(x: w * 0.1, y: h * 0.18, w: w * 0.8, h: h * 0.4),
          lineHeight: 1,
          maxLines: 1,
        ),
      );
      texts.add(
        kit.display(
          'title',
          title,
          RectMm(x: w * 0.1, y: h * 0.6, w: w * 0.8, h: 26 * s + 6),
          sizePt: 26,
        ),
      );
      texts.add(
        kit.meta(
          'date',
          slots.date ?? '',
          RectMm(x: w * 0.1, y: h * 0.6 + 26 * s + 10, w: w * 0.8, h: 6),
        ),
      );
      _settle(
        texts,
        ['title', 'date'],
        env,
        top: h * 0.6,
        maxBottom: h * 0.8 - 2,
        minTop: h * 0.5,
        gapMm: 3 * s + 1,
      );
    case 'cover_year_grid':
      final side = math.min(w * 0.76, h * 0.6);
      const gap = 2.0;
      final cell = (side - 2 * gap) / 3;
      final x0 = (w - side) / 2, y0 = h * 0.1;
      final ids = slots.photoIds;
      for (var i = 0; i < 9; i++) {
        final p = i < ids.length ? env.photos[ids[i]] : null;
        frames.add(
          photoFrame(
            'cover_grid_$i',
            p,
            RectMm(
              x: x0 + (i % 3) * (cell + gap),
              y: y0 + (i ~/ 3) * (cell + gap),
              w: cell,
              h: cell,
            ),
          ),
        );
      }
      final yy = y0 + side + 10 * s;
      texts.add(
        kit.display(
          'title',
          title,
          RectMm(x: w * 0.08, y: yy, w: w * 0.84, h: 40 * s + 4),
          sizePt: 40,
          maxLines: 1,
        ),
      );
      if (slots.subtitle != null) {
        texts.add(
          kit.meta(
            'subtitle',
            slots.subtitle!,
            RectMm(x: w * 0.1, y: yy + 40 * s + 8, w: w * 0.8, h: 6),
            color: accent,
            role: TextRole.subtitle,
          ),
        );
      }
      _settle(
        texts,
        ['title', 'subtitle'],
        env,
        top: yy,
        maxBottom: h - kSafeOuterMm,
        minTop: y0 + side + 3,
        gapMm: 3 * s + 1,
      );
  }

  final front = BookPage(
    id: 'cover_front',
    templateId: templateId,
    frames: frames,
    texts: texts,
    ornaments: ornaments,
    background: PageBackground(color: bg),
  );

  // Spine.
  final spineTexts = <TextBlock>[];
  final label = spineText ?? title;
  if (spineMm >= kMinSpineTextMm && label.isNotEmpty) {
    final longSide = h * 0.72;
    final size = math
        .min(9.0, mmToPt(spineMm) * 0.45)
        .clamp(kMinTextPt, 9.0)
        .toDouble();
    spineTexts.add(
      TextBlock(
        id: 'spine',
        role: TextRole.title,
        text: label,
        fontFamily: theme.metaFont,
        sizePt: size,
        weight: 600,
        color: theme.text,
        align: TextAlignKind.center,
        vAlign: VerticalAlignKind.middle,
        rectMm: RectMm(
          x: spineMm / 2 - longSide / 2,
          y: h / 2 - spineMm * 0.35,
          w: longSide,
          h: spineMm * 0.7,
        ),
        uppercase: true,
        trackingPct: 16,
        lineHeight: 1.1,
        maxLines: 1,
        rotationDeg: 90,
      ),
    );
  }
  final spine = BookPage(
    id: 'cover_spine',
    templateId: 'spine',
    texts: spineTexts,
    background: PageBackground(color: bg),
  );

  // Back cover.
  final backTexts = <TextBlock>[
    if (backText != null && backText.isNotEmpty)
      kit.body(
        'back_text',
        backText,
        RectMm(x: w * 0.2, y: h * 0.34, w: w * 0.6, h: h * 0.3),
        sizePt: 11,
        italic: true,
        align: TextAlignKind.center,
        maxLines: 6,
      ),
    kit.meta(
      'back_mark',
      backMark,
      RectMm(x: w * 0.3, y: h - 18, w: w * 0.4, h: 5),
      sizePt: 8,
      opacity: 0.6,
      trackingPct: 30,
      role: TextRole.colophon,
    ),
  ];
  final back = BookPage(
    id: 'cover_back',
    templateId: 'back',
    texts: backTexts,
    ornaments: [Ornaments.divider(w / 2, h - 22, 8, accent)],
    background: PageBackground(color: bg),
  );

  return CoverDesign(
    templateId: templateId,
    slots: slots,
    spineText: spineText,
    backText: backText,
    spineMm: spineMm,
    front: front,
    back: back,
    spine: spine,
  );
}

/// Re-stacks the text blocks [ids] (in order) from [top] using their real
/// laid-out heights and [gapMm] between them. If the stack would pass
/// [maxBottom] it moves up (not above [minTop]) and then tightens gaps, so
/// minimum text sizes never push text off the safe area.
void _settle(
  List<TextBlock> texts,
  List<String> ids,
  ComposeEnv env, {
  required double top,
  required double maxBottom,
  double minTop = 0,
  double gapMm = 4,
}) {
  final idx = [for (final id in ids) texts.indexWhere((t) => t.id == id)]
      .where((i) => i >= 0)
      .toList();
  if (idx.isEmpty) return;
  final heights = [
    for (final i in idx)
      layoutTextBlock(
            texts[i].copyWith(
              rectMm: texts[i].rectMm.copyWith(h: 1000),
              vAlign: VerticalAlignKind.top,
            ),
            env.fonts,
          ).heightMm +
          0.4,
  ];
  var gap = gapMm;
  double total() =>
      heights.fold<double>(0, (a, b) => a + b) + gap * (heights.length - 1);
  var y = top;
  if (y + total() > maxBottom) y = maxBottom - total();
  if (y < minTop) {
    y = minTop;
    while (gap > 1 && y + total() > maxBottom) {
      gap -= 0.5;
    }
  }
  for (var k = 0; k < idx.length; k++) {
    final t = texts[idx[k]];
    texts[idx[k]] = t.copyWith(
      rectMm: t.rectMm.copyWith(y: y, h: heights[k]),
      vAlign: VerticalAlignKind.top,
    );
    y += heights[k] + gap;
  }
}

Ornament _gradient(RectMm r, double fromOpacity, double toOpacity) => Ornament(
  type: OrnamentType.gradient,
  params: {
    'x': r.x,
    'y': r.y,
    'w': r.w,
    'h': r.h,
    'o0': fromOpacity,
    'o1': toOpacity,
  },
  color: _black,
  color2: _black,
);

/// Size at which a single-line block fills its rect width (capped).
double _fitWidth(TextBlock b, ComposeEnv env, {required double maxPt}) {
  final m = env.fonts.metrics(b.fontFamily, b.weight, italic: b.italic);
  final text = displayText(b);
  final at1 = m.widthPt(text, 1, trackingPct: b.trackingPct);
  if (at1 <= 0) return maxPt;
  final byWidth = mmToPt(b.rectMm.w) * 0.98 / at1;
  final byHeight = mmToPt(b.rectMm.h) / b.lineHeight;
  final size = byWidth < byHeight ? byWidth : byHeight;
  return size.clamp(kMinTextPt, maxPt).toDouble();
}
