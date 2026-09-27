import '../model/geometry.dart';
import 'spec_data.dart';

enum Binding { softcover, hardcover, layflat }

enum PageSide { left, right }

/// Printed book format (section 6.3). Data lives in
/// packages/layout_spec/formats.json and is mirrored in spec_data.dart.
class BookFormat {
  const BookFormat({
    required this.id,
    required this.trimWMm,
    required this.trimHMm,
    required this.binding,
    required this.minPages,
    required this.maxPages,
    this.hidden = false,
  });

  final String id;
  final double trimWMm;
  final double trimHMm;
  final Binding binding;
  final int minPages;
  final int maxPages;
  final bool hidden;

  double get aspect => trimWMm / trimHMm;

  RectMm get trim => RectMm(x: 0, y: 0, w: trimWMm, h: trimHMm);

  RectMm get bleedBox => trim.inflate(kBleedMm);

  static BookFormat byId(String id) =>
      kBookFormats.firstWhere((f) => f.id == id, orElse: () => kBookFormats[1]);

  static List<BookFormat> get visible =>
      kBookFormats.where((f) => !f.hidden).toList();

  /// Inner page index 0 is a recto (right-hand) page.
  static PageSide sideOf(int pageIndex) =>
      pageIndex.isEven ? PageSide.right : PageSide.left;

  /// Safe area of an inner page: 10 mm outer edges, 15 mm on the gutter side.
  RectMm safeArea(PageSide side) {
    final left = side == PageSide.right ? kSafeGutterMm : kSafeOuterMm;
    final right = side == PageSide.right ? kSafeOuterMm : kSafeGutterMm;
    return RectMm(
      x: left,
      y: kSafeOuterMm,
      w: trimWMm - left - right,
      h: trimHMm - 2 * kSafeOuterMm,
    );
  }

  /// Gutter x position (mm) on a page of the given side.
  double gutterX(PageSide side) => side == PageSide.right ? 0 : trimWMm;

  /// Clamp a page count into range and make it even.
  int fitPageCount(int n) {
    var c = n.clamp(minPages, maxPages);
    if (c.isOdd) c = c + 1 <= maxPages ? c + 1 : c - 1;
    return c;
  }
}
