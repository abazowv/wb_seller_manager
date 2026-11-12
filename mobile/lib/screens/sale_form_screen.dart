import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/common.dart';
import '../blocs/products_bloc.dart';
import '../blocs/sales_bloc.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../widgets/common.dart';

/// Добавление / редактирование записи о продажах за день.
class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key, this.sale});

  final Sale? sale;

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _orders = TextEditingController(text: widget.sale?.ordersCount.toString() ?? '');
  late final _items = TextEditingController(text: widget.sale?.itemsSold.toString() ?? '');
  late final _amount = TextEditingController(text: _amountText(widget.sale?.totalAmount));
  late final _note = TextEditingController(text: widget.sale?.note ?? '');
  late DateTime _date = widget.sale != null ? parseIsoDate(widget.sale!.date) : dateOnly(DateTime.now());
  late int? _productId = widget.sale?.productId;
  bool _writeOff = true;
  bool _amountEdited = false;

  bool get _isEdit => widget.sale != null;

  static String _amountText(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _amountEdited = _isEdit;
    _items.addListener(() {
      _suggestAmount();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _orders.dispose();
    _items.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Product? _product(List<Product> products) {
    for (final p in products) {
      if (p.id == _productId) return p;
    }
    return null;
  }

  /// Подставляем сумму = штук × цена, пока пользователь не ввёл её сам.
  void _suggestAmount() {
    if (_amountEdited) return;
    final p = _product(context.read<ProductsBloc>().state.products);
    final n = int.tryParse(_items.text.trim());
    if (p != null && n != null) _amount.text = _amountText(p.sellingPrice * n);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final draft = SaleDraft(
      date: toIsoDate(_date),
      ordersCount: int.parse(_orders.text.trim()),
      itemsSold: int.parse(_items.text.trim()),
      totalAmount: parseDecimal(_amount.text)!,
      productId: _productId,
      note: _note.text.trim(),
      writeOffStock: _writeOff,
    );
    context.read<SalesBloc>().add(SaleSaved(draft, id: widget.sale?.id));
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить запись?',
      message: 'Запись о продажах будет удалена без возможности восстановления.',
    );
    if (!ok || !mounted) return;
    context.read<SalesBloc>().add(SaleDeleted(widget.sale!.id));
    Navigator.pop(context);
  }

  String? _intValidator(String? v, String label) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 0) return 'Введите $label (целое число ≥ 0)';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final products = context.select((ProductsBloc b) => b.state.products);
    final product = _product(products);
    final theme = Theme.of(context);
    return BlocListener<SalesBloc, SalesState>(
      listenWhen: (a, b) => a.actionStatus != b.actionStatus && b.actionKind == ActionKind.save,
      listener: (context, state) {
        if (state.actionStatus == ActionStatus.success) {
          showSnack(context, state.actionMessage ?? 'Сохранено');
          Navigator.pop(context);
        } else if (state.actionStatus == ActionStatus.failure) {
          showSnack(context, state.actionMessage ?? 'Ошибка', error: true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Изменить продажу' : 'Новая продажа'),
          actions: [
            if (_isEdit) IconButton(tooltip: 'Удалить', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Дата'),
                  subtitle: Text(formatDate(toIsoDate(_date))),
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
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: products.any((p) => p.id == _productId) ? _productId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Товар (необязательно)',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Все товары / без привязки')),
                  for (final p in products)
                    DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text('${p.name} · ${formatMoney(p.sellingPrice)} · ${p.stock} шт.', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  setState(() => _productId = v);
                  _suggestAmount();
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _orders,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Заказов'),
                      validator: (v) => _intValidator(v, 'число заказов'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _items,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Продано, шт.'),
                      validator: (v) => _intValidator(v, 'количество'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: 'Сумма продаж, ₽',
                  helperText: product != null && !_amountEdited ? 'Рассчитано по цене товара — можно изменить' : null,
                ),
                onChanged: (_) => setState(() => _amountEdited = true),
                validator: (v) {
                  final n = parseDecimal(v ?? '');
                  return n == null || n < 0 ? 'Введите сумму' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
              if (_productId != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _writeOff,
                  onChanged: (v) => setState(() => _writeOff = v),
                  title: const Text('Списать товар со склада'),
                  subtitle: Text(
                    product != null ? 'Сейчас на складе: ${product.stock} шт.' : '',
                    style: TextStyle(color: product != null && product.stock == 0 ? lossColor : null),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              BlocBuilder<SalesBloc, SalesState>(
                buildWhen: (a, b) => a.actionStatus != b.actionStatus,
                builder: (context, state) {
                  final saving = state.actionStatus == ActionStatus.inProgress && state.actionKind == ActionKind.save;
                  return FilledButton.icon(
                    onPressed: saving ? null : _submit,
                    icon: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_isEdit ? 'Сохранить' : 'Добавить продажу'),
                  );
                },
              ),
              if (product != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Оценочная прибыль: ${signedMoney((parseDecimal(_amount.text) ?? 0) - (int.tryParse(_items.text) ?? 0) * product.purchasePrice)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
