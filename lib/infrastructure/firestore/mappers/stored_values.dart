// Small pieces every Firestore mapper reads the same way: times, change
// stamps, identifiers and the domain's own checks. Pure functions.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The time stored as [value], in UTC like every time of the domain.
///
/// Firestore stores times as a `Timestamp` (seconds and nanoseconds since
/// 1970, no time zone); `toDate` gives the phone's local time, so it is
/// turned back to UTC.
DateTime timeFrom(Object? value) => switch (value) {
  final Timestamp timestamp => timestamp.toDate().toUtc(),
  _ => throw FormatException('Not a stored time', value),
};

/// The stamp stored as [by] and [at]: both or neither, never one alone.
ChangeStamp? stampOrNull(String? by, Object? at) {
  if (by == null && at == null) return null;
  if (by == null || at == null) throw const FormatException('Half a stamp');
  return ChangeStamp(by: identifier(by, MemberId.new), at: timeFrom(at));
}

/// The value of [result], or a [FormatException] naming [what] was
/// refused: stored data the domain refuses is unreadable data.
T valid<T, F>(Result<T, F> result, String what) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw FormatException('Invalid $what: $failure'),
};

/// The identifier [make] builds from [text]. Identifier constructors throw
/// an [ArgumentError] on a value no adapter should make (a blank id, a
/// staircase `a`): in code it is a bug, but in a stored document it is
/// unreadable data, so it becomes a [FormatException].
T identifier<T>(String text, T Function(String) make) {
  try {
    return make(text);
  } on ArgumentError {
    throw FormatException('Not a stored identifier', text);
  }
}
