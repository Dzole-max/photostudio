import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/book_format.dart';
import '../text/font_registry.dart';
import '../text/text_layout.dart';
import '../theme/book_theme.dart';

/// Minimum printed text size (in-house rule, section 6.2).
const double kMinTextPt = 8;

/// Default caption size and colour opacity (section 5.4).
const double kCaptionPt = 9;
const double kCaptionOpacity = 0.8;

/// Builds text blocks in the theme's fonts, scaled to the format.
class TypeKit {
  TypeKit(this.theme, this.format, this.fonts, {String? textColor})
    : textColor = textColor ?? theme.text,
      scale =
          (format.trimWMm < format.trimHMm ? format.trimWMm : format.trimHMm) /
          200;

  final BookTheme theme;
  final BookFormat format;
  final FontRegistry fonts;
  final String textColor;

  /// 1.0 on Classic (200 mm), 0.7 on Mini.
  final double scale;

  double sized(double pt) => (pt * scale).clamp(kMinTextPt, 400).toDouble();

  TextBlock display(
    String id,
    String text,
    RectMm rect, {
    double sizePt = 30,
    TextAlignKind align = TextAlignKind.center,
    VerticalAlignKind vAlign = VerticalAlignKind.top,
    TextRole role = TextRole.title,
    String? color,
    bool fit = true,
    int maxLines = 2,
  }) {
    final block = TextBlock(
      id: id,
      role: role,
      text: text,
      fontFamily: theme.displayFont,
      sizePt: sized(sizePt),
      weight: theme.displayWeight,
      color: color ?? textColor,
      align: align,
      vAlign: vAlign,
      rectMm: rect,
      uppercase: theme.displayCaps,
      trackingPct: theme.displayTrackingPct,
      lineHeight: 1.12,
      maxLines: maxLines,
      minSizePt: sized(sizePt) * 0.55 < kMinTextPt
          ? kMinTextPt
          : sized(sizePt) * 0.55,
    );
    return fit ? autoFit(block, maxLines: maxLines) : block;
  }

  TextBlock body(
    String id,
    String text,
    RectMm rect, {
    double sizePt = 10.5,
    TextAlignKind align = TextAlignKind.left,
    VerticalAlignKind vAlign = VerticalAlignKind.top,
    bool italic = false,
    TextRole role = TextRole.body,
    String? color,
    double opacity = 1,
    int? maxLines,
  }) {
    return autoFit(
      TextBlock(
        id: id,
        role: role,
        text: text,
        fontFamily: theme.bodyFont,
        sizePt: sizePt < kMinTextPt ? kMinTextPt : sizePt,
        italic: italic && theme.bodyFont != 'Nunito',
        color: color ?? textColor,
        opacity: opacity,
        align: align,
        vAlign: vAlign,
        rectMm: rect,
        lineHeight: 1.45,
        maxLines: maxLines,
        minSizePt: kMinTextPt,
      ),
      maxLines: maxLines,
    );
  }

  TextBlock caption(
    String id,
    String text,
    RectMm rect, {
    TextAlignKind align = TextAlignKind.left,
  }) => body(
    id,
    text,
    rect,
    sizePt: kCaptionPt,
    align: align,
    role: TextRole.caption,
    opacity: kCaptionOpacity,
    maxLines: 2,
  );

  TextBlock meta(
    String id,
    String text,
    RectMm rect, {
    double sizePt = 8.5,
    TextAlignKind align = TextAlignKind.center,
    VerticalAlignKind vAlign = VerticalAlignKind.top,
    bool caps = true,
    double trackingPct = 20,
    int weight = 600,
    TextRole role = TextRole.date,
    String? color,
    double opacity = 1,
  }) {
    return autoFit(
      TextBlock(
        id: id,
        role: role,
        text: text,
        fontFamily: theme.metaFont,
        sizePt: sizePt < kMinTextPt ? kMinTextPt : sizePt,
        weight: weight,
        color: color ?? textColor,
        opacity: opacity,
        align: align,
        vAlign: vAlign,
        rectMm: rect,
        uppercase: caps,
        trackingPct: trackingPct,
        lineHeight: 1.3,
        maxLines: 2,
        minSizePt: kMinTextPt,
      ),
      maxLines: 2,
    );
  }

  TextBlock script(
    String id,
    String text,
    RectMm rect, {
    double sizePt = 40,
    String? color,
  }) => autoFit(
    TextBlock(
      id: id,
      role: TextRole.monogram,
      text: text,
      fontFamily: 'GreatVibes',
      sizePt: sized(sizePt),
      color: color ?? theme.accent,
      align: TextAlignKind.center,
      vAlign: VerticalAlignKind.middle,
      rectMm: rect,
      lineHeight: 1.1,
      maxLines: 1,
      minSizePt: kMinTextPt,
    ),
    maxLines: 1,
  );

  /// Page number: Manrope 8 pt, outer bottom corner, 8 mm from the trim.
  TextBlock pageNumber(int pageIndex) {
    final side = BookFormat.sideOf(pageIndex);
    const w = 20.0, h = 5.0, edge = 8.0;
    final right = side == PageSide.right;
    return TextBlock(
      id: 'pn_$pageIndex',
      role: TextRole.pageNumber,
      text: '${pageIndex + 1}',
      fontFamily: 'Manrope',
      sizePt: 8,
      weight: 400,
      color: textColor,
      opacity: 0.7,
      align: right ? TextAlignKind.right : TextAlignKind.left,
      vAlign: VerticalAlignKind.bottom,
      rectMm: RectMm(
        x: right ? format.trimWMm - edge - w : edge,
        y: format.trimHMm - edge - h,
        w: w,
        h: h,
      ),
      lineHeight: 1.2,
    );
  }

  /// Shrinks [b] (down to its minSizePt) until it fits; if it still doesn't,
  /// wraps up to [maxLines].
  TextBlock autoFit(TextBlock b, {int? maxLines}) {
    final r = layoutTextBlock(b.copyWith(maxLines: null), fonts);
    final lines = r.lines.length;
    if (!r.overflows && (maxLines == null || lines <= maxLines)) return b;
    final size = fitSize(
      b,
      fonts,
      minPt: b.minSizePt ?? kMinTextPt,
      maxPt: b.sizePt,
      maxLines: maxLines,
    );
    return b.copyWith(sizePt: size);
  }
}
