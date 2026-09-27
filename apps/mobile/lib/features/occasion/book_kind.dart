import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';

/// The six occasion tiles on Home, in their fixed order. "Year" is the
/// whole-year book ([Occasion.family] in the domain); "Family" is the
/// open-ended family book ([Occasion.other]).
enum BookKind {
  wedding(
    Occasion.wedding,
    OccasionTone.wedding,
    Icons.favorite_outline_rounded,
  ),
  travel(Occasion.travel, OccasionTone.travel, Icons.flight_takeoff_rounded),
  baby(Occasion.baby, OccasionTone.baby, Icons.child_friendly_outlined),
  birthday(Occasion.birthday, OccasionTone.birthday, Icons.cake_outlined),
  year(Occasion.family, OccasionTone.year, Icons.calendar_month_outlined),
  family(Occasion.other, OccasionTone.family, Icons.diversity_1_outlined);

  const BookKind(this.occasion, this.tone, this.icon);

  final Occasion occasion;
  final OccasionTone tone;
  final IconData icon;

  static BookKind? byName(String name) =>
      BookKind.values.where((k) => k.name == name).firstOrNull;

  String label(AppLocalizations l) => switch (this) {
    wedding => l.kindWedding,
    travel => l.kindTravel,
    baby => l.kindBaby,
    birthday => l.kindBirthday,
    year => l.kindYear,
    family => l.kindFamily,
  };

  String hint(AppLocalizations l) => switch (this) {
    wedding => l.kindWeddingHint,
    travel => l.kindTravelHint,
    baby => l.kindBabyHint,
    birthday => l.kindBirthdayHint,
    year => l.kindYearHint,
    family => l.kindFamilyHint,
  };

  /// "Wedding book", "Travel book"…
  String title(AppLocalizations l) => switch (this) {
    wedding => l.kindWeddingTitle,
    travel => l.kindTravelTitle,
    baby => l.kindBabyTitle,
    birthday => l.kindBirthdayTitle,
    year => l.kindYearTitle,
    family => l.kindFamilyTitle,
  };

  /// One line about what the book holds.
  String about(AppLocalizations l) => switch (this) {
    wedding => l.kindWeddingAbout,
    travel => l.kindTravelAbout,
    baby => l.kindBabyAbout,
    birthday => l.kindBirthdayAbout,
    year => l.kindYearAbout,
    family => l.kindFamilyAbout,
  };

  /// "Choose wedding photos"…
  String action(AppLocalizations l) => switch (this) {
    wedding => l.kindWeddingAction,
    travel => l.kindTravelAction,
    baby => l.kindBabyAction,
    birthday => l.kindBirthdayAction,
    year => l.kindYearAction,
    family => l.kindFamilyAction,
  };
}
