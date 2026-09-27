import '../model/album.dart';

enum OrnamentStyle {
  goldKeylines,
  leafSprig,
  goldFrame,
  compassTick,
  passportStamp,
  contourLines,
  softRoundFrames,
  confettiDots,
  deckleCorners,
  none,
}

/// A book theme: palette + fonts + ornaments + default cover + template
/// weights (section 5.1).
class BookTheme {
  const BookTheme({
    required this.id,
    required this.occasion,
    required this.background,
    required this.text,
    required this.accent,
    required this.displayFont,
    required this.bodyFont,
    required this.metaFont,
    required this.ornament,
    required this.defaultCover,
    this.displayWeight = 500,
    this.displayCaps = false,
    this.displayTrackingPct = 0,
    this.playful = false,
    this.templateWeights = const {},
  });

  final String id;
  final Occasion occasion;
  final String background;
  final String text;
  final String accent;
  final String displayFont;
  final String bodyFont;
  final String metaFont;
  final int displayWeight;
  final bool displayCaps;
  final double displayTrackingPct;
  final OrnamentStyle ornament;
  final String defaultCover;
  final bool playful;

  /// Multipliers applied to template scores (1 = neutral).
  final Map<String, double> templateWeights;

  bool get isDark => background == '#1E2433';

  static BookTheme byId(String id) =>
      kBookThemes.firstWhere((t) => t.id == id, orElse: () => kBookThemes.last);

  /// Themes offered for an occasion, recommended first.
  static List<BookTheme> forOccasion(Occasion o) {
    final ids = switch (o) {
      Occasion.wedding => [
        'wedding_ivory',
        'wedding_blush',
        'wedding_midnight',
      ],
      Occasion.travel => [
        'travel_lagoon',
        'travel_terracotta',
        'travel_alpine',
      ],
      Occasion.baby => ['baby_cloud', 'minimal_gallery', 'family_heirloom'],
      Occasion.birthday => [
        'birthday_confetti',
        'baby_cloud',
        'minimal_gallery',
      ],
      Occasion.family => [
        'family_heirloom',
        'minimal_gallery',
        'travel_lagoon',
      ],
      Occasion.other => ['minimal_gallery', 'family_heirloom', 'travel_lagoon'],
    };
    return [for (final id in ids) byId(id)];
  }
}

const List<BookTheme> kBookThemes = [
  BookTheme(
    id: 'wedding_ivory',
    occasion: Occasion.wedding,
    background: '#FBF8F2',
    text: '#2B2622',
    accent: '#B8955A',
    displayFont: 'CormorantGaramond',
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.goldKeylines,
    defaultCover: 'cover_wedding_monogram',
    templateWeights: {'hero_bordered': 1.2, 'two_side_by_side': 1.1},
  ),
  BookTheme(
    id: 'wedding_blush',
    occasion: Occasion.wedding,
    background: '#F4E7E1',
    text: '#3B2E2A',
    accent: '#C98F7E',
    displayFont: 'CormorantGaramond',
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.leafSprig,
    defaultCover: 'cover_wedding_fullbleed',
    templateWeights: {'hero_centered': 1.2, 'two_offset': 1.1},
  ),
  BookTheme(
    id: 'wedding_midnight',
    occasion: Occasion.wedding,
    background: '#1E2433',
    text: '#F4EFE6',
    accent: '#C9A96A',
    displayFont: 'CormorantGaramond',
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.goldFrame,
    defaultCover: 'cover_wedding_midnight_frame',
    templateWeights: {'full_bleed': 1.15, 'hero_bordered': 1.1},
  ),
  BookTheme(
    id: 'travel_lagoon',
    occasion: Occasion.travel,
    background: '#F3EFE6',
    text: '#173B45',
    accent: '#1F8A8A',
    displayFont: 'Manrope',
    displayWeight: 700,
    displayCaps: true,
    displayTrackingPct: 20,
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.compassTick,
    defaultCover: 'cover_travel_coordinates',
    templateWeights: {'full_bleed': 1.2, 'three_rows': 1.1},
  ),
  BookTheme(
    id: 'travel_terracotta',
    occasion: Occasion.travel,
    background: '#F2E6D8',
    text: '#3A2A20',
    accent: '#C0603A',
    displayFont: 'Manrope',
    displayWeight: 700,
    displayCaps: true,
    displayTrackingPct: 20,
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.passportStamp,
    defaultCover: 'cover_travel_postcard',
    templateWeights: {'photo_with_text_right': 1.15, 'two_offset': 1.1},
  ),
  BookTheme(
    id: 'travel_alpine',
    occasion: Occasion.travel,
    background: '#EEF1EE',
    text: '#22302B',
    accent: '#4E6E5D',
    displayFont: 'Manrope',
    displayWeight: 700,
    displayCaps: true,
    displayTrackingPct: 20,
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.contourLines,
    defaultCover: 'cover_travel_mapstamp',
    templateWeights: {'hero_bordered': 1.15, 'three_rows': 1.15},
  ),
  BookTheme(
    id: 'baby_cloud',
    occasion: Occasion.baby,
    background: '#F5F3EF',
    text: '#3A3A44',
    accent: '#9DB4C9',
    displayFont: 'Nunito',
    displayWeight: 700,
    bodyFont: 'Nunito',
    metaFont: 'Nunito',
    ornament: OrnamentStyle.softRoundFrames,
    defaultCover: 'cover_baby_cloud',
    playful: true,
    templateWeights: {'polaroid_scatter': 1.1, 'hero_centered': 1.15},
  ),
  BookTheme(
    id: 'birthday_confetti',
    occasion: Occasion.birthday,
    background: '#FFF8EE',
    text: '#26221E',
    accent: '#E0694A',
    displayFont: 'Nunito',
    displayWeight: 800,
    bodyFont: 'Nunito',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.confettiDots,
    defaultCover: 'cover_birthday_confetti',
    playful: true,
    templateWeights: {'polaroid_scatter': 1.2},
  ),
  BookTheme(
    id: 'family_heirloom',
    occasion: Occasion.family,
    background: '#F1EBE0',
    text: '#2E2A25',
    accent: '#7A5C3E',
    displayFont: 'CormorantGaramond',
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.deckleCorners,
    defaultCover: 'cover_year_grid',
    templateWeights: {'four_grid': 1.1, 'photo_with_text_below': 1.1},
  ),
  BookTheme(
    id: 'minimal_gallery',
    occasion: Occasion.other,
    background: '#FFFFFF',
    text: '#111111',
    accent: '#111111',
    displayFont: 'Manrope',
    displayWeight: 600,
    bodyFont: 'Lora',
    metaFont: 'Manrope',
    ornament: OrnamentStyle.none,
    defaultCover: 'cover_travel_coordinates',
    templateWeights: {'hero_centered': 1.2, 'full_bleed': 1.1},
  ),
];
