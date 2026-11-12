import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/products_bloc.dart';
import '../core/formatters.dart';
import '../models/product.dart';
import '../widgets/common.dart';
import '../widgets/refresh.dart';
import 'product_details_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProductsBloc>();
    return BlocListener<ProductsBloc, ProductsState>(
      listenWhen: (a, b) => a.actionStatus != b.actionStatus && b.actionKind == ActionKind.delete,
      listener: (context, state) {
        if (state.actionStatus == ActionStatus.success) showSnack(context, state.actionMessage ?? 'Удалено');
        if (state.actionStatus == ActionStatus.failure) showSnack(context, state.actionMessage ?? 'Ошибка', error: true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Товары'),
          actions: [
            BlocBuilder<ProductsBloc, ProductsState>(
              buildWhen: (a, b) => a.sort != b.sort,
              builder: (context, state) => PopupMenuButton<ProductSort>(
                tooltip: 'Сортировка',
                icon: const Icon(Icons.sort),
                initialValue: state.sort,
                onSelected: (s) => bloc.add(ProductsSortChanged(s)),
                itemBuilder: (_) => [
                  for (final s in ProductSort.values) PopupMenuItem(value: s, child: Text(s.label)),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'products-fab',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProductFormScreen())),
          icon: const Icon(Icons.add),
          label: const Text('Товар'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (q) {
                  bloc.add(ProductsSearchChanged(q));
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Поиск по названию или описанию',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            bloc.add(const ProductsSearchChanged(''));
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            BlocBuilder<ProductsBloc, ProductsState>(
              buildWhen: (a, b) => a.filter != b.filter,
              builder: (context, state) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final f in StockFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f.label),
                          selected: state.filter == f,
                          onSelected: (_) => bloc.add(ProductsFilterChanged(f)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<ProductsBloc, ProductsState>(
                builder: (context, state) {
                  if (state.status == LoadStatus.loading && state.products.isEmpty) return const LoadingView();
                  if (state.status == LoadStatus.failure && state.products.isEmpty) {
                    return ErrorView(message: state.error ?? 'Ошибка', onRetry: () => bloc.add(const ProductsRequested()));
                  }
                  final items = state.visible;
                  return RefreshIndicator(
                    onRefresh: () async {
                      bloc.add(const ProductsRequested());
                      await waitForReload(bloc, (s) => s.status != LoadStatus.loading);
                    },
                    child: items.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 60),
                            EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: state.products.isEmpty ? 'Товаров пока нет' : 'Ничего не найдено',
                              subtitle: state.products.isEmpty
                                  ? 'Добавьте товар с ценами и остатком на складе'
                                  : 'Измените запрос или фильтр',
                            ),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _ProductTile(
                              product: items[i],
                              threshold: state.lowStockThreshold,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.threshold});

  final Product product;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ProductDetailsScreen(productId: product.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(tag: 'product-image-${product.id}', child: ProductImage(path: product.imageUrl, size: 64)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '${formatMoney(product.sellingPrice)}  ·  закупка ${formatMoney(product.purchasePrice)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StockBadge(stock: product.stock, threshold: threshold),
                        const SizedBox(width: 8),
                        Text(
                          '+${formatMoney(product.unitProfit)} / шт.',
                          style: theme.textTheme.labelSmall?.copyWith(color: profitTone(product.unitProfit)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
