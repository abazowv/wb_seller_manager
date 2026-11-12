import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../models/reports.dart';
import '../repositories/reports_repository.dart';
import 'common.dart';

/// Группировка графиков аналитики.
enum AnalyticsGroup {
  day('day', 'Дни', '30 дней', 'предыдущих 30 дней'),
  week('week', 'Недели', '12 недель', 'предыдущих 12 недель'),
  month('month', 'Месяцы', '12 месяцев', 'предыдущих 12 месяцев');

  const AnalyticsGroup(this.apiValue, this.label, this.rangeLabel, this.previousLabel);

  final String apiValue;
  final String label;
  final String rangeLabel;
  final String previousLabel;
}

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class AnalyticsRequested extends AnalyticsEvent {
  const AnalyticsRequested();
}

class AnalyticsGroupChanged extends AnalyticsEvent {
  const AnalyticsGroupChanged(this.group);

  final AnalyticsGroup group;

  @override
  List<Object?> get props => [group];
}

class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.group = AnalyticsGroup.day,
    this.status = LoadStatus.initial,
    this.report,
    this.error,
  });

  final AnalyticsGroup group;
  final LoadStatus status;
  final AnalyticsReport? report;
  final String? error;

  @override
  List<Object?> get props => [group, status, report, error];
}

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc(this._repository, DataChangeBus bus) : super(const AnalyticsState()) {
    on<AnalyticsRequested>((e, emit) => _load(emit, silent: state.report != null));
    on<AnalyticsGroupChanged>((e, emit) async {
      emit(AnalyticsState(group: e.group, status: LoadStatus.loading, report: state.report));
      await _load(emit, silent: true);
    });
    _busSub = bus.stream.listen((_) => add(const AnalyticsRequested()));
  }

  final ReportsRepository _repository;
  late final StreamSubscription<DataChange> _busSub;

  Future<void> _load(Emitter<AnalyticsState> emit, {bool silent = false}) async {
    if (!silent) emit(AnalyticsState(group: state.group, status: LoadStatus.loading, report: state.report));
    try {
      final report = await _repository.analytics(group: state.group.apiValue);
      emit(AnalyticsState(group: state.group, status: LoadStatus.success, report: report));
    } on ApiException catch (e) {
      emit(AnalyticsState(group: state.group, status: LoadStatus.failure, report: state.report, error: e.message));
    }
  }

  @override
  Future<void> close() {
    _busSub.cancel();
    return super.close();
  }
}
