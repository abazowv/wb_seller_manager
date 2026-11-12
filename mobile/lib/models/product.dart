import 'package:equatable/equatable.dart';

import 'json.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    this.description = '',
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.imageUrl,
    this.stock = 0,
    this.stats,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: toInt(json['id']),
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        purchasePrice: toDouble(json['purchase_price']),
        sellingPrice: toDouble(json['selling_price']),
        imageUrl: json['image_url'] as String?,
        stock: toInt(json['stock']),
        stats: json['stats'] is Map<String, dynamic>
            ? ProductStats.fromJson(json['stats'] as Map<String, dynamic>)
            : null,
      );

  final int id;
  final String name;
  final String description;
  final double purchasePrice;
  final double sellingPrice;
  final String? imageUrl;
  final int stock;

  /// Есть только в ответе GET /products/:id.
  final ProductStats? stats;

  double get unitProfit => sellingPrice - purchasePrice;

  double get marginPercent => sellingPrice > 0 ? unitProfit / sellingPrice * 100 : 0;

  bool isLowStock(int threshold) => stock <= threshold;

  @override
  List<Object?> get props => [id, name, description, purchasePrice, sellingPrice, imageUrl, stock, stats];
}

class ProductStats extends Equatable {
  const ProductStats({
    required this.unitProfit,
    required this.marginPercent,
    required this.itemsSold,
    required this.salesCount,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.stockValue,
    required this.totalIn,
    required this.totalOut,
  });

  factory ProductStats.fromJson(Map<String, dynamic> json) => ProductStats(
        unitProfit: toDouble(json['unit_profit']),
        marginPercent: toDouble(json['margin_percent']),
        itemsSold: toInt(json['items_sold']),
        salesCount: toInt(json['sales_count']),
        revenue: toDouble(json['revenue']),
        cost: toDouble(json['cost']),
        profit: toDouble(json['profit']),
        stockValue: toDouble(json['stock_value']),
        totalIn: toInt(json['total_in']),
        totalOut: toInt(json['total_out']),
      );

  final double unitProfit;
  final double marginPercent;
  final int itemsSold;
  final int salesCount;
  final double revenue;
  final double cost;
  final double profit;
  final double stockValue;
  final int totalIn;
  final int totalOut;

  @override
  List<Object?> get props =>
      [unitProfit, marginPercent, itemsSold, salesCount, revenue, cost, profit, stockValue, totalIn, totalOut];
}

/// Данные формы товара (создание/редактирование).
class ProductDraft extends Equatable {
  const ProductDraft({
    required this.name,
    required this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    this.imagePath,
    this.removeImage = false,
  });

  final String name;
  final String description;
  final double purchasePrice;
  final double sellingPrice;
  final int stock;

  /// Локальный путь к новой фотографии (из image_picker).
  final String? imagePath;
  final bool removeImage;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'stock': stock,
        if (removeImage) 'image_url': null,
      };

  @override
  List<Object?> get props => [name, description, purchasePrice, sellingPrice, stock, imagePath, removeImage];
}
