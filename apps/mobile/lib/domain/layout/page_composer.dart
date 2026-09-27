import 'dart:math' as math;

import '../geo/geo_data.dart';
import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/book_format.dart';
import '../spec/book_strings.dart';
import '../text/font_registry.dart';
import '../theme/book_theme.dart';
import 'map_composer.dart';
import 'ornaments.dart';
import 'smart_crop.dart';
import 'templates.dart';
import 'type_kit.dart';

/// Face bounding boxes must stay this far from the gutter (section 6.2).
const double kFaceGutterMm = 12;

/// On panoramas, face centres must stay this far from the gutter.
const double kPanoramaFaceGutterMm = 20;

/// Everything a page needs to be (re)composed, independent of its geometry.
class PageContent {
  PageContent({
    required this.templateId,
    this.mirrored = false,
    this.chapterId,
    List<String?>? photoIds,
    Map<int, CropRect>? userCrops,
    Map<int, String>? captions,
    this.title,
    this.subtitle,
    this.body,
    this.label,
    Map<String, TextOverride>? textOverrides,
  }) : photoIds = photoIds ?? [],
       userCrops = userCrops ?? {},
       captions = captions ?? {},
       textOverrides = textOverrides ?? {};

  String templateId;
  bool mirrored;
  String? chapterId;
  List<String?> photoIds;
  Map<int, CropRect> userCrops;
  Map<int, String> captions;
  String? title;
  String? subtitle;
  String? body;
  String? label;

  /// Hand-set size/alignment per text block id.
  Map<String, TextOverride> textOverrides;

  PageContent copy() => PageContent(
    templateId: templateId,
    mirrored: mirrored,
    chapterId: chapterId,
    photoIds: [...photoIds],
    userCrops: {...userCrops},
    captions: {...captions},
    title: title,
    subtitle: subtitle,
    body: body,
    label: label,
    textOverrides: {...textOverrides},
  );
}

class TextOverride {
  const TextOverride({required this.sizePt, required this.align});

  final double sizePt;
  final TextAlignKind align;
}

/// Shared inputs for composing pages of one album.
class ComposeEnv {
  ComposeEnv({
    required this.format,
    required this.theme,
    required this.accent,
    required this.strings,
    required this.fonts,
    required this.photos,
    required this.chapters,
    this.geo,
    this.seed = 1,
    int? year,
  }) : kit = TypeKit(theme, format, fonts),
       year = year ?? DateTime.now().year;

  final BookFormat format;
  final BookTheme theme;
  final String accent;
  final BookStrings strings;
  final FontRegistry fonts;
  final Map<String, PhotoRef> photos;
  final List<Chapter> chapters;
  final GeoData? geo;
  final int seed;
  final TypeKit kit;

  /// Year printed in the colophon.
  final int year;
}

/// Extracts the content of an existing page so it can be recomposed.
PageContent contentOf(BookPage page) {
  final c = PageContent(
    templateId: page.templateId,
    mirrored: page.mirrored,
    chapterId: page.chapterId,
    photoIds: [for (final f in page.frames) f.photoId],
    userCrops: {
      for (var i = 0; i < page.frames.length; i++)
        if (page.frames[i].userCrop) i: page.frames[i].crop,
    },
  );
  for (final t in page.texts) {
    if (t.userStyled) {
      c.textOverrides[t.id] = TextOverride(sizePt: t.sizePt, align: t.align);
    }
    if (t.id == 'quote') {
      c.body = t.text.replaceAll(RegExp('^“|”\$'), '');
      continue;
    }
    if (t.id.startsWith('cap_')) {
      final i = int.tryParse(t.id.split('_').last);
      if (i != null) c.captions[i] = t.text;
      continue;
    }
    switch (t.role) {
      case TextRole.title || TextRole.chapter
          when page.templateId != 'map_page' && t.id != 'notes':
        c.title = t.text;
      case TextRole.subtitle:
        c.subtitle = t.text;
      case TextRole.body:
        c.body = t.text;
      case TextRole.date || TextRole.label when !t.id.startsWith('map_'):
        c.label = t.text;
      default:
        break;
    }
  }
  return c;
}

