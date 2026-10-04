import 'dart:io';

/// Writes [text] to [file] so that a reader finds either the old content or
/// the new one, never half of it, even when the app is killed mid-write.
///
/// The text goes to `<file>.tmp` first, is flushed to the disk, and the
/// temporary file is then renamed over [file]: on Android and iOS a rename
/// within a folder is atomic. A `.tmp` left behind by a killed write is
/// simply overwritten by the next one.
Future<void> writeAtomically(File file, String text) async {
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(text, flush: true);
  await temporary.rename(file.path);
}
