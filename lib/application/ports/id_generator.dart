/// Makes the identifiers the app creates itself: a new street's id, the
/// phone's member id in M1 (PLAN §6.1: identifiers are opaque and never
/// typed by a person).
///
/// A port so tests get predictable ids (`street-1`, `street-2`…) and assert
/// them, while the app gets random ones.
abstract interface class IdGenerator {
  /// A new identifier, never returned before: non-blank, made of ASCII
  /// letters and digits only, so it is safe in a file name or a Firestore
  /// document path.
  String newId();
}
