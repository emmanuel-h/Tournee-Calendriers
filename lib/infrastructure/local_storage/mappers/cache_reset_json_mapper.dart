// Translation between where a reset of the phone's Firestore copy stands
// (PLAN §6.3, §8.3) and the JSON the phone keeps for it. Pure functions: no
// file here, so they are tested alone.
//
// The schema, version 1:
//
//   { version: 1, reset: "none" | "waiting" | "due" }
//
// Steps under fixed names, so renaming the Dart enum never changes what is
// on the phone.

/// Where a reset of the phone's copy of the server's data stands.
enum CacheResetStep {
  /// Nothing asked: the copy stays.
  none,

  /// Asked, but changes made on this phone may still wait to be sent:
  /// emptying the copy now would lose them.
  waiting,

  /// Asked, and the server had every change made on this phone when it was
  /// last checked: the next start empties the copy.
  due,
}

/// The schema version this code writes and reads.
const storedCacheResetVersion = 1;

const _none = 'none';
const _waiting = 'waiting';
const _due = 'due';

/// The stored form of [step].
Map<String, Object?> cacheResetToJson(CacheResetStep step) => {
  'version': storedCacheResetVersion,
  'reset': switch (step) {
    CacheResetStep.none => _none,
    CacheResetStep.waiting => _waiting,
    CacheResetStep.due => _due,
  },
};

/// The step read from [json] as `jsonDecode` gives it. Throws a
/// [FormatException] when it is not a version 1 file.
CacheResetStep cacheResetFromJson(Object? json) {
  if (json case {
    'version': storedCacheResetVersion,
    'reset': final String reset,
  }) {
    return switch (reset) {
      _none => CacheResetStep.none,
      _waiting => CacheResetStep.waiting,
      _due => CacheResetStep.due,
      _ => throw FormatException('Not a reset step: $reset'),
    };
  }
  throw FormatException('Not a version $storedCacheResetVersion file: $json');
}
