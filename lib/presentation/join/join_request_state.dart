import 'package:tournee_calendriers/presentation/launch/launch_place.dart';

/// What « Demande envoyée » shows of the member's request (PLAN §5.2,
/// JoinPending mockup). `sealed`: the screen handles each case.
sealed class JoinRequestState {
  const JoinRequestState();
}

/// The phone is looking for the request (it may be gone already).
final class RequestUnknown extends JoinRequestState {
  const RequestUnknown();
}

/// The request waits for an active member: « Tournée 49 · CS
/// Villefranche ».
final class RequestWaiting extends JoinRequestState {
  const RequestWaiting({
    required this.number,
    required this.centre,
    required this.canLeave,
  });

  final int number;
  final String centre;

  /// The phone has its start screen to go back to (a tournée open, streets
  /// of its own): a back arrow leads there. Otherwise this screen is the
  /// app until the request is answered.
  final bool canLeave;

  RequestWaiting withCanLeave(bool canLeave) =>
      RequestWaiting(number: number, centre: centre, canLeave: canLeave);

  @override
  bool operator ==(Object other) =>
      other is RequestWaiting &&
      other.number == number &&
      other.centre == centre &&
      other.canLeave == canLeave;

  @override
  int get hashCode => Object.hash(number, centre, canLeave);

  @override
  String toString() => 'RequestWaiting($number, $centre, $canLeave)';
}

/// Accepted: the tournée is open; the start screen shows it.
final class RequestAccepted extends JoinRequestState {
  const RequestAccepted();
}

/// The request is no more, [refused] by the team or cancelled: the app
/// goes on to [next] (« Bienvenue », or the start screen when the phone
/// has something to show there).
final class RequestClosed extends JoinRequestState {
  const RequestClosed({required this.refused, required this.next});

  final bool refused;
  final LaunchPlace next;

  @override
  bool operator ==(Object other) =>
      other is RequestClosed && other.refused == refused && other.next == next;

  @override
  int get hashCode => Object.hash(refused, next);

  @override
  String toString() => 'RequestClosed($refused, $next)';
}
