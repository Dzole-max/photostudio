import 'dart:math' as math;

import '../model/album.dart';
import '../model/geometry.dart';

class CropResult {
  const CropResult(this.crop, {required this.facesSafe});

  final CropRect crop;

  /// Every face box (with 8 % padding) lies fully inside the crop.
  final bool facesSafe;
}

/// Face padding required around each face box (fraction of the box size).
const double kFacePadding = 0.08;

/// Union of all face boxes, padded; null when there are no faces.
CropRect? faceUnion(PhotoRef photo, {double padding = kFacePadding}) {
  if (photo.faces.isEmpty) return null;
  var x0 = 1.0, y0 = 1.0, x1 = 0.0, y1 = 0.0;
  for (final f in photo.faces) {
    final px = f.w * padding, py = f.h * padding;
    x0 = math.min(x0, f.x - px);
    y0 = math.min(y0, f.y - py);
    x1 = math.max(x1, f.x + f.w + px);
    y1 = math.max(y1, f.y + f.h + py);
  }
  return CropRect(
    x: x0.clamp(0, 1),
    y: y0.clamp(0, 1),
    w: (x1 - x0).clamp(0, 1),
    h: (y1 - y0).clamp(0, 1),
  );
}

/// Largest crop of the photo with the frame's aspect, centred on the faces
/// (or on the photo's focus point), optionally zoomed in by [zoom] ≥ 1.
CropResult smartCrop(
  PhotoRef photo,
  double frameAspect, {
  double zoom = 1,
  double? focusX,
  double? focusY,
}) {
  final photoAspect = photo.aspect;
  double w, h;
  if (photoAspect > frameAspect) {
    h = 1;
    w = frameAspect / photoAspect;
  } else {
    w = 1;
    h = photoAspect / frameAspect;
  }
  w /= zoom;
  h /= zoom;

  final faces = faceUnion(photo);
  double cx, cy;
  if (faces != null) {
    cx = faces.x + faces.w / 2;
    // Keep eyes a little above centre: bias towards the upper faces.
    cy = faces.y + faces.h * 0.45;
  } else {
    cx = focusX ?? photo.focusX;
    cy = focusY ?? photo.focusY;
  }
  var x = (cx - w / 2).clamp(0.0, 1 - w);
  var y = (cy - h / 2).clamp(0.0, 1 - h);

  // If faces don't fit but could, slide the window to contain them.
  if (faces != null) {
    if (faces.w <= w) {
      if (faces.x < x) x = faces.x;
      if (faces.right > x + w) x = faces.right - w;
    }
    if (faces.h <= h) {
      if (faces.y < y) y = faces.y;
      if (faces.bottom > y + h) y = faces.bottom - h;
    }
    x = x.clamp(0.0, 1 - w);
    y = y.clamp(0.0, 1 - h);
  }
  final crop = CropRect(x: x, y: y, w: w, h: h);
  return CropResult(crop, facesSafe: facesInside(photo, crop));
}

bool facesInside(PhotoRef photo, CropRect crop) {
  for (final f in photo.faces) {
    final px = f.w * kFacePadding, py = f.h * kFacePadding;
    if (f.x - px < crop.x - 1e-6 ||
        f.y - py < crop.y - 1e-6 ||
        f.x + f.w + px > crop.right + 1e-6 ||
        f.y + f.h + py > crop.bottom + 1e-6) {
      return false;
    }
  }
  return true;
}

/// Effective print resolution of [photo] shown through [crop] in a frame of
/// [frame] mm (the smaller of both axes).
double effectiveDpi(PhotoRef photo, CropRect crop, RectMm frame) {
  final pxW = photo.width * crop.w;
  final pxH = photo.height * crop.h;
  final inW = frame.w / kMmPerInch;
  final inH = frame.h / kMmPerInch;
  return math.min(pxW / inW, pxH / inH);
}

/// Crop of the same centre adjusted to a new frame aspect (used when a page
/// is re-laid out and the user had cropped by hand).
CropRect adaptCrop(CropRect crop, PhotoRef photo, double frameAspect) {
  final cx = crop.x + crop.w / 2;
  final cy = crop.y + crop.h / 2;
  final zoom = math.max(1.0, 1 / math.max(crop.w, crop.h));
  return smartCrop(
    photo.copyWith(faces: const []),
    frameAspect,
    zoom: zoom,
    focusX: cx,
    focusY: cy,
  ).crop;
}

/// Horizontal page-space extent (mm) of a face box shown through [crop] in
/// [rect].
(double, double) facePageSpan(FaceBox f, CropRect crop, RectMm rect) {
  final x0 = rect.x + (f.x - crop.x) / crop.w * rect.w;
  final x1 = rect.x + (f.x + f.w - crop.x) / crop.w * rect.w;
  return (x0, x1);
}

/// Slides [crop] horizontally so no face box (or face centre, for
/// panoramas) comes within [minDistMm] of the gutter at [gutterX].
/// Returns the crop unchanged when there is no room to move.
CropRect avoidGutter(
  PhotoRef photo,
  CropRect crop,
  RectMm rect, {
  required double gutterX,
  required double minDistMm,
  bool centresOnly = false,
}) {
  var result = crop;
  for (var pass = 0; pass < 3; pass++) {
    var shiftMm = 0.0;
    for (final f in photo.faces) {
      final (x0, x1) = facePageSpan(f, result, rect);
      final lo = centresOnly ? (x0 + x1) / 2 : x0;
      final hi = centresOnly ? (x0 + x1) / 2 : x1;
      if (hi < gutterX - minDistMm || lo > gutterX + minDistMm) continue;
      // Push the face to whichever side of the gutter needs less movement
      // and still lies on the page.
      // Half a millimetre of margin so the result clears the rule.
      final pushRight = gutterX + minDistMm + 0.5 - lo;
      final pushLeft = gutterX - minDistMm - 0.5 - hi;
      final candidate = pushRight.abs() <= pushLeft.abs()
          ? pushRight
          : pushLeft;
      if (candidate.abs() > shiftMm.abs()) shiftMm = candidate;
    }
    if (shiftMm == 0) return result;
    // Moving content right in the page = moving the crop window left.
    final dx = -shiftMm / rect.w * result.w;
    final nx = (result.x + dx).clamp(0.0, 1 - result.w);
    if ((nx - result.x).abs() < 1e-9) return result;
    result = result.copyWith(x: nx);
  }
  return result;
}

/// True when any face violates the gutter rule for this frame.
bool faceNearGutter(
  PhotoRef photo,
  CropRect crop,
  RectMm rect, {
  required double gutterX,
  required double minDistMm,
  bool centresOnly = false,
}) {
  for (final f in photo.faces) {
    final (x0, x1) = facePageSpan(f, crop, rect);
    // Faces cropped out of the frame don't matter.
    if (x1 < rect.x || x0 > rect.right) continue;
    final lo = centresOnly ? (x0 + x1) / 2 : x0;
    final hi = centresOnly ? (x0 + x1) / 2 : x1;
    if (hi >= gutterX - minDistMm && lo <= gutterX + minDistMm) return true;
  }
  return false;
}
