// In-memory PhoneSettings: no file, answers at once, and records every
// write so tests can assert it.
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';

final class FakePhoneSettings implements PhoneSettings {
  FakePhoneSettings({this.memberName, this.theme = ThemeChoice.system});

  @override
  MemberName? memberName;

  @override
  ThemeChoice theme;

  /// Every name given to [setMemberName], in order.
  final names = <MemberName>[];

  /// Every theme given to [setTheme], in order.
  final themes = <ThemeChoice>[];

  @override
  Future<void> setMemberName(MemberName name) async {
    names.add(name);
    memberName = name;
  }

  @override
  Future<void> setTheme(ThemeChoice theme) async {
    themes.add(theme);
    this.theme = theme;
  }
}
