// A TourneeDirectory in memory, for what « Mes tournées » asks of it: where
// the member's requests stand. A test plays the server by adding to the
// stream of a request ([answer]); the calls a test does not expect fail.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';

final class FakeTourneeDirectory implements TourneeDirectory {
  /// Every (tournée, member) whose request was watched, in order.
  final watched = <(TourneeId, MemberId)>[];

  final _requests = <TourneeId, StreamController<MemberStatus?>>{};

  /// The stream of the request to join [tournee]; one per tournée.
  StreamController<MemberStatus?> _request(TourneeId tournee) =>
      _requests.putIfAbsent(tournee, StreamController.broadcast);

  /// The server tells where the request to join [tournee] stands.
  void answer(TourneeId tournee, MemberStatus? status) =>
      _request(tournee).add(status);

  /// The listener of the request to join [tournee] fails (no right to
  /// read, server error).
  void fail(TourneeId tournee) =>
      _request(tournee).addError(StateError('listener failed'));

  /// Whether someone still listens to the request to join [tournee].
  bool isWatching(TourneeId tournee) => _request(tournee).hasListener;

  @override
  Stream<MemberStatus?> watchRequest(TourneeId tournee, MemberId member) {
    watched.add((tournee, member));
    return _request(tournee).stream;
  }

  @override
  Future<Result<JoinPreview, JoinFailure>> preview(JoinCode code) =>
      throw UnimplementedError('preview');

  @override
  Future<void> requestToJoin(JoinPreview preview, Member request) =>
      throw UnimplementedError('requestToJoin');

  @override
  Future<void> cancelRequest(TourneeId tournee, MemberId member) =>
      throw UnimplementedError('cancelRequest');

  @override
  Future<Result<bool, DirectoryFailure>> isTaken(
    RescueCentre centre,
    TourneeNumber number,
  ) => throw UnimplementedError('isTaken');

  @override
  Future<Result<List<RescueCentre>, DirectoryFailure>> rescueCentres() =>
      throw UnimplementedError('rescueCentres');
}
