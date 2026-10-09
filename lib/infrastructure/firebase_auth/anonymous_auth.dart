/// The two things the app asks of Firebase Authentication: the session kept
/// on the phone, and an anonymous sign-in.
///
/// A seam of the adapter, not a port: it keeps `FirebaseAuth` (which needs
/// the real platform) out of `FirebaseIdentity`, so its rules are tested
/// with a fake.
abstract interface class AnonymousAuth {
  /// The uid of the account signed in on this phone, or null before the
  /// first sign-in. Firebase keeps the session on the phone, so it is known
  /// at start-up without the network.
  String? get currentUid;

  /// Signs in anonymously. Completes once [currentUid] is set, or without
  /// setting it when the sign-in failed (no network): never throws.
  Future<void> signIn();
}
