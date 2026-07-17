import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/calculator_provider.dart';

/// Shows the live expression trail plus a smaller live-preview result
/// beneath it, right-aligned in classic calculator style. Also surfaces
/// a small "active sheet" chip when a saved sheet is currently loaded.
class DisplayPanel extends StatelessWidget {
  const DisplayPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;
    final activeSheet = vm.activeSheetId == null
        ? null
        : vm.sheets.where((s) => s.id == vm.activeSheetId).firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (activeSheet != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(activeSheet.title),
                avatar: const Icon(Icons.description_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                backgroundColor: scheme.secondaryContainer,
              ),
            ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              vm.expression.isEmpty ? '0' : vm.expression,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                vm.liveResult,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                maxLines: 1,
              ),
            ),
          ),
          if (vm.history.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 16,
                color: scheme.outline.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
