import 'package:equatable/equatable.dart';

import 'json.dart';

/// Запись о продажах за день.
class Sale extends Equatable {
  const Sale({
    required this.id,
    required this.date,
    required this.ordersCount,
    required this.itemsSold,
    required this.totalAmount,
    this.productId,
    this.productName,
    this.note = '',
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: toInt(json['id']),
        date: json['date'] as String,
        ordersCount: toInt(json['orders_count']),
        itemsSold: toInt(json['items_sold']),
        totalAmount: toDouble(json['total_amount']),
        productId: json['product_id'] == null ? null : toInt(json['product_id']),
        productName: json['product_name'] as String?,
        note: json['note'] as String? ?? '',
      );

  final int id;

  /// ГГГГ-ММ-ДД
  final String date;
  final int ordersCount;
  final int itemsSold;
  final double totalAmount;
  final int? productId;
  final String? productName;
  final String note;

  @override
  List<Object?> get props => [id, date, ordersCount, itemsSold, totalAmount, productId, productName, note];
}

class SaleDraft extends Equatable {
  const SaleDraft({
    required this.date,
    required this.ordersCount,
    required this.itemsSold,
    required this.totalAmount,
    this.productId,
    this.note = '',
    this.writeOffStock = true,
  });

  final String date;
  final int ordersCount;
  final int itemsSold;
  final double totalAmount;
  final int? productId;
  final String note;
  final bool writeOffStock;

  Map<String, dynamic> toJson() => {
        'date': date,
        'orders_count': ordersCount,
        'items_sold': itemsSold,
        'total_amount': totalAmount,
        'product_id': productId,
        'note': note,
        'write_off_stock': writeOffStock,
      };

  @override
  List<Object?> get props => [date, ordersCount, itemsSold, totalAmount, productId, note, writeOffStock];
}
