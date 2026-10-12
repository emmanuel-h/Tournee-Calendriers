import 'package:tournee_calendriers/domain/shared/change_stamp.dart';

/// How long the Corbeille keeps a deleted street or a removed number
/// (« Gardés 30 jours, puis supprimés définitivement », PLAN §5.11).
///
/// The security rules repeat it (`firebase/firestore.rules`): the server
/// refuses a hard delete of anything removed more recently.
const corbeilleRetention = Duration(days: 30);

/// Whether something removed with [removal] has been in the Corbeille
/// longer than [corbeilleRetention] at [now], so it may be purged.
///
/// Strictly longer: at 30 days exactly it is still kept. The server checks
/// the same with its own clock, so a phone a little ahead may have a purge
/// refused for a moment; it is tried again at the next start.
bool isPastRetention(ChangeStamp removal, {required DateTime now}) =>
    now.difference(removal.at) > corbeilleRetention;
