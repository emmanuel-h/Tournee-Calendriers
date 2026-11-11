import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// A newcomer's « Demander à rejoindre » (PLAN §5.2): who asks, under
/// which name, when, for which secteur and with which code.
///
/// The one [Member] made outside the `Sector` root (PLAN §10.1): the
/// newcomer cannot read the secteur, so there is no aggregate to ask. What
/// makes a request valid is therefore built in here, and only here: its
/// member is pending, with no acceptance, and it carries the code it was
/// made with, which the server checks is still the secteur's.
final class JoinRequest {
  /// The request of [by], named [name], to join [sector] with [code] at
  /// [at].
  JoinRequest({
    required this.sector,
    required this.code,
    required MemberId by,
    required MemberName name,
    required DateTime at,
  }) : member = Member(id: by, name: name, requestedAt: at);

  /// The secteur asked for.
  final SectorId sector;

  /// The code the newcomer typed or scanned.
  final JoinCode code;

  /// The newcomer as the team will see them in Équipe: always pending,
  /// since nothing here can set an acceptance.
  final Member member;

  @override
  bool operator ==(Object other) =>
      other is JoinRequest &&
      other.sector == sector &&
      other.code == code &&
      other.member == member;

  @override
  int get hashCode => Object.hash(sector, code, member);

  @override
  String toString() =>
      'JoinRequest(${sector.value}, ${code.display}, ${member.id.value})';
}
