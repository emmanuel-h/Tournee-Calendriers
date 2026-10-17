import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../support/fakes/fake_admin_status.dart';

void main() {
  late FakeAdminStatus admins;

  ProviderContainer phone() {
    final container = ProviderContainer(
      overrides: [adminStatusProvider.overrideWithValue(admins)],
    );
    addTearDown(container.dispose);
    container.listen(adminProvider, (_, _) {});
    return container;
  }

  setUp(() => admins = FakeAdminStatus());

  test('should say no until the status is known', () {
    admins = FakeAdminStatus(phoneIsAdmin: true);

    expect(phone().read(adminProvider), isFalse);
  });

  test('should say yes once the phone is known to be an admin', () async {
    admins = FakeAdminStatus(phoneIsAdmin: true);
    final container = phone();
    await pumpEventQueue();

    expect(container.read(adminProvider), isTrue);
  });

  test('should follow the status as it changes', () async {
    final container = phone();
    await pumpEventQueue();

    admins.phoneIsAdmin = true;
    expect(container.read(adminProvider), isTrue);

    admins.phoneIsAdmin = false;
    expect(container.read(adminProvider), isFalse);
  });

  test('should say no when the status cannot be followed', () async {
    admins = FakeAdminStatus(phoneIsAdmin: true);
    final container = phone();
    await pumpEventQueue();

    admins.fail();

    expect(container.read(adminProvider), isFalse);
  });

  test('should stop following once the app goes', () async {
    final container = phone();
    await pumpEventQueue();

    container.dispose();

    expect(admins.isFollowed, isFalse);
  });
}
