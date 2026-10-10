import 'package:tournee_calendriers/domain/tournee/member_name.dart';

/// The look the member chose in Paramètres → Thème (PLAN §5.9).
enum ThemeChoice {
  /// Light or dark as the phone is set: the default.
  system,

  /// Always light (« Clair »).
  light,

  /// Always dark (« Sombre »).
  dark,
}

/// What the member set on this phone in Paramètres (PLAN §5.9, §6.3): the
/// first name they go by and the app's theme. On the phone only.
///
/// An application port: the use cases own it, an adapter of
/// `infrastructure/local_storage/` implements it. Read without waiting: the
/// adapter loads the values before the first screen, so the app opens in
/// the chosen theme.
abstract interface class PhoneSettings {
  /// The member's first name; null until they give one (« Bienvenue »,
  /// PLAN §5.1, or Paramètres).
  MemberName? get memberName;

  /// The chosen theme; [ThemeChoice.system] until the member picks one.
  ThemeChoice get theme;

  /// Keeps [name]. Answered by [memberName] at once; the returned `Future`
  /// ends once it is kept on the phone.
  Future<void> setMemberName(MemberName name);

  /// Keeps [theme]. Answered by [theme] at once; the returned `Future` ends
  /// once it is kept on the phone.
  Future<void> setTheme(ThemeChoice theme);
}
