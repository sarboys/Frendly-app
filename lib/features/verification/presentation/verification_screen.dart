import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/verification_state.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final verificationAsync = ref.watch(verificationProvider);

    return BbV5Scaffold(
      child: verificationAsync.when(
        data: (verification) => Stack(
          children: [
            BbV5Page(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const BbV5TopBar(
                    kicker: 'Доверие',
                    title: 'Верификация',
                    accent: 'профиля',
                  ),
                  const SizedBox(height: 20),
                  BbV5Card(
                    tint: BbV5Colors.brandSoft,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeroIcon(
                          icon: LucideIcons.shield_check,
                          color: BbV5Colors.brand,
                        ),
                        const SizedBox(height: 16),
                        const BbV5HeroTitle(
                          title: 'Получи',
                          accent: 'галочку доверия',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Верифицированные профили получают больше приглашений, выше в радаре и доступны фильтру «только проверенные».',
                          style: AppTextStyles.bodySoft.copyWith(
                            fontSize: 13,
                            height: 1.55,
                            color: BbV5Colors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(
                              child: _MetricMiniTile(
                                value: 'x3',
                                label: 'приглашений',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _MetricMiniTile(
                                value: '+38%',
                                label: 'доверия',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _MetricMiniTile(
                                value: 'Free',
                                label: 'галочка',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StepTile(
                    index: 1,
                    icon: LucideIcons.camera,
                    title: 'Селфи',
                    subtitle: 'Покажи лицо без фильтров',
                    done: verification.selfieDone ||
                        verification.status == 'verified',
                  ),
                  const SizedBox(height: 10),
                  _StepTile(
                    index: 2,
                    icon: LucideIcons.file_text,
                    title: 'Документ',
                    subtitle: 'Паспорт или права. Скан удалим в течение 24ч.',
                    done: verification.documentDone ||
                        verification.status == 'verified',
                  ),
                  const SizedBox(height: 10),
                  _StepTile(
                    index: 3,
                    icon: LucideIcons.clock,
                    title: 'Проверка',
                    subtitle: _reviewSubtitle(verification),
                    done: verification.status == 'verified',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BbV5Colors.paperHi,
                      borderRadius: BorderRadius.circular(BbV5Radii.md),
                      border: Border.all(color: BbV5Colors.hair),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.lock,
                              size: 15,
                              color: BbV5Colors.ink,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Что будет с документом',
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'Sora',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: BbV5Colors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '· Сравним фото с селфи и удалим скан в течение 24 часов\n'
                          '· Никогда не показываем документ другим пользователям\n'
                          '· Не передаём третьим сторонам',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11.5,
                            height: 1.55,
                            color: BbV5Colors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  BbV5Card(
                    radius: BbV5Radii.md,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const _HeroIcon(
                          icon: LucideIcons.sparkles,
                          color: BbV5Colors.terra,
                          size: 40,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Premium-проверка',
                                style: AppTextStyles.caption.copyWith(
                                  fontFamily: 'Sora',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: BbV5Colors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+ селфи-видео и live-фото за 30 секунд',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: BbV5Colors.inkMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: BbV5Colors.accent,
                            borderRadius: BorderRadius.circular(BbV5Radii.pill),
                          ),
                          child: Text(
                            '+',
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'Sora',
                              fontWeight: FontWeight.w600,
                              color: BbV5Colors.paperHi,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BbV5FixedBottomBar(
                footer: Text(
                  'Около 2 минут',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: BbV5Colors.inkMute,
                  ),
                ),
                child: BbV5PillButton(
                  label: _ctaLabel(verification),
                  icon: _ctaIcon(verification),
                  dark: true,
                  height: 52,
                  fontSize: 14,
                  expanded: true,
                  onPressed:
                      _submitting || verification.status == 'under_review'
                          ? null
                          : () => _submitNextStep(verification),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: BbV5Colors.accent),
        ),
        error: (error, _) => Center(
          child: Text(
            error.toString(),
            style: AppTextStyles.bodySoft.copyWith(color: BbV5Colors.inkSoft),
          ),
        ),
      ),
    );
  }

  String _reviewSubtitle(VerificationStateData verification) {
    return switch (verification.status) {
      'under_review' => 'Обычно занимает до 5 минут',
      'verified' => 'Завершена',
      _ => 'Ждёт документ',
    };
  }

  String _ctaLabel(VerificationStateData verification) {
    if (verification.status == 'verified') {
      return 'Готово';
    }
    if (verification.status == 'under_review') {
      return 'Документ отправлен';
    }
    return verification.selfieDone
        ? 'Загрузить · Документ'
        : 'Загрузить · Селфи';
  }

  IconData _ctaIcon(VerificationStateData verification) {
    if (verification.status == 'verified') {
      return LucideIcons.check;
    }
    return LucideIcons.eye;
  }

  Future<void> _submitNextStep(VerificationStateData verification) async {
    if (verification.status == 'verified') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль уже верифицирован')),
      );
      return;
    }

    final nextStep = verification.selfieDone ? 'document' : 'selfie';
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _submitting = true;
    });
    try {
      await repository.submitVerificationStep(nextStep);
      if (!mounted) {
        return;
      }
      container.invalidate(verificationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStep == 'selfie' ? 'Селфи загружено' : 'Документ загружен',
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не получилось отправить шаг верификации'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
    required this.icon,
    required this.color,
    this.size = 56,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(size >= 56 ? 18 : 999),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Icon(icon, size: size >= 56 ? 24 : 17, color: color),
    );
  }
}

class _MetricMiniTile extends StatelessWidget {
  const _MetricMiniTile({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.sm),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 15,
              height: 1,
              color: BbV5Colors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9.5,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: BbV5Radii.md,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: done ? BbV5Colors.brand : BbV5Colors.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: done ? BbV5Colors.brand : BbV5Colors.hair,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: done ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                ),
              ),
              if (done)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: BbV5Colors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: BbV5Colors.paper, width: 2),
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      size: 12,
                      color: BbV5Colors.paperHi,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.itemTitle.copyWith(
                    fontSize: 14,
                    color: BbV5Colors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$index/3',
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}
