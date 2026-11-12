import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../core/formatters.dart';
import '../models/reports.dart';
import '../repositories/reports_repository.dart';
import 'common.dart';
import 'sales_bloc.dart' show SalesFilter, SalesPeriod;

sealed class FinanceEvent extends Equatable {
  const FinanceEvent();

  @override
  List<Object?> get props => [];
}

class FinanceRequested extends FinanceEvent {
  const FinanceRequested();
}

class FinancePeriodChanged extends FinanceEvent {
  const FinancePeriodChanged(this.filter);

  final SalesFilter filter;

  @override
  List<Object?> get props => [filter];
}

class FinanceState extends Equatable {
  const FinanceState({required this.filter, this.status = LoadStatus.initial, this.report, this.error});

  final SalesFilter filter;
  final LoadStatus status;
  final FinanceReport? report;
  final String? error;

  @override
  List<Object?> get props => [filter, status, report, error];
}

/// Финансы за период: выручка, себестоимость, оценочная прибыль.
class FinanceBloc extends Bloc<FinanceEvent, FinanceState> {
  FinanceBloc(this._repository, DataChangeBus bus)
      : super(FinanceState(filter: SalesFilter.preset(SalesPeriod.currentMonth))) {
    on<FinanceRequested>((e, emit) => _load(emit, silent: state.report != null));
    on<FinancePeriodChanged>((e, emit) async {
      emit(FinanceState(filter: e.filter, status: LoadStatus.loading, report: state.report));
      await _load(emit);
    });
    _busSub = bus.stream.listen((_) => add(const FinanceRequested()));
  }

  final ReportsRepository _repository;
  late final StreamSubscription<DataChange> _busSub;

  Future<void> _load(Emitter<FinanceState> emit, {bool silent = false}) async {
    if (!silent) emit(FinanceState(filter: state.filter, status: LoadStatus.loading, report: state.report));
    final today = dateOnly(DateTime.now());
    final from = state.filter.from ?? DateTime(today.year - 5);
    final to = state.filter.to ?? today;
    try {
      final report = await _repository.finance(from: toIsoDate(from), to: toIsoDate(to));
      emit(FinanceState(filter: state.filter, status: LoadStatus.success, report: report));
    } on ApiException catch (e) {
      emit(FinanceState(filter: state.filter, status: LoadStatus.failure, report: state.report, error: e.message));
    }
  }

  @override
  Future<void> close() {
    _busSub.cancel();
    return super.close();
  }
}
