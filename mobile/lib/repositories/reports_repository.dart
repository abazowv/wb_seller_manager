import '../core/api_client.dart';
import '../core/formatters.dart';
import '../models/reports.dart';

class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Future<DashboardData> dashboard({required int lowStockThreshold}) async {
    final data = await _api.get('/dashboard', query: {
      'today': toIsoDate(DateTime.now()),
      'low_stock_threshold': lowStockThreshold,
    }) as Map<String, dynamic>;
    return DashboardData.fromJson(data);
  }

  Future<FinanceReport> finance({required String from, required String to}) async {
    final data = await _api.get('/finance', query: {'from': from, 'to': to}) as Map<String, dynamic>;
    return FinanceReport.fromJson(data);
  }

  /// group: day | week | month
  Future<AnalyticsReport> analytics({required String group}) async {
    final data = await _api.get('/analytics', query: {
      'group': group,
      'today': toIsoDate(DateTime.now()),
    }) as Map<String, dynamic>;
    return AnalyticsReport.fromJson(data);
  }
}
