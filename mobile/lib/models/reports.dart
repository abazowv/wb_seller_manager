import 'package:equatable/equatable.dart';

import 'json.dart';
import 'sale.dart';

/// Итоги за период (выручка, себестоимость, прибыль и т. д.).
class PeriodTotals extends Equatable {
  const PeriodTotals({
    this.from,
    this.to,
    this.revenue = 0,
    this.orders = 0,
    this.itemsSold = 0,
    this.cost = 0,
    this.profit = 0,
    this.marginPercent = 0,
    this.avgCheck = 0,
    this.salesCount = 0,
    this.estimatedCost = 0,
  });

  factory PeriodTotals.fromJson(Map<String, dynamic> json) => PeriodTotals(
        from: json['from'] as String?,
        to: json['to'] as String?,
        revenue: toDouble(json['revenue']),
        orders: toInt(json['orders']),
        itemsSold: toInt(json['items_sold']),
        cost: toDouble(json['cost']),
        profit: toDouble(json['profit']),
        marginPercent: toDouble(json['margin_percent']),
        avgCheck: toDouble(json['avg_check']),
        salesCount: toInt(json['sales_count']),
        estimatedCost: toDouble(json['estimated_cost']),
      );

  final String? from;
  final String? to;
  final double revenue;
  final int orders;
  final int itemsSold;
  final double cost;
  final double profit;
  final double marginPercent;
  final double avgCheck;
  final int salesCount;

  /// Часть себестоимости, рассчитанная приблизительно (продажи без товара).
  final double estimatedCost;

  @override
  List<Object?> get props =>
      [from, to, revenue, orders, itemsSold, cost, profit, marginPercent, avgCheck, salesCount, estimatedCost];
}

/// Точка графика.
class ChartPoint extends Equatable {
  const ChartPoint({
    required this.period,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.orders,
    required this.itemsSold,
  });

  factory ChartPoint.fromJson(Map<String, dynamic> json) => ChartPoint(
        period: json['period'] as String,
        revenue: toDouble(json['revenue']),
        cost: toDouble(json['cost']),
        profit: toDouble(json['profit']),
        orders: toInt(json['orders']),
        itemsSold: toInt(json['items_sold']),
      );

  final String period;
  final double revenue;
  final double cost;
  final double profit;
  final int orders;
  final int itemsSold;

  @override
  List<Object?> get props => [period, revenue, cost, profit, orders, itemsSold];
}

class LowStockItem extends Equatable {
  const LowStockItem({required this.id, required this.name, required this.stock, this.imageUrl});

  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(
        id: toInt(json['id']),
        name: json['name'] as String? ?? '',
        stock: toInt(json['stock']),
        imageUrl: json['image_url'] as String?,
      );

  final int id;
  final String name;
  final int stock;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, name, stock, imageUrl];
}

class StockSummary extends Equatable {
  const StockSummary({
    required this.productsCount,
    required this.inStockCount,
    required this.totalUnits,
    required this.stockValue,
    required this.lowStockThreshold,
    required this.lowStock,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) => StockSummary(
        productsCount: toInt(json['products_count']),
        inStockCount: toInt(json['in_stock_count']),
        totalUnits: toInt(json['total_units']),
        stockValue: toDouble(json['stock_value']),
        lowStockThreshold: toInt(json['low_stock_threshold']),
        lowStock: (json['low_stock'] as List? ?? [])
            .map((e) => LowStockItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int productsCount;
  final int inStockCount;
  final int totalUnits;
  final double stockValue;
  final int lowStockThreshold;
  final List<LowStockItem> lowStock;

  @override
  List<Object?> get props => [productsCount, inStockCount, totalUnits, stockValue, lowStockThreshold, lowStock];
}

class DashboardData extends Equatable {
  const DashboardData({
    required this.today,
    required this.week,
    required this.month,
    required this.stock,
    required this.recentSales,
    required this.chart,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        today: PeriodTotals.fromJson(json['today'] as Map<String, dynamic>),
        week: PeriodTotals.fromJson(json['week'] as Map<String, dynamic>),
        month: PeriodTotals.fromJson(json['month'] as Map<String, dynamic>),
        stock: StockSummary.fromJson(json['stock'] as Map<String, dynamic>),
        recentSales: (json['recent_sales'] as List).map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList(),
        chart: (json['chart'] as List).map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final PeriodTotals today;
  final PeriodTotals week;
  final PeriodTotals month;
  final StockSummary stock;
  final List<Sale> recentSales;
  final List<ChartPoint> chart;

  @override
  List<Object?> get props => [today, week, month, stock, recentSales, chart];
}

class FinanceReport extends Equatable {
  const FinanceReport({
    required this.current,
    required this.previous,
    required this.revenueChange,
    required this.profitChange,
    required this.stockValue,
    required this.byDay,
  });

  factory FinanceReport.fromJson(Map<String, dynamic> json) {
    final change = json['change'] as Map<String, dynamic>? ?? {};
    return FinanceReport(
      current: PeriodTotals.fromJson(json),
      previous: PeriodTotals.fromJson(json['previous'] as Map<String, dynamic>),
      revenueChange: toDoubleOrNull(change['revenue']),
      profitChange: toDoubleOrNull(change['profit']),
      stockValue: toDouble(json['stock_value']),
      byDay: (json['by_day'] as List).map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final PeriodTotals current;
  final PeriodTotals previous;

  /// Изменение к прошлому периоду в %, null — сравнивать не с чем.
  final double? revenueChange;
  final double? profitChange;
  final double stockValue;
  final List<ChartPoint> byDay;

  @override
  List<Object?> get props => [current, previous, revenueChange, profitChange, stockValue, byDay];
}

class TopProduct extends Equatable {
  const TopProduct({
    required this.id,
    required this.name,
    required this.itemsSold,
    required this.revenue,
    required this.profit,
    this.imageUrl,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        id: toInt(json['id']),
        name: json['name'] as String? ?? '',
        itemsSold: toInt(json['items_sold']),
        revenue: toDouble(json['revenue']),
        profit: toDouble(json['profit']),
        imageUrl: json['image_url'] as String?,
      );

  final int id;
  final String name;
  final int itemsSold;
  final double revenue;
  final double profit;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, name, itemsSold, revenue, profit, imageUrl];
}

class AnalyticsReport extends Equatable {
  const AnalyticsReport({
    required this.group,
    required this.points,
    required this.totals,
    required this.previous,
    required this.change,
    required this.topProducts,
  });

  factory AnalyticsReport.fromJson(Map<String, dynamic> json) {
    final change = json['change'] as Map<String, dynamic>? ?? {};
    return AnalyticsReport(
      group: json['group'] as String,
      points: (json['points'] as List).map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList(),
      totals: PeriodTotals.fromJson({
        ...json['totals'] as Map<String, dynamic>,
        'from': json['from'],
        'to': json['to'],
      }),
      previous: PeriodTotals.fromJson(json['previous'] as Map<String, dynamic>),
      change: change.map((k, v) => MapEntry(k, toDoubleOrNull(v))),
      topProducts:
          (json['top_products'] as List).map((e) => TopProduct.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final String group;
  final List<ChartPoint> points;
  final PeriodTotals totals;
  final PeriodTotals previous;

  /// revenue / profit / orders / items_sold → изменение в % (null — нет данных).
  final Map<String, double?> change;
  final List<TopProduct> topProducts;

  @override
  List<Object?> get props => [group, points, totals, previous, change, topProducts];
}
