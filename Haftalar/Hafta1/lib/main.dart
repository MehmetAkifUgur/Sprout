import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'data/repositories/habit_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');

  final database = await AppDatabase.open();
  runApp(SproutApp(repository: HabitRepository(database)));
}
