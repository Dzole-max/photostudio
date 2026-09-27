import 'package:memoria/domain/captions/caption_request.dart';
import 'package:memoria/domain/captions/fake_caption_writer.dart';
import 'package:memoria/domain/layout/chapters.dart';
import 'package:memoria/domain/layout/layout_engine.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/occasion/occasion_rules.dart';
import 'package:memoria/domain/spec/book_format.dart';
import 'package:memoria/domain/spec/book_strings.dart';
import 'package:memoria/domain/spec/spec_data.dart';
import 'package:memoria/domain/theme/book_theme.dart';

import 'domain_fixtures.dart';

final DateTime kTestNow = DateTime.utc(2026, 9, 1, 12);

/// Builds a sample book through the same steps the app uses.
Album buildSampleBook(
  String set, {
  String language = 'en',
  int seed = 1,
  String? formatId,
  String? themeId,
  Map<String, PhotoRef>? photos,
}) {
  final all = photos ?? DomainFixtures.sample(set);
  final wedding = set == 'wedding';
  final suggestion = detectOccasion(
    all.values.toList(),
    geo: DomainFixtures.geo,
    language: language,
  );
  final occasion = suggestion.occasion;
  final story = wedding
      ? StoryAnswers(
          names: 'Aleksandar & Elena',
          eventDate: DateTime.utc(2026, 8, 15),
          place: 'Ohrid',
          moment: 'The quiet minute on the pier before the party',
        )
      : const StoryAnswers(names: 'Mia & Luka', title: 'Zanzibar 2026');
  final plans = planChapters(all, occasion, BookStrings(language));
  final captions = FakeCaptionWriter(geo: DomainFixtures.geo).write(
    CaptionRequest(
      occasion: occasion,
      language: language,
      story: story,
      chapters: plans,
      photos: all,
      destination: suggestion.destination,
    ),
  );
  final theme = BookTheme.byId(
    themeId ?? BookTheme.forOccasion(occasion).first.id,
  );
  final format = BookFormat.byId(
    formatId ??
        (occasion == Occasion.travel
            ? kTravelDefaultFormatId
            : kDefaultFormatId),
  );
  return layoutAlbum(
    LayoutInput(
      albumId: 'sample_$set',
      occasion: occasion,
      theme: theme,
      format: format,
      language: language,
      photos: all,
      plans: plans,
      captions: captions,
      story: story,
      fonts: DomainFixtures.fonts,
      geo: DomainFixtures.geo,
      seed: seed,
      now: kTestNow,
    ),
  );
}
