import 'dart:math' as math;

import '../geo/geo_data.dart';
import '../model/album.dart';
import '../model/captions.dart';
import '../spec/book_strings.dart';
import 'caption_request.dart';

/// Offline caption writer used by the fake provider: localised templates for
/// all six languages, following the same rules as the real prompt
/// (supabase/functions/ai-captions/prompt.ts): short, the user's own names
/// and words, no invented facts, captions on roughly 30 % of photos.
class FakeCaptionWriter {
  FakeCaptionWriter({this.geo});

  final GeoData? geo;

  CaptionSet write(CaptionRequest r) {
    final lang = BookStrings.supported.contains(r.language) ? r.language : 'en';
    final s = BookStrings(lang);
    final p = _phrases[lang]!;
    final tone = r.story.tone;

    String placeName(String? name, String? placeId) {
      if (placeId != null && geo != null) {
        for (final g in geo!.places) {
          if (g.id == placeId) return g.nameIn(lang);
        }
      }
      return name ?? '';
    }

    final allPhotos = [
      for (final c in r.chapters)
        for (final id in c.photoIds) r.photos[id],
    ].whereType<PhotoRef>().toList();
    final times = allPhotos.map((x) => x.takenAt).whereType<DateTime>().toList()
      ..sort();
    final start = r.story.eventDate ?? (times.isEmpty ? null : times.first);
    final place = r.story.place?.trim().isNotEmpty == true
        ? r.story.place!.trim()
        : (r.destination ??
              placeName(
                r.chapters.firstOrNull?.chapter.placeName,
                r.chapters.firstOrNull?.chapter.placeId,
              ));
    final names = r.story.names?.trim();

    // Title and subtitle.
    String title;
    var subtitle = '';
    switch (r.occasion) {
      case Occasion.wedding:
        title = names?.isNotEmpty == true ? names! : s.ourWedding;
        subtitle = [
          if (start != null) s.dateLong(start),
          if (place.isNotEmpty) place,
        ].join(' · ');
      case Occasion.travel:
        final trip = r.story.title?.trim();
        title = trip?.isNotEmpty == true
            ? trip!.replaceAll(RegExp(r'\s*\d{4}$'), '')
            : (place.isEmpty ? s.chapter(1) : place);
        subtitle = start == null ? '' : s.monthYearTitle(start);
      case Occasion.baby:
        title = names?.isNotEmpty == true
            ? s.firstYear(names!)
            : (r.story.title ?? '');
        subtitle = start == null ? '' : s.dateLong(start);
      case Occasion.birthday:
        title = r.story.title?.trim().isNotEmpty == true
            ? r.story.title!.trim()
            : (names ?? '');
        subtitle = start == null ? '' : s.dateLong(start);
      case Occasion.family:
        title = r.story.title?.trim().isNotEmpty == true
            ? r.story.title!.trim()
            : s.ourYear(start?.year ?? DateTime.now().year);
        subtitle = names ?? '';
      case Occasion.other:
        title = r.story.title?.trim().isNotEmpty == true
            ? r.story.title!.trim()
            : (place.isNotEmpty ? place : s.chapter(1));
        subtitle = start == null ? '' : s.monthYearTitle(start);
    }

    // Chapters.
    final chapters = <ChapterText>[];
    for (var ci = 0; ci < r.chapters.length; ci++) {
      final plan = r.chapters[ci];
      final c = plan.chapter;
      final chapterPlace = placeName(c.placeName, c.placeId);
      final photos = [for (final id in plan.photoIds) r.photos[id]]
          .whereType<PhotoRef>()
          .toList();
      final list = _nounList(photos, p, bare: true);
      var chapterTitle = c.title;
      if (r.occasion == Occasion.travel &&
          c.placeName != null &&
          chapterTitle == c.placeName) {
        chapterTitle = chapterPlace;
      }
      String intro;
      if (tone == Tone.minimal) {
        intro = '';
      } else if (r.occasion == Occasion.wedding) {
        final kind = [
          s.gettingReady,
          s.ceremony,
          s.portraits,
          s.party,
        ].indexOf(c.title);
        final t = kind < 0 ? '' : p.wedding[kind];
        intro = t
            .replaceAll('{place}', place)
            .replaceAll(
              '{names}',
              names?.isNotEmpty == true ? names! : p.theCouple,
            );
        if (intro.contains('{place}') ||
            (place.isEmpty && t.contains('{place}'))) {
          intro = '';
        }
      } else if (list.isNotEmpty && chapterPlace.isNotEmpty) {
        final t = switch (tone) {
          Tone.poetic => p.introPoetic,
          Tone.playful => p.introPlayful,
          _ => p.introWarm,
        };
        intro = t
            .replaceAll('{place}', chapterPlace)
            .replaceAll('{list}', list);
      } else if (list.isNotEmpty) {
        intro = _cap(list);
        intro = '$intro.';
      } else {
        intro = '';
      }
      chapters.add(
        ChapterText(
          id: c.id,
          title: chapterTitle,
          intro: _limitWords(intro, 30),
        ),
      );
    }

    // Captions on ~30 % of photos: the best in each chapter.
    final captions = <PhotoCaption>[];
    final tripStart = times.isEmpty
        ? null
        : DateTime.utc(times.first.year, times.first.month, times.first.day);
    for (final plan in r.chapters) {
      final photos = [for (final id in plan.photoIds) r.photos[id]]
          .whereType<PhotoRef>()
          .toList();
      final quota = (photos.length * 0.3).round();
      final best = [...photos]
        ..sort((a, b) => b.quality.overall.compareTo(a.quality.overall));
      final chosen = best.take(quota).toList()
        ..sort(
          (a, b) => (a.takenAt ?? DateTime.utc(0)).compareTo(
            b.takenAt ?? DateTime.utc(0),
          ),
        );
      final chapterPlace = placeName(
        plan.chapter.placeName,
        plan.chapter.placeId,
      );
      for (var i = 0; i < chosen.length; i++) {
        final photo = chosen[i];
        final text = _caption(
          photo,
          i,
          r.occasion,
          tone,
          chapterPlace,
          p,
          s,
          tripStart,
        );
        if (text.isNotEmpty) {
          captions.add(
            PhotoCaption(photoId: photo.id, text: _limitWords(text, 12)),
          );
        }
      }
    }

    final moment = r.story.moment?.trim();
    final back = moment != null && moment.isNotEmpty
        ? '“$moment”'
        : [title, subtitle].where((e) => e.isNotEmpty).join(' · ');

    return CaptionSet(
      title: title,
      subtitle: subtitle,
      chapters: chapters,
      captions: captions,
      backCover: back,
    );
  }

