import 'package:freezed_annotation/freezed_annotation.dart';

import 'geometry.dart';

part 'album.freezed.dart';
part 'album.g.dart';

/// Version of the album JSON contract (packages/layout_spec/album.schema.json).
const int kAlbumSchemaVersion = 1;

enum Occasion { wedding, travel, baby, birthday, family, other }

enum AlbumStatus { draft, ordered, delivered, archived }

/// Cover material: printed matte/gloss laminate, or a linen / leather-look
/// cloth cover (hardcover formats only).
enum CoverFinish { matte, gloss, linen, leather }

/// The three products a book can be made into.
enum Edition { album, livingMemories, illustrated }

/// Illustrated Edition styles (never named after a studio).
enum IllustrationStyle { watercolor, inkSketch, comic, caricature, animated3d }

enum PhotoOrientation { landscape, portrait, square }

enum ExclusionReason { burst, duplicate, blur, user }

enum Tone { warm, poetic, playful, minimal }

enum TextRole {
  title,
  subtitle,
  caption,
  chapter,
  body,
  date,
  pageNumber,
  colophon,
  label,
  monogram,
}

enum TextAlignKind { left, center, right }

enum VerticalAlignKind { top, middle, bottom }

enum OrnamentType {
  line,
  rect,
  circle,
  arc,
  path,
  stamp,
  monogramRing,
  gradient,
}

/// A face found on device; box normalised to the oriented image (0..1).
@freezed
abstract class FaceBox with _$FaceBox {
  const factory FaceBox({
    required double x,
    required double y,
    required double w,
    required double h,
    double? eyesOpen,
    double? smile,
  }) = _FaceBox;

  factory FaceBox.fromJson(Map<String, Object?> json) =>
      _$FaceBoxFromJson(json);
}

@freezed
abstract class PhotoLabel with _$PhotoLabel {
  const factory PhotoLabel({required String text, required double confidence}) =
      _PhotoLabel;

  factory PhotoLabel.fromJson(Map<String, Object?> json) =>
      _$PhotoLabelFromJson(json);
}

/// All values 0..1 except [faceCount].
@freezed
abstract class QualityScore with _$QualityScore {
  const factory QualityScore({
    @Default(0.5) double sharpness,
    @Default(0.5) double exposure,
    @Default(1) double eyesOpen,
    @Default(0) int faceCount,
    @Default(0.5) double overall,

    /// Raw variance of the Laplacian (before per-batch normalisation).
    @Default(0) double laplacian,
  }) = _QualityScore;

  factory QualityScore.fromJson(Map<String, Object?> json) =>
      _$QualityScoreFromJson(json);
}

@freezed
abstract class PhotoRef with _$PhotoRef {
  const PhotoRef._();

  const factory PhotoRef({
    required String id,

    /// `pm:<id>` for gallery assets, `asset:<path>` for bundled samples.
    /// Stripped before the document leaves the phone.
    String? localAssetId,
    String? remoteUrl,

    /// Pixel size after applying EXIF orientation.
    required int width,
    required int height,
    DateTime? takenAt,
    double? lat,
    double? lng,
    String? placeName,

    /// Gazetteer id of [placeName] (assets/geo/places.json) for localising.
    String? placeId,
    String? countryCode,
    @Default(<FaceBox>[]) List<FaceBox> faces,
    @Default(<PhotoLabel>[]) List<PhotoLabel> labels,
    @Default(QualityScore()) QualityScore quality,

    /// 64-bit perceptual hash as 16 hex characters.
    @Default('0000000000000000') String hash,
    String? burstGroupId,
    @Default(false) bool isExcluded,
    ExclusionReason? excludedReason,
    @Default(false) bool userPinned,

    /// Dominant hue in degrees (0..360) of a small thumbnail, if colourful.
    double? dominantHue,

    /// Saliency fallback for cropping: centre of the sharpest 3×3 tile (0..1).
    @Default(0.5) double focusX,
    @Default(0.45) double focusY,

    /// Derived image (illustration, print enhancement, cover art): never
    /// offered in curation or the photo tray.
    @Default(false) bool artwork,

    /// Photo this artwork was made from.
    String? sourceId,
  }) = _PhotoRef;

  factory PhotoRef.fromJson(Map<String, Object?> json) =>
      _$PhotoRefFromJson(json);

  double get aspect => width / height;

