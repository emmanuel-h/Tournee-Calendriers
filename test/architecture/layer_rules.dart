// The dependency rule of PLAN §10.1, as a pure function over source text.
//
// Keeping the checker free of file-system access lets the architecture test
// feed it in-memory fixtures and prove that each rule really fires.
//
// The rules, from inside out:
//
//   domain          -> domain; dart:core / math / collection; package:collection
//   application     -> domain, application; the same, plus dart:async
//   presentation    -> domain, application, presentation; plus Riverpod
//   ui              -> domain, presentation, ui; any package
//   infrastructure  -> domain, application, infrastructure; any package
//   bootstrap, main -> everything
//
// On top of that, backend packages (Firebase, http, shared_preferences,
// path_provider) may only appear in infrastructure/ and bootstrap/, and MapLibre only in ui/map/
// and infrastructure/maplibre_offline/.

/// The package name from `pubspec.yaml`; imports of our own code start with
/// `package:tournee_calendriers/`.
const _ownPackage = 'package:tournee_calendriers/';

/// A Dart file of `lib/`, identified by its path relative to `lib/`
/// (for example `domain/street/street.dart`).
final class SourceFile {
  const SourceFile(this.path, this.content);

  final String path;
  final String content;
}

/// One forbidden dependency: [path] (relative to `lib/`) refers to [uri].
final class Violation {
  const Violation(this.path, this.uri, this.reason);

  final String path;

  /// The URI exactly as written in the directive; empty when the file itself
  /// is misplaced.
  final String uri;
  final String reason;

  @override
  String toString() =>
      uri.isEmpty ? '$path: $reason' : '$path -> $uri: $reason';
}

enum _Layer { domain, application, presentation, ui, infrastructure, bootstrap }

/// External libraries the three pure layers may use. Anything not listed is
/// refused, so a new dependency there is a deliberate change to this file.
const _pureDart = {'dart:core', 'dart:math', 'dart:collection'};
const _pureDartPackages = ['package:collection/'];

/// Which of our layers each layer may import.
const _allowedLayers = {
  _Layer.domain: {_Layer.domain},
  _Layer.application: {_Layer.domain, _Layer.application},
  _Layer.presentation: {_Layer.domain, _Layer.application, _Layer.presentation},
  _Layer.ui: {_Layer.domain, _Layer.presentation, _Layer.ui},
  _Layer.infrastructure: {
    _Layer.domain,
    _Layer.application,
    _Layer.infrastructure,
  },
  _Layer.bootstrap: {..._Layer.values},
};

/// Packages confined to some folders of `lib/`, whatever the layer allows.
const _confinedPackages = <String, List<String>>{
  'package:cloud_firestore/': _backendFolders,
  'package:firebase_': _backendFolders,
  'package:http/': _backendFolders,
  'package:shared_preferences/': _backendFolders,
  'package:path_provider/': _backendFolders,
  'package:maplibre_gl/': ['ui/map/', 'infrastructure/maplibre_offline/'],
};
const _backendFolders = ['infrastructure/', 'bootstrap/'];

/// Returns every forbidden dependency found in [files], in input order.
List<Violation> findViolations(Iterable<SourceFile> files) => [
  for (final file in files) ..._checkFile(file),
];

List<Violation> _checkFile(SourceFile file) {
  final layer = _layerOf(file.path);
  if (layer == null) {
    return [
      Violation(file.path, '', 'file sits outside every layer of PLAN §10.1'),
    ];
  }
  return [
    for (final uri in _referencedUris(file.content))
      ?_checkUri(file.path, layer, uri),
  ];
}

/// `null` means the file is not in any layer folder. `main.dart` is the app
/// entry point Flutter expects at the root of `lib/`; it belongs to the
/// composition root.
_Layer? _layerOf(String libPath) {
  if (libPath == 'main.dart') return _Layer.bootstrap;
  final folder = libPath.split('/').first;
  for (final layer in _Layer.values) {
    if (layer.name == folder) return layer;
  }
  return null;
}

