import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/utils/frendly_legal_links.dart';
import 'package:mobile2/shared/widgets/dateasy_refresh_indicator.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(paymentsCatalogProvider);
    final perks = _perksFromCatalog(catalog.valueOrNull);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > 420 ? 420.0 : constraints.maxWidth;

          return Center(
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: DecoratedBox(
                decoration: const BoxDecoration(gradient: dateasyHeroGradient),
                child: Stack(
                  children: [
                    const _GlowBlob(
                      alignment: Alignment(1.18, -1.12),
                      colorA: DateasyColors.lilac,
                      colorB: DateasyColors.pink,
                      opacity: 0.4,
                    ),
                    const _GlowBlob(
                      alignment: Alignment(-1.18, 1.2),
                      colorA: DateasyColors.lime,
                      colorB: DateasyColors.lime2,
                      opacity: 0.3,
                    ),
                    SafeArea(
                      child: DateasyRefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(paymentsCatalogProvider);
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    const _TopBar(),
                                    const _HeroBlock(),
                                    _PerkList(
                                      perks: perks,
                                      loading: catalog.isLoading,
                                      hasError: catalog.hasError,
                                    ),
                                    const _PaymentsPausedPanel(),
                                    const SizedBox(height: 10),
                                    const _PaywallLegalLinks(),
                                  ],
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
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        _GlassIconButton(
          icon: LucideIcons.x,
          onTap: () => context.go('/profile'),
        ),
      ],
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: dateasyPinkGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55FF639F),
                  blurRadius: 30,
                  spreadRadius: -12,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.crown,
              color: DateasyColors.foreground,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Frendly',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: dateasyLimeGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Plus',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: DateasyColors.backgroundDeep,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Больше встреч, лайков и приоритет в радаре',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 14,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkList extends StatelessWidget {
  const _PerkList({
    required this.perks,
    required this.loading,
    required this.hasError,
  });

  final List<_Perk> perks;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (perks.isEmpty) {
      return _InlineState(
        text: loading
            ? 'Загружаем преимущества Plus'
            : hasError
                ? 'Не удалось загрузить преимущества Plus'
                : 'Plus скоро станет доступен',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0; index < perks.length; index++) ...[
              _PerkRow(perk: perks[index]),
              if (index != perks.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.perk});

  final _Perk perk;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: dateasyLimeGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            perk.icon,
            color: DateasyColors.backgroundDeep,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            perk.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                ),
          ),
        ),
        const Icon(
          LucideIcons.check,
          color: DateasyColors.lime,
          size: 16,
        ),
      ],
    );
  }
}

class _PaymentsPausedPanel extends StatelessWidget {
  const _PaymentsPausedPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: _GlassPanel(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Plus скоро',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Подписка и покупка токенов пока недоступны.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallLegalLinks extends StatelessWidget {
  const _PaywallLegalLinks();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: DateasyColors.muted,
          fontSize: 10,
          decoration: TextDecoration.underline,
        );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 0,
      children: [
        _LegalTextButton(
          label: 'Terms of Use (EULA)',
          url: frendlyTermsUrl,
          style: style,
        ),
        Text(
          '.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
                fontSize: 10,
              ),
        ),
        _LegalTextButton(
          label: 'Privacy Policy',
          url: frendlyPrivacyUrl,
          style: style,
        ),
      ],
    );
  }
}

class _LegalTextButton extends StatelessWidget {
  const _LegalTextButton({
    required this.label,
    required this.url,
    required this.style,
  });

  final String label;
  final String url;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => openFrendlyLegalUrlOrNotify(context, url),
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: DateasyColors.muted,
      ),
      child: Text(label, style: style),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassPanel(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: _GlassPanel(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.alignment,
    required this.colorA,
    required this.colorB,
    required this.opacity,
  });

  final Alignment alignment;
  final Color colorA;
  final Color colorB;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Opacity(
            opacity: opacity,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
              child: Container(
                width: 288,
                height: 288,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [colorA, colorB]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Perk {
  const _Perk({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  factory _Perk.fromLabel(String label, int index) {
    final lower = label.toLowerCase();
    final icon = lower.contains('like') || lower.contains('лайк')
        ? LucideIcons.heart
        : lower.contains('ai') || lower.contains('маршрут')
            ? LucideIcons.sparkles
            : lower.contains('boost') || lower.contains('буст')
                ? LucideIcons.zap
                : lower.contains('view') || lower.contains('просмотр')
                    ? LucideIcons.eye
                    : [
                        LucideIcons.check,
                        LucideIcons.sparkles,
                        LucideIcons.zap,
                      ][index % 3];
    return _Perk(icon: icon, label: label);
  }
}

List<_Perk> _perksFromCatalog(PaymentsCatalog? catalog) {
  if (catalog == null) {
    return const [];
  }
  return _perksFromRaw(catalog.raw);
}

List<_Perk> _perksFromRaw(Map<String, Object?> raw) {
  final labels = <String>[
    ..._labelList(raw['perks']),
    ..._labelList(raw['benefits']),
    ..._labelList(raw['features']),
    ..._labelList(raw['plusPerks']),
    ..._labelList(raw['plusBenefits']),
  ];
  return labels
      .toSet()
      .toList(growable: false)
      .asMap()
      .entries
      .map((entry) => _Perk.fromLabel(entry.value, entry.key))
      .toList(growable: false);
}

List<String> _labelList(Object? value) {
  if (value is Iterable) {
    return value.map(_labelFrom).whereType<String>().toList(growable: false);
  }
  final single = _labelFrom(value);
  return single == null ? const [] : [single];
}

String? _labelFrom(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map) {
    return _stringOrNull(
      value['label'] ?? value['title'] ?? value['text'] ?? value['name'],
    );
  }
  return _stringOrNull(value);
}

String? _stringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
