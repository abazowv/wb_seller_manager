import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../core/settings_store.dart';
import '../models/reports.dart';
import '../repositories/reports_repository.dart';
import 'common.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить/обновить сводку. silent — без индикатора загрузки на весь экран.
class DashboardRequested extends DashboardEvent {
  const DashboardRequested({this.silent = false});

  final bool silent;

  @override
  List<Object?> get props => [silent];
}

class DashboardState extends Equatable {
  const DashboardState({this.status = LoadStatus.initial, this.data, this.error});

  final LoadStatus status;
  final DashboardData? data;
  final String? error;

  @override
  List<Object?> get props => [status, data, error];
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._repository, this._settings, DataChangeBus bus) : super(const DashboardState()) {
    on<DashboardRequested>(_onRequested);
    // Любое изменение данных — пересчитываем сводку автоматически.
    _busSub = bus.stream.listen((_) => add(const DashboardRequested(silent: true)));
  }

  final ReportsRepository _repository;
  final SettingsStore _settings;
  late final StreamSubscription<DataChange> _busSub;

  Future<void> _onRequested(DashboardRequested event, Emitter<DashboardState> emit) async {
    if (!event.silent || state.data == null) {
      emit(DashboardState(status: LoadStatus.loading, data: state.data));
    }
    try {
      final data = await _repository.dashboard(lowStockThreshold: _settings.lowStockThreshold);
      emit(DashboardState(status: LoadStatus.success, data: data));
    } on ApiException catch (e) {
      emit(DashboardState(status: LoadStatus.failure, data: state.data, error: e.message));
    }
  }

  @override
  Future<void> close() {
    _busSub.cancel();
    return super.close();
  }
}
