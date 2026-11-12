import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/reports.dart';

double _niceMax(double v) {
  if (v <= 0) return 100;
  final magnitude = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final n = v / magnitude;
  final nice = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10;
  return nice * magnitude;
}

Widget _bottomLabel(double value, TitleMeta meta, List<ChartPoint> points, String group) {
  final i = value.toInt();
  if (i < 0 || i >= points.length) return const SizedBox.shrink();
  final step = (points.length / 7).ceil();
  if (i % step != 0 && i != points.length - 1) return const SizedBox.shrink();
  return SideTitleWidget(
    meta: meta,
    child: Text(formatPeriodLabel(points[i].period, group), style: const TextStyle(fontSize: 10)),
  );
}

Widget _leftLabel(double value, TitleMeta meta) {
  if (value == meta.max || value == 0) {
    return SideTitleWidget(
      meta: meta,
      child: Text(formatCompact(value), style: const TextStyle(fontSize: 10)),
    );
  }
  return const SizedBox.shrink();
}

/// Столбики выручки (и опционально прибыли) по дням/неделям/месяцам.
class RevenueBarChart extends StatelessWidget {
  const RevenueBarChart({
    super.key,
    required this.points,
    this.group = 'day',
    this.showProfit = false,
    this.height = 200,
  });

  final List<ChartPoint> points;
  final String group;
  final bool showProfit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = _niceMax(points.fold<double>(0, (m, p) => math.max(m, p.revenue)));
    final barWidth = math.max(3.0, math.min(18.0, 220 / math.max(points.length, 1) / (showProfit ? 2 : 1)));
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: math.min(0, points.fold<double>(0, (m, p) => math.min(m, p.profit))),
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 44, interval: maxY / 4, getTitlesWidget: _leftLabel),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) => _bottomLabel(v, meta, points, group),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (g, gi, rod, ri) {
                final p = points[g.x];
                final label = ri == 0 ? 'Выручка' : 'Прибыль';
                return BarTooltipItem(
                  '${formatPeriodLabel(p.period, group)}\n$label: ${formatMoney(rod.toY)}',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 2,
                barRods: [
                  BarChartRodData(
                    toY: points[i].revenue,
                    width: barWidth,
                    color: scheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  if (showProfit)
                    BarChartRodData(
                      toY: points[i].profit,
                      width: barWidth,
                      color: points[i].profit >= 0 ? profitColor : lossColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Линии выручки, себестоимости и прибыли.
class FinanceLineChart extends StatelessWidget {
  const FinanceLineChart({super.key, required this.points, this.group = 'day', this.height = 220});

  final List<ChartPoint> points;
  final String group;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = _niceMax(points.fold<double>(0, (m, p) => math.max(m, p.revenue)));
    final minY = math.min(0.0, points.fold<double>(0, (m, p) => math.min(m, p.profit)));
    LineChartBarData line(List<double> values, Color color, {bool filled = false}) => LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2.5,
          dotData: FlDotData(show: points.length <= 12),
          belowBarData: BarAreaData(show: filled, color: color.withValues(alpha: 0.12)),
        );
    const labels = ['Выручка', 'Себестоимость', 'Прибыль'];
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 44, interval: maxY / 4, getTitlesWidget: _leftLabel),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, meta) => _bottomLabel(v, meta, points, group),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${labels[s.barIndex]}: ${formatMoney(s.y)}',
                        TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            line(points.map((p) => p.revenue).toList(), scheme.primary, filled: true),
            line(points.map((p) => p.cost).toList(), warningColor),
            line(points.map((p) => p.profit).toList(), profitColor),
          ],
        ),
      ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  /// Подпись → цвет.
  final Map<String, Color> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final e in items.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(e.key, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}
