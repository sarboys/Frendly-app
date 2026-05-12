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

  void _toggleNotify() {
    setState(() => _notifyEnabled = !_notifyEnabled);
    if (_notifyEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Сообщим, как только запустим After Dark'),
          backgroundColor: BbV5AfterDarkColors.magenta,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    }
  }

  void _showRestoreMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Раздел закрыт. Откроется после анонса.'),
        backgroundColor: BbV5AfterDarkColors.violetDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

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
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 128),
                      sliver: SliverList.list(
                        children: [
                          _AfterDarkHeader(
                            onBack: () => Navigator.of(context).maybePop(),
                            onRestore: _showRestoreMessage,
                          ),
                          const SizedBox(height: 24),
                          const Center(child: _AfterDarkBadge()),
                          const SizedBox(height: 20),
                          Text(
                            'Ночной круг для тех,\nкто живёт интенсивнее.',
                            textAlign: TextAlign.center,
                            style: bbV5DisplayStyle(
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.02,
                              color: BbV5AfterDarkColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Свидания, найтлайф, wellness и closed play — в защищённом, верифицированном кругу.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySoft.copyWith(
                                color: BbV5AfterDarkColors.foregroundSoft,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const _LockedTeaserCard(),
                          const SizedBox(height: 24),
                          const _AfterDarkFeatureList(),
                          const SizedBox(height: 28),
                          _AfterDarkNotifyRow(
                            notifyEnabled: _notifyEnabled,
                            onNotify: _toggleNotify,
                          ),
                          const SizedBox(height: 12),
                          const _AfterDarkDisabledCta(),
                          const SizedBox(height: 12),
                          Text(
                            'Запуск ограниченным составом · по приглашениям',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: BbV5AfterDarkColors.foregroundMute,
                              fontSize: 10.5,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterDarkHeader extends StatelessWidget {
  const _AfterDarkHeader({
    required this.onBack,
    required this.onRestore,
  });

  final VoidCallback onBack;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AfterDarkCircleButton(
          icon: LucideIcons.arrow_left,
          onTap: onBack,
        ),
        const Spacer(),
        TextButton(
          onPressed: onRestore,
          style: TextButton.styleFrom(
            foregroundColor: BbV5AfterDarkColors.foregroundSoft,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Восстановить'),
        ),
      ],
    );
  }
}

class _AfterDarkCircleButton extends StatelessWidget {
  const _AfterDarkCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: BbV5AfterDarkColors.surfaceHi,
            shape: BoxShape.circle,
            border: Border.all(color: BbV5AfterDarkColors.border),
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
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            BbV5AfterDarkColors.magenta,
            BbV5AfterDarkColors.violet,
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: BbV5AfterDarkColors.neonShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.sparkles,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'FRENDLY+ 18 · AFTER DARK',
              style: AppTextStyles.caption.copyWith(
                fontFamily: 'Sora',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1,
                letterSpacing: 1.1,
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BbV5AfterDarkColors.surfaceHi,
            BbV5AfterDarkColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BbV5AfterDarkColors.border),
      ),
      child: Column(
        children: [
          const _BlurredPreviewDots(),
          const SizedBox(height: 16),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: BbV5AfterDarkColors.magenta.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: BbV5AfterDarkColors.magenta.withValues(alpha: 0.33),
              ),
            ),
            child: const Icon(
              LucideIcons.lock,
              color: BbV5AfterDarkColors.magenta,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '8 событий сегодня ночью',
            textAlign: TextAlign.center,
            style: AppTextStyles.itemTitle.copyWith(
              color: BbV5AfterDarkColors.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Открой раздел, чтобы увидеть детали',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: BbV5AfterDarkColors.foregroundMute,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredPreviewDots extends StatelessWidget {
  const _BlurredPreviewDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewDot(color: Color(0xFFE94BB8)),
        SizedBox(width: 8),
        _PreviewDot(color: Color(0xFFF59E0B)),
        SizedBox(width: 8),
        _PreviewDot(color: Color(0xFF8B5CF6)),
      ],
    );
  }
}

class _PreviewDot extends StatelessWidget {
  const _PreviewDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, BbV5AfterDarkColors.violetDeep],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _AfterDarkFeatureList extends StatelessWidget {
  const _AfterDarkFeatureList();

  static const _features = [
    _AfterDarkFeatureData(
      icon: LucideIcons.eye,
      title: 'Закрытая лента After Dark',
      subtitle: 'Найтлайф, свидания, wellness и Inner Circle',
    ),
    _AfterDarkFeatureData(
      icon: LucideIcons.shield_check,
      title: 'Только верифицированные',
      subtitle: 'Все участники прошли проверку возраста и фото',
    ),
    _AfterDarkFeatureData(
      icon: LucideIcons.lock,
      title: 'Скрытые локации',
      subtitle: 'Адрес открывается за 4 часа до старта',
    ),
    _AfterDarkFeatureData(
      icon: LucideIcons.key_round,
      title: 'NDA · кодекс молчания',
      subtitle: 'Что было ночью — остаётся в круге',
    ),
    _AfterDarkFeatureData(
      icon: LucideIcons.heart,
      title: 'Безопасность 360°',
      subtitle: 'SOS, сопровождение, доверенные лица — всегда под рукой',
    ),
    _AfterDarkFeatureData(
      icon: LucideIcons.file_text,
      title: 'Кодекс After Dark',
      subtitle: 'Согласие, уважение, никакого harassment. Жёстко.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final feature in _features) ...[
          _AfterDarkFeatureRow(feature: feature),
          if (feature != _features.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AfterDarkFeatureData {
  const _AfterDarkFeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _AfterDarkFeatureRow extends StatelessWidget {
  const _AfterDarkFeatureRow({required this.feature});

  final _AfterDarkFeatureData feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BbV5AfterDarkColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BbV5AfterDarkColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BbV5AfterDarkColors.violet.withValues(alpha: 0.27),
                  BbV5AfterDarkColors.magenta.withValues(alpha: 0.13),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BbV5AfterDarkColors.border),
            ),
            child: Icon(
              feature.icon,
              size: 16,
              color: BbV5AfterDarkColors.magenta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: AppTextStyles.itemTitle.copyWith(
                    color: BbV5AfterDarkColors.foreground,
                    fontSize: 13.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5AfterDarkColors.foregroundMute,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              LucideIcons.sparkles,
              size: 14,
              color: BbV5AfterDarkColors.magenta,
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterDarkNotifyRow extends StatelessWidget {
  const _AfterDarkNotifyRow({
    required this.notifyEnabled,
    required this.onNotify,
  });

  final bool notifyEnabled;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onNotify,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: notifyEnabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      BbV5AfterDarkColors.violet.withValues(alpha: 0.2),
                      BbV5AfterDarkColors.magenta.withValues(alpha: 0.13),
                    ],
                  )
                : null,
            color: notifyEnabled ? null : BbV5AfterDarkColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: notifyEnabled
                  ? BbV5AfterDarkColors.magenta.withValues(alpha: 0.47)
                  : BbV5AfterDarkColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notifyEnabled
                      ? BbV5AfterDarkColors.magenta
                      : BbV5AfterDarkColors.surfaceHi,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notifyEnabled ? LucideIcons.check : LucideIcons.bell,
                  size: 16,
                  color: notifyEnabled
                      ? Colors.white
                      : BbV5AfterDarkColors.foregroundSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notifyEnabled ? 'Уведомим первым' : 'Уведомить о запуске',
                      style: AppTextStyles.itemTitle.copyWith(
                        color: BbV5AfterDarkColors.foreground,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Без спама. Только когда откроем доступ.',
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5AfterDarkColors.foregroundMute,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AfterDarkDisabledCta extends StatelessWidget {
  const _AfterDarkDisabledCta();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              BbV5AfterDarkColors.violet.withValues(alpha: 0.4),
              BbV5AfterDarkColors.magenta.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: BbV5AfterDarkColors.neonShadow,
        ),
        child: Opacity(
          opacity: 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.moon,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Скоро · следите за обновлениями',
                      style: AppTextStyles.button.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.84,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AfterDarkBackground extends StatelessWidget {
  const _AfterDarkBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                BbV5AfterDarkColors.background,
                BbV5AfterDarkColors.backgroundDeep,
              ],
            ),
          ),
        ),
        Positioned(
          right: -120,
          top: -120,
          width: 320,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  BbV5AfterDarkColors.magenta.withValues(alpha: 0.2),
                  BbV5AfterDarkColors.magenta.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -150,
          top: 180,
          width: 360,
          height: 300,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  BbV5AfterDarkColors.violet.withValues(alpha: 0.2),
                  BbV5AfterDarkColors.violet.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -40,
          right: -40,
          bottom: -170,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  BbV5AfterDarkColors.violetDeep.withValues(alpha: 0.33),
                  BbV5AfterDarkColors.violetDeep.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
