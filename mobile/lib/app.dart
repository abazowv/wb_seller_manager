import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'blocs/analytics_bloc.dart';
import 'blocs/auth_bloc.dart';
import 'blocs/dashboard_bloc.dart';
import 'blocs/finance_bloc.dart';
import 'blocs/inventory_bloc.dart';
import 'blocs/products_bloc.dart';
import 'blocs/sales_bloc.dart';
import 'blocs/settings_cubit.dart';
import 'core/api_client.dart';
import 'core/data_change_bus.dart';
import 'core/settings_store.dart';
import 'core/theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/reports_repository.dart';
import 'repositories/sales_repository.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

/// Корень приложения: репозитории и глобальные BLoC.
class WbSellerApp extends StatelessWidget {
  const WbSellerApp({super.key, required this.settings, required this.api, required this.bus});

  final SettingsStore settings;
  final ApiClient api;
  final DataChangeBus bus;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: settings),
        RepositoryProvider.value(value: api),
        RepositoryProvider.value(value: bus),
        RepositoryProvider(create: (_) => AuthRepository(api, settings)),
        RepositoryProvider(create: (_) => ProductRepository(api, bus)),
        RepositoryProvider(create: (_) => SalesRepository(api, bus)),
        RepositoryProvider(create: (_) => InventoryRepository(api, bus)),
        RepositoryProvider(create: (_) => ReportsRepository(api)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => AuthBloc(ctx.read<AuthRepository>())..add(const AuthStarted())),
          BlocProvider(create: (_) => SettingsCubit(settings, bus)),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WB Seller Manager',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Данные пользователя (BLoC экранов) живут над Navigator, чтобы быть
      // доступными на всех экранах; при смене пользователя они пересоздаются.
      builder: (context, child) => BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (a, b) => a.status != b.status,
        listener: (context, state) => _navigatorKey.currentState?.popUntil((r) => r.isFirst),
        buildWhen: (a, b) => a.status != b.status || a.user?.id != b.user?.id,
        builder: (context, state) {
          if (state.status != AuthStatus.authenticated) return child!;
          return _UserScope(key: ValueKey(state.user?.id), child: child!);
        },
      ),
      home: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (a, b) => a.status != b.status,
        builder: (context, state) {
          switch (state.status) {
            case AuthStatus.unknown:
              return const SplashScreen();
            case AuthStatus.unauthenticated:
              return const LoginScreen();
            case AuthStatus.authenticated:
              return const HomeShell();
          }
        },
      ),
    );
  }
}

/// BLoC с данными конкретного пользователя.
class _UserScope extends StatelessWidget {
  const _UserScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsStore>();
    final bus = context.read<DataChangeBus>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (ctx) => DashboardBloc(ctx.read<ReportsRepository>(), settings, bus)..add(const DashboardRequested()),
        ),
        BlocProvider(create: (ctx) => SalesBloc(ctx.read<SalesRepository>(), bus)..add(const SalesRequested())),
        BlocProvider(
          create: (ctx) => ProductsBloc(ctx.read<ProductRepository>(), settings, bus)..add(const ProductsRequested()),
        ),
        BlocProvider(
          create: (ctx) => InventoryBloc(ctx.read<InventoryRepository>(), ctx.read<ProductRepository>(), settings, bus)
            ..add(const InventoryRequested()),
        ),
        BlocProvider(create: (ctx) => FinanceBloc(ctx.read<ReportsRepository>(), bus)..add(const FinanceRequested())),
        BlocProvider(
          create: (ctx) => AnalyticsBloc(ctx.read<ReportsRepository>(), bus)..add(const AnalyticsRequested()),
        ),
      ],
      child: child,
    );
  }
}
