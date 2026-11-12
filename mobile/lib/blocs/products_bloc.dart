import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../core/settings_store.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import 'common.dart';

enum StockFilter {
  all('Все'),
  inStock('В наличии'),
  low('Мало'),
  outOfStock('Нет в наличии');

  const StockFilter(this.label);

  final String label;
}

enum ProductSort {
  newest('Сначала новые'),
  name('По названию'),
  stock('По остатку'),
  price('По цене');

  const ProductSort(this.label);

  final String label;
}

// ---------- События ----------

sealed class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

class ProductsRequested extends ProductsEvent {
  const ProductsRequested();
}

class ProductsSearchChanged extends ProductsEvent {
  const ProductsSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ProductsFilterChanged extends ProductsEvent {
  const ProductsFilterChanged(this.filter);

  final StockFilter filter;

  @override
  List<Object?> get props => [filter];
}

class ProductsSortChanged extends ProductsEvent {
  const ProductsSortChanged(this.sort);

  final ProductSort sort;

  @override
  List<Object?> get props => [sort];
}

class ProductSaved extends ProductsEvent {
  const ProductSaved(this.draft, {this.id});

  final ProductDraft draft;
  final int? id;

  @override
  List<Object?> get props => [draft, id];
}

class ProductDeleted extends ProductsEvent {
  const ProductDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

// ---------- Состояние ----------

class ProductsState extends Equatable {
  const ProductsState({
    this.status = LoadStatus.initial,
    this.products = const [],
    this.query = '',
    this.filter = StockFilter.all,
    this.sort = ProductSort.newest,
    this.lowStockThreshold = SettingsStore.defaultThreshold,
    this.error,
    this.actionStatus = ActionStatus.idle,
    this.actionKind,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<Product> products;
  final String query;
  final StockFilter filter;
  final ProductSort sort;
  final int lowStockThreshold;
  final String? error;
  final ActionStatus actionStatus;
  final ActionKind? actionKind;
  final String? actionMessage;

  /// Товары с учётом поиска, фильтра и сортировки.
  List<Product> get visible {
    final q = query.trim().toLowerCase();
    final list = products.where((p) {
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q) && !p.description.toLowerCase().contains(q)) {
        return false;
      }
      switch (filter) {
        case StockFilter.all:
          return true;
        case StockFilter.inStock:
          return p.stock > 0;
        case StockFilter.low:
          return p.stock > 0 && p.stock <= lowStockThreshold;
        case StockFilter.outOfStock:
          return p.stock == 0;
      }
    }).toList();
    switch (sort) {
      case ProductSort.newest:
        list.sort((a, b) => b.id.compareTo(a.id));
      case ProductSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case ProductSort.stock:
        list.sort((a, b) => a.stock.compareTo(b.stock));
      case ProductSort.price:
        list.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
    }
    return list;
  }

  ProductsState copyWith({
    LoadStatus? status,
    List<Product>? products,
    String? query,
    StockFilter? filter,
    ProductSort? sort,
    int? lowStockThreshold,
    String? error,
    ActionStatus? actionStatus,
    ActionKind? actionKind,
    String? actionMessage,
  }) {
    return ProductsState(
      status: status ?? this.status,
      products: products ?? this.products,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      error: error,
      actionStatus: actionStatus ?? this.actionStatus,
      actionKind: actionKind ?? this.actionKind,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, products, query, filter, sort, lowStockThreshold, error, actionStatus, actionKind, actionMessage];
}

// ---------- BLoC ----------

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc(this._repository, this._settings, DataChangeBus bus)
      : super(ProductsState(lowStockThreshold: _settings.lowStockThreshold)) {
    on<ProductsRequested>(_onRequested);
    on<ProductsSearchChanged>((e, emit) => emit(state.copyWith(query: e.query)));
    on<ProductsFilterChanged>((e, emit) => emit(state.copyWith(filter: e.filter)));
    on<ProductsSortChanged>((e, emit) => emit(state.copyWith(sort: e.sort)));
    on<ProductSaved>(_onSaved);
    on<ProductDeleted>(_onDeleted);
    // Остатки меняются при продажах и движениях склада.
    _busSub = bus.stream.where((c) => c != DataChange.products).listen((_) => add(const ProductsRequested()));
  }

  final ProductRepository _repository;
  final SettingsStore _settings;
  late final StreamSubscription<DataChange> _busSub;

  Future<void> _load(Emitter<ProductsState> emit) async {
    try {
      final products = await _repository.fetchAll();
      emit(state.copyWith(
        status: LoadStatus.success,
        products: products,
        lowStockThreshold: _settings.lowStockThreshold,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onRequested(ProductsRequested event, Emitter<ProductsState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _load(emit);
  }

  Future<void> _onSaved(ProductSaved event, Emitter<ProductsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, actionKind: ActionKind.save));
    try {
      if (event.id == null) {
        await _repository.create(event.draft);
      } else {
        await _repository.update(event.id!, event.draft);
      }
      emit(state.copyWith(
        actionStatus: ActionStatus.success,
        actionMessage: event.id == null ? 'Товар добавлен' : 'Товар сохранён',
      ));
      await _load(emit);
    } on ApiException catch (e) {
      emit(state.copyWith(actionStatus: ActionStatus.failure, actionMessage: e.message));
    }
  }

  Future<void> _onDeleted(ProductDeleted event, Emitter<ProductsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, actionKind: ActionKind.delete));
    try {
      await _repository.delete(event.id);
      emit(state.copyWith(
        actionStatus: ActionStatus.success,
        actionMessage: 'Товар удалён',
        products: state.products.where((p) => p.id != event.id).toList(),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(actionStatus: ActionStatus.failure, actionMessage: e.message));
    }
  }

  @override
  Future<void> close() {
    _busSub.cancel();
    return super.close();
  }
}
