import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'finance_screen.dart';

/// Вкладка «Отчёты»: финансы и аналитика.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Отчёты'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Финансы'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Аналитика'),
            ],
          ),
        ),
        body: const TabBarView(children: [FinanceView(), AnalyticsView()]),
      ),
    );
  }
}
