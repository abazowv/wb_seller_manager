import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/data_change_bus.dart';
import '../core/settings_store.dart';

class SettingsState extends Equatable {
  const SettingsState({required this.lowStockThreshold});

  final int lowStockThreshold;

  @override
  List<Object?> get props => [lowStockThreshold];
}

/// Настройки пользователя (порог низкого остатка хранится в shared_preferences).
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._store, this._bus) : super(SettingsState(lowStockThreshold: _store.lowStockThreshold));

  final SettingsStore _store;
  final DataChangeBus _bus;

  Future<void> setLowStockThreshold(int value) async {
    final v = value.clamp(0, 1000);
    await _store.saveLowStockThreshold(v);
    emit(SettingsState(lowStockThreshold: v));
    _bus.notify(DataChange.settings);
  }
}
