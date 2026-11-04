import 'package:maplibre_gl/maplibre_gl.dart';

/// MapLibre's channel to one map on Android and iOS, safe to dispose before
/// the map exists.
///
/// maplibre_gl 0.27.1 names the channel only once the platform view is
/// created (`initPlatform`), but `dispose` always uses it: a map that leaves
/// the screen before Android has created its view (a quick back, a tab
/// switch, a restart) throws a `LateInitializationError` while Flutter
/// unmounts it. Such a map has no channel to close, so nothing is lost by
/// skipping it.
class StartedMapChannel extends MapLibreMethodChannel {
  var _started = false;

  /// Makes every map of the app use this channel. MapLibre creates one per
  /// `MapLibreMap` through this replaceable factory.
  static void install() {
    MapLibrePlatform.createInstance = StartedMapChannel.new;
  }

  @override
  Future<void> initPlatform(int id) {
    // The channel is named in the first, synchronous step of the call.
    _started = true;
    return super.initPlatform(id);
  }

  @override
  void dispose() {
    if (_started) super.dispose();
  }
}
