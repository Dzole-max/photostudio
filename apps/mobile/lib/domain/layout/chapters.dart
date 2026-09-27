import '../model/album.dart';
import '../spec/book_strings.dart';

/// A chapter and the (time-ordered) photos that belong to it.
class ChapterPlan {
  ChapterPlan(this.chapter, this.photoIds);

  Chapter chapter;
  final List<String> photoIds;
}

/// Wedding time-of-day buckets (wall-clock hours).
const _weddingBuckets = [(0, 14), (14, 16.5), (16.5, 19), (19, 24.1)];

/// Photos included in the book, oldest first (undated photos last).
List<PhotoRef> includedPhotos(Map<String, PhotoRef> photos) {
  final list = photos.values.where((p) => !p.isExcluded && !p.artwork).toList();
  list.sort((a, b) {
    final ta = a.takenAt, tb = b.takenAt;
    if (ta == null && tb == null) return a.id.compareTo(b.id);
    if (ta == null) return 1;
    if (tb == null) return -1;
    final c = ta.compareTo(tb);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}

DateTime _day(DateTime t) => DateTime.utc(t.year, t.month, t.day);

DateRange? _range(List<PhotoRef> ps) {
  final times = ps.map((p) => p.takenAt).whereType<DateTime>().toList()..sort();
  if (times.isEmpty) return null;
  return DateRange(start: times.first, end: times.last);
}

/// Splits photos into chapters (section 7.7 step 1). Timestamps are
/// wall-clock times of the camera stored as UTC.
List<ChapterPlan> planChapters(
  Map<String, PhotoRef> photos,
  Occasion occasion,
  BookStrings strings,
) {
  final sorted = includedPhotos(photos);
  if (sorted.isEmpty) return [];
  final groups = <List<PhotoRef>>[];
  final titles = <String>[];
  final places = <(String?, String?, double?, double?)>[];

  switch (occasion) {
    case Occasion.travel:
      // Contiguous runs of the same place; long runs are split per day.
      final runs = <List<PhotoRef>>[];
      for (final p in sorted) {
        final key = p.placeName;
        if (runs.isEmpty ||
            (key != null &&
                runs.last.last.placeName != null &&
                runs.last.last.placeName != key)) {
          runs.add([p]);
        } else {
          runs.last.add(p);
        }
      }
      for (final run in runs) {
        final place = run.firstWhere(
          (p) => p.placeName != null,
          orElse: () => run.first,
        );
        final days = <DateTime, List<PhotoRef>>{};
        for (final p in run) {
          days
              .putIfAbsent(
                p.takenAt == null ? DateTime.utc(0) : _day(p.takenAt!),
                () => [],
              )
              .add(p);
        }
        final placeName = place.placeName;
        final lat = _avg(run.map((p) => p.lat));
        final lng = _avg(run.map((p) => p.lng));
        if (days.length > 1 && run.length > 24 && placeName != null) {
          var n = 1;
          for (final d in days.values) {
            groups.add(d);
            titles.add(strings.placeDay(placeName, n++));
            places.add((placeName, place.placeId, lat, lng));
          }
        } else {
          groups.add(run);
          titles.add(
            placeName ??
                (run.first.takenAt == null
                    ? strings.chapter(groups.length)
                    : strings.dateLong(run.first.takenAt!)),
          );
          places.add((placeName, place.placeId, lat, lng));
        }
      }
    case Occasion.wedding:
      final names = [
        strings.gettingReady,
        strings.ceremony,
        strings.portraits,
        strings.party,
      ];
      final buckets = List.generate(4, (_) => <PhotoRef>[]);
      for (final p in sorted) {
        final t = p.takenAt;
        final hour = t == null ? 12.0 : t.hour + t.minute / 60;
        final i = _weddingBuckets.indexWhere(
          (b) => hour >= b.$1 && hour < b.$2,
        );
        buckets[i < 0 ? 3 : i].add(p);
      }
      // Merge tiny buckets into their neighbour.
      for (var i = 0; i < 4; i++) {
        if (buckets[i].isEmpty) continue;
        if (buckets[i].length < 3 &&
            buckets.where((b) => b.isNotEmpty).length > 1) {
          final target = i > 0 && buckets.sublist(0, i).any((b) => b.isNotEmpty)
              ? buckets.sublist(0, i).lastIndexWhere((b) => b.isNotEmpty)
              : buckets.indexWhere((b) => b.isNotEmpty, i + 1);
          if (target >= 0) {
            buckets[target].addAll(buckets[i]);
            buckets[target].sort(
              (a, b) => (a.takenAt ?? DateTime.utc(0)).compareTo(
                b.takenAt ?? DateTime.utc(0),
              ),
            );
            buckets[i] = [];
            continue;
          }
        }
      }
      for (var i = 0; i < 4; i++) {
        if (buckets[i].isEmpty) continue;
        groups.add(buckets[i]);
        titles.add(names[i]);
        places.add((null, null, null, null));
      }
    case Occasion.family || Occasion.baby:
      final months = <String, List<PhotoRef>>{};
      for (final p in sorted) {
        final t = p.takenAt;
        months
            .putIfAbsent(t == null ? '' : '${t.year}-${t.month}', () => [])
            .add(p);
      }
      for (final g in months.values) {
        groups.add(g);
        final t = g.first.takenAt;
        titles.add(
          t == null
              ? strings.chapter(groups.length)
              : strings.monthYearTitle(t),
        );
        places.add((null, null, null, null));
      }
    case Occasion.birthday || Occasion.other:
      final days = <DateTime, List<PhotoRef>>{};
      for (final p in sorted) {
        days
            .putIfAbsent(
              p.takenAt == null ? DateTime.utc(0) : _day(p.takenAt!),
              () => [],
            )
            .add(p);
      }
      for (final g in days.values) {
        groups.add(g);
        final t = g.first.takenAt;
        titles.add(
          t == null ? strings.chapter(groups.length) : strings.dateLong(t),
        );
        places.add((null, null, null, null));
      }
  }

  return [
    for (var i = 0; i < groups.length; i++)
      ChapterPlan(
        Chapter(
          id: 'ch${i + 1}',
          title: titles[i],
          placeName: places[i].$1,
          placeId: places[i].$2,
          lat: places[i].$3,
          lng: places[i].$4,
          dateRange: _range(groups[i]),
        ),
        [for (final p in groups[i]) p.id],
      ),
  ];
}

double? _avg(Iterable<double?> values) {
  final v = values.whereType<double>().toList();
  if (v.isEmpty) return null;
  return v.reduce((a, b) => a + b) / v.length;
}
