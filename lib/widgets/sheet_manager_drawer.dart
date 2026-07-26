import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/calculation_sheet.dart';
import '../providers/calculator_provider.dart';
import 'drawer_grabber.dart';

/// The Sheet Manager — a Material 3 modal bottom sheet listing all saved
/// Calculation Sheets. Supports:
///   - Saving the current expression as a new sheet (title + optional
///     short description)
///   - Reloading a sheet back into the active calculator
///   - Editing a sheet's title and description via a dedicated dialog
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
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calculation Sheets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (vm.activeSheetId != null) ...[
                    // A sheet is loaded — the primary action is now
                    // updating *that* sheet in place (previously there
                    // was no way to persist changes back into a reloaded
                    // sheet at all, only ever create a new one).
                    FilledButton.tonalIcon(
                      onPressed: vm.expression.trim().isEmpty
                          ? null
                          : () => _updateActiveSheet(context, vm),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Update sheet'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Save as a new sheet instead',
                      onPressed: vm.expression.trim().isEmpty
                          ? null
                          : () => _promptSaveNewSheet(context, vm),
                      icon: const Icon(Icons.add),
                    ),
                  ] else
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
    final suggestedName = 'Sheet ${vm.sheets.length + 1}';
    final result = await _showSheetDetailsDialog(
      context,
      dialogTitle: 'Save as new sheet',
      initialTitle: suggestedName,
      initialDescription: '',
      selectSuggestedTitle: true,
      confirmLabel: 'Save',
    );
    if (result != null) {
      await vm.saveCurrentAsNewSheet(
        title: result.title,
        description: result.description,
      );
    }
  }

  Future<void> _updateActiveSheet(
    BuildContext context,
    CalculatorProvider vm,
  ) async {
    await vm.saveToActiveSheet();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sheet updated'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Small value type carrying the two fields the Sheet Details dialog
/// collects, so save and edit flows can share one dialog implementation.
class _SheetDetailsResult {
  final String title;
  final String description;
  const _SheetDetailsResult(this.title, this.description);
}

/// Shared title+description dialog used for both "Save as new sheet"
/// and "Edit sheet". Kept as a single implementation so the two flows
/// can never visually drift apart.
Future<_SheetDetailsResult?> _showSheetDetailsDialog(
  BuildContext context, {
  required String dialogTitle,
  required String initialTitle,
  required String initialDescription,
  required String confirmLabel,
  bool selectSuggestedTitle = false,
}) {
  final titleController = TextEditingController(text: initialTitle);
  if (selectSuggestedTitle) {
    // Select the suggested name so the first keystroke replaces it
    // instead of appending to it (previously produced titles like
    // "Sheet 1sheet 1" when typing over an unselected default).
    titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initialTitle.length,
    );
  }
  final descriptionController = TextEditingController(text: initialDescription);

  return showDialog<_SheetDetailsResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final isTitleEmpty = titleController.text.trim().isEmpty;
        return AlertDialog(
          title: Text(dialogTitle),
          // Fixed, landscape-ratio content box (wider than tall) instead
          // of letting the dialog auto-size to its content — without
          // this, the description field's maxLength counter text
          // ("123/250") could make the dialog's intrinsic width grow
          // while typing. SingleChildScrollView keeps this safe against
          // overflow (e.g. when the keyboard shrinks available vertical
          // space) without needing the box itself to grow.
          content: SizedBox(
            width: 360,
            height: 200,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    maxLength: CalculationSheet.maxTitleLength,
                    // Reactively validated below — this used to fail
                    // silently: confirming with an empty title closed
                    // the dialog with no error and no change saved,
                    // leaving the user thinking it had worked.
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Sheet title',
                      errorText: isTitleEmpty ? 'Title is required' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    // Kept short and capped so the description never
                    // dominates the dialog or the list — it's a note,
                    // not a document.
                    maxLines: 3,
                    minLines: 2,
                    maxLength: CalculationSheet.maxDescriptionLength,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isTitleEmpty
                  ? null
                  : () => Navigator.pop(
                        context,
                        _SheetDetailsResult(
                          titleController.text,
                          descriptionController.text,
                        ),
                      ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
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

class _SheetTile extends StatelessWidget {
  final CalculationSheet sheet;
  final bool isActive;
  const _SheetTile({super.key, required this.sheet, required this.isActive});

  Future<void> _editSheet(BuildContext context, CalculatorProvider vm) async {
    final result = await _showSheetDetailsDialog(
      context,
      dialogTitle: 'Edit sheet',
      initialTitle: sheet.title,
      initialDescription: sheet.description,
      confirmLabel: 'Save changes',
    );
    if (result != null && sheet.id != null) {
      await vm.updateSheetDetails(
        sheet.id!,
        title: result.title,
        description: result.description,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;

    // Explicit "on" colors matched to the tile's background — relying
    // on ambient/default text color caused low-contrast text in dark
    // mode when the card used a custom secondaryContainer fill.
    final onTileColor =
        isActive ? scheme.onSecondaryContainer : scheme.onSurface;
    final onTileVariant = isActive
        ? scheme.onSecondaryContainer.withValues(alpha: 0.75)
        : scheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: isActive ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ReorderableDragStartListener(
          index: vm.sheets.indexOf(sheet),
          child: Icon(Icons.drag_indicator, color: onTileVariant),
        ),
        title: Text(
          sheet.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, color: onTileColor),
        ),
        // A compact, capped-height subtitle: the expression preview
        // (single line) plus the description (up to 2 lines) if present
        // — kept small and muted so the list stays scannable rather
        // than clumsy, per the "minimal, standard" goal.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sheet.expression,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'monospace', color: onTileVariant),
            ),
            if (sheet.description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  sheet.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: onTileVariant.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          vm.reloadSheet(sheet);
          Navigator.pop(context);
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit sheet',
              icon: Icon(Icons.edit_outlined, color: onTileVariant),
              onPressed: () => _editSheet(context, vm),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline, color: onTileVariant),
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
        content: Text(
          '"${sheet.title}" and its own history will be permanently removed.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && sheet.id != null) {
      await vm.deleteSheet(sheet.id!);
    }
  }
}