  PhotoOrientation get orientation {
    final a = aspect;
    if (a > 1.1) return PhotoOrientation.landscape;
    if (a < 0.9) return PhotoOrientation.portrait;
    return PhotoOrientation.square;
  }

  bool hasLabel(Set<String> names, {double minConfidence = 0.6}) => labels.any(
    (l) =>
        l.confidence >= minConfidence && names.contains(l.text.toLowerCase()),
  );
}

@freezed
abstract class DateRange with _$DateRange {
  const factory DateRange({required DateTime start, required DateTime end}) =
      _DateRange;

  factory DateRange.fromJson(Map<String, Object?> json) =>
      _$DateRangeFromJson(json);
}

@freezed
abstract class Chapter with _$Chapter {
  const factory Chapter({
    required String id,
    required String title,
    String? subtitle,
    String? intro,
    @Default(0) int startPageIndex,
    String? placeName,
    String? placeId,
    double? lat,
    double? lng,
    DateRange? dateRange,
  }) = _Chapter;

  factory Chapter.fromJson(Map<String, Object?> json) =>
      _$ChapterFromJson(json);
}

@freezed
abstract class PhotoFrame with _$PhotoFrame {
  const factory PhotoFrame({
    required String id,
    String? photoId,
    required RectMm rectMm,
    @Default(CropRect.full) CropRect crop,
    @Default(0) double rotationDeg,
    @Default(0) double borderMm,
    @Default('#FFFFFF') String borderColor,
    @Default(0) double cornerRadiusMm,

    /// True once the user adjusted the crop by hand; re-layout keeps it.
    @Default(false) bool userCrop,
  }) = _PhotoFrame;

  factory PhotoFrame.fromJson(Map<String, Object?> json) =>
      _$PhotoFrameFromJson(json);
}

@freezed
abstract class TextBlock with _$TextBlock {
  const factory TextBlock({
    required String id,
    required TextRole role,
    required String text,
    required String fontFamily,
    required double sizePt,
    @Default(400) int weight,
    @Default(false) bool italic,
    @Default('#1F1B17') String color,
    @Default(1) double opacity,
    @Default(TextAlignKind.left) TextAlignKind align,
    @Default(VerticalAlignKind.top) VerticalAlignKind vAlign,
    required RectMm rectMm,
    @Default(0) double trackingPct,
    @Default(1.3) double lineHeight,
    @Default(false) bool uppercase,
    int? maxLines,

    /// Smallest size auto-fit may shrink to.
    double? minSizePt,

    /// Rotation around the rect centre (spine text uses 90).
    @Default(0) double rotationDeg,

    /// Size/alignment set by hand in the editor; kept on re-layout.
    @Default(false) bool userStyled,
  }) = _TextBlock;

  factory TextBlock.fromJson(Map<String, Object?> json) =>
      _$TextBlockFromJson(json);
}

/// Vector ornament drawn from primitives in both renderers. All geometry in mm
/// relative to the page trim box:
/// - line: x1,y1,x2,y2
/// - rect: x,y,w,h (optional r)
/// - circle / monogramRing: cx,cy,r
/// - stamp: cx,cy,r (double ring with inner radius r - gap; gap default 1.5)
/// - arc: cx,cy,r,start,sweep (degrees, clockwise from 3 o'clock)
/// - path: SVG path data in mm ([path]: absolute M, L, Q, C, A, Z);
///   optional closed fill
/// - gradient: x,y,w,h vertical gradient from [color] at opacity o0 to
///   [color2] at opacity o1
@freezed
abstract class Ornament with _$Ornament {
  const factory Ornament({
    required OrnamentType type,
    @Default(<String, double>{}) Map<String, double> params,
    String? path,
    @Default('#1F1B17') String color,
    String? color2,
    @Default(1) double opacity,
    @Default(0.5) double strokePt,
    @Default(false) bool fill,
    List<double>? dashMm,
  }) = _Ornament;

  factory Ornament.fromJson(Map<String, Object?> json) =>
      _$OrnamentFromJson(json);
}

@freezed
abstract class PageBackground with _$PageBackground {
  const factory PageBackground({required String color, String? photoId}) =
      _PageBackground;

  factory PageBackground.fromJson(Map<String, Object?> json) =>
      _$PageBackgroundFromJson(json);
}

@freezed
abstract class BookPage with _$BookPage {
  const factory BookPage({
    required String id,
    required String templateId,
    @Default(false) bool mirrored,
    String? chapterId,
    @Default(<PhotoFrame>[]) List<PhotoFrame> frames,
    @Default(<TextBlock>[]) List<TextBlock> texts,
    @Default(<Ornament>[]) List<Ornament> ornaments,
    PageBackground? background,
  }) = _BookPage;

