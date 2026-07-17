import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/calculator_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/calc_button_grid.dart';
import '../widgets/display_panel.dart';
import '../widgets/sheet_manager_drawer.dart';
import '../widgets/history_drawer.dart';

/// The primary screen. Redesigned to:
///  - Never scroll — display + button grid always fit the viewport,
///    like a standard calculator app.
///  - Make the Standard/Scientific toggle self-explanatory via a
///    labeled SegmentedButton instead of an unlabeled switch.
///  - Keep the Sheets entry point in the AppBar (as a badge icon) so it
///    never overlaps the button grid.
///  - Reveal History via a discoverable swipe-up gesture on the display,
///    with an animated icon reveal, plus a fallback AppBar icon.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  double _dragExtent = 0;
  static const double _dragThreshold = 70;
  bool _historyTriggered = false;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) return; // only track upward drags
    setState(() {
      _dragExtent = (_dragExtent - details.delta.dy).clamp(0, 120);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragExtent >= _dragThreshold && !_historyTriggered) {
      _historyTriggered = true;
      HistoryDrawer.show(context).then((_) {
        _historyTriggered = false;
      });
    }
    setState(() => _dragExtent = 0);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;
    final dragFraction = (_dragExtent / _dragThreshold).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlayStyle(scheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CalcBook'),
          actions: [
            IconButton(
              tooltip: 'History — swipe up on the display, or tap here',
              icon: const Icon(Icons.history),
              onPressed: () => HistoryDrawer.show(context),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: 'Calculation Sheets',
                onPressed: () => SheetManagerDrawer.show(context),
                icon: Badge(
                  label: Text('${vm.sheets.length}'),
                  isLabelVisible: vm.sheets.isNotEmpty,
                  child: const Icon(Icons.folder_copy_outlined),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Standard / Scientific — a labeled segmented control so
              // the mode is always explicit, never a mystery switch.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Standard'),
                      icon: Icon(Icons.calculate_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Scientific'),
                      icon: Icon(Icons.functions, size: 18),
                    ),
                  ],
                  selected: {vm.isScientificMode},
                  onSelectionChanged: (selection) {
                    if (selection.first != vm.isScientificMode) {
                      vm.toggleScientificMode();
                    }
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),

              // Display area — flexible, and carries the swipe-up
              // gesture that reveals History with an animated icon.
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DisplayPanel(),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: dragFraction,
                            duration: const Duration(milliseconds: 80),
                            child: AnimatedScale(
                              scale: 0.7 + 0.3 * dragFraction,
                              duration: const Duration(milliseconds: 80),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color: scheme.primary,
                                    size: 28,
                                  ),
                                  Icon(
                                    Icons.history,
                                    color: scheme.primary,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Button grid — fixed proportion of the remaining space,
              // never causes the page to scroll.
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: const CalcButtonGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
