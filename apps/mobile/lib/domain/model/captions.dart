import 'package:freezed_annotation/freezed_annotation.dart';

part 'captions.freezed.dart';
part 'captions.g.dart';

/// Output contract of the caption provider (section 7.5), validated on both
/// the edge function and the app.
@freezed
abstract class ChapterText with _$ChapterText {
  const factory ChapterText({
    required String id,
    required String title,
    @Default('') String intro,
  }) = _ChapterText;

  factory ChapterText.fromJson(Map<String, Object?> json) =>
      _$ChapterTextFromJson(json);
}

@freezed
abstract class PhotoCaption with _$PhotoCaption {
  const factory PhotoCaption({required String photoId, required String text}) =
      _PhotoCaption;

  factory PhotoCaption.fromJson(Map<String, Object?> json) =>
      _$PhotoCaptionFromJson(json);
}

@freezed
abstract class CaptionSet with _$CaptionSet {
  const CaptionSet._();

  const factory CaptionSet({
    required String title,
    @Default('') String subtitle,
    @Default(<ChapterText>[]) List<ChapterText> chapters,
    @Default(<PhotoCaption>[]) List<PhotoCaption> captions,
    @Default('') String backCover,
  }) = _CaptionSet;

  factory CaptionSet.fromJson(Map<String, Object?> json) =>
      _$CaptionSetFromJson(json);

  Map<String, String> get captionByPhoto => {
    for (final c in captions) c.photoId: c.text,
  };

  ChapterText? chapter(String id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }
}