/// Composes a page at [index] (which determines left/right side).
BookPage composePage(
  PageContent content,
  int index,
  ComposeEnv env, {
  required String id,
}) {
  final template = PageTemplate.byId(content.templateId);
  final side = BookFormat.sideOf(index);
  final photos = [
    for (final pid in content.photoIds) pid == null ? null : env.photos[pid],
  ];
  final slots = [
    for (var i = 0; i < photos.length; i++)
      SlotInput(
        aspect: photos[i]?.aspect ?? 1.5,
        hasCaption:
            template.captionMode == CaptionMode.below &&
            (content.captions[i]?.trim().isNotEmpty ?? false),
      ),
  ];
  final geometry = template.build(
    TemplateContext(
      format: env.format,
      side: side,
      mirrored: content.mirrored,
      slots: slots,
      rotationSeed: env.seed * 31 + index,
    ),
  );

  final frames = <PhotoFrame>[];
  final texts = <TextBlock>[];
  final ornaments = <Ornament>[];
  final kit = env.kit;
  final theme = env.theme;
  final w = env.format.trimWMm;

  // Photo frames.
  for (var i = 0; i < geometry.slots.length; i++) {
    final slot = geometry.slots[i];
    final photo = i < photos.length ? photos[i] : null;
    final inner = slot.borderMm > 0
        ? slot.rect.deflate(slot.borderMm)
        : slot.rect;
    var crop = CropRect.full;
    var userCrop = false;
    if (photo != null) {
      final manual = content.userCrops[i];
      if (manual != null) {
        final manualAspect = manual.w * photo.width / (manual.h * photo.height);
        crop = (manualAspect - inner.aspect).abs() < 0.01
            ? manual
            : adaptCrop(manual, photo, inner.aspect);
        userCrop = true;
      } else {
        crop = smartCrop(photo, inner.aspect).crop;
      }
      if (template.fullBleed) {
        crop = avoidGutter(
          photo,
          crop,
          inner,
          gutterX: template.panorama
              ? (side == PageSide.left ? w : 0)
              : env.format.gutterX(side),
          minDistMm: template.panorama ? kPanoramaFaceGutterMm : kFaceGutterMm,
          centresOnly: template.panorama,
        );
      }
    }
    final soft =
        theme.ornament == OrnamentStyle.softRoundFrames && !template.fullBleed;
    frames.add(
      PhotoFrame(
        id: '${id}_f$i',
        photoId: photo?.id,
        rectMm: slot.rect,
        crop: crop,
        rotationDeg: slot.rotationDeg,
        borderMm: slot.borderMm,
        borderColor: '#FFFFFF',
        cornerRadiusMm: soft ? 3 : 0,
        userCrop: userCrop,
      ),
    );
    if (slot.captionRect != null &&
        (content.captions[i]?.isNotEmpty ?? false)) {
      texts.add(kit.caption('cap_$i', content.captions[i]!, slot.captionRect!));
    }
    if (theme.ornament == OrnamentStyle.deckleCorners &&
        template.isHero &&
        !template.fullBleed) {
      ornaments.addAll(Ornaments.deckleCorners(slot.rect, env.accent));
    }
  }

  final box = geometry.textArea;
  switch (template.id) {
    case 'photo_with_text_right' || 'photo_with_text_below':
      final text = content.captions[0] ?? content.body;
      if (box != null && text != null && text.isNotEmpty) {
        texts.add(
          kit.body(
            'cap_0',
            text,
            box,
            sizePt: 10.5,
            italic: true,
            vAlign: template.id == 'photo_with_text_right'
                ? VerticalAlignKind.middle
                : VerticalAlignKind.top,
            role: TextRole.caption,
          ),
        );
      }
    case 'title_page':
      _titlePage(content, env, box!, texts, ornaments);
    case 'chapter_opener':
      _chapterOpener(content, env, box!, texts, ornaments, index);
    case 'map_page':
      _mapPage(content, env, box!, texts, ornaments);
    case 'quote_page':
      final quote = content.body ?? '';
      texts.add(
        kit
            .display(
              'quote',
              '“$quote”',
              RectMm(
                x: box!.x,
                y: box.y + box.h * 0.3,
                w: box.w,
                h: box.h * 0.35,
              ),
              sizePt: 20,
              role: TextRole.body,
              vAlign: VerticalAlignKind.middle,
              maxLines: 5,
            )
            .copyWith(
              uppercase: false,
              trackingPct: 0,
              italic: theme.displayFont == 'CormorantGaramond',
            ),
      );
      if (content.label != null) {
        texts.add(
          kit.meta(
            'attribution',
            content.label!,
            RectMm(x: box.x, y: box.y + box.h * 0.68, w: box.w, h: 6),
          ),
        );
      }
    case 'blank_note':
      final title = content.title ?? env.strings.notes;
      texts.add(
        kit.meta(
          'notes',
          title,
          RectMm(x: box!.x, y: box.y, w: box.w, h: 6),
          align: TextAlignKind.left,
          role: TextRole.title,
        ),
      );
      for (var y = box.y + 18; y < box.bottom - 2; y += 9) {
        ornaments.add(
          Ornament(
            type: OrnamentType.line,
            params: {'x1': box.x, 'y1': y, 'x2': box.right, 'y2': y},
            color: theme.text,
            opacity: 0.25,
            strokePt: 0.3,
          ),
        );
      }
    case 'colophon':
      final text = env.strings.colophon(env.year);
      texts.add(
        kit.meta(
          'colophon',
          text,
          RectMm(x: box!.x, y: box.y + box.h * 0.78, w: box.w, h: 8),
          sizePt: 8,
          caps: false,
          trackingPct: 4,
          weight: 400,
          role: TextRole.colophon,
          opacity: 0.8,
        ),
      );
      ornaments.add(
        Ornaments.divider(box.cx, box.y + box.h * 0.78 - 5, 10, env.accent),
      );
  }

  if (!geometry.hidePageNumber) texts.add(kit.pageNumber(index));

  // Re-apply hand-set text styles.
  for (var i = 0; i < texts.length; i++) {
    final o = content.textOverrides[texts[i].id];
    if (o != null) {
      texts[i] = texts[i].copyWith(
        sizePt: o.sizePt,
        align: o.align,
        userStyled: true,
      );
    }
  }

  return BookPage(
    id: id,
    templateId: template.id,
    mirrored: content.mirrored,
    chapterId: content.chapterId,
    frames: frames,
    texts: texts,
    ornaments: ornaments,
    background: PageBackground(color: theme.background),
  );
}

