import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/inventory_bloc.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/stock_movement.dart';
import '../widgets/common.dart';
import '../widgets/refresh.dart';

/// История движений склада (все товары или один товар).
class InventoryHistoryScreen extends StatelessWidget {
  const InventoryHistoryScreen({super.key, this.productId});

  final int? productId;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<InventoryBloc>();
    return BlocListener<InventoryBloc, InventoryState>(
      listenWhen: (a, b) => a.actionStatus != b.actionStatus && b.actionKind == ActionKind.delete,
      listener: (context, state) {
        if (state.actionStatus == ActionStatus.success) showSnack(context, state.actionMessage ?? 'Удалено');
        if (state.actionStatus == ActionStatus.failure) showSnack(context, state.actionMessage ?? 'Ошибка', error: true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('История склада')),
        body: BlocBuilder<InventoryBloc, InventoryState>(
          builder: (context, state) {
            var items = state.visibleMovements;
            if (productId != null) items = items.where((m) => m.productId == productId).toList();
            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final t in <MovementType?>[null, MovementType.stockIn, MovementType.stockOut])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t?.label ?? 'Все'),
                            selected: state.historyFilter == t,
                            onSelected: (_) => bloc.add(InventoryHistoryFilterChanged(t)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: () {
                    if (state.status == LoadStatus.loading && state.movements.isEmpty) return const LoadingView();
                    if (state.status == LoadStatus.failure && state.movements.isEmpty) {
                      return ErrorView(message: state.error ?? 'Ошибка', onRetry: () => bloc.add(const InventoryRequested()));
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        bloc.add(const InventoryRequested());
                        await waitForReload(bloc, (s) => s.status != LoadStatus.loading);
                      },
                      child: items.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 80),
                              EmptyState(icon: Icons.history, title: 'Движений нет'),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final m = items[i];
                                final showDate = i == 0 || items[i - 1].date != m.date;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showDate)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                        child: Text(formatDate(m.date), style: Theme.of(context).textTheme.labelLarge),
                                      ),
                                    Card(child: MovementTile(movement: m, showProduct: productId == null, canDelete: true)),
                                    const SizedBox(height: 6),
                                  ],
                                );
                              },
                            ),
                    );
                  }(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.movement, this.showProduct = true, this.canDelete = false});

  final StockMovement movement;
  final bool showProduct;
  final bool canDelete;

  Future<void> _delete(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить движение?',
      message: '${movement.type.label} ${movement.quantity} шт. будет отменён, остаток пересчитается.',
    );
    if (ok && context.mounted) context.read<InventoryBloc>().add(MovementDeleted(movement.id));
  }

  @override
  Widget build(BuildContext context) {
    final isIn = movement.type == MovementType.stockIn;
    final color = isIn ? profitColor : lossColor;
    final details = [
      if (showProduct) movement.productName,
      if (movement.description.isNotEmpty) movement.description,
      if (!showProduct || !canDelete) formatDate(movement.date),
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(isIn ? Icons.south_west : Icons.north_east, color: color, size: 20),
      ),
      title: Text(
        '${isIn ? '+' : '−'}${movement.quantity} шт. · ${movement.type.label}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: details.isEmpty ? null : Text(details.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: canDelete
          ? (movement.isFromSale
              ? const Tooltip(message: 'Создано продажей', child: Icon(Icons.receipt_long_outlined, size: 20))
              : IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context)))
          : null,
    );
  }
}
