import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Who made a change ([by]) and when ([at]): « Modifié par Léa · 14:02 »
/// on a house, « supprimée par Paul · hier » in the Corbeille (PLAN §5).
///
/// [at] always comes from the caller (a `Clock` port in the use cases),
/// never from `DateTime.now()`, so the domain stays testable.
final class ChangeStamp {
  const ChangeStamp({required this.by, required this.at});

  final MemberId by;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is ChangeStamp && other.by == by && other.at == at;

  @override
  int get hashCode => Object.hash(by, at);

  @override
  String toString() => 'ChangeStamp(${by.value}, $at)';
}
