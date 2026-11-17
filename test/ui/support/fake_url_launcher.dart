import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// The phone's other apps (browser, mail), as url_launcher reaches them: it
/// records what it was asked to open and answers [opens], or throws when
/// [fails].
///
/// `MockPlatformInterfaceMixin` lets a test class stand in for the plugin
/// (`UrlLauncherPlatform.instance = …`), which otherwise only accepts a
/// subclass registered by the plugin itself.
final class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  FakeUrlLauncher._({required this.opens, required this.fails});

  /// Installs the fake for the current test; the real plugin is back when
  /// the test ends.
  static FakeUrlLauncher install({bool opens = true, bool fails = false}) {
    final real = UrlLauncherPlatform.instance;
    final fake = FakeUrlLauncher._(opens: opens, fails: fails);
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = real);
    return fake;
  }

  final bool opens;
  final bool fails;
  final opened = <(String, PreferredLaunchMode)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add((url, options.mode));
    if (fails) throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    return opens;
  }
}
