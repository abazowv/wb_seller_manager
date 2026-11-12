import 'package:equatable/equatable.dart';

import 'json.dart';

enum MovementType {
  stockIn('in', 'Приход'),
  stockOut('out', 'Расход');

  const MovementType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MovementType fromApi(String v) => v == 'in' ? stockIn : stockOut;
}

class StockMovement extends Equatable {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.date,
    this.description = '',
    this.saleId,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: toInt(json['id']),
        productId: toInt(json['product_id']),
        productName: json['product_name'] as String? ?? '',
        type: MovementType.fromApi(json['type'] as String),
        quantity: toInt(json['quantity']),
        date: json['date'] as String,
        description: json['description'] as String? ?? '',
        saleId: json['sale_id'] == null ? null : toInt(json['sale_id']),
      );

  final int id;
  final int productId;
  final String productName;
  final MovementType type;
  final int quantity;
  final String date;
  final String description;

  /// Если движение создано продажей — его меняют через саму продажу.
  final int? saleId;

  bool get isFromSale => saleId != null;

  @override
  List<Object?> get props => [id, productId, productName, type, quantity, date, description, saleId];
}

class MovementDraft extends Equatable {
  const MovementDraft({
    required this.productId,
    required this.type,
    required this.quantity,
    required this.date,
    this.description = '',
  });

  final int productId;
  final MovementType type;
  final int quantity;
  final String date;
  final String description;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'type': type.apiValue,
        'quantity': quantity,
        'date': date,
        'description': description,
      };

  @override
  List<Object?> get props => [productId, type, quantity, date, description];
}
