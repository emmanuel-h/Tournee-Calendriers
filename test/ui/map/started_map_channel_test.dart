import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/ui/map/started_map_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('should dispose quietly when the map never got its view', () {
    expect(() => StartedMapChannel().dispose(), returnsNormally);
  });

  test('should close its channel when the map got its view', () async {
    const channel = MethodChannel('plugins.flutter.io/maplibre_gl_7');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final map = StartedMapChannel();

    await map.initPlatform(7);

    expect(map.dispose, returnsNormally);
  });

  test('should be the channel of every map once installed', () {
    final before = MapLibrePlatform.createInstance;
    addTearDown(() => MapLibrePlatform.createInstance = before);

    StartedMapChannel.install();

    expect(MapLibrePlatform.createInstance(), isA<StartedMapChannel>());
  });
}
