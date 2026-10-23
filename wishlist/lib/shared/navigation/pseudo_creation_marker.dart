/// Tells the router redirect that the pseudo was just created by the pseudo
/// screen, which is what sends a new user to the optional birthday step. An
/// existing user reaching `/pseudo` (an old link) is not concerned.
///
/// The router is global and has no access to providers, hence this plain
/// object.
class PseudoCreationMarker {
  bool _isSet = false;

  /// Set right before the profile is created.
  void mark() => _isSet = true;

  /// Clears the marker, for a creation that failed or was handled elsewhere.
  void clear() => _isSet = false;

  /// Whether the marker was set, clearing it.
  bool consume() {
    final wasSet = _isSet;
    _isSet = false;
    return wasSet;
  }
}

final pseudoCreationMarker = PseudoCreationMarker();
