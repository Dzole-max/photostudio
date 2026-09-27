import 'package:freezed_annotation/freezed_annotation.dart';

part 'geometry.freezed.dart';
part 'geometry.g.dart';

const double kMmPerInch = 25.4;
const double kPtPerMm = 72 / kMmPerInch;

double mmToPt(double mm) => mm * kPtPerMm;

double ptToMm(double pt) => pt / kPtPerMm;

/// Rectangle in millimetres relative to the page trim box (origin top-left).
@freezed
abstract class RectMm with _$RectMm {
  const RectMm._();

  const factory RectMm({
    required double x,
    required double y,
    required double w,
    required double h,
  }) = _RectMm;

  factory RectMm.fromJson(Map<String, Object?> json) => _$RectMmFromJson(json);

  double get right => x + w;

  double get bottom => y + h;

  double get cx => x + w / 2;

  double get cy => y + h / 2;

  double get aspect => w / h;

  RectMm inflate(double d) =>
      RectMm(x: x - d, y: y - d, w: w + 2 * d, h: h + 2 * d);

  RectMm deflate(double d) => inflate(-d);

  RectMm translate(double dx, double dy) =>
      RectMm(x: x + dx, y: y + dy, w: w, h: h);

  /// Horizontal mirror inside a page of [pageW] mm.
  RectMm mirrorX(double pageW) => RectMm(x: pageW - x - w, y: y, w: w, h: h);

  bool containsRect(RectMm o, {double epsilon = 0.01}) =>
      o.x >= x - epsilon &&
      o.y >= y - epsilon &&
      o.right <= right + epsilon &&
      o.bottom <= bottom + epsilon;

  bool overlaps(RectMm o) =>
      x < o.right && o.x < right && y < o.bottom && o.y < bottom;
}

/// Normalised crop in source-image space (0..1), after EXIF orientation.
@freezed
abstract class CropRect with _$CropRect {
  const CropRect._();

  const factory CropRect({
    required double x,
    required double y,
    required double w,
    required double h,
  }) = _CropRect;

  factory CropRect.fromJson(Map<String, Object?> json) =>
      _$CropRectFromJson(json);

  static const full = CropRect(x: 0, y: 0, w: 1, h: 1);

  double get right => x + w;

  double get bottom => y + h;
}