  String _caption(
    PhotoRef photo,
    int index,
    Occasion occasion,
    Tone tone,
    String place,
    _Phrases p,
    BookStrings s,
    DateTime? tripStart,
  ) {
    final noun = _topNoun(photo, p, bare: false);
    final t = photo.takenAt;
    if (occasion == Occasion.wedding) {
      if (noun == null) return '';
      if (tone == Tone.minimal || t == null) return _cap(noun);
      return '${_cap(noun)}, ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    final variant = index % 3;
    if (place.isNotEmpty &&
        variant == 0 &&
        tripStart != null &&
        t != null &&
        occasion == Occasion.travel) {
      final day =
          DateTime.utc(t.year, t.month, t.day).difference(tripStart).inDays + 1;
      return s.placeDay(place, day);
    }
    if (place.isNotEmpty && variant == 1 && t != null) {
      final tod = t.hour < 12 ? 0 : (t.hour < 17 ? 1 : (t.hour < 21 ? 2 : 3));
      return p.timeOfDay[tod].replaceAll('{place}', place);
    }
    if (noun != null && place.isNotEmpty && tone != Tone.minimal) {
      return p.nounInPlace
          .replaceAll('{noun}', _cap(noun))
          .replaceAll('{place}', place);
    }
    if (noun != null) return _cap(noun);
    return place;
  }

  String? _topNoun(PhotoRef photo, _Phrases p, {required bool bare}) {
    final labels = [...photo.labels]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    for (final l in labels) {
      final entry = p.nouns[_labelKey[l.text.toLowerCase()]];
      if (entry != null) return bare ? entry.$2 : entry.$1;
    }
    return null;
  }

  /// Up to three distinct nouns from the chapter's labels, joined naturally.
  String _nounList(List<PhotoRef> photos, _Phrases p, {required bool bare}) {
    final counts = <String, double>{};
    for (final ph in photos) {
      for (final l in ph.labels) {
        final key = _labelKey[l.text.toLowerCase()];
        if (key == null || !p.nouns.containsKey(key)) continue;
        counts[key] = (counts[key] ?? 0) + l.confidence;
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final words = [
      for (final k in keys.take(3)) bare ? p.nouns[k]!.$2 : p.nouns[k]!.$1,
    ];
    if (words.isEmpty) return '';
    if (words.length == 1) return words.first;
    return '${words.sublist(0, words.length - 1).join(', ')} ${p.and} ${words.last}';
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _limitWords(String s, int max) {
  final words = s.trim().split(RegExp(r'\s+'));
  if (words.length <= max) return s.trim();
  return '${words.take(max).join(' ').replaceAll(RegExp(r'[,;:]$'), '')}…';
}

/// Detected label → phrase key.
const Map<String, String> _labelKey = {
  'beach': 'beach',
  'sea': 'sea',
  'ocean': 'sea',
  'building': 'streets',
  'street': 'streets',
  'door': 'streets',
  'market': 'market',
  'food': 'market',
  'boat': 'boats',
  'forest': 'forest',
  'tree': 'forest',
  'animal': 'animals',
  'monkey': 'animals',
  'sky': 'light',
  'night': 'evening',
  'lake': 'lake',
  'water': 'water',
  'fish': 'water',
  'sand': 'sand',
  'dance': 'dance',
  'cake': 'cake',
  'bouquet': 'flowers',
  'flower': 'flowers',
  'jewelry': 'rings',
  'suit': 'suit',
  'gown': 'dress',
  'veil': 'dress',
  'bride': 'dress',
  'crowd': 'everyone',
  'party': 'evening',
  'drink': 'toast',
  'ceremony': 'ceremony',
  'table': 'evening',
};

class _Phrases {
  const _Phrases({
    required this.nouns,
    required this.and,
    required this.nounInPlace,
    required this.timeOfDay,
    required this.introWarm,
    required this.introPoetic,
    required this.introPlayful,
    required this.wedding,
    required this.theCouple,
  });

  /// key → (with article, bare for lists)
  final Map<String, (String, String)> nouns;
  final String and;
  final String nounInPlace;
  final List<String> timeOfDay;
  final String introWarm;
  final String introPoetic;
  final String introPlayful;

  /// Getting ready, ceremony, portraits, party.
  final List<String> wedding;
  final String theCouple;
}

final Map<String, _Phrases> _phrases = {
  'en': const _Phrases(
    nouns: {
      'beach': ('the beach', 'beach'),
      'sea': ('the sea', 'sea'),
      'streets': ('the old streets', 'old streets'),
      'market': ('the market', 'markets'),
      'boats': ('the boats', 'boats'),
      'forest': ('the forest', 'forest'),
      'animals': ('a curious visitor', 'wildlife'),
      'light': ('the evening light', 'evening light'),
      'evening': ('the evening', 'evenings'),
      'lake': ('the lake', 'the lake'),
      'water': ('the water', 'water'),
      'sand': ('the sand', 'sand'),
      'dance': ('on the dance floor', 'dancing'),
      'cake': ('the cake', 'cake'),
      'flowers': ('the flowers', 'flowers'),
      'rings': ('the rings', 'rings'),
      'suit': ('the suit', 'the suit'),
      'dress': ('the dress', 'the dress'),
      'everyone': ('everyone together', 'friends'),
      'toast': ('a toast', 'toasts'),
      'ceremony': ('the ceremony', 'the ceremony'),
    },
    and: 'and',
    nounInPlace: '{noun} in {place}',
    timeOfDay: [
      '{place} in the morning',
      '{place} in the afternoon',
      '{place} in the evening',
      '{place} at night',
    ],
    introWarm: 'Our days in {place}: {list}.',
    introPoetic: 'In {place}, the days were made of {list}.',
    introPlayful: '{place}, as promised: {list}.',
    wedding: [
      'The morning in {place}, before everything began.',
      '{names} said yes in {place}.',
      'Just the two of us, and the light over {place}.',
      'Then the music started, and everyone joined in.',
    ],
    theCouple: 'We',
  ),
  'de': const _Phrases(
    nouns: {
      'beach': ('der Strand', 'Strand'),
      'sea': ('das Meer', 'Meer'),
      'streets': ('die alten Gassen', 'alte Gassen'),
      'market': ('der Markt', 'Märkte'),
      'boats': ('die Boote', 'Boote'),
      'forest': ('der Wald', 'Wald'),
      'animals': ('ein neugieriger Besucher', 'Tiere'),
      'light': ('das Abendlicht', 'Abendlicht'),
      'evening': ('der Abend', 'lange Abende'),
      'lake': ('der See', 'der See'),
      'water': ('das Wasser', 'Wasser'),
      'sand': ('der Sand', 'Sand'),
      'dance': ('auf der Tanzfläche', 'Tanz'),
      'cake': ('die Torte', 'Torte'),
      'flowers': ('die Blumen', 'Blumen'),
      'rings': ('die Ringe', 'Ringe'),
      'suit': ('der Anzug', 'der Anzug'),
      'dress': ('das Kleid', 'das Kleid'),
      'everyone': ('alle zusammen', 'Freunde'),
      'toast': ('ein Toast', 'Toasts'),
      'ceremony': ('die Trauung', 'die Trauung'),
    },
    and: 'und',
    nounInPlace: '{noun} in {place}',
    timeOfDay: [
      '{place} am Morgen',
      '{place} am Nachmittag',
      '{place} am Abend',
      '{place} bei Nacht',
    ],
    introWarm: 'Unsere Tage in {place}: {list}.',
    introPoetic: 'In {place} bestanden die Tage aus {list}.',
    introPlayful: '{place}, wie versprochen: {list}.',
    wedding: [
      'Der Morgen in {place}, bevor alles begann.',
      '{names} haben in {place} Ja gesagt.',
      'Nur wir zwei und das Licht über {place}.',
      'Dann begann die Musik, und alle machten mit.',
    ],
    theCouple: 'Wir',
  ),
  'es': const _Phrases(
    nouns: {
      'beach': ('la playa', 'playa'),
      'sea': ('el mar', 'mar'),
      'streets': ('las calles antiguas', 'calles antiguas'),
      'market': ('el mercado', 'mercados'),
      'boats': ('los barcos', 'barcos'),
      'forest': ('el bosque', 'bosque'),
      'animals': ('un visitante curioso', 'animales'),
      'light': ('la luz de la tarde', 'luz de la tarde'),
      'evening': ('la noche', 'noches largas'),
      'lake': ('el lago', 'el lago'),
      'water': ('el agua', 'agua'),
      'sand': ('la arena', 'arena'),
      'dance': ('en la pista de baile', 'baile'),
      'cake': ('la tarta', 'tarta'),
      'flowers': ('las flores', 'flores'),
      'rings': ('los anillos', 'anillos'),
      'suit': ('el traje', 'el traje'),
      'dress': ('el vestido', 'el vestido'),
      'everyone': ('todos juntos', 'amigos'),
      'toast': ('un brindis', 'brindis'),
      'ceremony': ('la ceremonia', 'la ceremonia'),
    },
    and: 'y',
    nounInPlace: '{noun} en {place}',
    timeOfDay: [
      '{place} por la mañana',
      '{place} por la tarde',
      '{place} al atardecer',
      '{place} de noche',
    ],
    introWarm: 'Nuestros días en {place}: {list}.',
    introPoetic: 'En {place}, los días estaban hechos de {list}.',
    introPlayful: '{place}, tal como prometía: {list}.',
    wedding: [
      'La mañana en {place}, antes de que todo empezara.',
      '{names} se dieron el sí en {place}.',
      'Solo nosotros dos y la luz sobre {place}.',
      'Luego empezó la música y todos se unieron.',
    ],
    theCouple: 'Nosotros',
  ),
  'fr': const _Phrases(
    nouns: {
      'beach': ('la plage', 'plage'),
      'sea': ('la mer', 'mer'),
      'streets': ('les vieilles ruelles', 'vieilles ruelles'),
      'market': ('le marché', 'marchés'),
      'boats': ('les bateaux', 'bateaux'),
      'forest': ('la forêt', 'forêt'),
      'animals': ('un visiteur curieux', 'animaux'),
      'light': ('la lumière du soir', 'lumière du soir'),
      'evening': ('la soirée', 'longues soirées'),
      'lake': ('le lac', 'le lac'),
      'water': ('l’eau', 'eau'),
      'sand': ('le sable', 'sable'),
      'dance': ('sur la piste de danse', 'danse'),
      'cake': ('le gâteau', 'gâteau'),
      'flowers': ('les fleurs', 'fleurs'),
      'rings': ('les alliances', 'alliances'),
      'suit': ('le costume', 'le costume'),
      'dress': ('la robe', 'la robe'),
      'everyone': ('tout le monde réuni', 'amis'),
      'toast': ('un toast', 'toasts'),
      'ceremony': ('la cérémonie', 'la cérémonie'),
    },
    and: 'et',
    nounInPlace: '{noun} à {place}',
    timeOfDay: [
      '{place} le matin',
      '{place} l’après-midi',
      '{place} le soir',
      '{place} la nuit',
    ],
    introWarm: 'Nos jours à {place} : {list}.',
    introPoetic: 'À {place}, les jours étaient faits de {list}.',
    introPlayful: '{place}, comme promis : {list}.',
    wedding: [
      'Le matin à {place}, avant que tout commence.',
      '{names} se sont dit oui à {place}.',
      'Rien que nous deux, et la lumière sur {place}.',
      'Puis la musique a commencé, et tout le monde a suivi.',
    ],
    theCouple: 'Nous',
  ),
  'it': const _Phrases(
    nouns: {
      'beach': ('la spiaggia', 'spiaggia'),
      'sea': ('il mare', 'mare'),
      'streets': ('le vecchie strade', 'vecchie strade'),
      'market': ('il mercato', 'mercati'),
      'boats': ('le barche', 'barche'),
      'forest': ('la foresta', 'foresta'),
      'animals': ('un visitatore curioso', 'animali'),
      'light': ('la luce della sera', 'luce della sera'),
      'evening': ('la serata', 'lunghe serate'),
      'lake': ('il lago', 'il lago'),
      'water': ('l’acqua', 'acqua'),
      'sand': ('la sabbia', 'sabbia'),
      'dance': ('sulla pista da ballo', 'balli'),
      'cake': ('la torta', 'torta'),
      'flowers': ('i fiori', 'fiori'),
      'rings': ('gli anelli', 'anelli'),
      'suit': ('l’abito', 'l’abito'),
      'dress': ('l’abito da sposa', 'l’abito da sposa'),
      'everyone': ('tutti insieme', 'amici'),
      'toast': ('un brindisi', 'brindisi'),
      'ceremony': ('la cerimonia', 'la cerimonia'),
    },
    and: 'e',
    nounInPlace: '{noun} a {place}',
    timeOfDay: [
      '{place} al mattino',
      '{place} nel pomeriggio',
      '{place} la sera',
      '{place} di notte',
    ],
    introWarm: 'I nostri giorni a {place}: {list}.',
    introPoetic: 'A {place}, i giorni erano fatti di {list}.',
    introPlayful: '{place}, come promesso: {list}.',
    wedding: [
      'La mattina a {place}, prima che tutto iniziasse.',
      '{names} si sono detti sì a {place}.',
      'Solo noi due e la luce su {place}.',
      'Poi è partita la musica e tutti si sono uniti.',
    ],
    theCouple: 'Noi',
  ),
  'mk': const _Phrases(
    nouns: {
      'beach': ('плажата', 'плажа'),
      'sea': ('морето', 'море'),
      'streets': ('старите улици', 'стари улици'),
      'market': ('пазарот', 'пазари'),
      'boats': ('чамците', 'чамци'),
      'forest': ('шумата', 'шума'),
      'animals': ('љубопитен посетител', 'животни'),
      'light': ('вечерната светлина', 'вечерна светлина'),
      'evening': ('вечерта', 'долги вечери'),
      'lake': ('езерото', 'езерото'),
      'water': ('водата', 'вода'),
      'sand': ('песокот', 'песок'),
      'dance': ('на подиумот за танц', 'танц'),
      'cake': ('тортата', 'торта'),
      'flowers': ('цвеќињата', 'цвеќиња'),
      'rings': ('прстените', 'прстени'),
      'suit': ('оделото', 'оделото'),
      'dress': ('фустанот', 'фустанот'),
      'everyone': ('сите заедно', 'пријатели'),
      'toast': ('здравица', 'здравици'),
      'ceremony': ('венчавката', 'венчавката'),
    },
    and: 'и',
    nounInPlace: '{noun} во {place}',
    timeOfDay: [
      '{place} наутро',
      '{place} попладне',
      '{place} навечер',
      '{place} ноќе',
    ],
    introWarm: 'Нашите денови во {place}: {list}.',
    introPoetic: 'Во {place}, деновите беа од {list}.',
    introPlayful: '{place}, како што ветуваше: {list}.',
    wedding: [
      'Утрото во {place}, пред сè да почне.',
      '{names} си рекоа „да“ во {place}.',
      'Само ние двајца и светлината над {place}.',
      'Потоа почна музиката и сите се приклучија.',
    ],
    theCouple: 'Ние',
  ),
};

/// Deterministic helper for tests: how many captions the writer targets.
int captionQuota(int photos) => math.max(0, (photos * 0.3).round());
