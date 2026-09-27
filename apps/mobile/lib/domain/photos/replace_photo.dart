import '../model/album.dart';

/// Replaces photo [oldId] with [replacement] on every page, the cover and
/// the cover slots (e.g. after "Enhance for print"). The replacement is a
/// book photo in its own right, linked to the original by `sourceId`.
/// Crops are normalised, so they carry over unchanged.
Album replacePhoto(Album album, String oldId, PhotoRef replacement) {
  final photo = replacement.copyWith(artwork: false, sourceId: oldId);
  BookPage swap(BookPage p) => p.frames.any((f) => f.photoId == oldId)
      ? p.copyWith(
          frames: [
            for (final f in p.frames)
              f.photoId == oldId ? f.copyWith(photoId: photo.id) : f,
          ],
        )
      : p;
  final photos = {...album.photos, photo.id: photo}..remove(oldId);
  return album.copyWith(
    photos: photos,
    pages: [for (final p in album.pages) swap(p)],
    cover: album.cover.copyWith(
      front: swap(album.cover.front),
      back: swap(album.cover.back),
      slots: album.cover.slots.heroPhotoId == oldId
          ? album.cover.slots.copyWith(heroPhotoId: photo.id)
          : album.cover.slots,
    ),
  );
}