void _titlePage(
  PageContent c,
  ComposeEnv env,
  RectMm box,
  List<TextBlock> texts,
  List<Ornament> ornaments,
) {
  final kit = env.kit;
  final titleTop = box.y + box.h * 0.34;
  ornaments.addAll(
    Ornaments.forHeading(
      env.theme,
      env.accent,
      env.format.trimWMm,
      env.format.trimHMm,
      box.cx,
      titleTop - 10,
      seed: env.seed,
    ),
  );
  texts.add(
    kit.display(
      'title',
      c.title ?? '',
      RectMm(x: box.x, y: titleTop, w: box.w, h: 34 * kit.scale + 10),
      sizePt: 34,
      vAlign: VerticalAlignKind.bottom,
    ),
  );
  var y = titleTop + 34 * kit.scale + 16;
  if (c.subtitle != null && c.subtitle!.isNotEmpty) {
    texts.add(
      kit.body(
        'subtitle',
        c.subtitle!,
        RectMm(x: box.x + box.w * 0.1, y: y, w: box.w * 0.8, h: 14),
        sizePt: 12,
        italic: true,
        align: TextAlignKind.center,
        role: TextRole.subtitle,
        maxLines: 2,
      ),
    );
    y += 18;
  }
  if (c.label != null && c.label!.isNotEmpty) {
    texts.add(
      kit.meta(
        'date',
        c.label!,
        RectMm(x: box.x, y: y, w: box.w, h: 6),
        color: env.accent,
      ),
    );
  }
}

