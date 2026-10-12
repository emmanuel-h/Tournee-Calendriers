import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the button under the widget [button] (a `PrimaryButton`, a
/// `SecondaryButton`…) can be pressed. Material buttons are all
/// `ButtonStyleButton`s, disabled when `onPressed` is null.
bool isEnabled(WidgetTester tester, Finder button) => tester
    .widget<ButtonStyleButton>(
      find.descendant(
        of: button,
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    )
    .enabled;
