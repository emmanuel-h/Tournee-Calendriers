import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

// Paramètres (PLAN §5.9, §5.16): the member's first name, the name they go
// by in each secteur, and the app's theme, kept on the phone (PLAN §6.3).
// The theme works offline, always; a name needs the server once the member
// is in a secteur, which alone tells whether it is free there (#148).

/// The name and the theme the member set. Synchronous: read once at
/// start-up, so the app opens in the chosen theme.
final class ReadPhoneSettings {
  const ReadPhoneSettings(this._settings);

  final PhoneSettings _settings;

  ({MemberName? name, ThemeChoice theme}) call() =>
      (name: _settings.memberName, theme: _settings.theme);
}

/// Why a name was not given: [NameRefused] with the reason, or one of the
/// [RenameProblem]s.
///
/// `sealed`: these are the only cases, so the screens' `switch` handles
/// each one. An enum may implement a sealed class of its own library.
sealed class RenameFailure {}

/// The text typed cannot be a name ([reason]): nothing was changed.
final class NameRefused implements RenameFailure {
  const NameRefused(this.reason);

  final MemberNameFailure reason;

  @override
  bool operator ==(Object other) =>
      other is NameRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'NameRefused($reason)';
}

/// The failures of a rename that carry no data.
enum RenameProblem implements RenameFailure {
  /// The phone could not reach the server, which alone tells whether a
  /// name is free in a secteur: nothing was changed.
  noNetwork,

  /// Another member of the secteur holds the name, case and accents
  /// ignored ([ChangeSectorName] only): the member keeps theirs there.
  nameTaken,

  /// The secteur cannot be read any more, or the member is no longer
  /// active in it ([ChangeSectorName] only): nothing was changed.
  sectorGone,
}

/// A secteur where the new prénom was taken: the member keeps [name] there
/// (« vous y gardez « Paul D. » », PLAN §5.16).
final class NameKept {
  const NameKept({required this.sector, required this.name});

  /// The secteur, as « Mes secteurs » keeps it: « le secteur 49 ».
  final SectorSummary sector;

  /// The name the member keeps there.
  final MemberName name;

  @override
  bool operator ==(Object other) =>
      other is NameKept && other.sector == sector && other.name == name;

  @override
  int get hashCode => Object.hash(sector, name);

  @override
  String toString() => 'NameKept(${sector.id.value}, ${name.text})';
}

/// What « Prénom » did: [name] is the phone's prénom and the member's name
/// in each secteur but those of [kept], where it was taken.
final class NameChanged {
  const NameChanged({required this.name, required this.kept});

  final MemberName name;

  /// The secteurs where the member keeps their old name, in the order of
  /// « Mes secteurs ».
  final List<NameKept> kept;

  @override
  bool operator ==(Object other) =>
      other is NameChanged && other.name == name && sameItems(other.kept, kept);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(kept));

  @override
  String toString() => 'NameChanged(${name.text}, kept: $kept)';
}

/// « Prénom »: keeps the typed text as the member's name once cleaned, or
/// says why it cannot be a name.
///
/// The name is kept on the phone (PLAN §6.3) and given to the member in
/// each tournée of « Mes secteurs » they are active in, so Équipe shows it
/// to the team, except where another member holds it (names are unique
/// within a secteur, #148, PLAN §5.16): the member keeps their old name
/// there, and the result says where ([NameChanged.kept]).
///
/// Only the server tells whether a name is free. With the member active in
/// some tournée, a phone that reaches none of them changes nothing and
/// fails with [RenameProblem.noNetwork]. A tournée it could not reach while
/// it reached others takes the name later ([CatchUpMemberName]), as does a
/// pending request once accepted. Without any active tournée the name is
/// only the phone's, offline too. A tournée the phone cannot read
/// (removed, never opened) or that refuses the rename (the member left
/// meanwhile) is skipped.
final class ChangeMemberName {
  const ChangeMemberName(
    this._settings,
    this._sectors,
    this._identity,
    this._mySectors,
  );

  final PhoneSettings _settings;
  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final MySectorsStore _mySectors;

  Future<Result<NameChanged, RenameFailure>> call(String text) async {
    final MemberName name;
    switch (MemberName.create(text)) {
      case Ok(:final value):
        name = value;
      case Err(:final failure):
        return Err(NameRefused(failure));
    }
    final by = _identity.currentMember;
    final outcomes = <SectorId, _Renamed>{};
    for (final summary in _mySectors.mySectors.sectors) {
      // A pending request cannot rename itself (PLAN §8.2), a visit has no
      // member: neither is asked.
      if (summary.status != MemberStatus.active) continue;
      outcomes[summary.id] = await _renameIn(_sectors, summary.id, name, by);
    }
    if (outcomes.isNotEmpty &&
        outcomes.values.every((it) => it.outcome == _Outcome.offline)) {
      return const Err(RenameProblem.noNetwork);
    }
    await _settings.setMemberName(name);
    // Read again: « Mes secteurs » may have changed while the server
    // answered.
    final mine = _mySectors.mySectors;
    final kept = <NameKept>[];
    var named = mine;
    for (final summary in mine.sectors) {
      if (summary.isVisiting) continue;
      var now = name;
      if (outcomes[summary.id] case (
        outcome: _Outcome.taken,
        held: final held?,
      )) {
        kept.add(NameKept(sector: summary, name: held));
        now = held;
      }
      if (summary.memberName != now) {
        named = named.remember(summary.withMemberName(now));
      }
    }
    if (named != mine) await _mySectors.save(named);
    return Ok(NameChanged(name: name, kept: List.unmodifiable(kept)));
  }
}

