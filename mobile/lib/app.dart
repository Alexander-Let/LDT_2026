import 'package:flutter/material.dart';

import 'app/routes.dart';
import 'core/theme.dart';
import 'features/diary/diary_screen.dart';
import 'features/glossary/glossary_screen.dart';
import 'features/main/main_shell.dart';
import 'features/parents/parents_screen.dart';
import 'features/path/path_task_screen.dart';
import 'features/pet_creation/pet_creation_screen.dart';
import 'features/splash/splash_screen.dart';

/// Корень приложения: тёмная тема + именованные роуты.
class FinniApp extends StatelessWidget {
  const FinniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Финни',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppColors.dark),
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (_) => const SplashScreen(),
        Routes.createPet: (_) => const PetCreationScreen(),
        Routes.main: (_) => const MainShell(),
        Routes.pathTask: (_) => const PathTaskScreen(),
        Routes.parents: (_) => const ParentsScreen(),
        Routes.diary: (_) => const DiaryScreen(),
        Routes.glossary: (_) => const GlossaryScreen(),
      },
    );
  }
}
