import 'dart:io';

import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/atomic_file.dart';

/// The [IdentityProvider] of M1, before the team exists: the phone makes a
/// member id once, keeps it in a file, and reads it back at every start, so
/// the stamps of its changes stay the same person. From M2 the Firebase uid
/// replaces it (PLAN §6.1).
final class LocalIdentity implements IdentityProvider {
  const LocalIdentity._(this.currentMember);

  /// Reads the member id kept in [file], or makes one with [ids] and keeps
  /// it there when the file is missing or blank. Called once at start-up,
  /// by the composition root.
  static Future<LocalIdentity> load(File file, IdGenerator ids) async {
    // A sync check: `File.exists` would cost a round trip to another thread
    // for a call this small (the `avoid_slow_async_io` lint).
    if (file.existsSync()) {
      final stored = (await file.readAsString()).trim();
      if (stored.isNotEmpty) return LocalIdentity._(MemberId(stored));
    }
    final made = ids.newId();
    await file.parent.create(recursive: true);
    await writeAtomically(file, made);
    return LocalIdentity._(MemberId(made));
  }

  @override
  final MemberId currentMember;
}
