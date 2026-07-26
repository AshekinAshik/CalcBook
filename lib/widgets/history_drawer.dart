import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/calculation_history_entry.dart';
import '../models/calculation_sheet.dart';
import '../providers/calculator_provider.dart';
import 'drawer_grabber.dart';

/// The History drawer. It's context-aware: when no sheet is currently
/// loaded it shows *General* history (every calculation made outside
/// any sheet); when a sheet is active it shows *that sheet's own*
/// history instead — two logically separate lists that never mix.
/// Supports tap-to-reuse, swipe-to-delete per entry, and "Clear all"
/// scoped to whichever list is showing.
class HistoryDrawer extends StatelessWidget {
  const HistoryDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const HistoryDrawer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;

    final CalculationSheet? scopedSheet = vm.activeSheetId == null
        ? null
        : vm.sheets.where((s) => s.id == vm.activeSheetId).firstOrNull;
    final entries = scopedSheet == null
        ? vm.generalHistory
        : vm.sheetHistory(scopedSheet.id!);

    final headerTitle = scopedSheet == null ? 'History' : 'Sheet History';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const DrawerGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.history, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (entries.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          _confirmClearAll(context, vm, scopedSheet),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear all'),
                    ),
                ],
              ),
            ),
            if (scopedSheet != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Calculations made in "${scopedSheet.title}"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? _EmptyState(
                      scrollController: scrollController,
                      isScoped: scopedSheet != null,
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _HistoryTile(entry: entries[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    CalculatorProvider vm,
    CalculationSheet? scopedSheet,
  ) async {
    final message = scopedSheet == null
        ? 'This removes every logged General calculation. Sheets and their own history are not affected.'
        : 'This removes every logged calculation for "${scopedSheet.title}". Other sheets, General history, and the sheet itself are not affected.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (scopedSheet == null) {
        await vm.clearGeneralHistory();
      } else {
        await vm.clearSheetHistory(scopedSheet.id!);
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  final ScrollController scrollController;
  final bool isScoped;
  const _EmptyState({required this.scrollController, required this.isScoped});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      children: [
        const SizedBox(height: 48),
        Icon(Icons.history_toggle_off, size: 48, color: scheme.outline),
        const SizedBox(height: 12),
        Center(
          child: Text(
            isScoped ? 'No calculations in this sheet yet' : 'No calculations yet',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            isScoped
                ? 'Calculate something while this sheet is open and it\'ll show up here'
                : 'Every result you calculate outside a sheet shows up here automatically',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final CalculationHistoryEntry entry;
  const _HistoryTile({required this.entry});

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final isToday =
        t.year == now.year && t.month == now.month && t.day == now.day;
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $ampm';
    if (isToday) return time;
    return '${t.month}/${t.day} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        if (entry.id != null) vm.deleteHistoryEntry(entry.id!);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            entry.expression,
            style: TextStyle(
              fontFamily: 'monospace',
              color: scheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '= ${entry.result}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
          trailing: Text(
            _formatTime(entry.timestamp),
            style: TextStyle(color: scheme.outline, fontSize: 12),
          ),
          onTap: () {
            vm.reuseHistoryEntry(entry);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
