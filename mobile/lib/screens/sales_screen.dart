import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/sales_bloc.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/sale.dart';
import '../widgets/common.dart';
import '../widgets/period_chips.dart';
import '../widgets/refresh.dart';
import 'sale_form_screen.dart';

/// Daily Sales: список записей о продажах с фильтром по периоду.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, Sale sale) {
    return showConfirmDialog(
      context,
      title: 'Удалить запись?',
      message: 'Продажи за ${formatDate(sale.date)} на ${formatMoney(sale.totalAmount)} будут удалены.'
          '${sale.productId != null ? ' Списанный товар вернётся на склад.' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesBloc, SalesState>(
      listenWhen: (a, b) => a.actionStatus != b.actionStatus && b.actionKind == ActionKind.delete,
      listener: (context, state) {
        if (state.actionStatus == ActionStatus.success) showSnack(context, state.actionMessage ?? 'Удалено');
        if (state.actionStatus == ActionStatus.failure) {
          showSnack(context, state.actionMessage ?? 'Ошибка', error: true);
          context.read<SalesBloc>().add(const SalesRequested());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Продажи')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'sales-fab',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SaleFormScreen())),
          icon: const Icon(Icons.add),
          label: const Text('Добавить'),
        ),
        body: BlocBuilder<SalesBloc, SalesState>(
          builder: (context, state) {
            final bloc = context.read<SalesBloc>();
            return Column(
              children: [
                PeriodChips(filter: state.filter, onChanged: (f) => bloc.add(SalesFilterChanged(f))),
                const SizedBox(height: 8),
                Expanded(child: _body(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SalesState state) {
    final bloc = context.read<SalesBloc>();
    if (state.status == LoadStatus.loading && state.sales.isEmpty) return const LoadingView();
    if (state.status == LoadStatus.failure && state.sales.isEmpty) {
      return ErrorView(message: state.error ?? 'Ошибка', onRetry: () => bloc.add(const SalesRequested()));
    }
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        bloc.add(const SalesRequested());
        await waitForReload(bloc, (s) => s.status != LoadStatus.loading);
      },
      child: state.sales.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Нет продаж за этот период',
                  subtitle: 'Добавьте данные о заказах и выручке за день',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: state.sales.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Итого за период', style: theme.textTheme.labelMedium),
                                Text(
                                  formatMoney(state.totalAmount),
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${formatNumber(state.totalOrders)} заказов'),
                              Text('${formatNumber(state.totalItems)} шт.'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final sale = state.sales[i - 1];
                return Dismissible(
                  key: ValueKey(sale.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(color: lossColor, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, sale),
                  onDismissed: (_) => bloc.add(SaleDeleted(sale.id)),
                  child: _SaleTile(sale: sale),
                );
              },
            ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = parseIsoDate(sale.date);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${d.day}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(formatShortDate(sale.date).split(' ').last, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        title: Text(formatMoney(sale.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            '${sale.ordersCount} зак. · ${sale.itemsSold} шт.',
            if (sale.productName != null) sale.productName!,
            if (sale.note.isNotEmpty) sale.note,
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaleFormScreen(sale: sale))),
      ),
    );
  }
}