  factory BookPage.fromJson(Map<String, Object?> json) =>
      _$BookPageFromJson(json);
}

/// Typed cover slots (section 5.2). Unused slots stay null.
@freezed
abstract class CoverSlots with _$CoverSlots {
  const factory CoverSlots({
    String? title,
    String? subtitle,
    String? date,
    String? location,
    String? names,
    String? monogram,
    String? coordinates,
    String? heroPhotoId,
    @Default(<String>[]) List<String> photoIds,
    String? age,
    String? details,

    /// Where the book happened (map covers).
    double? lat,
    double? lng,
  }) = _CoverSlots;

  factory CoverSlots.fromJson(Map<String, Object?> json) =>
      _$CoverSlotsFromJson(json);
}

/// The cover spread. [front], [back] and [spine] hold resolved primitives in
/// mm relative to their own panel (front/back = trim size, spine = spineMm
/// wide), so renderers never need template logic.
@freezed
abstract class CoverDesign with _$CoverDesign {
  const factory CoverDesign({
    required String templateId,
    @Default(CoverSlots()) CoverSlots slots,
    String? spineText,
    String? backText,
    @Default(0) double spineMm,
    required BookPage front,
    required BookPage back,
    required BookPage spine,
  }) = _CoverDesign;

  factory CoverDesign.fromJson(Map<String, Object?> json) =>
      _$CoverDesignFromJson(json);
}

@freezed
abstract class StoryAnswers with _$StoryAnswers {
  const factory StoryAnswers({
    String? names,
    DateTime? eventDate,
    String? place,
    String? moment,
    String? title,
    @Default(Tone.warm) Tone tone,
  }) = _StoryAnswers;

  factory StoryAnswers.fromJson(Map<String, Object?> json) =>
      _$StoryAnswersFromJson(json);
}

@freezed
abstract class AlbumFlags with _$AlbumFlags {
  const factory AlbumFlags({
    @Default(false) bool illustrated,
    @Default(false) bool vectorText,

    /// Blank note pages the engine had to add to reach the minimum.
    @Default(0) int blankPagesAdded,

    /// A bundled demo book.
    @Default(false) bool sample,

    /// Edition the user chose when creating the book.
    @Default(Edition.album) Edition edition,
    IllustrationStyle? illustrationStyle,

    /// Local path of the last Living Memories video.
    String? videoPath,
  }) = _AlbumFlags;

  factory AlbumFlags.fromJson(Map<String, Object?> json) =>
      _$AlbumFlagsFromJson(json);
}

@freezed
abstract class Album with _$Album {
  const Album._();

  const factory Album({
    @Default(kAlbumSchemaVersion) int schemaVersion,
    required String id,
    required String title,
    String? subtitle,
    required Occasion occasion,
    required String themeId,
    required String formatId,
    @Default(CoverFinish.matte) CoverFinish coverFinish,

    /// Book language (may differ from the app language).
    required String language,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(AlbumStatus.draft) AlbumStatus status,
    @Default(1) int seed,

    /// Effective accent after adaptive tinting.
    required String accentColor,
    required CoverDesign cover,
    @Default(<BookPage>[]) List<BookPage> pages,
    @Default(<Chapter>[]) List<Chapter> chapters,
    @Default(<String, PhotoRef>{}) Map<String, PhotoRef> photos,
    @Default(StoryAnswers()) StoryAnswers story,
    @Default(AlbumFlags()) AlbumFlags flags,

    /// Books in the same series share a spine design ("Family 2025").
    String? series,

    /// This book's number in its series (1, 2, 3...), printed on the spine.
    int? seriesVolume,
  }) = _Album;

  factory Album.fromJson(Map<String, Object?> json) => _$AlbumFromJson(json);

  int get innerPages => pages.length;

  /// Photo ids placed anywhere in the book (cover included).
  Set<String> get usedPhotoIds => {
    for (final p in [...pages, cover.front, cover.back])
      for (final f in p.frames)
        if (f.photoId != null) f.photoId!,
  };

  /// The document as it leaves the phone: no local asset ids.
  Map<String, Object?> toServerJson() {
    final json = copyWith(
      photos: {
        for (final e in photos.entries)
          e.key: e.value.copyWith(localAssetId: null),
      },
    ).toJson();
    return json;
  }
}
