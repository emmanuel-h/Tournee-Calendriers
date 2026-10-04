import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_identity.dart';

import '../../support/fakes/fake_ports.dart';

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('identity_test');
  });

  tearDown(() => folder.delete(recursive: true));

  File memberFile() => File('${folder.path}/me/member_id');

  test('should make a member id and keep it on first start', () async {
    final identity = await LocalIdentity.load(
      memberFile(),
      FakeIdGenerator('member'),
    );

    expect(identity.currentMember, MemberId('member-1'));
    expect(memberFile().readAsStringSync(), 'member-1');
    expect(File('${memberFile().path}.tmp').existsSync(), isFalse);
  });

  test('should read the same member id at the next start', () async {
    final ids = FakeIdGenerator('member');
    await LocalIdentity.load(memberFile(), ids);

    final again = await LocalIdentity.load(memberFile(), ids);

    expect(again.currentMember, MemberId('member-1'));
  });

  test('should read the id without the spaces around it', () async {
    memberFile()
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(' abc \n');

    final identity = await LocalIdentity.load(memberFile(), FakeIdGenerator());

    expect(identity.currentMember, MemberId('abc'));
  });

  test('should make a new id when the file is blank', () async {
    memberFile()
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('  ');

    final identity = await LocalIdentity.load(
      memberFile(),
      FakeIdGenerator('member'),
    );

    expect(identity.currentMember, MemberId('member-1'));
    expect(memberFile().readAsStringSync(), 'member-1');
  });
}
