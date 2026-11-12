import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/data_change_bus.dart';
import 'core/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru';
  await initializeDateFormatting('ru');

  final settings = await SettingsStore.create();
  final api = ApiClient(settings);
  final bus = DataChangeBus();

  runApp(WbSellerApp(settings: settings, api: api, bus: bus));
}
