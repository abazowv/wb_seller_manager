/// Помощники для безопасного чтения JSON (числа могут прийти как int или double).
double toDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

int toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

double? toDoubleOrNull(Object? v) => v == null ? null : toDouble(v);

String? toStringOrNull(Object? v) => v == null ? null : '$v';
