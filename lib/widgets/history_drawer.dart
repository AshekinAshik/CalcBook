import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/calculation_history_entry.dart';
import '../providers/calculator_provider.dart';
import 'drawer_grabber.dart';

/// The History drawer — every calculation the user has evaluated with
/// "=" is logged here automatically, independent of the deliberately
/// curated Calculation Sheets. Supports tap-to-reuse, swipe-to-delete
/// per entry, and a "Clear all" action.
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
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.history, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'History',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (vm.history.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _confirmClearAll(context, vm),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear all'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: vm.history.isEmpty
                  ? _EmptyState(scrollController: scrollController)
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: vm.history.length,
                      itemBuilder: (context, index) {
                        final entry = vm.history[index];
                        return _HistoryTile(entry: entry);
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
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This removes every logged calculation. Saved Sheets are not affected.',
        ),
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
      await vm.clearHistory();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final ScrollController scrollController;
  const _EmptyState({required this.scrollController});

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
            'No calculations yet',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Every result you calculate shows up here automatically',
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
          // Explicit onSurface color — this previously had no color set
          // at all, which relied on an ambient default that read poorly
          // against the card's surfaceContainerLow fill in dark mode.
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
