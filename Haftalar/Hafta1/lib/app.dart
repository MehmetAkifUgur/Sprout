import 'package:flutter/material.dart';

import 'data/repositories/habit_repository.dart';
import 'presentation/screens/home/home_screen.dart';

class SproutApp extends StatelessWidget {
  const SproutApp({super.key, required this.repository, this.clock});

  final HabitRepository repository;

  /// Testlerde sabit bir "şimdi" vermek için.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitki Büyüt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: HomeScreen(repository: repository, clock: clock ?? DateTime.now),
    );
  }
}