/// Returns the reason [uri] is forbidden in [path], or `null` when allowed.
Violation? _checkUri(String path, _Layer layer, String uri) {
  String? reason;
  if (uri.startsWith('dart:')) {
    reason = _checkDartLibrary(layer, uri);
  } else if (uri.startsWith('package:') && !uri.startsWith(_ownPackage)) {
    reason = _checkPackage(path, layer, uri);
  } else {
    reason = _checkOwnCode(layer, _resolve(path, uri));
  }
  return reason == null ? null : Violation(path, uri, reason);
}

String? _checkDartLibrary(_Layer layer, String uri) {
  final allowed = switch (layer) {
    _Layer.domain => _pureDart,
    _Layer.application || _Layer.presentation => {..._pureDart, 'dart:async'},
    _Layer.ui || _Layer.infrastructure || _Layer.bootstrap => null,
  };
  if (allowed == null || allowed.contains(uri)) return null;
  return '${layer.name} may only use ${allowed.join(', ')}';
}

String? _checkPackage(String path, _Layer layer, String uri) {
  final allowed = switch (layer) {
    _Layer.domain || _Layer.application => _pureDartPackages,
    _Layer.presentation => [
      ..._pureDartPackages,
      'package:riverpod/',
      'package:flutter_riverpod/',
    ],
    _Layer.ui || _Layer.infrastructure || _Layer.bootstrap => null,
  };
  if (allowed != null && !allowed.any(uri.startsWith)) {
    return '${layer.name} may not depend on this package (PLAN §10.1)';
  }
  // main.dart lives at the root of lib/ but counts as part of bootstrap/.
  final location = path == 'main.dart' ? 'bootstrap/main.dart' : path;
  for (final MapEntry(key: prefix, value: folders)
      in _confinedPackages.entries) {
    if (uri.startsWith(prefix) && !folders.any(location.startsWith)) {
      return 'this package may only appear in ${folders.join(' or ')}';
    }
  }
  return null;
}

String? _checkOwnCode(_Layer layer, String targetPath) {
  final target = _layerOf(targetPath);
  if (target == null) return 'target sits outside every layer of PLAN §10.1';
  if (_allowedLayers[layer]!.contains(target)) return null;
  return '${layer.name} may not depend on ${target.name} (PLAN §10.1)';
}

/// Turns a reference to our own code into a path relative to `lib/`:
/// `package:tournee_calendriers/a/b.dart` or a relative `../a/b.dart`.
String _resolve(String fromPath, String uri) {
  if (uri.startsWith(_ownPackage)) return uri.substring(_ownPackage.length);
  final segments = fromPath.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    switch (segment) {
      case '.':
        break;
      case '..':
        // Climbing above lib/ leaves no segment: the result then matches no
        // layer and is reported.
        if (segments.isNotEmpty) segments.removeLast();
      default:
        segments.add(segment);
    }
  }
  return segments.join('/');
}

/// A directive starts a line with `import`, `export` or `part`, and runs up to
/// the next `;`. It may span several lines (conditional imports).
final _directive = RegExp(
  r'^\s*(?:import|export|part)\b([^;]*);',
  multiLine: true,
);

/// A quoted string inside a directive: the URI, plus any conditional URIs.
final _quoted = RegExp(r'''['"]([^'"]+)['"]''');

/// Comments are removed first so commented-out imports are not reported.
final _comment = RegExp(r'/\*[\s\S]*?\*/|//[^\n]*');

Iterable<String> _referencedUris(String source) sync* {
  final code = source.replaceAll(_comment, '');
  for (final directive in _directive.allMatches(code)) {
    final body = directive.group(1)!;
    // `part of 'x.dart'` names the library this file belongs to, which is a
    // dependency too.
    for (final quoted in _quoted.allMatches(body)) {
      final uri = quoted.group(1)!;
      // Skip the `== 'value'` of `if (dart.library.io == 'true')`.
      if (!uri.contains('.dart') && !uri.startsWith('dart:')) continue;
      yield uri;
    }
  }
}
