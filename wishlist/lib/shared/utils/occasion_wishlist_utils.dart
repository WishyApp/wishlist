import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/utils/string_utils.dart';

final _wordPattern = RegExp('[a-z]+|[0-9]+');
final _yearPattern = RegExp(r'^20[0-9]{2}$');

/// Finds the wishlist an occasion (Christmas, ...) refers to, from its name.
///
/// Rules:
/// 1. The name is normalized ([normalizeString]) then split with
///    `[a-z]+|[0-9]+`: "Noël2026" gives `noel` and `2026`.
/// 2. A wishlist matches when one of its words is exactly one of [keywords]
///    ("Noëlle" gives `noelle`: no match).
/// 3. Years are 4-digit numbers between 2000 and 2099. If the name contains
///    some and none equals the year of [occasionDate], the wishlist is
///    discarded.
/// 4. Choice: exactly one wishlist with the right year wins; otherwise exactly
///    one wishlist without any year wins; otherwise null.
Wishlist? findOccasionWishlist({
  required List<Wishlist> wishlists,
  required List<String> keywords,
  required DateTime occasionDate,
}) {
  final normalizedKeywords = keywords.map(normalizeString).toSet();
  final withRightYear = <Wishlist>[];
  final withoutYear = <Wishlist>[];

  for (final wishlist in wishlists) {
    final words = _wordPattern
        .allMatches(normalizeString(wishlist.name))
        .map((match) => match.group(0)!)
        .toList();
    if (!words.any(normalizedKeywords.contains)) {
      continue;
    }

    final years = words.where(_yearPattern.hasMatch).map(int.parse).toList();
    if (years.isEmpty) {
      withoutYear.add(wishlist);
    } else if (years.contains(occasionDate.year)) {
      withRightYear.add(wishlist);
    }
  }

  if (withRightYear.length == 1) {
    return withRightYear.single;
  }
  if (withRightYear.isEmpty && withoutYear.length == 1) {
    return withoutYear.single;
  }
  return null;
}
