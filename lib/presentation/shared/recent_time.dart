/// How long ago something happened, as the screens say it: « à
/// l'instant », « il y a 2 min », « il y a 3 h », « hier », « 3 oct. »
/// (a request in Équipe, a deletion in the Corbeille, PLAN §5.8, §5.11).
///
/// The notifier decides which case it is from the `Clock`; the screen only
/// words it. `sealed`: the screen's `switch` handles each case.
sealed class RecentTime {
  const RecentTime();

  /// How long before [now] [at] was, judged on the phone's calendar for
  /// « hier » and the day.
  ///
  /// Under a minute (or a little ahead, a teammate's clock may be) it is
  /// just now; under an hour, minutes; later the same day, hours; the day
  /// before, yesterday; otherwise the day, on the phone's clock.
  factory RecentTime.of(DateTime at, {required DateTime now}) {
    final elapsed = now.difference(at);
    if (elapsed < const Duration(minutes: 1)) return const JustNow();
    if (elapsed < const Duration(hours: 1)) {
      return MinutesAgo(elapsed.inMinutes);
    }
    final day = at.toLocal();
    final today = now.toLocal();
    if (_sameDay(day, today)) return HoursAgo(elapsed.inHours);
    // `DateTime` counts day 0 of a month as the last day of the month
    // before, so this is yesterday even on the 1st.
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (_sameDay(day, yesterday)) return const Yesterday();
    return OnDay(day);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Less than a minute ago: « à l'instant ».
final class JustNow extends RecentTime {
  const JustNow();

  @override
  bool operator ==(Object other) => other is JustNow;

  @override
  int get hashCode => (JustNow).hashCode;

  @override
  String toString() => 'JustNow';
}

/// [minutes] minutes ago, 1 to 59: « il y a 2 min ».
final class MinutesAgo extends RecentTime {
  const MinutesAgo(this.minutes);

  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is MinutesAgo && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(MinutesAgo, minutes);

  @override
  String toString() => 'MinutesAgo($minutes)';
}

/// [hours] hours ago, earlier the same day: « il y a 3 h ».
final class HoursAgo extends RecentTime {
  const HoursAgo(this.hours);

  final int hours;

  @override
  bool operator ==(Object other) => other is HoursAgo && other.hours == hours;

  @override
  int get hashCode => Object.hash(HoursAgo, hours);

  @override
  String toString() => 'HoursAgo($hours)';
}

/// The day before today: « hier ».
final class Yesterday extends RecentTime {
  const Yesterday();

  @override
  bool operator ==(Object other) => other is Yesterday;

  @override
  int get hashCode => (Yesterday).hashCode;

  @override
  String toString() => 'Yesterday';
}

/// Before yesterday: the day of [at], on the phone's clock (« 3 oct. »).
final class OnDay extends RecentTime {
  const OnDay(this.at);

  final DateTime at;

  @override
  bool operator ==(Object other) => other is OnDay && other.at == at;

  @override
  int get hashCode => Object.hash(OnDay, at);

  @override
  String toString() => 'OnDay($at)';
}
