import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/pet_skins.dart';
import '../../core/theme.dart';
import '../../core/ui/app_button.dart';
import '../../providers.dart';
import '../parents/attach_flow.dart';

/// Создание персонажа — по макетам «segee» (start_1.svg / start_2.svg):
/// жёлтый фон #FFD979 с текстурой (color-burn), сверху оранжевая
/// пилюля-заголовок #F75900, по центру — арт персонажа, снизу кнопка.
/// 1) выбор персонажа (центральный + соседи каруселью с боков),
/// 2) имя (белое поле с оранжевой обводкой на кремовом фоне до низа
/// экрана, текст — ТЁМНЫЙ). Слайд с характеристиками убран — на игру
/// они не влияют.
class PetCreationScreen extends ConsumerStatefulWidget {
  const PetCreationScreen({super.key});

  @override
  ConsumerState<PetCreationScreen> createState() => _PetCreationScreenState();
}

class _PetCreationScreenState extends ConsumerState<PetCreationScreen> {
  final _pager = PageController();
  final _carousel = PageController(viewportFraction: 0.55);
  final _nameController = TextEditingController();
  int _slide = 0;

  // 9 персонажей (PNG-арты от дизайнера, core/pet_skins.dart).
  static const _petCount = 9;
  // По умолчанию выбран ПЕРВЫЙ персонаж.
  int _petIndex = 0;

  @override
  void dispose() {
    _pager.dispose();
    _carousel.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _turnCarousel(int delta) {
    final next = (_petIndex + delta).clamp(0, _petCount - 1);
    if (next == _petIndex) return;
    _carousel.animateToPage(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Придумай имя питомцу')),
      );
      return;
    }
    final profile = ref.read(profileControllerProvider).valueOrNull;
    if (profile == null) {
      await ref.read(profileControllerProvider.notifier).createProfile(name);
    }
    await ref
        .read(gameStateControllerProvider.notifier)
        .createPet(
          petName: name,
          fur: 'Серый',
          ears: 'Круглые',
          character: '1-1-1',
          skin: petSkins[_petIndex],
        );
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.main, (_) => false);
  }

  void _next() {
    if (_slide == 1) {
      _finish();
      return;
    }
    _pager.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  /// «Привязать по коду» — восстановление прогресса на новом устройстве.
  /// Успех с данными с сервера → сразу на главную, минуя создание питомца.
  Future<void> _attachByCode() async {
    final outcome = await AttachCodeSheet.show(context);
    if (!mounted || outcome == null || !outcome.ok) return;
    if (outcome.restored) {
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.main, (_) => false);
    } else {
      // Профиль привязан, но сохранения на сервере нет — питомца создаём
      // как обычно, он уже будет синхронизироваться с привязанным профилем.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Профиль привязан! Теперь создай питомца.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Фон из on_start.png — полноэкранный, СТАТИЧНЫЙ (ничего с ним
          // не происходит: ни анимации, ни сдвигов).
          Image.asset(
            'assets/bg/on_start_full.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: AppColors.yellowBg),
          ),
          SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 26),
                  // Оранжевая пилюля-заголовок (как в макете, r20, #F75900).
                  _TitlePill(text: _slide == 1 ? 'Назови меня!' : 'Выбери персонажа'),
                  Expanded(
                    child: PageView(
                      controller: _pager,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _slide = i),
                      children: [
                        _petCarousel(),
                        _name(),
                      ],
                    ),
                  ),
                  // Нижняя кнопка: белая (макет start_1) / зелёная (start_2).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(52, 0, 52, 8),
                    child: _slide == 1
                        ? AppButton(
                            text: 'Готово',
                            variant: AppButtonVariant.success,
                            onPressed: _next,
                          )
                        : AppButton(text: 'Далее', onPressed: _next),
                  ),
                  // Спокойный вход «у меня уже есть код» — не конкурирует
                  // с основной кнопкой, виден только на первом слайде.
                  // Visibility с maintainSize — чтобы кнопка «Далее» не
                  // прыгала при переходе ко второму слайду.
                  Visibility(
                    visible: _slide == 0,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(200, 48),
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: _attachByCode,
                      child: const Text(
                        'Привязать по коду',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
    );
  }

  // ---- Слайд 1: выбор персонажа (start_1.svg) ----
  Widget _petCarousel() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Центральный персонаж + соседи по карусели (без статических
        // «двойников» — соседи рисуются только каруселью).
        PageView.builder(
          controller: _carousel,
          itemCount: _petCount,
          onPageChanged: (i) => setState(() => _petIndex = i),
          itemBuilder: (_, i) {
            final center = i == _petIndex;
            return Center(
              child: AnimatedScale(
                scale: center ? 1 : 0.8,
                duration: const Duration(milliseconds: 200),
                child: Opacity(
                  opacity: center ? 1 : 0.45,
                  child: Image.asset(
                    petSkins[i],
                    height: 400,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.pets, size: 160, color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
        // Стрелки карусели.
        Positioned(
          left: 16,
          child: _carouselArrow(Icons.chevron_left, () => _turnCarousel(-1)),
        ),
        Positioned(
          right: 16,
          child: _carouselArrow(Icons.chevron_right, () => _turnCarousel(1)),
        ),
        // Название выбранного персонажа (вместо «Персонаж N из 9»).
        Positioned(
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              petSkinNames[_petIndex],
              style: AppTextStyles.label(color: Colors.black87, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _carouselArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFBA0000), size: 32),
      ),
    );
  }

  // ---- Слайд 2: имя (start_2.svg) ----
  Widget _name() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // При поднятой клавиатуре места меньше — персонаж уменьшается,
        // но не вылезает за заголовок и не перекрывает поле.
        final petHeight = math.min(430.0, constraints.maxHeight * 0.52);
        return Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                // Большой персонаж (в макете 304×621).
                Expanded(
                  child: Center(
                    child: Image.asset(
                      petSkins[_petIndex],
                      height: petHeight,
                      errorBuilder: (_, _, _) => const Icon(Icons.pets, size: 140),
                    ),
                  ),
                ),
                // Белое поле имени: обводка #F75900 4px, ТЁМНЫЙ текст
                // (было: белый текст на белом фоне).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.yellowButton, width: 4),
                    ),
                    child: TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      maxLength: 16,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Оранжевая пилюля-заголовок сверху (r20, #F75900, белый текст) — как
/// в макетах start_1/start_2.
class _TitlePill extends StatelessWidget {
  final String text;

  const _TitlePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.yellowButton,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          text,
          style: AppTextStyles.label(color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
