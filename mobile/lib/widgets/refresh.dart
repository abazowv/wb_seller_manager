import 'package:flutter_bloc/flutter_bloc.dart';

/// Для RefreshIndicator: ждём, пока BLoC закончит перезагрузку.
Future<void> waitForReload<S>(BlocBase<S> bloc, bool Function(S state) isDone) async {
  await bloc.stream.firstWhere(isDone).timeout(const Duration(seconds: 20), onTimeout: () => bloc.state);
}
