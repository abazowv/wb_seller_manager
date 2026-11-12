import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);
final _moneyPrecise = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 2);
final _number = NumberFormat.decimalPattern('ru_RU');
final _compact = NumberFormat.compact(locale: 'ru_RU');
final _percent = NumberFormat.decimalPattern('ru_RU')..maximumFractionDigits = 1;

/// 12 345 ₽
String formatMoney(num value, {bool precise = false}) {
  if (precise && value != value.roundToDouble()) return _moneyPrecise.format(value);
  return _money.format(value);
}

/// 12 тыс. — для подписей осей графиков.
String formatCompact(num value) => _compact.format(value);

String formatNumber(num value) => _number.format(value);

String formatPercent(num value) => '${value >= 0 ? '' : '−'}${_percent.format(value.abs())}%';

/// 2026-11-12
String toIsoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime parseIsoDate(String value) => DateTime.parse(value);

/// 12 нояб. 2026
String formatDate(String isoDate) => DateFormat('d MMM y', 'ru').format(parseIsoDate(isoDate));

/// 12 нояб.
String formatShortDate(String isoDate) => DateFormat('d MMM', 'ru').format(parseIsoDate(isoDate));

/// Четверг, 12 ноября
String formatLongDate(DateTime date) {
  final s = DateFormat('EEEE, d MMMM', 'ru').format(date);
  return s[0].toUpperCase() + s.substring(1);
}

/// Подпись точки графика в зависимости от группировки.
String formatPeriodLabel(String isoDate, String group) {
  final d = parseIsoDate(isoDate);
  switch (group) {
    case 'month':
      return DateFormat('LLL', 'ru').format(d);
    case 'week':
    case 'day':
    default:
      return DateFormat('d.MM').format(d);
  }
}

/// Пустая строка → null, иначе число (поддерживает запятую как разделитель).
double? parseDecimal(String text) {
  final t = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
