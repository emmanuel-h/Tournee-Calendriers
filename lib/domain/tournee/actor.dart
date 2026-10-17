import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Who runs a command of a `Tournee` (PLAN §5.12, §6.1): the member using
/// the phone, and whether they are one of the app's administrators.
///
/// Admins are global, not per tournée (an `admins/{uid}` document added by
/// hand): an admin manages every tournée, member of it or not. So the
/// tournée cannot tell from its own members whether someone is an admin;
/// the use case asks and hands the answer in with the member id.
///
/// An immutable value, equal to another with the same fields.
final class Actor {
  const Actor({required this.member, required this.isAdmin});

  /// The member acting: their uid, in the tournée or not.
  final MemberId member;

  /// Whether they are an administrator of the app.
  final bool isAdmin;

  @override
  bool operator ==(Object other) =>
      other is Actor && other.member == member && other.isAdmin == isAdmin;

  @override
  int get hashCode => Object.hash(member, isAdmin);

  @override
  String toString() =>
      'Actor(${member.value}, ${isAdmin ? 'admin' : 'member'})';
}
