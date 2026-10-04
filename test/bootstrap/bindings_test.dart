import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/bootstrap/bindings.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../support/fakes/fake_address_directory.dart';

void main() {
  late Directory storage;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('bindings_test');
  });

  tearDown(() => storage.delete(recursive: true));

  Future<ProviderContainer> containerWith({
    FakeAddressDirectory? directory,
  }) async {
    final container = ProviderContainer(
      overrides: await bindAdapters(
        storage: storage,
        addressDirectory: directory,
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should bind each port to the adapter of the phone', () async {
    final container = await containerWith();

    final streets = container.read(streetRepositoryProvider);
    expect(streets, isA<LocalStreetRepository>());
    expect(
      (streets as LocalStreetRepository).directory.path,
      '${storage.path}/streets',
    );
    expect(
      container.read(addressDirectoryProvider),
      isA<BanAddressDirectory>(),
    );
    expect(container.read(clockProvider), isA<SystemClock>());
    expect(container.read(idGeneratorProvider), isA<RandomIdGenerator>());
  });

  test('should keep the member id across starts', () async {
    final first = (await containerWith()).read(identityProvider);
    final second = (await containerWith()).read(identityProvider);

    expect(second.currentMember, first.currentMember);
    expect(
      File('${storage.path}/member_id').readAsStringSync(),
      first.currentMember.value,
    );
  });

  test('should use the directory given instead of the BAN', () async {
    final directory = FakeAddressDirectory();

    final container = await containerWith(directory: directory);

    expect(container.read(addressDirectoryProvider), same(directory));
  });

  test('should make one HTTP client for the app', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(httpClientProvider),
      same(container.read(httpClientProvider)),
    );
  });
}
