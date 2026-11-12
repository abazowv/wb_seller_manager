import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/analytics_bloc.dart';
import '../blocs/common.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/reports.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/refresh.dart';
import 'product_details_screen.dart';

/// Аналитика: графики по дням/неделям/месяцам, сравнение периодов, лучшие товары.
class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AnalyticsBloc>();
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        final report = state.report;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<AnalyticsGroup>(
                  segments: [
                    for (final g in AnalyticsGroup.values) ButtonSegment(value: g, label: Text(g.label)),
                  ],
                  selected: {state.group},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => bloc.add(AnalyticsGroupChanged(s.first)),
                ),
              ),
            ),
            if (state.status == LoadStatus.loading && report != null) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: () {
                if (report == null) {
                  return state.status == LoadStatus.failure
                      ? ErrorView(message: state.error ?? 'Ошибка', onRetry: () => bloc.add(const AnalyticsRequested()))
                      : const LoadingView();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    bloc.add(AnalyticsGroupChanged(state.group));
                    await waitForReload(bloc, (s) => s.status != LoadStatus.loading);
                  },
                  child: _content(context, report, state.group),
                );
              }(),
            ),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, AnalyticsReport r, AnalyticsGroup group) {
    final theme = Theme.of(context);
    final t = r.totals;
    final p = r.previous;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Последние ${group.rangeLabel}: ${formatShortDate(t.from!)} — ${formatShortDate(t.to!)}',
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Text('Выручка и прибыль', style: theme.textTheme.titleSmall),
                ),
                RevenueBarChart(points: r.points, group: r.group, showProfit: true, height: 220),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChartLegend(items: {'Выручка': theme.colorScheme.primary, 'Прибыль': profitColor}),
                ),
              ],
            ),
          ),
        ),
        SectionHeader('Сравнение с периодом до (${group.previousLabel})'),
        Card(
          child: Column(
            children: [
              _CompareRow(label: 'Выручка', current: formatMoney(t.revenue), previous: formatMoney(p.revenue), change: r.change['revenue']),
              _CompareRow(label: 'Прибыль', current: signedMoney(t.profit), previous: signedMoney(p.profit), change: r.change['profit']),
              _CompareRow(label: 'Заказы', current: formatNumber(t.orders), previous: formatNumber(p.orders), change: r.change['orders']),
              _CompareRow(
                label: 'Продано, шт.',
                current: formatNumber(t.itemsSold),
                previous: formatNumber(p.itemsSold),
                change: r.change['items_sold'],
              ),
            ],
          ),
        ),
        const SectionHeader('Лучшие товары'),
        if (r.topProducts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Нет продаж, привязанных к товарам, за этот период. '
                  'Указывайте товар при добавлении продажи, чтобы видеть рейтинг.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < r.topProducts.length; i++) _TopProductTile(rank: i + 1, item: r.topProducts[i]),
              ],
            ),
          ),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.current, required this.previous, required this.change});

  final String label;
  final String current;
  final String previous;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(label),
      subtitle: Text('было: $previous', style: theme.textTheme.bodySmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(current, style: const TextStyle(fontWeight: FontWeight.w700)),
          ChangeBadge(percent: change),
        ],
      ),
    );
  }
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({required this.rank, required this.item});

  final int rank;
  final TopProduct item;

  @override
  Widget build(BuildContext context) {
    final medal = [const Color(0xFFFFB300), const Color(0xFF9E9E9E), const Color(0xFFB8733C)];
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          ProductImage(path: item.imageUrl, size: 44, radius: 10),
          Positioned(
            left: -6,
            top: -6,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: rank <= 3 ? medal[rank - 1] : Theme.of(context).colorScheme.secondary,
              child: Text('$rank', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${formatNumber(item.itemsSold)} шт. · прибыль ${signedMoney(item.profit)}'),
      trailing: Text(formatMoney(item.revenue), style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductDetailsScreen(productId: item.id))),
    );
  }
}
