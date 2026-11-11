import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

/// What the code typed or scanned shows. `sealed`: the screen handles each
/// case.
sealed class JoinLookup {
  const JoinLookup();
}

/// No complete code yet, or the phone waits for its account to ask.
final class NoLookup extends JoinLookup {
  const NoLookup();
}

/// The server is being asked.
final class LookingUp extends JoinLookup {
  const LookingUp();
}

/// The secteur of the code, to confirm before asking to join: « Secteur 49
/// · CS Villefranche » over « Campagne 2026 » (PLAN §5.2). Its member
/// count is not shown: the join code's document does not hold it.
final class SectorFound extends JoinLookup {
  const SectorFound({
    required this.number,
    required this.centre,
    required this.campaign,
  });

  factory SectorFound.of(JoinPreview preview) => SectorFound(
    number: preview.number.value,
    centre: preview.centre.name,
    campaign: preview.campaign.value,
  );

  final int number;
  final String centre;
  final int campaign;

  @override
  bool operator ==(Object other) =>
      other is SectorFound &&
      other.number == number &&
      other.centre == centre &&
      other.campaign == campaign;

  @override
  int get hashCode => Object.hash(number, centre, campaign);

  @override
  String toString() => 'SectorFound($number, $centre, $campaign)';
}

/// No secteur has the code: mistyped, or replaced by a new one.
final class CodeUnknown extends JoinLookup {
  const CodeUnknown();
}

/// The server could not be reached: « Réessayer ».
final class LookupOffline extends JoinLookup {
  const LookupOffline();
}

/// Where « Demander à rejoindre » stands. `sealed`: the screen handles
/// each case.
sealed class JoinRun {
  const JoinRun();
}

/// Not asked yet.
final class JoinIdle extends JoinRun {
  const JoinIdle();
}

/// The request is being sent.
final class JoinSending extends JoinRun {
  const JoinSending();
}

/// The phone could not sign in: « Pas de réseau ».
final class JoinOffline extends JoinRun {
  const JoinOffline();
}

/// The secteur is already in « Mes secteurs »: nothing was sent.
final class JoinAlreadyJoined extends JoinRun {
  const JoinAlreadyJoined();
}

/// The request to join [sector] is sent: the waiting screen follows it.
final class JoinSent extends JoinRun {
  const JoinSent(this.sector);

  final SectorId sector;

  @override
  bool operator ==(Object other) => other is JoinSent && other.sector == sector;

  @override
  int get hashCode => sector.hashCode;

  @override
  String toString() => 'JoinSent(${sector.value})';
}

/// The name the request carried is taken in the secteur (#148, PLAN §5.16,
/// JoinNameTaken mockup): « ⚠ « Léa » est déjà pris dans ce secteur… »
/// over the field « Votre nom dans ce secteur », whose name the next
/// request carries, for this secteur only.
final class JoinNameTaken {
  const JoinNameTaken({required this.taken, required this.typed, this.problem});

  /// The name refused: « Léa ».
  final String taken;

  /// What the field holds.
  final String typed;

  /// Why [typed] cannot be a name, once « Demander à rejoindre » was
  /// pressed with it; null otherwise.
  final MemberNameFailure? problem;

  @override
  bool operator ==(Object other) =>
      other is JoinNameTaken &&
      other.taken == taken &&
      other.typed == typed &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(taken, typed, problem);

  @override
  String toString() => 'JoinNameTaken($taken, $typed, $problem)';
}

/// What « Rejoindre un secteur » shows (PLAN §5.2, Join mockup).
/// Immutable: the notifier replaces it with [copyWith].
final class JoinSectorState {
  const JoinSectorState({
    required this.signedIn,
    required this.defaultName,
    required this.first,
    required this.second,
    required this.invalidCharacter,
    required this.scanRefused,
    required this.lookup,
    required this.run,
    this.nameTaken,
  });

  /// The phone has its account: the server can be asked.
  final bool signedIn;

  /// The phone's prénom, which the request carries unless it was taken in
  /// the secteur ([nameTaken]); null until the member gives one.
  final String? defaultName;

  /// The member gave their first name, which the request carries.
  bool get hasName => defaultName != null;

  /// The first three characters of the code, upper case, without dash.
  final String first;

  /// The last three.
  final String second;

  /// What is typed holds a character no code has (0, O, 1, I, L…).
  final bool invalidCharacter;

  /// The QR code scanned is not a secteur's.
  final bool scanRefused;
  final JoinLookup lookup;
  final JoinRun run;

  /// The prénom was taken in the secteur: the screen asks for another name
  /// there. Null otherwise, and again once another code is typed.
  final JoinNameTaken? nameTaken;

  /// « Demander à rejoindre » can be pressed.
  bool get canRequest =>
      signedIn &&
      hasName &&
      lookup is SectorFound &&
      run is! JoinSending &&
      run is! JoinSent;

  JoinSectorState copyWith({
    bool? signedIn,
    String? first,
    String? second,
    bool? invalidCharacter,
    bool? scanRefused,
    JoinLookup? lookup,
    JoinRun? run,
    JoinNameTaken? nameTaken,
    bool keepNameTaken = true,
  }) => JoinSectorState(
    signedIn: signedIn ?? this.signedIn,
    defaultName: defaultName,
    first: first ?? this.first,
    second: second ?? this.second,
    invalidCharacter: invalidCharacter ?? this.invalidCharacter,
    scanRefused: scanRefused ?? this.scanRefused,
    lookup: lookup ?? this.lookup,
    run: run ?? this.run,
    // `keepNameTaken: false` drops it; a value given replaces it.
    nameTaken: nameTaken ?? (keepNameTaken ? this.nameTaken : null),
  );
}
