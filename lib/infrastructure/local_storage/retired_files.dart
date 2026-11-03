import 'dart:io';

/// Deletes from the phone's storage folder [storage] what older versions
/// of the app kept there and no version reads any more (PLAN §6.3):
///
/// - `streets/`, the streets of a phone with no secteur open (M1 to
///   0.10.0), gone with that mode (#119): streets only live in a secteur;
/// - `moved_streets.json`, the secteurs those streets were moved into.
///
/// Nothing else lives under those names: a secteur's streets are in
/// Firestore's cache, and the new streets not yet all written in
/// `unfinished_streets/`, which stays. Once deleted they are gone for good,
/// so the next starts find nothing and do nothing.
///
/// A file the system refuses to delete (a full disk, a lock) is left for the
/// next start: the app works the same with it.
Future<void> deleteRetiredFiles(Directory storage) async {
  final separator = Platform.pathSeparator;
  await _deleteQuietly(Directory('${storage.path}${separator}streets'));
  await _deleteQuietly(File('${storage.path}${separator}moved_streets.json'));
}

Future<void> _deleteQuietly(FileSystemEntity entity) async {
  try {
    // `recursive`: a folder goes with what it holds; a file is deleted as
    // it is.
    if (entity.existsSync()) await entity.delete(recursive: true);
  } on FileSystemException {
    // Left for the next start.
  }
}
