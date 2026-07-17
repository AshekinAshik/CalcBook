import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/calculation_sheet.dart';
import '../providers/calculator_provider.dart';

/// The Sheet Manager — a Material 3 modal bottom sheet listing all saved
/// Calculation Sheets. Supports:
///   - Saving the current expression as a new sheet
///   - Reloading a sheet back into the active calculator
///   - Inline rename
///   - Delete
///   - Drag-to-reorder (persists displayOrder)
class SheetManagerDrawer extends StatelessWidget {
  const SheetManagerDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const SheetManagerDrawer(),
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
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calculation Sheets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: vm.expression.trim().isEmpty
                        ? null
                        : () => _promptSaveNewSheet(context, vm),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Save current'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: vm.sheets.isEmpty
                  ? _EmptyState(scrollController: scrollController)
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: vm.sheets.length,
                      onReorder: (oldIndex, newIndex) =>
                          vm.reorderSheet(oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final sheet = vm.sheets[index];
                        return _SheetTile(
                          key: ValueKey(sheet.id),
                          sheet: sheet,
                          isActive: sheet.id == vm.activeSheetId,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _promptSaveNewSheet(
    BuildContext context,
    CalculatorProvider vm,
  ) async {
    final controller = TextEditingController(
      text: 'Sheet ${vm.sheets.length + 1}',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as new sheet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Sheet title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (title != null) {
      await vm.saveCurrentAsNewSheet(title: title);
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
        Icon(Icons.note_add_outlined, size: 48, color: scheme.outline),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No saved sheets yet',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Build an expression, then tap "Save current"',
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

class _SheetTile extends StatefulWidget {
  final CalculationSheet sheet;
  final bool isActive;
  const _SheetTile({super.key, required this.sheet, required this.isActive});

  @override
  State<_SheetTile> createState() => _SheetTileState();
}

class _SheetTileState extends State<_SheetTile> {
  bool _isRenaming = false;
  late final TextEditingController _renameController;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.sheet.title);
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  void _commitRename(CalculatorProvider vm) {
    if (widget.sheet.id != null) {
      vm.renameSheet(widget.sheet.id!, _renameController.text);
    }
    setState(() => _isRenaming = false);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: widget.isActive
          ? scheme.secondaryContainer
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ReorderableDragStartListener(
          index: vm.sheets.indexOf(widget.sheet),
          child: const Icon(Icons.drag_indicator),
        ),
        title: _isRenaming
            ? TextField(
                controller: _renameController,
                autofocus: true,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (_) => _commitRename(vm),
              )
            : Text(
                widget.sheet.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
        subtitle: Text(
          widget.sheet.expression,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'monospace',
            color: scheme.onSurfaceVariant,
          ),
        ),
        onTap: () {
          if (_isRenaming) return;
          vm.reloadSheet(widget.sheet);
          Navigator.pop(context);
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _isRenaming ? 'Confirm rename' : 'Rename',
              icon: Icon(_isRenaming ? Icons.check : Icons.edit_outlined),
              onPressed: () {
                if (_isRenaming) {
                  _commitRename(vm);
                } else {
                  setState(() => _isRenaming = true);
                }
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, vm),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CalculatorProvider vm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sheet?'),
        content: Text('"${widget.sheet.title}" will be permanently removed.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && widget.sheet.id != null) {
      await vm.deleteSheet(widget.sheet.id!);
    }
  }
}
