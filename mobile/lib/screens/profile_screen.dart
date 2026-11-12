import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_bloc.dart';
import '../blocs/settings_cubit.dart';
import '../core/api_client.dart';
import '../widgets/common.dart';

/// Профиль и настройки: порог низкого остатка, выход.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editThreshold(BuildContext context, int current) async {
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Порог низкого остатка'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'шт.', helperText: 'Товар с остатком не больше порога считается заканчивающимся'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && context.mounted) await context.read<SettingsCubit>().setLowStockThreshold(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.select((AuthBloc b) => b.state.user);
    final threshold = context.select((SettingsCubit c) => c.state.lowStockThreshold);
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 28, color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '', style: theme.textTheme.titleLarge),
                        Text(user?.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Настройки'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const Text('Порог низкого остатка'),
                  subtitle: const Text('Предупреждать, когда товара осталось не больше'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: threshold > 0 ? () => context.read<SettingsCubit>().setLowStockThreshold(threshold - 1) : null,
                      ),
                      InkWell(
                        onTap: () => _editThreshold(context, threshold),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('$threshold', style: theme.textTheme.titleMedium),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => context.read<SettingsCubit>().setLowStockThreshold(threshold + 1),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Сервер'),
                  subtitle: Text(ApiClient.baseUrl),
                ),
              ],
            ),
          ),
          const SectionHeader('О приложении'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('WB Seller Manager'),
              subtitle: Text('Версия 1.0.0 · учёт продаж, товаров и склада для продавцов Wildberries'),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Выйти из аккаунта?',
                message: 'Данные останутся на сервере, вы сможете войти снова.',
                confirmLabel: 'Выйти',
              );
              if (ok && context.mounted) context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
