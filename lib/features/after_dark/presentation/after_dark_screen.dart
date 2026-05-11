import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class AfterDarkScreen extends StatefulWidget {
  const AfterDarkScreen({super.key});

  @override
  State<AfterDarkScreen> createState() => _AfterDarkScreenState();
}

class _AfterDarkScreenState extends State<AfterDarkScreen> {
  bool _notifyEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BbV5AfterDarkColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AfterDarkBackground()),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _AfterDarkHeader(
                          onBack: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _AfterDarkBadge(),
                            const SizedBox(height: 18),
                            Text(
                              'Ночные встречи\nс мягкими правилами.',
                              style: bbV5DisplayStyle(
                                fontSize: 34,
                                height: 0.98,
                                color: BbV5AfterDarkColors.foreground,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Приватный режим 18+ для событий, где важны consent, безопасность и понятные границы.',
                              style: AppTextStyles.bodySoft.copyWith(
                                color: BbV5AfterDarkColors.foregroundSoft,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 26, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _LockedTeaserCard(),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      sliver: SliverGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.2,
                        children: const [
                          _AfterDarkFeature(
                            icon: LucideIcons.shield_check,
                            title: 'Consent first',
                            subtitle: 'Кодекс до входа',
                          ),
                          _AfterDarkFeature(
                            icon: LucideIcons.lock,
                            title: 'Закрытый адрес',
                            subtitle: 'Локация после подтверждения',
                          ),
                          _AfterDarkFeature(
                            icon: LucideIcons.moon,
                            title: 'Ночной радар',
                            subtitle: 'Только 18+ события',
                          ),
                          _AfterDarkFeature(
                            icon: LucideIcons.sparkles,
                            title: 'Inner Circle',
                            subtitle: 'Малые группы',
                          ),
                          _AfterDarkFeature(
                            icon: LucideIcons.eye_off,
                            title: 'Без съемки',
                            subtitle: 'Приватность по умолчанию',
                          ),
                          _AfterDarkFeature(
                            icon: LucideIcons.bell,
                            title: 'Ранний доступ',
                            subtitle: 'Сначала уведомление',
                          ),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 132),
                      sliver: SliverToBoxAdapter(
                        child: _AfterDarkCodeCard(
                          notifyEnabled: _notifyEnabled,
                          onNotify: () {
                            setState(() => _notifyEnabled = true);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AfterDarkBottomBar(
              notifyEnabled: _notifyEnabled,
              onNotify: () {
                setState(() => _notifyEnabled = true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterDarkHeader extends StatelessWidget {
  const _AfterDarkHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AfterDarkCircleButton(
          icon: LucideIcons.arrow_left,
          onTap: onBack,
        ),
        const Spacer(),
        const _AfterDarkCircleButton(icon: LucideIcons.shield_check),
      ],
    );
  }
}

class _AfterDarkCircleButton extends StatelessWidget {
  const _AfterDarkCircleButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: BbV5AfterDarkColors.surface.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: BbV5AfterDarkColors.border),
            boxShadow: BbV5AfterDarkColors.glowShadow,
          ),
          child: Icon(icon, size: 18, color: BbV5AfterDarkColors.foreground),
        ),
      ),
    );
  }
}

class _AfterDarkBadge extends StatelessWidget {
  const _AfterDarkBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: BbV5AfterDarkColors.neonGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: BbV5AfterDarkColors.neonShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.moon,
              size: 14,
              color: BbV5AfterDarkColors.foreground,
            ),
            const SizedBox(width: 7),
            Text(
              'After Dark',
              style: AppTextStyles.caption.copyWith(
                fontFamily: 'Sora',
                color: BbV5AfterDarkColors.foreground,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedTeaserCard extends StatelessWidget {
  const _LockedTeaserCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BbV5AfterDarkColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BbV5AfterDarkColors.border),
        boxShadow: BbV5AfterDarkColors.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -34,
            child: Icon(
              LucideIcons.moon,
              size: 124,
              color: BbV5AfterDarkColors.magenta.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: BbV5AfterDarkColors.neonGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: BbV5AfterDarkColors.neonShadow,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: BbV5AfterDarkColors.foreground,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Тизер закрыт до запуска',
                style: bbV5DisplayStyle(
                  fontSize: 22,
                  color: BbV5AfterDarkColors.foreground,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Мы откроем подборку ночных форматов после модерации, проверки safety и настройки доступа.',
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5AfterDarkColors.foregroundSoft,
                  height: 1.42,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AfterDarkFeature extends StatelessWidget {
  const _AfterDarkFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BbV5AfterDarkColors.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BbV5AfterDarkColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: BbV5AfterDarkColors.cyan),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.itemTitle.copyWith(
              color: BbV5AfterDarkColors.foreground,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5AfterDarkColors.foregroundMute,
              letterSpacing: 0,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterDarkCodeCard extends StatelessWidget {
  const _AfterDarkCodeCard({
    required this.notifyEnabled,
    required this.onNotify,
  });

  final bool notifyEnabled;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BbV5AfterDarkColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BbV5AfterDarkColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.shield_check,
                size: 18,
                color: BbV5AfterDarkColors.cyan,
              ),
              const SizedBox(width: 8),
              Text(
                'Кодекс After Dark',
                style: AppTextStyles.itemTitle.copyWith(
                  color: BbV5AfterDarkColors.foreground,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Consent first. Без съемки. Один репорт сразу уходит в safety очередь.',
            style: AppTextStyles.bodySoft.copyWith(
              color: BbV5AfterDarkColors.foregroundSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _AfterDarkNotifyButton(
            notifyEnabled: notifyEnabled,
            onNotify: onNotify,
          ),
        ],
      ),
    );
  }
}

class _AfterDarkBottomBar extends StatelessWidget {
  const _AfterDarkBottomBar({
    required this.notifyEnabled,
    required this.onNotify,
  });

  final bool notifyEnabled;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BbV5AfterDarkColors.background.withValues(alpha: 0),
            BbV5AfterDarkColors.background.withValues(alpha: 0.96),
            BbV5AfterDarkColors.background,
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: _AfterDarkNotifyButton(
                    notifyEnabled: notifyEnabled,
                    onNotify: onNotify,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor:
                            BbV5AfterDarkColors.surface.withValues(alpha: 0.7),
                        disabledForegroundColor:
                            BbV5AfterDarkColors.foregroundMute,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Скоро',
                        style: AppTextStyles.button.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AfterDarkNotifyButton extends StatelessWidget {
  const _AfterDarkNotifyButton({
    required this.notifyEnabled,
    required this.onNotify,
  });

  final bool notifyEnabled;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: notifyEnabled ? null : onNotify,
        icon: Icon(
          notifyEnabled ? LucideIcons.check : LucideIcons.bell,
          size: 16,
        ),
        label: Text(notifyEnabled ? 'Ждем запуск' : 'Уведомить'),
        style: FilledButton.styleFrom(
          backgroundColor: BbV5AfterDarkColors.magenta,
          foregroundColor: BbV5AfterDarkColors.foreground,
          disabledBackgroundColor: BbV5AfterDarkColors.violet,
          disabledForegroundColor: BbV5AfterDarkColors.foreground,
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}

class _AfterDarkBackground extends StatelessWidget {
  const _AfterDarkBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF160D24),
                Color(0xFF2B143A),
                Color(0xFF3A1230),
              ],
            ),
          ),
        ),
        Positioned(
          right: -80,
          top: -86,
          width: 260,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x66FF3EA5), Color(0x00FF3EA5)],
              ),
            ),
          ),
        ),
        Positioned(
          left: -100,
          top: 260,
          width: 320,
          height: 320,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x552FE3FF), Color(0x002FE3FF)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
