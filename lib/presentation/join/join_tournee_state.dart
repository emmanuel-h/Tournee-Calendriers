import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

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

/// The tournée of the code, to confirm before asking to join: « Tournée 49
/// · CS Villefranche » over « Campagne 2026 » (PLAN §5.2). Its member
/// count is not shown: the join code's document does not hold it.
final class TourneeFound extends JoinLookup {
  const TourneeFound({
    required this.number,
    required this.centre,
    required this.campaign,
  });

  factory TourneeFound.of(JoinPreview preview) => TourneeFound(
    number: preview.number.value,
    centre: preview.centre.name,
    campaign: preview.campaign.value,
  );

  final int number;
  final String centre;
  final int campaign;

  @override
  bool operator ==(Object other) =>
      other is TourneeFound &&
      other.number == number &&
      other.centre == centre &&
      other.campaign == campaign;

  @override
  int get hashCode => Object.hash(number, centre, campaign);

  @override
  String toString() => 'TourneeFound($number, $centre, $campaign)';
}

/// No tournée has the code: mistyped, or replaced by a new one.
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

/// The tournée is already in « Mes tournées »: nothing was sent.
final class JoinAlreadyJoined extends JoinRun {
  const JoinAlreadyJoined();
}

/// The request to join [tournee] is sent: the waiting screen follows it.
final class JoinSent extends JoinRun {
  const JoinSent(this.tournee);

  final TourneeId tournee;

  @override
  bool operator ==(Object other) =>
      other is JoinSent && other.tournee == tournee;

  @override
  int get hashCode => tournee.hashCode;

  @override
  String toString() => 'JoinSent(${tournee.value})';
}

/// What « Rejoindre une tournée » shows (PLAN §5.2, Join mockup).
/// Immutable: the notifier replaces it with [copyWith].
final class JoinTourneeState {
  const JoinTourneeState({
    required this.signedIn,
    required this.hasName,
    required this.first,
    required this.second,
    required this.invalidCharacter,
    required this.scanRefused,
    required this.lookup,
    required this.run,
  });

  /// The phone has its account: the server can be asked.
  final bool signedIn;

  /// The member gave their first name, which the request carries.
  final bool hasName;

  /// The first three characters of the code, upper case, without dash.
  final String first;

  /// The last three.
  final String second;

  /// What is typed holds a character no code has (0, O, 1, I, L…).
  final bool invalidCharacter;

  /// The QR code scanned is not a tournée's.
  final bool scanRefused;
  final JoinLookup lookup;
  final JoinRun run;

  /// « Demander à rejoindre » can be pressed.
  bool get canRequest =>
      signedIn &&
      hasName &&
      lookup is TourneeFound &&
      run is! JoinSending &&
      run is! JoinSent;

  JoinTourneeState copyWith({
    bool? signedIn,
    String? first,
    String? second,
    bool? invalidCharacter,
    bool? scanRefused,
    JoinLookup? lookup,
    JoinRun? run,
  }) => JoinTourneeState(
    signedIn: signedIn ?? this.signedIn,
    hasName: hasName,
    first: first ?? this.first,
    second: second ?? this.second,
    invalidCharacter: invalidCharacter ?? this.invalidCharacter,
    scanRefused: scanRefused ?? this.scanRefused,
    lookup: lookup ?? this.lookup,
    run: run ?? this.run,
  );
}
