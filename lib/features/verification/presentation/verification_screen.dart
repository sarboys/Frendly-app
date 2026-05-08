import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final verificationAsync = ref.watch(verificationProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: verificationAsync.when(
          data: (verification) => Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    ),
                    Expanded(
                      child: Text(
                        'Верификация',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.itemTitle.copyWith(
                          fontSize: 16,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.secondary,
                            colors.secondary.withValues(alpha: 0.82),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colors.secondaryForeground
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.verified_user_outlined,
                              color: colors.secondaryForeground,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Получи синюю галочку',
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: colors.secondaryForeground,
                              fontSize: 22,
                              height: 1.25,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Верифицированные профили получают в 3 раза больше приглашений и видны в фильтре «только проверенные».',
                            style: AppTextStyles.bodySoft.copyWith(
                              color: colors.secondaryForeground
                                  .withValues(alpha: 0.9),
                              fontSize: 13,
                              height: 1.625,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StepTile(
                      index: 1,
                      icon: Icons.camera_alt_outlined,
                      title: 'Селфи',
                      subtitle: 'Покажи лицо без фильтров',
                      done: verification.selfieDone ||
                          verification.status == 'verified',
                    ),
                    const SizedBox(height: 12),
                    _StepTile(
                      index: 2,
                      icon: Icons.description_outlined,
                      title: 'Документ',
                      subtitle: 'Паспорт или права. Скан удалим.',
                      done: verification.documentDone ||
                          verification.status == 'verified',
                    ),
                    const SizedBox(height: 12),
                    _StepTile(
                      index: 3,
                      icon: Icons.schedule_outlined,
                      title: 'Проверка',
                      subtitle: verification.status == 'under_review'
                          ? 'Обычно за 5 минут'
                          : verification.status == 'verified'
                              ? 'Завершена'
                              : 'Ждёт документ',
                      done: verification.status == 'verified',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.secondarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Что будет с документом',
                            style: AppTextStyles.itemTitle.copyWith(
                              fontSize: 13,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '· Сравним фото с селфи и удалим скан в течение 24 часов\n'
                            '· Не показываем твой документ другим пользователям\n'
                            '· Никогда не передаём третьим сторонам',
                            style: AppTextStyles.meta.copyWith(
                              color: colors.inkSoft,
                              fontWeight: FontWeight.w400,
                              height: 1.625,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background.withValues(alpha: 0.92),
                    border: Border(
                      top: BorderSide(
                        color: colors.border.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.foreground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _submitting ||
                                    verification.status == 'under_review'
                                ? null
                                : () async {
                                    final nextStep = verification.selfieDone
                                        ? 'document'
                                        : 'selfie';
                                    final repository =
                                        ref.read(backendRepositoryProvider);
                                    final container = ProviderScope.containerOf(
                                      context,
                                      listen: false,
                                    );
                                    setState(() {
                                      _submitting = true;
                                    });
                                    try {
                                      await repository
                                          .submitVerificationStep(nextStep);
                                      if (!mounted) {
                                        return;
                                      }
                                      container
                                          .invalidate(verificationProvider);
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Не получилось отправить шаг верификации',
                                            ),
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
                                  },
                            child: Text(
                              verification.status == 'under_review'
                                  ? 'Документ отправлен'
                                  : verification.selfieDone
                                      ? 'Загрузить документ'
                                      : 'Отправить селфи',
                              style: AppTextStyles.button.copyWith(
                                color: colors.primaryForeground,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Около 2 минут',
                          style: AppTextStyles.meta.copyWith(
                            color: colors.inkMute,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.primary),
          ),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
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
    final colors = AppColors.of(context);
    final subtitleColor = done ? colors.inkSoft : colors.inkMute;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 20, color: colors.inkSoft),
              ),
              if (done)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.card, width: 2),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: colors.secondaryForeground,
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
                  style: AppTextStyles.itemTitle.copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.meta.copyWith(
                    color: subtitleColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$index/3',
            style: AppTextStyles.meta.copyWith(
              color: colors.inkMute,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
