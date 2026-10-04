import 'package:flutter/material.dart';

/// An empty screen with only its French title: the place each screen of
/// PLAN §5 will be built in, so navigation can be wired before the screens.
final class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)));
}
