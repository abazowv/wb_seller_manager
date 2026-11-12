import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../blocs/common.dart';
import '../blocs/products_bloc.dart';
import '../core/formatters.dart';
import '../models/product.dart';
import '../widgets/common.dart';

/// Добавление / редактирование товара с фото.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description = TextEditingController(text: widget.product?.description ?? '');
  late final _purchase = TextEditingController(text: _num(widget.product?.purchasePrice));
  late final _selling = TextEditingController(text: _num(widget.product?.sellingPrice));
  late final _stock = TextEditingController(text: widget.product?.stock.toString() ?? '');
  String? _imagePath;
  bool _removeImage = false;

  bool get _isEdit => widget.product != null;

  static String _num(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _purchase.dispose();
    _selling.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Сделать фото'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_imagePath != null || (widget.product?.imageUrl != null && !_removeImage))
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Убрать фото'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _imagePath = null;
                    _removeImage = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 85);
      if (file != null) {
        setState(() {
          _imagePath = file.path;
          _removeImage = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) showSnack(context, 'Не удалось открыть ${source == ImageSource.camera ? 'камеру' : 'галерею'}: ${e.message}', error: true);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final draft = ProductDraft(
      name: _name.text.trim(),
      description: _description.text.trim(),
      purchasePrice: parseDecimal(_purchase.text) ?? 0,
      sellingPrice: parseDecimal(_selling.text) ?? 0,
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      imagePath: _imagePath,
      removeImage: _removeImage && _imagePath == null,
    );
    context.read<ProductsBloc>().add(ProductSaved(draft, id: widget.product?.id));
  }

  String? _priceValidator(String? v) {
    final n = parseDecimal(v ?? '');
    if (n == null || n < 0) return 'Введите цену';
    return null;
  }

  Widget _imagePreview() {
    final scheme = Theme.of(context).colorScheme;
    Widget content;
    if (_imagePath != null) {
      content = Image.file(File(_imagePath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (!_removeImage && widget.product?.imageUrl != null) {
      content = ProductImage(path: widget.product!.imageUrl, size: 180, radius: 0);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 40, color: scheme.primary),
          const SizedBox(height: 8),
          Text('Добавить фото', style: TextStyle(color: scheme.primary)),
        ],
      );
    }
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Container(
          width: 180,
          height: 180,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (_imagePath != null || (!_removeImage && widget.product?.imageUrl != null))
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: CircleAvatar(radius: 18, child: Icon(Icons.edit, size: 18, color: scheme.primary)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchase = parseDecimal(_purchase.text) ?? 0;
    final selling = parseDecimal(_selling.text) ?? 0;
    final margin = selling - purchase;
    return BlocListener<ProductsBloc, ProductsState>(
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
        appBar: AppBar(title: Text(_isEdit ? 'Изменить товар' : 'Новый товар')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _imagePreview(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (v) => (v?.trim() ?? '').isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Описание', alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchase,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Закупка, ₽'),
                      onChanged: (_) => setState(() {}),
                      validator: _priceValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _selling,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Цена продажи, ₽'),
                      onChanged: (_) => setState(() {}),
                      validator: _priceValidator,
                    ),
                  ),
                ],
              ),
              if (selling > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Прибыль с единицы: ${signedMoney(margin)} (${formatPercent(margin / selling * 100)})',
                    style: TextStyle(color: profitTone(margin), fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stock,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Остаток на складе, шт.' : 'Начальный остаток, шт.',
                  helperText: _isEdit
                      ? 'Изменение остатка запишется в историю склада как корректировка'
                      : 'Запишется в историю склада как приход',
                ),
              ),
              const SizedBox(height: 28),
              BlocBuilder<ProductsBloc, ProductsState>(
                buildWhen: (a, b) => a.actionStatus != b.actionStatus,
                builder: (context, state) {
                  final saving = state.actionStatus == ActionStatus.inProgress && state.actionKind == ActionKind.save;
                  return FilledButton.icon(
                    onPressed: saving ? null : _submit,
                    icon: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_isEdit ? 'Сохранить' : 'Добавить товар'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
