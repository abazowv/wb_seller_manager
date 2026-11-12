import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../core/formatters.dart';
import '../models/sale.dart';
import '../repositories/sales_repository.dart';
import 'common.dart';

/// Готовые периоды для фильтра продаж.
enum SalesPeriod {
  today('Сегодня'),
  week('7 дней'),
  month('30 дней'),
  currentMonth('Этот месяц'),
  all('Всё время'),
  custom('Период');

  const SalesPeriod(this.label);

  final String label;
}

class SalesFilter extends Equatable {
  const SalesFilter({required this.period, this.from, this.to});

  factory SalesFilter.preset(SalesPeriod period, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    switch (period) {
      case SalesPeriod.today:
        return SalesFilter(period: period, from: today, to: today);
      case SalesPeriod.week:
        return SalesFilter(period: period, from: today.subtract(const Duration(days: 6)), to: today);
      case SalesPeriod.month:
        return SalesFilter(period: period, from: today.subtract(const Duration(days: 29)), to: today);
      case SalesPeriod.currentMonth:
        return SalesFilter(period: period, from: DateTime(today.year, today.month), to: today);
      case SalesPeriod.all:
      case SalesPeriod.custom:
        return SalesFilter(period: period);
    }
  }

  final SalesPeriod period;
  final DateTime? from;
  final DateTime? to;

  @override
  List<Object?> get props => [period, from, to];
}

// ---------- События ----------

sealed class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class SalesRequested extends SalesEvent {
  const SalesRequested();
}

class SalesFilterChanged extends SalesEvent {
  const SalesFilterChanged(this.filter);

  final SalesFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Создать (id == null) или изменить запись о продажах.
class SaleSaved extends SalesEvent {
  const SaleSaved(this.draft, {this.id});

  final SaleDraft draft;
  final int? id;

  @override
  List<Object?> get props => [draft, id];
}

class SaleDeleted extends SalesEvent {
  const SaleDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

// ---------- Состояние ----------

class SalesState extends Equatable {
  const SalesState({
    required this.filter,
    this.status = LoadStatus.initial,
    this.sales = const [],
    this.error,
    this.actionStatus = ActionStatus.idle,
    this.actionKind,
    this.actionMessage,
  });

  final SalesFilter filter;
  final LoadStatus status;
  final List<Sale> sales;
  final String? error;
  final ActionStatus actionStatus;
  final ActionKind? actionKind;
  final String? actionMessage;

  double get totalAmount => sales.fold(0, (s, e) => s + e.totalAmount);

  int get totalOrders => sales.fold(0, (s, e) => s + e.ordersCount);

  int get totalItems => sales.fold(0, (s, e) => s + e.itemsSold);

  SalesState copyWith({
    SalesFilter? filter,
    LoadStatus? status,
    List<Sale>? sales,
    String? error,
    ActionStatus? actionStatus,
    ActionKind? actionKind,
    String? actionMessage,
  }) {
    return SalesState(
      filter: filter ?? this.filter,
      status: status ?? this.status,
      sales: sales ?? this.sales,
      error: error,
      actionStatus: actionStatus ?? this.actionStatus,
      actionKind: actionKind ?? this.actionKind,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [filter, status, sales, error, actionStatus, actionKind, actionMessage];
}

// ---------- BLoC ----------

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  SalesBloc(this._repository, DataChangeBus bus)
      : super(SalesState(filter: SalesFilter.preset(SalesPeriod.month))) {
    on<SalesRequested>(_onRequested);
    on<SalesFilterChanged>(_onFilterChanged);
    on<SaleSaved>(_onSaved);
    on<SaleDeleted>(_onDeleted);
    // Удаление товара меняет название в продажах — перезагружаем список.
    _busSub = bus.stream.where((c) => c == DataChange.products).listen((_) => add(const SalesRequested()));
  }

  final SalesRepository _repository;
  late final StreamSubscription<DataChange> _busSub;

  Future<void> _load(Emitter<SalesState> emit) async {
    try {
      final f = state.filter;
      final sales = await _repository.fetch(
        from: f.from == null ? null : toIsoDate(f.from!),
        to: f.to == null ? null : toIsoDate(f.to!),
      );
      emit(state.copyWith(status: LoadStatus.success, sales: sales));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onRequested(SalesRequested event, Emitter<SalesState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _load(emit);
  }

  Future<void> _onFilterChanged(SalesFilterChanged event, Emitter<SalesState> emit) async {
    emit(state.copyWith(filter: event.filter, status: LoadStatus.loading));
    await _load(emit);
  }

  Future<void> _onSaved(SaleSaved event, Emitter<SalesState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, actionKind: ActionKind.save));
    try {
      if (event.id == null) {
        await _repository.create(event.draft);
      } else {
        await _repository.update(event.id!, event.draft);
      }
      emit(state.copyWith(
        actionStatus: ActionStatus.success,
        actionMessage: event.id == null ? 'Продажа добавлена' : 'Изменения сохранены',
      ));
      await _load(emit);
    } on ApiException catch (e) {
      emit(state.copyWith(actionStatus: ActionStatus.failure, actionMessage: e.message));
    }
  }

  Future<void> _onDeleted(SaleDeleted event, Emitter<SalesState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, actionKind: ActionKind.delete));
    try {
      await _repository.delete(event.id);
      emit(state.copyWith(
        actionStatus: ActionStatus.success,
        actionMessage: 'Запись удалена',
        sales: state.sales.where((s) => s.id != event.id).toList(),
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
