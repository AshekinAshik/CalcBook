import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/calculator_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/calc_button_grid.dart';
import '../widgets/display_panel.dart';
import '../widgets/sheet_manager_drawer.dart';
import '../widgets/history_drawer.dart';

/// The primary screen:
///  - Never scrolls — display + button grid always fit the viewport,
///    like a standard calculator app.
///  - Standard/Scientific toggle is a labeled SegmentedButton, never a
///    mystery switch.
///  - Sheets access lives in the AppBar (badge icon), so it never
///    overlaps the button grid.
///  - History is revealed via a swipe-up gesture on the display — with
///    a standard "drag handle + label" affordance instead of a lone,
///    ambiguous arrow — plus a fallback AppBar icon for discoverability.
///
/// Only the AppBar's badge/toggle state is subscribed here via
/// `context.select`; the display and button grid manage their own
/// narrower subscriptions, so a keystroke doesn't force this whole
/// screen (AppBar, SegmentedButton, etc.) to rebuild.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  double _dragExtent = 0;
  static const double _dragThreshold = 64;
  bool _historyTriggered = false;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) return; // only track upward drags
    setState(() {
      _dragExtent = (_dragExtent - details.delta.dy).clamp(0, 100);
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
    final scheme = Theme.of(context).colorScheme;
    final sheetsCount =
        context.select<CalculatorProvider, int>((vm) => vm.sheets.length);
    final isScientificMode = context
        .select<CalculatorProvider, bool>((vm) => vm.isScientificMode);
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
                  label: Text('$sheetsCount'),
                  isLabelVisible: sheetsCount > 0,
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
                  selected: {isScientificMode},
                  onSelectionChanged: (selection) {
                    if (selection.first != isScientificMode) {
                      context.read<CalculatorProvider>().toggleScientificMode();
                    }
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),

              // Display area — flexible, and carries the swipe-up
              // gesture that reveals History. Given a larger flex share
              // than before so the calculation area has real breathing
              // room, matching standard mobile calculator proportions
              // (roughly 40/60 display-to-keypad in Standard mode).
              Expanded(
                flex: isScientificMode ? 2 : 3,
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
                        bottom: 6,
                        child: IgnorePointer(
                          child: _HistoryPeekHandle(dragFraction: dragFraction),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Button grid — a smaller proportion of the remaining
              // space than before (never causes the page to scroll).
              // Scientific mode gets a bit more room since it has two
              // extra rows to fit.
              Expanded(
                flex: isScientificMode ? 5 : 4,
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

/// The swipe-up-for-History affordance shown at the bottom of the
/// display. At rest it's a small, standard "drag handle" pill — the
/// same universally-recognized shape used by bottom sheets — which by
/// itself is a more familiar "there's more here" cue than a lone arrow
/// icon. As the user drags, it morphs into an explicit label ("History"
/// + icon) so there's no ambiguity about what's about to open.
class _HistoryPeekHandle extends StatelessWidget {
  final double dragFraction;
  const _HistoryPeekHandle({required this.dragFraction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Explicit label + icon, fades and slides in only once the user
        // has committed to the gesture.
        AnimatedOpacity(
          opacity: dragFraction,
          duration: const Duration(milliseconds: 100),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'History',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // The persistent handle pill — always faintly visible so the
        // gesture is discoverable even before the user starts dragging.
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 36 + (8 * dragFraction),
          height: 4,
          decoration: BoxDecoration(
            color: Color.lerp(
              scheme.outlineVariant,
              scheme.primary,
              dragFraction,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
