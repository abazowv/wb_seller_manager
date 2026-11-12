import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icon, size: 36, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Карточка показателя: иконка, подпись и крупное значение.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.footer,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: c),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (footer != null) ...[const SizedBox(height: 4), footer!],
          ],
        ),
      ),
    );
  }
}

/// Сетка карточек по две в ряд.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

/// Изменение к прошлому периоду: ▲ 12% / ▼ 5%.
class ChangeBadge extends StatelessWidget {
  const ChangeBadge({super.key, required this.percent, this.suffix = ''});

  final double? percent;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (percent == null) {
      return Text('нет данных для сравнения',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final up = percent! >= 0;
    final color = percent == 0 ? theme.colorScheme.onSurfaceVariant : (up ? profitColor : lossColor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: color),
        Flexible(
          child: Text(
            '${formatPercent(percent!.abs())}$suffix',
            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Фото товара с сервера или заглушка.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.path, this.size = 56, this.radius = 12});

  final String? path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = ApiClient.imageUrl(path);
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.primaryContainer.withValues(alpha: 0.6),
      child: Icon(Icons.inventory_2_outlined, color: scheme.onPrimaryContainer, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Плашка остатка: красная — нет, оранжевая — мало, зелёная — достаточно.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.stock, required this.threshold});

  final int stock;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final color = stock == 0 ? lossColor : (stock <= threshold ? warningColor : profitColor);
    final text = stock == 0 ? 'Нет в наличии' : '$stock шт.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Удалить',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
}

/// Цвет числа прибыли: зелёный/красный.
Color profitTone(num value) => value >= 0 ? profitColor : lossColor;

String signedMoney(num value) => value < 0 ? '−${formatMoney(value.abs())}' : formatMoney(value);
