// An AdminStatus in memory. A test says whether the phone's member is an
// admin ([phoneIsAdmin], told at once to whoever follows it) and which
// members are ([admins]).
import 'dart:async';

import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

final class FakeAdminStatus implements AdminStatus {
  FakeAdminStatus({
    this._phoneIsAdmin = false,
    Iterable<MemberId> admins = const [],
  }) : admins = {...admins};

  bool _phoneIsAdmin;

  /// The members [isAdmin] says are admins.
  final Set<MemberId> admins;

  /// Every member [isAdmin] was asked about, in order.
  final asked = <MemberId>[];

  final _changes = StreamController<bool>.broadcast(sync: true);

  /// Whether someone still follows the phone's admin status.
  bool get isFollowed => _changes.hasListener;

  bool get phoneIsAdmin => _phoneIsAdmin;

  /// The server says the phone's member is an admin, or no longer one.
  set phoneIsAdmin(bool value) {
    _phoneIsAdmin = value;
    _changes.add(value);
  }

  /// The listener of the phone's admin status fails.
  void fail() => _changes.addError(StateError('listener failed'));

  /// Whether the phone's admin status fails before its first answer.
  bool unreadable = false;

  @override
  Stream<bool> watchIsAdmin() async* {
    if (unreadable) throw StateError('admin status unreadable');
    yield _phoneIsAdmin;
    yield* _changes.stream;
  }

  @override
  Future<bool> isAdmin(MemberId member) async {
    asked.add(member);
    return admins.contains(member);
  }
}
