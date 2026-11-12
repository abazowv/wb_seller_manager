import 'package:flutter/material.dart';

import '../blocs/sales_bloc.dart';
import '../core/formatters.dart';

/// Горизонтальные чипы выбора периода + выбор произвольного диапазона дат.
class PeriodChips extends StatelessWidget {
  const PeriodChips({super.key, required this.filter, required this.onChanged, this.periods = SalesPeriod.values});

  final SalesFilter filter;
  final ValueChanged<SalesFilter> onChanged;
  final List<SalesPeriod> periods;

  Future<void> _pickRange(BuildContext context) async {
    final today = dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: filter.from != null && filter.to != null
          ? DateTimeRange(start: filter.from!, end: filter.to!)
          : DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
      helpText: 'Выберите период',
      saveText: 'Готово',
    );
    if (range != null) onChanged(SalesFilter(period: SalesPeriod.custom, from: range.start, to: range.end));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final p in periods)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  p == SalesPeriod.custom && filter.period == SalesPeriod.custom && filter.from != null
                      ? '${formatShortDate(toIsoDate(filter.from!))} – ${formatShortDate(toIsoDate(filter.to!))}'
                      : p.label,
                ),
                avatar: p == SalesPeriod.custom ? const Icon(Icons.date_range, size: 18) : null,
                selected: filter.period == p,
                onSelected: (_) {
                  if (p == SalesPeriod.custom) {
                    _pickRange(context);
                  } else {
                    onChanged(SalesFilter.preset(p));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
