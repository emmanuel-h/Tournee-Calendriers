// A TourneeDirectory in memory, for « Mes tournées », « Nouvelle tournée »
// and « Rejoindre ». A test plays the server: it adds to the stream of a
// request ([answer]), says which codes show a tournée ([previews]), which
// numbers are taken ([taken]) and which centres are known ([centres]), or
// cuts the network ([offline]). It records the requests sent and cancelled.
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

  /// The tournée each code shows; any other code is unknown.
  final previews = <JoinCode, JoinPreview>{};

  /// The numbers taken, by the key of their centre: the same station
  /// however written.
  final taken = <(RescueCentreKey, TourneeNumber)>{};

  /// The centres de secours the app knows.
  List<RescueCentre> centres = const [];

  /// Plays a phone without network: every read fails with `noNetwork`.
  var offline = false;

  /// Every code [preview] was asked, in order.
  final previewed = <JoinCode>[];

  /// Every (centre, number) [isTaken] was asked, in order.
  final takenAsked = <(RescueCentre, TourneeNumber)>[];

  /// How many times [rescueCentres] was asked.
  var centresAsked = 0;

  /// Every request sent, in order.
  final sent = <(JoinPreview, Member)>[];

  /// Every (tournée, member) whose request was cancelled, in order.
  final cancelled = <(TourneeId, MemberId)>[];

  /// Answers held back, one per call of [preview] / [isTaken] in order
  /// while any is left: the call waits for its gate, so a test makes a
  /// slow server answer after a later one.
  final previewGates = <Completer<void>>[];
  final takenGates = <Completer<void>>[];

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
  Future<Result<JoinPreview, JoinFailure>> preview(JoinCode code) async {
    previewed.add(code);
    if (previewGates.isNotEmpty) await previewGates.removeAt(0).future;
    if (offline) return const Err(JoinFailure.noNetwork);
    return switch (previews[code]) {
      final preview? => Ok(preview),
      null => const Err(JoinFailure.unknownCode),
    };
  }

  @override
  Future<void> requestToJoin(JoinPreview preview, Member request) async {
    sent.add((preview, request));
  }

  @override
  Future<void> cancelRequest(TourneeId tournee, MemberId member) async {
    cancelled.add((tournee, member));
  }

  @override
  Future<Result<bool, DirectoryFailure>> isTaken(
    RescueCentre centre,
    TourneeNumber number,
  ) async {
    takenAsked.add((centre, number));
    if (takenGates.isNotEmpty) await takenGates.removeAt(0).future;
    if (offline) return const Err(DirectoryFailure.noNetwork);
    return Ok(taken.contains((centre.key, number)));
  }

  @override
  Future<Result<List<RescueCentre>, DirectoryFailure>> rescueCentres() async {
    centresAsked++;
    if (offline) return const Err(DirectoryFailure.noNetwork);
    return Ok(centres);
  }
}
