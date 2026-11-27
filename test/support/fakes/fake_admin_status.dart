// An AdminStatus in memory. A test says what the phone's member may do as
// an admin ([phoneGrants], or [phoneIsAdmin] for every permission in the CS
// Villefranche; told at once to whoever follows it) and which members are
// admins ([admins]).
import 'dart:async';

import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Every permission in the CS Villefranche, the centre of the secteurs of
/// the tests: what « an admin » meant before PLAN §5.23.
final everyPermissionInVillefranche = AdminGrants(
  centres: {
    switch (RescueCentre.create('CS Villefranche')) {
      Ok(:final value) => value.key,
      Err(:final failure) => throw StateError('$failure'),
    }: Permission.values
        .toSet(),
  },
);

final class FakeAdminStatus implements AdminStatus {
  FakeAdminStatus({
    bool phoneIsAdmin = false,
    AdminGrants? phoneGrants,
    Iterable<MemberId> admins = const [],
  }) : _phoneGrants =
           phoneGrants ??
           (phoneIsAdmin ? everyPermissionInVillefranche : AdminGrants.none),
       admins = {...admins};

  AdminGrants _phoneGrants;

  /// The members [isAdmin] says are admins.
  final Set<MemberId> admins;

  /// Every member [isAdmin] was asked about, in order.
  final asked = <MemberId>[];

  final _changes = StreamController<AdminGrants>.broadcast(sync: true);

  /// Whether someone still follows the phone's grants.
  bool get isFollowed => _changes.hasListener;

  AdminGrants get phoneGrants => _phoneGrants;

  /// The server gives the phone's member new grants.
  set phoneGrants(AdminGrants value) {
    _phoneGrants = value;
    _changes.add(value);
  }

  bool get phoneIsAdmin => _phoneGrants.isAdmin;

  /// The server makes the phone's member an admin of every permission in
  /// the CS Villefranche, or no longer an admin.
  set phoneIsAdmin(bool value) =>
      phoneGrants = value ? everyPermissionInVillefranche : AdminGrants.none;

  /// The listener of the phone's grants fails.
  void fail() => _changes.addError(StateError('listener failed'));

  /// Whether the phone's grants fail before their first answer.
  bool unreadable = false;

  @override
  Stream<AdminGrants> watchGrants() async* {
    if (unreadable) throw StateError('admin status unreadable');
    yield _phoneGrants;
    yield* _changes.stream;
  }

  @override
  Future<bool> isAdmin(MemberId member) async {
    asked.add(member);
    return admins.contains(member);
  }
}
