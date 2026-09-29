import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../providers.dart';

/// Разводящий экран: есть профиль с питомцем → главная, иначе создание.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final profile = await ref.read(profileControllerProvider.future);
    final game = await ref.read(gameStateControllerProvider.future);
    final hasPet = profile != null && game.hasPet();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      hasPet ? Routes.main : Routes.createPet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/pet/logo.png',
              width: 180,
              height: 180,
              errorBuilder: (_, _, _) =>
                  Text('ФИННИ', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: c.onSurface)),
            ),
            const SizedBox(height: 16),
            Text('ФИННИ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: c.onSurface)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
