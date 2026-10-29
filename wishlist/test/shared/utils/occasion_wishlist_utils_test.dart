import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/utils/occasion_wishlist_utils.dart';

import '../../fixtures/fake_data.dart';

Wishlist _wishlist(int id, String name) => Wishlist(
      id: id,
      createdAt: fakeCreatedAt,
      name: name,
      idOwner: fakeCurrentUserId,
      color: fakeColorBlue,
      endDate: DateTime(2024, 6, 15),
      canOwnerSeeTakenWish: true,
      order: 0,
      updatedBy: fakeCurrentUserId,
      updatedAt: fakeUpdatedAt,
    );

void main() {
  group('findOccasionWishlist', () {
    final occasionDate = DateTime(2026, 12, 25);
    const keywords = ['noel', 'christmas', 'xmas'];

    String? find(List<String> names, {List<String> words = keywords}) {
      final wishlists = [
        for (var i = 0; i < names.length; i++) _wishlist(i + 1, names[i]),
      ];
      return findOccasionWishlist(
        wishlists: wishlists,
        keywords: words,
        occasionDate: occasionDate,
      )?.name;
    }

    final cases = <String, (List<String>, String?)>{
      'matches a name with the right year': (['Noël 2026'], 'Noël 2026'),
      'matches a keyword inside a sentence': (
        ['Mes envies de Noël'],
        'Mes envies de Noël',
      ),
      'matches an english keyword': (['Christmas list'], 'Christmas list'),
      'matches a keyword case-insensitively': (['XMAS'], 'XMAS'),
      'splits letters from digits': (['noel2026'], 'noel2026'),
      'discards a wrong year': (['Noël 2025'], null),
      'does not match a longer word': (['Liste de Noëlle'], null),
      'ignores unrelated names': (['Vacances'], null),
      'is ambiguous with two lists without year': (
        ['Noël', 'Idées Noël'],
        null
      ),
      'prefers the right year over a wrong year': (
        ['Noël 2025', 'Noël 2026'],
        'Noël 2026',
      ),
      'prefers the right year over no year': (
        ['Noël', 'Noël 2026'],
        'Noël 2026'
      ),
      'is ambiguous with two lists of the right year': (
        ['Noël 2026', 'Christmas 2026'],
        null,
      ),
      'falls back to the only list without year': (
        ['Noël 2025', 'Mes envies de Noël'],
        'Mes envies de Noël',
      ),
      'returns null without wishlists': (<String>[], null),
    };

    cases.forEach((description, c) {
      test(description, () {
        expect(find(c.$1), c.$2);
      });
    });

    test('returns null without keywords', () {
      expect(find(['Noël 2026'], words: const []), isNull);
    });
  });
}
