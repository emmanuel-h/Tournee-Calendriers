// A hand-written CommuneSearch: answers from a map given by the test, or
// holds an answer back until the test releases it, to play a slow network
// (an answer arriving after the user typed something else).
import 'dart:async';

import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

typedef CommuneSearchResult = Result<List<CommuneMatch>, CommuneSearchFailure>;

final class FakeCommuneSearch implements CommuneSearch {
  FakeCommuneSearch({this.answers = const {}});

  /// The answer for each name; any other finds nothing.
  final Map<String, CommuneSearchResult> answers;

  /// Every name searched, in order.
  final searched = <String>[];

  /// Names whose answer waits until [release] is called for them.
  final _held = <String, Completer<CommuneSearchResult>>{};

  /// Makes the next search for [name] wait until [release].
  void hold(String name) => _held[name] = Completer();

  /// Lets the held search for [name] answer [answer].
  void release(String name, CommuneSearchResult answer) =>
      _held.remove(name)!.complete(answer);

  @override
  Future<CommuneSearchResult> search(String name) {
    searched.add(name);
    final held = _held[name];
    if (held != null) return held.future;
    return Future.value(answers[name] ?? const Ok([]));
  }
}
