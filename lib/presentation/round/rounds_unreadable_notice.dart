import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// Whether the app still has to say that the phone's tournées could not be
/// read at start-up (#143): true until the message has been shown once.
final roundsUnreadableNoticeProvider =
    NotifierProvider<RoundsUnreadableNotice, bool>(RoundsUnreadableNotice.new);

/// The message « Les tournées gardées sur ce téléphone n'ont pas pu être
/// relues… », owed once per start when `open_round.json` was unreadable,
/// rather than starting silently with none.
final class RoundsUnreadableNotice extends Notifier<bool> {
  @override
  bool build() => ref.watch(roundsUnreadableAtStartProvider)();

  /// The message was shown: it is not owed any more.
  void told() => state = false;
}
