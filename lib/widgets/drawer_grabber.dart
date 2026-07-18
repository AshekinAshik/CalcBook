import 'package:flutter/material.dart';

/// The small rounded grabber bar shown at the top of both the Sheet
/// Manager and History bottom sheets. Extracted into one place so the
/// two drawers stay visually consistent and there's a single source of
/// truth for this bit of chrome.
class DrawerGrabber extends StatelessWidget {
  const DrawerGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
