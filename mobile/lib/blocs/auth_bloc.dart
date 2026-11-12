import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

// ---------- События ----------

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Запуск приложения: проверяем сохранённый токен.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({required this.name, required this.email, required this.password});

  final String name;
  final String email;
  final String password;

  @override
  List<Object?> get props => [name, email, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested({this.sessionExpired = false});

  final bool sessionExpired;

  @override
  List<Object?> get props => [sessionExpired];
}

// ---------- Состояние ----------

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.isSubmitting = false, this.error});

  final AuthStatus status;
  final User? user;
  final bool isSubmitting;
  final String? error;

  AuthState copyWith({AuthStatus? status, User? user, bool? isSubmitting, String? error, bool clearUser = false}) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, user, isSubmitting, error];
}

// ---------- BLoC ----------

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    _unauthorizedSub = _repository.onUnauthorized.listen((_) {
      if (state.status == AuthStatus.authenticated) add(const AuthLogoutRequested(sessionExpired: true));
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _unauthorizedSub;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    // Небольшая пауза, чтобы splash-экран не мигал.
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 900));
    if (!_repository.hasToken) {
      await minSplash;
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    try {
      final user = await _repository.me();
      await minSplash;
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on ApiException catch (e) {
      await minSplash;
      if (e.statusCode == 401) await _repository.logout();
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        error: e.statusCode == 401 ? 'Сессия истекла, войдите снова' : e.message,
      ));
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final user = await _repository.login(email: event.email.trim(), password: event.password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e.message));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final user = await _repository.register(
        name: event.name.trim(),
        email: event.email.trim(),
        password: event.password,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e.message));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(AuthState(
      status: AuthStatus.unauthenticated,
      error: event.sessionExpired ? 'Сессия истекла, войдите снова' : null,
    ));
  }

  @override
  Future<void> close() {
    _unauthorizedSub.cancel();
    return super.close();
  }
}
