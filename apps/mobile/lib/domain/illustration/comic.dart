import 'dart:math' as math;

import '../layout/smart_crop.dart';
import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/book_format.dart';
import '../text/font_registry.dart';
import '../text/text_layout.dart';

/// Comic templates of the Cartoon & Comic Edition: panels with ink borders
/// and the page's caption lettered into a speech bubble.
const kComicTemplates = [
  'comic_splash',
  'comic_2_panels',
  'comic_3_panels',
  'comic_4_panels',
];

const _ink = '#151515';
const _paper = '#FBF8F1';
const _bubble = '#FFFFFF';
const double _gutterMm = 4;
const double _borderMm = 0.9;
const double _bubblePadMm = 4;

String comicTemplateFor(int photos) => switch (photos) {
  <= 1 => 'comic_splash',
  2 => 'comic_2_panels',
  3 => 'comic_3_panels',
  _ => 'comic_4_panels',
};

/// Panel rectangles for [templateId] inside [box].
List<RectMm> comicPanels(String templateId, RectMm box) {
  const g = _gutterMm;
  final landscape = box.w > box.h * 1.15;
  RectMm r(double x, double y, double w, double h) =>
      RectMm(x: box.x + x, y: box.y + y, w: w, h: h);
  final hw = (box.w - g) / 2, hh = (box.h - g) / 2;
  return switch (templateId) {
    'comic_2_panels' when landscape => [
      r(0, 0, hw, box.h),
      r(hw + g, 0, hw, box.h),
    ],
    'comic_2_panels' => [r(0, 0, box.w, hh), r(0, hh + g, box.w, hh)],
    'comic_3_panels' when landscape => [
      r(0, 0, hw, box.h),
      r(hw + g, 0, hw, hh),
      r(hw + g, hh + g, hw, hh),
    ],
    'comic_3_panels' => [
      r(0, 0, box.w, hh),
      r(0, hh + g, hw, hh),
      r(hw + g, hh + g, hw, hh),
    ],
    'comic_4_panels' => [
      r(0, 0, hw, hh),
      r(hw + g, 0, hw, hh),
      r(0, hh + g, hw, hh),
      r(hw + g, hh + g, hw, hh),
    ],
    _ => [box],
  };
}

/// The caption a comic page letters into its bubble.
String? pageCaption(BookPage page) {
  for (final role in const [TextRole.caption, TextRole.body]) {
    final t = page.texts.where(
      (t) => t.role == role && t.text.trim().isNotEmpty,
    );
    if (t.isNotEmpty) return t.map((t) => t.text.trim()).join(' ');
  }
  return null;
}

/// Rebuilds a photo page as a comic page. Special pages (title, chapter
/// openers, maps, notes) and pages without photos are returned unchanged.
BookPage comicPage({
  required BookPage page,
  required int pageIndex,
  required BookFormat format,
  required Map<String, PhotoRef> photos,
  required FontRegistry fonts,
}) {
  final ids = [
    for (final f in page.frames)
      if (f.photoId != null && photos.containsKey(f.photoId)) f.photoId!,
  ];
  if (ids.isEmpty) return page;
  // Up to 4 panels; the photo with the most people gets the first panel.
  final chosen = ids.take(4).toList()
    ..sort(
      (a, b) => photos[b]!.faces.length.compareTo(photos[a]!.faces.length),
    );
  final templateId = comicTemplateFor(chosen.length);
  final box = format.safeArea(BookFormat.sideOf(pageIndex));
  final panels = comicPanels(templateId, box);
  final frames = <PhotoFrame>[
    for (var i = 0; i < chosen.length; i++)
      PhotoFrame(
        id: '${page.id}_panel$i',
        photoId: chosen[i],
        rectMm: panels[i],
        crop: smartCrop(
          photos[chosen[i]]!,
          (panels[i].w - 2 * _borderMm) / (panels[i].h - 2 * _borderMm),
        ).crop,
        borderMm: _borderMm,
        borderColor: _ink,
      ),
  ];
  final keep = page.texts.where((t) => t.role == TextRole.pageNumber).toList();
  final caption = pageCaption(page);
  final bubble = caption == null
      ? null
      : speechBubble(
          id: '${page.id}_bubble',
          text: caption,
          panel: panels.first,
          photo: photos[chosen.first]!,
          crop: frames.first.crop,
          fonts: fonts,
        );
  return page.copyWith(
    templateId: templateId,
    frames: frames,
    texts: [...keep, ?bubble?.text],
    ornaments: bubble?.shapes ?? const [],
    background: const PageBackground(color: _paper),
  );
}

class SpeechBubble {
  const SpeechBubble(this.text, this.shapes);

  final TextBlock text;
  final List<Ornament> shapes;
}

