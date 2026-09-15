import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/habit_repository.dart';

/// main() içinde açılmış veritabanı ile override edilir.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider override edilmeli'),
);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(databaseProvider)),
);

/// Testlerde sabit bir "şimdi" vermek için override edilebilir.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