/// « Votre nom dans le secteur 49 » (PLAN §5.16): the member goes by the
/// typed name in the tournée [SectorId] only; the phone's prénom and the
/// other tournées stay as they are. Needs the server, which alone tells
/// whether the name is free there.
///
/// Fails with [NameRefused] for a text that cannot be a name,
/// [RenameProblem.nameTaken] when another member holds it there,
/// [RenameProblem.noNetwork] offline and [RenameProblem.sectorGone] when
/// the member is no longer active in that tournée.
final class ChangeSectorName {
  const ChangeSectorName(this._sectors, this._identity, this._mySectors);

  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final MySectorsStore _mySectors;

  Future<Result<MemberName, RenameFailure>> call(
    SectorId id,
    String text,
  ) async {
    final MemberName name;
    switch (MemberName.create(text)) {
      case Ok(:final value):
        name = value;
      case Err(:final failure):
        return Err(NameRefused(failure));
    }
    final summary = _mySectors.mySectors.find(id);
    if (summary == null || summary.status != MemberStatus.active) {
      return const Err(RenameProblem.sectorGone);
    }
    final renamed = await _renameIn(
      _sectors,
      id,
      name,
      _identity.currentMember,
    );
    switch (renamed.outcome) {
      case _Outcome.renamed:
        await _remember(_mySectors, id, name);
        return Ok(name);
      case _Outcome.taken:
        return const Err(RenameProblem.nameTaken);
      case _Outcome.offline:
        return const Err(RenameProblem.noNetwork);
      case _Outcome.skipped:
        return const Err(RenameProblem.sectorGone);
    }
  }
}

/// Catches up the member's name in [SectorId], one of their tournées,
/// when the server holds another one than the phone's (`WatchOwnName`):
/// sends the name the member goes by there (`SectorSummary.memberName`,
/// the prénom when none) with the same rename as « Prénom ».
///
/// Covers what [ChangeMemberName] could not reach: a rename made while
/// the request to join waited (PLAN §8.2: a pending member cannot rename
/// themself), sent once accepted, and a tournée the phone could not reach
/// at the rename, sent once the server is heard again. Where the name
/// turns out to be taken, the member keeps the name the server holds,
/// which the phone then remembers for that tournée (#148).
///
/// Equal names send nothing: the rename the server then echoes back stops
/// there. A phone without a name yet, a tournée it does not know as one
/// the member is active in, cannot read or that refuses the rename (the
/// member left meanwhile), or a server out of reach, send and keep
/// nothing.
final class CatchUpMemberName {
  const CatchUpMemberName(
    this._settings,
    this._sectors,
    this._identity,
    this._mySectors,
  );

  final PhoneSettings _settings;
  final SectorRepository _sectors;
  final IdentityProvider _identity;
  final MySectorsStore _mySectors;

  Future<void> call(SectorId sector, MemberName heard) async {
    final summary = _mySectors.mySectors.find(sector);
    if (summary == null || summary.status != MemberStatus.active) return;
    final wanted = summary.memberName ?? _settings.memberName;
    if (wanted == null || wanted == heard) return;
    final renamed = await _renameIn(
      _sectors,
      sector,
      wanted,
      _identity.currentMember,
    );
    switch (renamed.outcome) {
      case _Outcome.renamed:
        await _remember(_mySectors, sector, wanted);
      case _Outcome.taken:
        await _remember(_mySectors, sector, heard);
      case _Outcome.offline || _Outcome.skipped:
        break;
    }
  }
}

/// Keeps on the phone that the member goes by [name] in the tournée [id],
/// when « Mes secteurs » still holds it (read again: it may have changed
/// while the server answered).
Future<void> _remember(MySectorsStore store, SectorId id, MemberName name) {
  final mine = store.mySectors;
  return switch (mine.find(id)) {
    final summary? when summary.memberName != name => store.save(
      mine.remember(summary.withMemberName(name)),
    ),
    _ => Future.value(),
  };
}

/// What became of a rename in one tournée.
enum _Outcome {
  /// Done, or the member already went by that name there.
  renamed,

  /// Another member holds the name there: the member keeps theirs.
  taken,

  /// The server could not be reached.
  offline,

  /// The tournée cannot be read, or the member is no longer in it.
  skipped,
}

/// The [outcome] of a rename, with the name the member [held] in the
/// tournée before it (null when not in it).
typedef _Renamed = ({_Outcome outcome, MemberName? held});

/// Renames [by] to [name] in the tournée [id] and tells how it went.
Future<_Renamed> _renameIn(
  SectorRepository sectors,
  SectorId id,
  MemberName name,
  MemberId by,
) async {
  final sector = await sectors.find(id);
  if (sector == null) return (outcome: _Outcome.skipped, held: null);
  final held = sector.memberOf(by)?.name;
  // Nothing to write, offline too: the member already goes by it.
  if (held == name) return (outcome: _Outcome.renamed, held: held);
  final _Outcome outcome;
  switch (sector.rename(name, by: by)) {
    case Err(failure: SectorCommandFailure.nameTaken):
      outcome = _Outcome.taken;
    case Err():
      outcome = _Outcome.skipped;
    case Ok(value: (final renamed, final change)):
      outcome = switch (await sectors.save(renamed, change)) {
        Ok() => _Outcome.renamed,
        Err(failure: SectorWriteFailure.nameTaken) => _Outcome.taken,
        Err(failure: SectorWriteFailure.noNetwork) => _Outcome.offline,
        // Only an admin's commands are refused for not being one.
        Err(failure: SectorWriteFailure.notAdmin) => _Outcome.skipped,
      };
  }
  return (outcome: outcome, held: held);
}

/// « Thème »: keeps the theme chosen.
final class ChooseTheme {
  const ChooseTheme(this._settings);

  final PhoneSettings _settings;

  Future<void> call(ThemeChoice theme) => _settings.setTheme(theme);
}
