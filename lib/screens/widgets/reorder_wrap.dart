import 'package:flutter/material.dart';

import '../../ui.dart';

/// ↔️ ریزا پەیڤێن هەلبژارتی: پەیڤەکێ بکێشە و ل سەر یەکا دی بهێلە ➔ جهێ خۆ دگوهۆڕیت
/// (پێدڤی نینە هەمی پەیڤان راکەی و ژ نوی هەلبژێری)
class ReorderWrap extends StatelessWidget {
  final List<int> items;
  final Widget Function(int item) build;
  final void Function(int from, int to) onMove;
  final bool enabled;
  final double spacing;
  const ReorderWrap({super.key, required this.items, required this.build, required this.onMove, this.enabled = true, this.spacing = 0});

  @override
  Widget build(BuildContext context) {
    Widget cell(int k) {
      final child = build(items[k]);
      if (!enabled) return child;
      return DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != k,
        onAcceptWithDetails: (d) => onMove(d.data, k),
        builder: (_, cand, __) => Draggable<int>(
          data: k,
          feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.9, child: child)),
          childWhenDragging: Opacity(opacity: 0.25, child: child),
          child: Container(
            decoration: cand.isEmpty
                ? null
                : BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.accent, width: 3), right: BorderSide(color: AppColors.accent, width: 3))),
            child: child,
          ),
        ),
      );
    }

    return Wrap(spacing: spacing, runSpacing: spacing, children: [
      for (var k = 0; k < items.length; k++) cell(k),
      if (enabled && items.length >= 2)
        DragTarget<int>(
          onWillAcceptWithDetails: (d) => d.data != items.length - 1,
          onAcceptWithDetails: (d) => onMove(d.data, items.length),
          builder: (_, cand, __) => Container(
            width: cand.isEmpty ? 30 : 56,
            height: 44,
            decoration: cand.isEmpty
                ? null
                : BoxDecoration(border: Border.all(color: AppColors.accent, width: 2), borderRadius: BorderRadius.circular(10)),
          ),
        ),
    ]);
  }
}

/// جهێ پەیڤێ د لیستێ دا بگوهۆڕە (to = جهێ نوو؛ length = دوماهیێ)
void moveItem(List<int> list, int from, int to) {
  final item = list.removeAt(from);
  list.insert(to > from ? (to - 1).clamp(0, list.length) : to, item);
}
