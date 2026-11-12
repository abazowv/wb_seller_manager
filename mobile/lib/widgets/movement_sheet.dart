import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/inventory_bloc.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import 'common.dart';

/// Нижний лист «Приход / Расход» для товара.
Future<void> showMovementSheet(
  BuildContext context, {
  required List<Product> products,
  Product? product,
  MovementType type = MovementType.stockIn,
}) {
  final bloc = context.read<InventoryBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: _MovementSheet(products: products, initialProduct: product, initialType: type),
    ),
  );
}

class _MovementSheet extends StatefulWidget {
  const _MovementSheet({required this.products, this.initialProduct, required this.initialType});

  final List<Product> products;
  final Product? initialProduct;
  final MovementType initialType;

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _desc = TextEditingController();
  late MovementType _type = widget.initialType;
  late int? _productId = widget.initialProduct?.id ?? (widget.products.isNotEmpty ? widget.products.first.id : null);
  DateTime _date = dateOnly(DateTime.now());
  String? _error;

  Product? get _product {
    for (final p in widget.products) {
      if (p.id == _productId) return p;
    }
    return widget.initialProduct;
  }

  @override
  void dispose() {
    _qty.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate() || _productId == null) return;
    context.read<InventoryBloc>().add(MovementSaved(MovementDraft(
          productId: _productId!,
          type: _type,
          quantity: int.parse(_qty.text.trim()),
          date: toIsoDate(_date),
          description: _desc.text.trim(),
        )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = _product;
    return BlocConsumer<InventoryBloc, InventoryState>(
      listenWhen: (a, b) => a.actionStatus != b.actionStatus && b.actionKind == ActionKind.save,
      listener: (context, state) {
        if (state.actionStatus == ActionStatus.success) {
          Navigator.pop(context);
          showSnack(context, state.actionMessage ?? 'Сохранено');
        } else if (state.actionStatus == ActionStatus.failure) {
          setState(() => _error = state.actionMessage);
        }
      },
      builder: (context, state) {
        final saving = state.actionStatus == ActionStatus.inProgress && state.actionKind == ActionKind.save;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Движение товара', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                SegmentedButton<MovementType>(
                  segments: const [
                    ButtonSegment(value: MovementType.stockIn, label: Text('Приход'), icon: Icon(Icons.south_west)),
                    ButtonSegment(value: MovementType.stockOut, label: Text('Расход'), icon: Icon(Icons.north_east)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                if (widget.initialProduct == null)
                  DropdownButtonFormField<int>(
                    initialValue: _productId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Товар'),
                    items: [
                      for (final p in widget.products)
                        DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.stock} шт.)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _productId = v),
                    validator: (v) => v == null ? 'Выберите товар' : null,
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ProductImage(path: product?.imageUrl, size: 44),
                    title: Text(product?.name ?? ''),
                  ),
                if (product != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Сейчас на складе: ${product.stock} шт.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qty,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Количество, шт.'),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Введите количество больше 0';
                    if (_type == MovementType.stockOut && product != null && n > product.stock) {
                      return 'На складе только ${product.stock} шт.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  decoration: InputDecoration(
                    labelText: 'Комментарий',
                    hintText: _type == MovementType.stockIn ? 'Поставка от поставщика' : 'Отгрузка на склад WB',
                  ),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(formatDate(toIsoDate(_date))),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: lossColor)),
                  ),
                FilledButton.icon(
                  onPressed: saving ? null : _submit,
                  icon: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_type == MovementType.stockIn ? 'Записать приход' : 'Записать расход'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
