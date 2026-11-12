import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';

/// Главный экран с нижней навигацией.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onNavigate: _goTo),
      const SalesScreen(),
      const ProductsScreen(),
      const InventoryScreen(),
      const ReportsScreen(),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Главная'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Продажи'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Товары'),
            NavigationDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse), label: 'Склад'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Отчёты'),
          ],
        ),
      ),
    );
  }
}

/// Индексы вкладок для перехода из Dashboard.
abstract final class HomeTab {
  static const dashboard = 0;
  static const sales = 1;
  static const products = 2;
  static const inventory = 3;
  static const reports = 4;
}
