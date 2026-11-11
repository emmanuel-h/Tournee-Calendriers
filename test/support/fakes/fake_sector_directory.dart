// A SectorDirectory in memory, for « Mes secteurs », « Nouveau secteur »
// and « Rejoindre ». A test plays the server: it adds to the stream of a
// request ([answer]), says which codes show a tournée ([previews]), which
// numbers are taken ([taken]) and which centres are known ([centres]), or
// cuts the network ([offline]). It records the requests sent and cancelled.
// It also plays the server telling a member they lost a tournée ([lose])
// and the name it holds for them in a tournée ([hearName]), and lists every
// tournée of the app for an admin ([overviews]), or refuses it to a phone
// no longer an admin's ([notAdmin]).
import 'dart:async';

import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/join_request.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

final class FakeSectorDirectory implements SectorDirectory {
  /// Every (tournée, member) whose request was watched, in order.
  final watched = <(SectorId, MemberId)>[];

  final _requests = <SectorId, StreamController<MemberStatus?>>{};

  /// The tournée each code shows; any other code is unknown.
  final previews = <JoinCode, JoinPreview>{};

  /// The numbers taken, by the key of their centre: the same station
  /// however written.
  final taken = <(RescueCentreKey, SectorNumber)>{};

  /// The centres de secours the app knows.
  List<RescueCentre> centres = const [];

  /// Plays a phone without network: every read fails with `noNetwork`.
  var offline = false;

  /// Every code [preview] was asked, in order.
  final previewed = <JoinCode>[];

  /// Every (centre, number) [isTaken] was asked, in order.
  final takenAsked = <(RescueCentre, SectorNumber)>[];

  /// How many times [rescueCentres] was asked.
  var centresAsked = 0;

  /// Every request sent, in order.
  final sent = <JoinRequest>[];

  /// Every (tournée, member) whose request was cancelled, in order.
  final cancelled = <(SectorId, MemberId)>[];

  /// Answers held back, one per call of [preview] / [isTaken] in order
  /// while any is left: the call waits for its gate, so a test makes a
  /// slow server answer after a later one.
  final previewGates = <Completer<void>>[];
  final takenGates = <Completer<void>>[];

  /// The stream of the request to join [sector]; one per tournée.
  StreamController<MemberStatus?> _request(SectorId sector) =>
      _requests.putIfAbsent(sector, StreamController.broadcast);

  /// The server tells where the request to join [sector] stands.
  void answer(SectorId sector, MemberStatus? status) =>
      _request(sector).add(status);

  /// The listener of the request to join [sector] fails (no right to
  /// read, server error).
  void fail(SectorId sector) =>
      _request(sector).addError(StateError('listener failed'));

  /// Whether someone still listens to the request to join [sector].
  bool isWatching(SectorId sector) => _request(sector).hasListener;

  /// Every (tournée, member) whose membership was watched, in order.
  final memberships = <(SectorSummary, MemberId)>[];

  final _losses = <SectorId, StreamController<SectorLoss>>{};

  StreamController<SectorLoss> _loss(SectorId sector) =>
      _losses.putIfAbsent(sector, StreamController.broadcast);

  /// The server tells the member they lost [sector], for [loss].
  void lose(SectorId sector, SectorLoss loss) => _loss(sector).add(loss);

  /// The listener of the membership of [sector] fails (a server error).
  void failMembership(SectorId sector) =>
      _loss(sector).addError(StateError('listener failed'));

  /// Whether someone still listens to the membership of [sector].
  bool isFollowing(SectorId sector) => _loss(sector).hasListener;

  @override
  Stream<SectorLoss> watchMembership(SectorSummary sector, MemberId member) {
    memberships.add((sector, member));
    return _loss(sector.id).stream;
  }

  /// Every (tournée, member) whose own name was watched, in order.
  final ownNames = <(SectorId, MemberId)>[];

  final _names = <SectorId, StreamController<MemberName>>{};

  StreamController<MemberName> _name(SectorId sector) =>
      _names.putIfAbsent(sector, StreamController.broadcast);

  /// The server tells the member's name in [sector] is [name].
  void hearName(SectorId sector, MemberName name) => _name(sector).add(name);

  /// The listener of the member's name in [sector] fails (a server error).
  void failOwnName(SectorId sector) =>
      _name(sector).addError(StateError('listener failed'));

  /// Whether someone still listens to the member's name in [sector].
  bool isHearingName(SectorId sector) => _name(sector).hasListener;

  @override
  Stream<MemberName> watchOwnName(SectorId sector, MemberId member) {
    ownNames.add((sector, member));
    return _name(sector).stream;
  }

  @override
  Stream<MemberStatus?> watchRequest(SectorId sector, MemberId member) {
    watched.add((sector, member));
    return _request(sector).stream;
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
  Future<void> requestToJoin(JoinRequest request) async {
    sent.add(request);
  }

  @override
  Future<void> cancelRequest(SectorId sector, MemberId member) async {
    cancelled.add((sector, member));
  }

  @override
  Future<Result<bool, DirectoryFailure>> isTaken(
    RescueCentre centre,
    SectorNumber number,
  ) async {
    takenAsked.add((centre, number));
    if (takenGates.isNotEmpty) await takenGates.removeAt(0).future;
    if (offline) return const Err(DirectoryFailure.noNetwork);
    return Ok(taken.contains((centre.key, number)));
  }

  /// Every tournée of the app, as « Tous les secteurs » lists them.
  List<SectorOverview> overviews = const [];

  /// Every admin [allSectors] was asked for, in order.
  final allAsked = <MemberId>[];

  /// Plays a server that no longer takes the phone for an admin's:
  /// [allSectors] fails with `notAdmin`.
  var notAdmin = false;

  @override
  Future<Result<List<SectorOverview>, DirectoryFailure>> allSectors(
    MemberId caller,
  ) async {
    allAsked.add(caller);
    if (offline) return const Err(DirectoryFailure.noNetwork);
    if (notAdmin) return const Err(DirectoryFailure.notAdmin);
    return Ok(overviews);
  }

  @override
  Future<Result<List<RescueCentre>, DirectoryFailure>> rescueCentres() async {
    centresAsked++;
    if (offline) return const Err(DirectoryFailure.noNetwork);
    return Ok(centres);
  }
}
