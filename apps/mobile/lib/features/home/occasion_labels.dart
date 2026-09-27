import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../domain/model/album.dart';

String occasionLabel(AppLocalizations l, Occasion o) => switch (o) {
  Occasion.wedding => l.occasionWedding,
  Occasion.travel => l.occasionTravel,
  Occasion.baby => l.occasionBaby,
  Occasion.birthday => l.occasionBirthday,
  Occasion.family => l.occasionFamily,
  Occasion.other => l.occasionOther,
};

IconData occasionIcon(Occasion o) => switch (o) {
  Occasion.wedding => Icons.favorite_outline_rounded,
  Occasion.travel => Icons.flight_takeoff_rounded,
  Occasion.baby => Icons.child_friendly_outlined,
  Occasion.birthday => Icons.cake_outlined,
  Occasion.family => Icons.calendar_month_outlined,
  Occasion.other => Icons.auto_awesome_outlined,
};
