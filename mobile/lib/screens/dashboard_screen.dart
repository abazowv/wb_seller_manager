import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_bloc.dart';
import '../blocs/common.dart';
import '../blocs/dashboard_bloc.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/reports.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'product_details_screen.dart';
import 'profile_screen.dart';
import 'sale_form_screen.dart';

enum _Period { today, week, month }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Period _period = _Period.today;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Привет, ${user?.name ?? ''}!', overflow: TextOverflow.ellipsis),
            Text(
              formatLongDate(DateTime.now()),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Профиль и настройки',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard-fab',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SaleFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Продажа'),
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          final data = state.data;
          if (data == null) {
            if (state.status == LoadStatus.failure) {
              return ErrorView(
                message: state.error ?? 'Ошибка',
                onRetry: () => context.read<DashboardBloc>().add(const DashboardRequested()),
              );
            }
            return const LoadingView();
          }
          return RefreshIndicator(
            onRefresh: () async {
              // Не silent: сначала придёт loading (данные остаются на экране), затем результат.
              final bloc = context.read<DashboardBloc>()..add(const DashboardRequested());
              await bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
            },
            child: _content(context, data, state),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, DashboardData data, DashboardState state) {
    final theme = Theme.of(context);
    final totals = switch (_period) {
      _Period.today => data.today,
      _Period.week => data.week,
      _Period.month => data.month,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        if (state.status == LoadStatus.failure && state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Не удалось обновить: ${state.error}', style: const TextStyle(color: lossColor)),
          ),
        SegmentedButton<_Period>(
          segments: const [
            ButtonSegment(value: _Period.today, label: Text('Сегодня')),
            ButtonSegment(value: _Period.week, label: Text('Неделя')),
            ButtonSegment(value: _Period.month, label: Text('Месяц')),
          ],
          selected: {_period},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
        const SizedBox(height: 16),
        _RevenueHero(totals: totals),
        const SizedBox(height: 12),
        StatGrid(children: [
          StatCard(label: 'Заказы', value: formatNumber(totals.orders), icon: Icons.shopping_bag_outlined),
          StatCard(
            label: 'Продано, шт.',
            value: formatNumber(totals.itemsSold),
            icon: Icons.local_shipping_outlined,
            color: Colors.indigo,
          ),
          StatCard(
            label: 'Оценочная прибыль',
            value: signedMoney(totals.profit),
            icon: Icons.trending_up,
            color: profitTone(totals.profit),
            footer: Text('маржа ${formatPercent(totals.marginPercent)}', style: theme.textTheme.labelSmall),
          ),
          StatCard(
            label: 'Товаров на складе',
            value: '${formatNumber(data.stock.totalUnits)} шт.',
            icon: Icons.warehouse_outlined,
            color: Colors.teal,
            footer: Text(
              '${data.stock.inStockCount} из ${data.stock.productsCount} позиций',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ]),
        if (data.stock.lowStock.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LowStockCard(stock: data.stock, onOpen: () => widget.onNavigate(HomeTab.inventory)),
        ],
        SectionHeader(
          'Выручка за 7 дней',
          action: TextButton(onPressed: () => widget.onNavigate(HomeTab.reports), child: const Text('Аналитика')),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: RevenueBarChart(points: data.chart, height: 180),
          ),
        ),
        SectionHeader(
          'Последние продажи',
          action: TextButton(onPressed: () => widget.onNavigate(HomeTab.sales), child: const Text('Все')),
        ),
        if (data.recentSales.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Пока нет продаж. Нажмите «Продажа», чтобы добавить первую запись.', textAlign: TextAlign.center),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final s in data.recentSales)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.receipt_long, color: theme.colorScheme.onPrimaryContainer, size: 20),
                    ),
                    title: Text(formatMoney(s.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${formatDate(s.date)} · ${s.ordersCount} зак. · ${s.itemsSold} шт.'
                      '${s.productName != null ? '\n${s.productName}' : ''}',
                    ),
                    isThreeLine: s.productName != null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => SaleFormScreen(sale: s)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({required this.totals});

  final PeriodTotals totals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [scheme.primary, const Color(0xFFCB11AB)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Продажи', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(totals.revenue),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Средний чек: ${formatMoney(totals.avgCheck)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.stock, required this.onOpen});

  final StockSummary stock;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final items = stock.lowStock.take(3).toList();
    return Card(
      color: warningColor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: warningColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Заканчивается товар: ${stock.lowStock.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: onOpen, child: const Text('На склад')),
              ],
            ),
            for (final p in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: ProductImage(path: p.imageUrl, size: 36, radius: 8),
                title: Text(p.name, overflow: TextOverflow.ellipsis),
                trailing: StockBadge(stock: p.stock, threshold: stock.lowStockThreshold),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ProductDetailsScreen(productId: p.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
