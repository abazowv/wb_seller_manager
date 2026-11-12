import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/product_details_bloc.dart';
import '../blocs/products_bloc.dart';
import '../blocs/settings_cubit.dart';
import '../core/data_change_bus.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/product_repository.dart';
import '../widgets/common.dart';
import '../widgets/movement_sheet.dart';
import 'inventory_history_screen.dart';
import 'product_form_screen.dart';

/// Карточка товара: цены, прибыль по товару, остаток и история движений.
class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ProductDetailsBloc(
        productId: productId,
        products: ctx.read<ProductRepository>(),
        inventory: ctx.read<InventoryRepository>(),
        bus: ctx.read<DataChangeBus>(),
      )..add(const ProductDetailsRequested()),
      child: const _ProductDetailsView(),
    );
  }
}

class _ProductDetailsView extends StatelessWidget {
  const _ProductDetailsView();

  Future<void> _delete(BuildContext context, Product product) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить товар?',
      message: '«${product.name}» и вся история его движений по складу будут удалены. '
          'Записи о продажах сохранятся без привязки к товару.',
    );
    if (!ok || !context.mounted) return;
    context.read<ProductsBloc>().add(ProductDeleted(product.id));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductDetailsBloc, ProductDetailsState>(
      listenWhen: (a, b) => !a.deleted && b.deleted,
      listener: (context, state) => Navigator.maybePop(context),
      builder: (context, state) {
        final product = state.product;
        return Scaffold(
          appBar: AppBar(
            title: Text(product?.name ?? 'Товар', overflow: TextOverflow.ellipsis),
            actions: product == null
                ? null
                : [
                    IconButton(
                      tooltip: 'Изменить',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ProductFormScreen(product: product)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Удалить',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, product),
                    ),
                  ],
          ),
          body: () {
            if (product == null) {
              if (state.status == LoadStatus.failure) {
                return ErrorView(
                  message: state.error ?? 'Ошибка',
                  onRetry: () => context.read<ProductDetailsBloc>().add(const ProductDetailsRequested()),
                );
              }
              return const LoadingView();
            }
            return _content(context, product, state.movements);
          }(),
        );
      },
    );
  }

  Widget _content(BuildContext context, Product product, List<StockMovement> movements) {
    final theme = Theme.of(context);
    final stats = product.stats;
    final threshold = context.select((SettingsCubit c) => c.state.lowStockThreshold);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Center(
          child: Hero(
            tag: 'product-image-${product.id}',
            child: ProductImage(path: product.imageUrl, size: 200, radius: 24),
          ),
        ),
        const SizedBox(height: 16),
        Text(product.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(product.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        StatGrid(children: [
          StatCard(label: 'Цена продажи', value: formatMoney(product.sellingPrice, precise: true), icon: Icons.sell_outlined),
          StatCard(
            label: 'Закупочная цена',
            value: formatMoney(product.purchasePrice, precise: true),
            icon: Icons.shopping_cart_outlined,
            color: Colors.orange,
          ),
          StatCard(
            label: 'Прибыль с единицы',
            value: signedMoney(product.unitProfit),
            icon: Icons.trending_up,
            color: profitTone(product.unitProfit),
            footer: Text('маржа ${formatPercent(product.marginPercent.roundToDouble())}', style: theme.textTheme.labelSmall),
          ),
          StatCard(
            label: 'На складе',
            value: '${product.stock} шт.',
            icon: Icons.warehouse_outlined,
            color: Colors.teal,
            footer: Text(
              product.stock == 0
                  ? 'нет в наличии'
                  : product.stock <= threshold
                      ? 'заканчивается (порог $threshold)'
                      : 'достаточно',
              style: theme.textTheme.labelSmall?.copyWith(
                color: product.stock <= threshold ? warningColor : profitColor,
              ),
            ),
          ),
        ]),
        if (stats != null) ...[
          const SectionHeader('Прибыль по товару (все продажи)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _row(context, 'Продано', '${formatNumber(stats.itemsSold)} шт. (${stats.salesCount} записей)'),
                  _row(context, 'Выручка', formatMoney(stats.revenue)),
                  _row(context, 'Себестоимость', formatMoney(stats.cost)),
                  _row(context, 'Прибыль', signedMoney(stats.profit), color: profitTone(stats.profit), bold: true),
                  const Divider(),
                  _row(context, 'Стоимость остатка (по закупке)', formatMoney(stats.stockValue)),
                  _row(context, 'Всего приходов / расходов', '${stats.totalIn} / ${stats.totalOut} шт.'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showMovementSheet(context, products: [product], product: product, type: MovementType.stockIn),
                icon: const Icon(Icons.south_west),
                label: const Text('Приход'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: product.stock == 0
                    ? null
                    : () => showMovementSheet(context, products: [product], product: product, type: MovementType.stockOut),
                icon: const Icon(Icons.north_east),
                label: const Text('Расход'),
              ),
            ),
          ],
        ),
        SectionHeader(
          'Движения по складу',
          action: movements.length > 5
              ? TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => InventoryHistoryScreen(productId: product.id)),
                  ),
                  child: const Text('Все'),
                )
              : null,
        ),
        if (movements.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Движений пока нет')))
        else
          Card(
            child: Column(children: [for (final m in movements.take(5)) MovementTile(movement: m, showProduct: false)]),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
