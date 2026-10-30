import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/utils/string_utils.dart';

final _wordPattern = RegExp('[a-z]+|[0-9]+');
final _yearPattern = RegExp(r'^20[0-9]{2}$');

/// Finds the wishlist of [userId] that an occasion (Christmas, ...) refers to,
/// from its name.
///
/// Pass the occasion being shown as [occasionDate]: the coming Christmas
/// before December 25, the one just passed during the after-party days.
///
/// Rules:
/// 0. Only open wishlists owned by [userId] are considered.
/// 1. Names and [keywords] are normalized ([normalizeString]) then split with
///    `[a-z]+|[0-9]+`: "Noël2026" gives `noel` and `2026`. A keyword that does
///    not make exactly one word is ignored.
/// 2. A wishlist matches when one of its words is exactly one of the keywords
///    ("Noëlle" gives `noelle`: no match).
/// 3. Years are 4-digit numbers between 2000 and 2099, or 2-digit numbers
///    equal to the year of [occasionDate] or of the previous year modulo 100
///    ("Noël 26"); other 2-digit numbers ("Top 10") are not years. If the name
///    contains years and none is the year of [occasionDate], the wishlist is
///    discarded.
/// 4. Choice: exactly one wishlist with the right year wins; if none has the
///    right year, exactly one wishlist without any year wins; otherwise null
///    (two wishlists with the right year never fall back to one without).
Wishlist? findOccasionWishlist({
  required List<Wishlist> wishlists,
  required List<String> keywords,
  required String userId,
  required DateTime occasionDate,
}) {
  final normalizedKeywords = _normalizedKeywords(keywords);
  final year = occasionDate.year;
  final shortYear = year % 100;
  final previousShortYear = (year - 1) % 100;
  final withRightYear = <Wishlist>[];
  final withoutYear = <Wishlist>[];

  for (final wishlist in wishlists) {
    if (wishlist.idOwner != userId || wishlist.isClosed) {
      continue;
    }
    final words = _words(wishlist.name);
    if (!words.any(normalizedKeywords.contains)) {
      continue;
    }

    var hasYear = false;
    var hasRightYear = false;
    for (final word in words) {
      if (_yearPattern.hasMatch(word)) {
        hasYear = true;
        hasRightYear |= int.parse(word) == year;
      } else if (word.length == 2 && RegExp(r'^[0-9]+$').hasMatch(word)) {
        final number = int.parse(word);
        if (number == shortYear) {
          hasYear = true;
          hasRightYear = true;
        } else if (number == previousShortYear) {
          hasYear = true;
        }
      }
    }
    if (!hasYear) {
      withoutYear.add(wishlist);
    } else if (hasRightYear) {
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

/// Whether one of the words of [name] is exactly one of [keywords] (rules 1
/// and 2 of [findOccasionWishlist]), whatever the year.
bool nameHasKeyword(String name, List<String> keywords) {
  final normalizedKeywords = _normalizedKeywords(keywords);
  return _words(name).any(normalizedKeywords.contains);
}

Set<String> _normalizedKeywords(List<String> keywords) {
  final normalized = <String>{};
  for (final keyword in keywords) {
    final words = _words(keyword);
    if (words.length == 1) {
      normalized.add(words.single);
    }
  }
  return normalized;
}

List<String> _words(String text) => _wordPattern
    .allMatches(normalizeString(text))
    .map((match) => match.group(0)!)
    .toList();
