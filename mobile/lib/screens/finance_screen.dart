import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/finance_bloc.dart';
import '../blocs/sales_bloc.dart' show SalesPeriod;
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/reports.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/period_chips.dart';
import '../widgets/refresh.dart';

/// Финансы: выручка, себестоимость, оценочная прибыль за период.
class FinanceView extends StatelessWidget {
  const FinanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FinanceBloc>();
    return BlocBuilder<FinanceBloc, FinanceState>(
      builder: (context, state) {
        final report = state.report;
        return Column(
          children: [
            const SizedBox(height: 12),
            PeriodChips(
              filter: state.filter,
              periods: const [
                SalesPeriod.week,
                SalesPeriod.month,
                SalesPeriod.currentMonth,
                SalesPeriod.today,
                SalesPeriod.custom,
              ],
              onChanged: (f) => bloc.add(FinancePeriodChanged(f)),
            ),
            if (state.status == LoadStatus.loading && report != null) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: () {
                if (report == null) {
                  return state.status == LoadStatus.failure
                      ? ErrorView(message: state.error ?? 'Ошибка', onRetry: () => bloc.add(const FinanceRequested()))
                      : const LoadingView();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    bloc.add(FinancePeriodChanged(state.filter));
                    await waitForReload(bloc, (s) => s.status != LoadStatus.loading);
                  },
                  child: _content(context, report),
                );
              }(),
            ),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, FinanceReport r) {
    final theme = Theme.of(context);
    final c = r.current;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          '${formatDate(c.from!)} — ${formatDate(c.to!)}',
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        StatGrid(children: [
          StatCard(
            label: 'Выручка',
            value: formatMoney(c.revenue),
            icon: Icons.payments_outlined,
            footer: ChangeBadge(percent: r.revenueChange, suffix: ' к прошлому'),
          ),
          StatCard(
            label: 'Себестоимость',
            value: formatMoney(c.cost),
            icon: Icons.shopping_cart_outlined,
            color: warningColor,
            footer: Text(
              c.estimatedCost > 0 ? 'из них оценка ${formatMoney(c.estimatedCost)}' : 'по закупочным ценам',
              style: theme.textTheme.labelSmall,
            ),
          ),
          StatCard(
            label: 'Оценочная прибыль',
            value: signedMoney(c.profit),
            icon: Icons.trending_up,
            color: profitTone(c.profit),
            footer: ChangeBadge(percent: r.profitChange, suffix: ' к прошлому'),
          ),
          StatCard(
            label: 'Маржинальность',
            value: formatPercent(c.marginPercent),
            icon: Icons.percent,
            color: Colors.indigo,
            footer: Text('средний чек ${formatMoney(c.avgCheck)}', style: theme.textTheme.labelSmall),
          ),
        ]),
        const SectionHeader('Динамика по дням'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
            child: Column(
              children: [
                FinanceLineChart(points: r.byDay),
                const SizedBox(height: 8),
                ChartLegend(items: {
                  'Выручка': theme.colorScheme.primary,
                  'Себестоимость': warningColor,
                  'Прибыль': profitColor,
                }),
              ],
            ),
          ),
        ),
        const SectionHeader('Сводка'),
        Card(
          child: Column(
            children: [
              _line(context, 'Заказов', formatNumber(c.orders)),
              _line(context, 'Продано штук', formatNumber(c.itemsSold)),
              _line(context, 'Выручка', formatMoney(c.revenue)),
              _line(context, '− Себестоимость', formatMoney(c.cost)),
              const Divider(height: 1),
              _line(context, '= Оценочная прибыль', signedMoney(c.profit), color: profitTone(c.profit), bold: true),
              const Divider(height: 1),
              _line(
                context,
                'Прошлый период (${formatShortDate(r.previous.from!)} – ${formatShortDate(r.previous.to!)})',
                '${formatMoney(r.previous.revenue)} / ${signedMoney(r.previous.profit)}',
              ),
              _line(context, 'Товар на складе (по закупке)', formatMoney(r.stockValue)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Прибыль оценочная: себестоимость считается по закупочной цене товара. Для продаж без '
          'привязки к товару используется средняя доля закупки в цене ваших товаров. '
          'Комиссии и логистика Wildberries не учитываются.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, String label, String value, {Color? color, bool bold = false}) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
    );
  }
}
