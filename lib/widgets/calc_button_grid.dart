import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/calculator_provider.dart';
import 'calc_button.dart';

/// The main button grid. Every row — including the optional Scientific
/// rows — is wrapped in `Expanded`, so the grid always divides whatever
/// vertical space its parent gives it evenly among rows. This is what
/// guarantees the calculator never needs to scroll: toggling Scientific
/// mode on adds more rows, and each existing row simply gets a little
/// shorter to compensate, exactly like native calculator apps.
class CalcButtonGrid extends StatelessWidget {
  const CalcButtonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    // `read` for the instance used by key callbacks (doesn't subscribe —
    // the provider object itself never changes), `select` for the one
    // field that should actually trigger a rebuild here. Previously this
    // used a broad `watch`, which rebuilt all ~25 button widgets on
    // every single keystroke even though only the Scientific toggle
    // ever changes what this grid renders.
    final vm = context.read<CalculatorProvider>();
    final isScientificMode =
        context.select<CalculatorProvider, bool>((p) => p.isScientificMode);

    final rows = <List<_KeySpec>>[
      if (isScientificMode) ..._scientificRows(vm),
      ..._standardRows(vm),
    ];

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: rows
          .map(
            (row) => Expanded(
              child: Row(
                children: row.map((k) => Expanded(child: _buildKey(k))).toList(),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKey(_KeySpec k) {
    return CalcButton(
      label: k.label,
      onTap: k.onTap,
      role: k.role,
      fontSize: k.fontSize,
    );
  }

  List<List<_KeySpec>> _scientificRows(CalculatorProvider vm) {
    return [
      [
        _KeySpec('sin', () => vm.appendToken('sin('), role: CalcButtonRole.function, fontSize: 16),
        _KeySpec('cos', () => vm.appendToken('cos('), role: CalcButtonRole.function, fontSize: 16),
        _KeySpec('tan', () => vm.appendToken('tan('), role: CalcButtonRole.function, fontSize: 16),
        _KeySpec('log', () => vm.appendToken('log('), role: CalcButtonRole.function, fontSize: 16),
        _KeySpec('ln', () => vm.appendToken('ln('), role: CalcButtonRole.function, fontSize: 16),
      ],
      [
        _KeySpec('√', () => vm.appendToken('sqrt('), role: CalcButtonRole.function, fontSize: 18),
        _KeySpec('xʸ', () => vm.appendToken('^'), role: CalcButtonRole.function, fontSize: 16),
        _KeySpec('(', () => vm.appendToken('('), role: CalcButtonRole.function, fontSize: 18),
        _KeySpec(')', () => vm.appendToken(')'), role: CalcButtonRole.function, fontSize: 18),
        _KeySpec('π', () => vm.appendToken('π'), role: CalcButtonRole.function, fontSize: 18),
      ],
    ];
  }

  List<List<_KeySpec>> _standardRows(CalculatorProvider vm) {
    return [
      [
        _KeySpec('AC', vm.clearAll, role: CalcButtonRole.subtle),
        _KeySpec('⌫', vm.backspace, role: CalcButtonRole.subtle),
        _KeySpec('%', () => vm.appendToken('%'), role: CalcButtonRole.subtle),
        _KeySpec('÷', () => vm.appendToken('÷'), role: CalcButtonRole.operatorKey),
      ],
      [
        _KeySpec('7', () => vm.appendToken('7')),
        _KeySpec('8', () => vm.appendToken('8')),
        _KeySpec('9', () => vm.appendToken('9')),
        _KeySpec('×', () => vm.appendToken('×'), role: CalcButtonRole.operatorKey),
      ],
      [
        _KeySpec('4', () => vm.appendToken('4')),
        _KeySpec('5', () => vm.appendToken('5')),
        _KeySpec('6', () => vm.appendToken('6')),
        _KeySpec('−', () => vm.appendToken('-'), role: CalcButtonRole.operatorKey),
      ],
      [
        _KeySpec('1', () => vm.appendToken('1')),
        _KeySpec('2', () => vm.appendToken('2')),
        _KeySpec('3', () => vm.appendToken('3')),
        _KeySpec('+', () => vm.appendToken('+'), role: CalcButtonRole.operatorKey),
      ],
      [
        _KeySpec('.', () => vm.appendToken('.')),
        _KeySpec('0', () => vm.appendToken('0')),
        _KeySpec('00', () => vm.appendToken('00')),
        _KeySpec('=', vm.evaluateEquals, role: CalcButtonRole.accent),
      ],
    ];
  }
}

class _KeySpec {
  final String label;
  final VoidCallback onTap;
  final CalcButtonRole role;
  final double fontSize;
  _KeySpec(
    this.label,
    this.onTap, {
    this.role = CalcButtonRole.number,
    this.fontSize = 24,
  });
}
