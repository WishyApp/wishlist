/// Which text the wall and the recommendation dialog show. One rule for both,
/// so they stay consistent: with a store page the generic text and an update
/// button; without one, the text names the store to update from.
enum UpdateTextVariant {
  generic,
  iosStore,
  androidStore;

  static UpdateTextVariant of({
    required bool hasLink,
    required String? platform,
  }) {
    if (hasLink) {
      return generic;
    }
    return switch (platform) {
      'ios' => iosStore,
      'android' => androidStore,
      _ => generic,
    };
  }
}
