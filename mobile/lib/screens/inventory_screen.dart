import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/inventory_bloc.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../widgets/common.dart';
import '../widgets/movement_sheet.dart';
import '../widgets/refresh.dart';
import 'inventory_history_screen.dart';
import 'product_details_screen.dart';

/// Склад: остатки, приход/расход, предупреждение о низком остатке.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<InventoryBloc>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Склад'),
        actions: [
          IconButton(
            tooltip: 'История движений',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InventoryHistoryScreen())),
          ),
        ],
      ),
      floatingActionButton: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (a, b) => a.products.isEmpty != b.products.isEmpty,
        builder: (context, state) => state.products.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                heroTag: 'inventory-fab',
                onPressed: () => showMovementSheet(context, products: state.products),
                icon: const Icon(Icons.swap_vert),
                label: const Text('Движение'),
              ),
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          if (state.status == LoadStatus.loading && state.products.isEmpty) return const LoadingView();
          if (state.status == LoadStatus.failure && state.products.isEmpty) {
            return ErrorView(message: state.error ?? 'Ошибка', onRetry: () => bloc.add(const InventoryRequested()));
          }
          final low = state.lowStockProducts;
          return RefreshIndicator(
            onRefresh: () async {
              bloc.add(const InventoryRequested());
              await waitForReload(bloc, (s) => s.status != LoadStatus.loading);
            },
            child: state.products.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.warehouse_outlined,
                      title: 'Склад пуст',
                      subtitle: 'Сначала добавьте товары на вкладке «Товары»',
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: [
                      StatGrid(children: [
                        StatCard(
                          label: 'Единиц на складе',
                          value: formatNumber(state.totalUnits),
                          icon: Icons.inventory_outlined,
                          color: Colors.teal,
                        ),
                        StatCard(
                          label: 'Стоимость остатка',
                          value: formatMoney(state.stockValue),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ]),
                      if (low.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: warningColor.withValues(alpha: 0.1),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_rounded, color: warningColor),
                            title: Text('Низкий остаток: ${low.length} ${_plural(low.length)}'),
                            subtitle: Text(
                              'Порог — ${state.lowStockThreshold} шт. (меняется в профиле). '
                              '${low.take(3).map((p) => p.name).join(', ')}${low.length > 3 ? '…' : ''}',
                            ),
                          ),
                        ),
                      ],
                      const SectionHeader('Остатки'),
                      for (final p in state.products) ...[
                        _StockTile(product: p, products: state.products, threshold: state.lowStockThreshold),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }

  static String _plural(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'товара';
    return 'товаров';
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.product, required this.products, required this.threshold});

  final Product product;
  final List<Product> products;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final low = product.stock <= threshold;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ProductDetailsScreen(productId: product.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              ProductImage(path: product.imageUrl, size: 48, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StockBadge(stock: product.stock, threshold: threshold),
                        if (low && product.stock > 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.warning_amber_rounded, size: 16, color: warningColor),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Приход',
                icon: const Icon(Icons.add_circle_outline, color: profitColor),
                onPressed: () =>
                    showMovementSheet(context, products: products, product: product, type: MovementType.stockIn),
              ),
              IconButton(
                tooltip: 'Расход',
                icon: const Icon(Icons.remove_circle_outline, color: lossColor),
                onPressed: product.stock == 0
                    ? null
                    : () => showMovementSheet(context, products: products, product: product, type: MovementType.stockOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