void _chapterOpener(
  PageContent c,
  ComposeEnv env,
  RectMm box,
  List<TextBlock> texts,
  List<Ornament> ornaments,
  int index,
) {
  final kit = env.kit;
  final hasPhoto = c.photoIds.any((p) => p != null);
  final top = hasPhoto ? box.y + 2 : box.y + box.h * 0.32;
  if (c.label != null && c.label!.isNotEmpty) {
    texts.add(
      kit.meta(
        'label',
        c.label!,
        RectMm(x: box.x, y: top, w: box.w, h: 6),
        color: env.accent,
        role: TextRole.label,
      ),
    );
  }
  final titleY = top + 9;
  texts.add(
    kit.display(
      'title',
      c.title ?? '',
      RectMm(x: box.x, y: titleY, w: box.w, h: 26 * kit.scale + 6),
      sizePt: 26,
      role: TextRole.chapter,
    ),
  );
  final dividerY = titleY + 26 * kit.scale + 12;
  if (env.theme.ornament == OrnamentStyle.passportStamp && !hasPhoto) {
    final r = 11 * kit.scale + 4;
    ornaments.add(
      Ornaments.stamp(
        box.right - r - 4,
        box.y + r + 4,
        r,
        env.accent,
        opacity: 0.55,
      ),
    );
  } else if (env.theme.ornament != OrnamentStyle.goldFrame) {
    ornaments.addAll(
      Ornaments.forHeading(
        env.theme,
        env.accent,
        env.format.trimWMm,
        env.format.trimHMm,
        box.cx,
        dividerY - 4,
        seed: env.seed + index,
      ),
    );
  } else {
    ornaments.addAll(
      Ornaments.forHeading(
        env.theme,
        env.accent,
        env.format.trimWMm,
        env.format.trimHMm,
        box.cx,
        0,
      ),
    );
  }
  if (c.body != null && c.body!.isNotEmpty) {
    texts.add(
      kit.body(
        'intro',
        c.body!,
        RectMm(
          x: box.x + box.w * 0.12,
          y: dividerY + 2,
          w: box.w * 0.76,
          h: math.max(20, box.bottom - dividerY - 6),
        ),
        sizePt: 10.5,
        align: TextAlignKind.center,
        maxLines: 6,
      ),
    );
  }
}

void _mapPage(
  PageContent c,
  ComposeEnv env,
  RectMm box,
  List<TextBlock> texts,
  List<Ornament> ornaments,
) {
  final kit = env.kit;
  texts.add(
    kit.meta(
      'title',
      c.title ?? env.strings.theRoute,
      RectMm(x: box.x, y: box.y, w: box.w, h: 6),
      role: TextRole.title,
      sizePt: 9,
    ),
  );
  final geo = env.geo;
  if (geo == null) return;
  final mapRect = RectMm(x: box.x, y: box.y + 12, w: box.w, h: box.h - 12);
  final drawing = composeRouteMap(
    rect: mapRect,
    stops: stopsFromChapters(env.chapters),
    geo: geo,
    textColor: env.theme.text,
    accent: env.accent,
    strings: env.strings,
    fonts: env.fonts,
  );
  ornaments.addAll(drawing.ornaments);
  texts.addAll(drawing.texts);
}
