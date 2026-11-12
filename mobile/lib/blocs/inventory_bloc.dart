import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../core/settings_store.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/product_repository.dart';
import 'common.dart';

// ---------- События ----------

sealed class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

class InventoryRequested extends InventoryEvent {
  const InventoryRequested();
}

/// Фильтр истории: null — все движения.
class InventoryHistoryFilterChanged extends InventoryEvent {
  const InventoryHistoryFilterChanged(this.type);

  final MovementType? type;

  @override
  List<Object?> get props => [type];
}

class MovementSaved extends InventoryEvent {
  const MovementSaved(this.draft, {this.id});

  final MovementDraft draft;
  final int? id;

  @override
  List<Object?> get props => [draft, id];
}

class MovementDeleted extends InventoryEvent {
  const MovementDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

// ---------- Состояние ----------

class InventoryState extends Equatable {
  const InventoryState({
    this.status = LoadStatus.initial,
    this.products = const [],
    this.movements = const [],
    this.historyFilter,
    this.lowStockThreshold = SettingsStore.defaultThreshold,
    this.error,
    this.actionStatus = ActionStatus.idle,
    this.actionKind,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<Product> products;
  final List<StockMovement> movements;
  final MovementType? historyFilter;
  final int lowStockThreshold;
  final String? error;
  final ActionStatus actionStatus;
  final ActionKind? actionKind;
  final String? actionMessage;

  List<Product> get lowStockProducts => products.where((p) => p.stock <= lowStockThreshold).toList();

  int get totalUnits => products.fold(0, (s, p) => s + p.stock);

  double get stockValue => products.fold(0, (s, p) => s + p.stock * p.purchasePrice);

  List<StockMovement> get visibleMovements =>
      historyFilter == null ? movements : movements.where((m) => m.type == historyFilter).toList();

  InventoryState copyWith({
    LoadStatus? status,
    List<Product>? products,
    List<StockMovement>? movements,
    MovementType? historyFilter,
    bool clearHistoryFilter = false,
    int? lowStockThreshold,
    String? error,
    ActionStatus? actionStatus,
    ActionKind? actionKind,
    String? actionMessage,
  }) {
    return InventoryState(
      status: status ?? this.status,
      products: products ?? this.products,
      movements: movements ?? this.movements,
      historyFilter: clearHistoryFilter ? null : historyFilter ?? this.historyFilter,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      error: error,
      actionStatus: actionStatus ?? this.actionStatus,
      actionKind: actionKind ?? this.actionKind,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        movements,
        historyFilter,
        lowStockThreshold,
        error,
        actionStatus,
        actionKind,
        actionMessage,
      ];
}

// ---------- BLoC ----------

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc(this._inventory, this._products, this._settings, DataChangeBus bus)
      : super(InventoryState(lowStockThreshold: _settings.lowStockThreshold)) {
    on<InventoryRequested>(_onRequested);
    on<InventoryHistoryFilterChanged>(
      (e, emit) => emit(e.type == null ? state.copyWith(clearHistoryFilter: true) : state.copyWith(historyFilter: e.type)),
    );
    on<MovementSaved>(_onSaved);
    on<MovementDeleted>(_onDeleted);
    _busSub = bus.stream.listen((_) => add(const InventoryRequested()));
  }

  final InventoryRepository _inventory;
  final ProductRepository _products;
  final SettingsStore _settings;
  late final StreamSubscription<DataChange> _busSub;

  Future<void> _load(Emitter<InventoryState> emit) async {
    try {
      final results = await Future.wait([_products.fetchAll(), _inventory.fetchMovements()]);
      final products = (results[0] as List<Product>)..sort((a, b) => a.stock.compareTo(b.stock));
      emit(state.copyWith(
        status: LoadStatus.success,
        products: products,
        movements: results[1] as List<StockMovement>,
        lowStockThreshold: _settings.lowStockThreshold,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onRequested(InventoryRequested event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _load(emit);
  }

  Future<void> _onSaved(MovementSaved event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, actionKind: ActionKind.save));
    try {
      if (event.id == null) {
        await _inventory.create(event.draft);
      } else {
        await _inventory.update(event.id!, event.draft);
      }
      emit(state.copyWith(
        actionStatus: ActionStatus.success,
        actionMessage: event.draft.type == MovementType.stockIn ? 'Приход записан' : 'Расход записан',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(actionStatus: ActionStatus.failure, actionMessage: e.message));
    }
  }

  Future<void> _onDeleted(MovementDeleted event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, actionKind: ActionKind.delete));
    try {
      await _inventory.delete(event.id);
      emit(state.copyWith(actionStatus: ActionStatus.success, actionMessage: 'Движение удалено'));
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