/// A speech bubble in the top corner of [panel] away from the faces, its
/// tail pointing at the nearest face. Text is fitted (10–16 pt, ≤ 5 lines).
SpeechBubble speechBubble({
  required String id,
  required String text,
  required RectMm panel,
  required PhotoRef photo,
  required CropRect crop,
  required FontRegistry fonts,
}) {
  // Face position inside the panel (0..1), or the upper middle.
  var fx = 0.5, fy = 0.45;
  if (photo.faces.isNotEmpty) {
    final f = photo.faces.first;
    fx = ((f.x + f.w / 2 - crop.x) / crop.w).clamp(0.05, 0.95);
    fy = ((f.y - crop.y) / crop.h).clamp(0.05, 0.95);
  }
  final onRight = fx < 0.5;
  final w = math.min(panel.w * 0.62, 95.0);
  const inset = 3.0;
  final x = onRight ? panel.right - inset - w : panel.x + inset;
  final y = panel.y + inset;
  const pad = _bubblePadMm;
  final probe = TextBlock(
    id: id,
    role: TextRole.caption,
    text: text,
    fontFamily: 'Nunito',
    sizePt: 16,
    weight: 800,
    color: _ink,
    align: TextAlignKind.center,
    vAlign: VerticalAlignKind.middle,
    rectMm: RectMm(x: x + pad, y: y + pad, w: w - 2 * pad, h: panel.h * 0.4),
    lineHeight: 1.2,
    maxLines: 5,
    minSizePt: 10,
  );
  final size = fitSize(probe, fonts, minPt: 10, maxPt: 16, maxLines: 5);
  final laid = layoutTextBlock(probe.copyWith(sizePt: size), fonts);
  final textH = math.min(laid.heightMm, panel.h * 0.4);
  final h = textH + 2 * pad;
  final body = RectMm(x: x, y: y, w: w, h: h);
  final textBlock = probe.copyWith(
    sizePt: size,
    rectMm: RectMm(x: x + pad, y: y + pad, w: w - 2 * pad, h: textH),
  );

  // Tail from the bubble's lower edge toward the face.
  final baseX = onRight ? body.x + w * 0.3 : body.right - w * 0.3;
  // Leans toward the face but stays short, like a lettered comic.
  final toward = (panel.x + fx * panel.w - baseX).clamp(-10.0, 10.0);
  final tipX = (baseX + toward).clamp(panel.x + 4, panel.right - 4);
  final tipY = math.min(
    body.bottom + 8,
    math.max(body.bottom + 5, panel.y + fy * panel.h - 2),
  );
  final tail =
      'M ${_n(baseX - 4.5)} ${_n(body.bottom - 0.6)} '
      'L ${_n(tipX)} ${_n(tipY)} L ${_n(baseX + 4.5)} ${_n(body.bottom - 0.6)} Z';
  final tailEdges =
      'M ${_n(baseX - 4.5)} ${_n(body.bottom)} '
      'L ${_n(tipX)} ${_n(tipY)} L ${_n(baseX + 4.5)} ${_n(body.bottom)}';
  final outline = roundedRectPath(body, math.min(h / 2, 8));
  return SpeechBubble(textBlock, [
    Ornament(
      type: OrnamentType.path,
      path: outline,
      color: _bubble,
      fill: true,
    ),
    Ornament(
      type: OrnamentType.path,
      path: outline,
      color: _ink,
      strokePt: 1.2,
    ),
    // Covers the outline where the tail joins, then draws the tail's sides.
    Ornament(type: OrnamentType.path, path: tail, color: _bubble, fill: true),
    Ornament(
      type: OrnamentType.path,
      path: tailEdges,
      color: _ink,
      strokePt: 1.2,
    ),
  ]);
}

String roundedRectPath(RectMm r, double radius) {
  final k = math.min(radius, math.min(r.w, r.h) / 2);
  return 'M ${_n(r.x + k)} ${_n(r.y)} '
      'L ${_n(r.right - k)} ${_n(r.y)} '
      'A ${_n(k)} ${_n(k)} 0 0 1 ${_n(r.right)} ${_n(r.y + k)} '
      'L ${_n(r.right)} ${_n(r.bottom - k)} '
      'A ${_n(k)} ${_n(k)} 0 0 1 ${_n(r.right - k)} ${_n(r.bottom)} '
      'L ${_n(r.x + k)} ${_n(r.bottom)} '
      'A ${_n(k)} ${_n(k)} 0 0 1 ${_n(r.x)} ${_n(r.bottom - k)} '
      'L ${_n(r.x)} ${_n(r.y + k)} '
      'A ${_n(k)} ${_n(k)} 0 0 1 ${_n(r.x + k)} ${_n(r.y)} Z';
}

String _n(double v) => v.toStringAsFixed(2);
