import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/section_header.dart';
import '../../providers.dart';

/// Справка (по макету iPhone 17 - 17): синяя шапка с артом, тёмная часть
/// со скруглённым верхом, термины глоссария из контент-бандла.
class GlossaryScreen extends ConsumerWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final terms = ref.watch(gameContentProvider)?.glossary ?? const [];

    return Scaffold(
      backgroundColor: AppColors.figmaHeaderBlue,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                const SectionHeader(
                  title: 'Справка',
                  color: AppColors.figmaHeaderBlue,
                  artAsset: 'assets/bg/header_art.png',
                  height: 160,
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
            RoundedBody(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (terms.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('Термины подгружаются…',
                              style: AppTextStyles.body(color: c.textDim)),
                        ),
                      )
                    else
                      for (final term in terms)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.figmaCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.figmaCard, width: 1.5),
                              ),
                              child: ExpansionTile(
                                leading: Text(term.emoji,
                                    style: const TextStyle(fontSize: 22)),
                                title: Text(term.term,
                                    style: AppTextStyles.body(
                                        color: c.text,
                                        size: 16,
                                        weight: FontWeight.w700)),
                                iconColor: c.gold,
                                collapsedIconColor: c.textDim,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(term.text,
                                          style: AppTextStyles.body(
                                              color: c.textDim, size: 14)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
