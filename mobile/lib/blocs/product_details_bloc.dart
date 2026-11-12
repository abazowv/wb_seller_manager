import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/product_repository.dart';
import 'common.dart';

sealed class ProductDetailsEvent extends Equatable {
  const ProductDetailsEvent();

  @override
  List<Object?> get props => [];
}

class ProductDetailsRequested extends ProductDetailsEvent {
  const ProductDetailsRequested();
}

class ProductDetailsState extends Equatable {
  const ProductDetailsState({
    this.status = LoadStatus.initial,
    this.product,
    this.movements = const [],
    this.error,
    this.deleted = false,
  });

  final LoadStatus status;
  final Product? product;
  final List<StockMovement> movements;
  final String? error;

  /// Товар удалён (например, с этого же экрана) — экран нужно закрыть.
  final bool deleted;

  @override
  List<Object?> get props => [status, product, movements, error, deleted];
}

/// Карточка товара: статистика прибыли и история движений этого товара.
class ProductDetailsBloc extends Bloc<ProductDetailsEvent, ProductDetailsState> {
  ProductDetailsBloc({
    required this.productId,
    required this.products,
    required this.inventory,
    required DataChangeBus bus,
  }) : super(const ProductDetailsState()) {
    on<ProductDetailsRequested>(_onRequested);
    _busSub = bus.stream.listen((_) => add(const ProductDetailsRequested()));
  }

  final int productId;
  final ProductRepository products;
  final InventoryRepository inventory;
  late final StreamSubscription<DataChange> _busSub;

  Future<void> _onRequested(ProductDetailsRequested event, Emitter<ProductDetailsState> emit) async {
    if (state.product == null) emit(const ProductDetailsState(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        products.fetchOne(productId),
        inventory.fetchMovements(productId: productId),
      ]);
      emit(ProductDetailsState(
        status: LoadStatus.success,
        product: results[0] as Product,
        movements: results[1] as List<StockMovement>,
      ));
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        emit(ProductDetailsState(status: LoadStatus.failure, error: e.message, deleted: true));
      } else {
        emit(ProductDetailsState(
          status: LoadStatus.failure,
          product: state.product,
          movements: state.movements,
          error: e.message,
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _busSub.cancel();
    return super.close();
  }
}
