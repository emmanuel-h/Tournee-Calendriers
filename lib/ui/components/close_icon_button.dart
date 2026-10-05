import 'package:flutter/material.dart';

/// The ✕ that leaves a screen or a sheet: the top bar of « Modifier la
/// rue » and « Modifier les portes », the title line of the building grid.
///
/// An `IconButton` keeps a 48 dp tap target around its 24 dp glyph; the
/// [tooltip] is also the name screen readers say.
final class CloseIconButton extends StatelessWidget {
  const CloseIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: const Icon(Icons.close),
    onPressed: onPressed,
  );
}
