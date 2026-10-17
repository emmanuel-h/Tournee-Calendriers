import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// Why a number cannot be a count of [NobodyHomeTries].
enum NobodyHomeTriesFailure {
  /// Below 0 or above [NobodyHomeTries.max].
  outOfRange,
}

/// How many times a house (or a door) was tried with nobody home (#80,
/// PLAN §6.1): the first « personne » is try 1, and each « Repassé,
/// toujours personne » adds one.
///
/// The count follows the status (see [keptBy]): it goes back to 0 when the
/// house is to do again, it is at least 1 while nobody is home, and it is
/// kept as it is on « fait » and « repasser », so the tile still says the
/// house took three tries once it is done. A new campaign starts every
/// house to do, hence at 0.
final class NobodyHomeTries {
  const NobodyHomeTries._(this.count);

  /// Never tried with nobody home.
  static const none = NobodyHomeTries._(0);

  /// The highest count: « ×99 » still fits on a tile, and the security
  /// rules refuse anything higher (PLAN §8.2). Nobody knocks 99 times.
  static const max = 99;

  /// The count [count], or [NobodyHomeTriesFailure.outOfRange] when it is
  /// below 0 or above [max] (stored data the app never writes).
  static Result<NobodyHomeTries, NobodyHomeTriesFailure> create(int count) =>
      count < 0 || count > max
      ? const Err(NobodyHomeTriesFailure.outOfRange)
      : Ok(NobodyHomeTries._(count));

  /// The tries a house or door with [status] keeps of [tries]:
  /// - to do: none, the house is to try again from the start;
  /// - nobody home: at least one, this « personne » being a try. Coming
  ///   back to « personne » from another status (by a tap or the status
  ///   control) adds nothing more: only « Repassé, toujours personne »
  ///   ([next]) counts a new try;
  /// - done or « repasser »: [tries] as they are.
  ///
  /// The `House` and `Dwelling` factories run it, so whatever builds a
  /// house (a command, an adapter reading old data without a count) never
  /// breaks those rules.
  static NobodyHomeTries keptBy(VisitStatus status, NobodyHomeTries tries) =>
      switch (status) {
        VisitStatus.toDo => none,
        VisitStatus.nobodyHome => tries.count == 0 ? none.next : tries,
        VisitStatus.done || VisitStatus.comeBack => tries,
      };

  /// The number of tries, 0 to [max].
  final int count;

  /// One more try; [max] stays [max].
  NobodyHomeTries get next => count < max ? NobodyHomeTries._(count + 1) : this;

  @override
  bool operator ==(Object other) =>
      other is NobodyHomeTries && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'NobodyHomeTries($count)';
}
