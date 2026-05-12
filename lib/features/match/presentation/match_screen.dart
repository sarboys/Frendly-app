import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/match.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _show = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: BbV5Colors.ink,
      body: Stack(
        children: [
          const Positioned.fill(child: _MatchBackground()),
          SafeArea(
            bottom: false,
            child: matchesAsync.when(
              data: (matches) => _buildMatch(context, matches),
              loading: () => const Center(
                child: CircularProgressIndicator(color: BbV5Colors.paperHi),
              ),
              error: (error, _) => _MatchEmptyState(text: error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatch(BuildContext context, List<MatchData> matches) {
    if (matches.isEmpty) {
      return const _MatchEmptyState(text: 'Совпадений пока нет');
    }

    final match = matches.firstWhere(
      (item) => item.userId == widget.userId,
      orElse: () => matches.first,
    );

    if (match.userId != widget.userId) {
      return const _MatchEmptyState(text: 'Совпадение не найдено');
    }

    final shortName = match.displayName.split(' ').first;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _MatchCircleButton(
                  icon: LucideIcons.x,
                  onPressed: () => context.pop(),
                ),
              ),
              Expanded(
                child: AnimatedOpacity(
                  opacity: _show ? 1 : 0,
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: _show ? Offset.zero : const Offset(0, 0.05),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _AvatarConvergence(show: _show, match: match),
                                const SizedBox(height: 26),
                                Text(
                                  'FRENDLY MATCH',
                                  style: bbV5KickerStyle(
                                    color: BbV5Colors.gold,
                                    fontSize: 10,
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: 'Это '),
                                      TextSpan(
                                        text: 'взаимно.',
                                        style: bbV5DisplayStyle(
                                          fontSize: 44,
                                          height: 0.95,
                                          color: BbV5Colors.paperHi,
                                        ).copyWith(
                                          fontFamily: 'InstrumentSerif',
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  style: bbV5DisplayStyle(
                                    fontSize: 44,
                                    height: 0.95,
                                    color: BbV5Colors.paperHi,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '$shortName лайкнул(а) тебя в ответ',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySoft.copyWith(
                                    color: BbV5Colors.paperHi
                                        .withValues(alpha: 0.76),
                                  ),
                                ),
                                if (match.commonInterests.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: match.commonInterests
                                        .take(4)
                                        .map((interest) =>
                                            _MatchTag(label: interest))
                                        .toList(growable: false),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  '${match.score}% совпадение',
                                  style: AppTextStyles.caption.copyWith(
                                    color: BbV5Colors.gold,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              _MatchActions(match: match),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarConvergence extends StatelessWidget {
  const _AvatarConvergence({
    required this.show,
    required this.match,
  });

  final bool show;
  final MatchData match;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      width: 288,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 760),
            curve: Curves.easeOutBack,
            left: show ? 32 : -132,
            top: 30,
            child: Transform.rotate(
              angle: -0.08,
              child: const _MatchAvatarTile(
                name: 'Ты',
                gradient: [BbV5Colors.terra, BbV5Colors.accentDeep],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 820),
            curve: Curves.easeOutBack,
            right: show ? 32 : -132,
            top: 30,
            child: Transform.rotate(
              angle: 0.08,
              child: _MatchAvatarTile(
                name: match.displayName,
                imageUrl: match.avatarUrl,
                gradient: const [BbV5Colors.rose, BbV5Colors.gold],
              ),
            ),
          ),
          AnimatedScale(
            scale: show ? 1 : 0.4,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: show ? 1 : 0,
              duration: const Duration(milliseconds: 520),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      BbV5Colors.paperHi,
                      BbV5Colors.gold.withValues(alpha: 0.82),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: BbV5Colors.gold.withValues(alpha: 0.5),
                      blurRadius: 60,
                      spreadRadius: 18,
                    ),
                    BoxShadow(
                      color: BbV5Colors.terra.withValues(alpha: 0.35),
                      blurRadius: 110,
                      spreadRadius: 32,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.heart,
                  size: 30,
                  color: BbV5Colors.terra,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchAvatarTile extends StatelessWidget {
  const _MatchAvatarTile({
    required this.name,
    required this.gradient,
    this.imageUrl,
  });

  final String name;
  final List<Color> gradient;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: BbV5Colors.paperHi.withValues(alpha: 0.62),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 48,
            spreadRadius: -12,
            offset: Offset(0, 24),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Center(
              child: Text(
                name.characters.first.toUpperCase(),
                style: bbV5DisplayStyle(
                  fontSize: 44,
                  color: BbV5Colors.paperHi,
                ),
              ),
            )
          : BbAvatar(
              name: name,
              imageUrl: imageUrl,
              size: BbAvatarSize.xl,
            ),
    );
  }
}

class _MatchActions extends ConsumerStatefulWidget {
  const _MatchActions({required this.match});

  final MatchData match;

  @override
  ConsumerState<_MatchActions> createState() => _MatchActionsState();
}

class _MatchActionsState extends ConsumerState<_MatchActions> {
  bool _openingChat = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _openingChat ? null : _openChat,
            style: FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: BbV5Colors.paperHi,
              foregroundColor: BbV5Colors.ink,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(LucideIcons.message_circle, size: 18),
            label: Text(
              _openingChat ? 'Открываем' : 'Написать',
              style: AppTextStyles.button.copyWith(
                color: BbV5Colors.ink,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => context.pushRoute(
              AppRoute.createMeetup,
              queryParameters: {'inviteeUserId': widget.match.userId},
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: BbV5Colors.paperHi,
              side: BorderSide(
                color: BbV5Colors.paperHi.withValues(alpha: 0.24),
              ),
              shape: const StadiumBorder(),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
            icon: const Icon(LucideIcons.calendar_plus, size: 18),
            label: Text(
              'Пригласить на встречу',
              style: AppTextStyles.button.copyWith(
                color: BbV5Colors.paperHi,
                fontSize: 14,
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => context.goRoute(AppRoute.dating),
          icon: const Icon(LucideIcons.sparkles, size: 14),
          label: const Text('Продолжить смотреть'),
          style: TextButton.styleFrom(
            foregroundColor: BbV5Colors.paperHi.withValues(alpha: 0.62),
            textStyle: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openChat() async {
    setState(() => _openingChat = true);
    try {
      final repository = ref.read(backendRepositoryProvider);
      final chatId =
          await repository.createOrGetDirectChat(widget.match.userId);
      if (mounted && context.mounted) {
        context.pushRoute(
          AppRoute.personalChat,
          pathParameters: {'chatId': chatId},
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingChat = false);
      }
    }
  }
}

class _MatchTag extends StatelessWidget {
  const _MatchTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: BbV5Colors.paperHi,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MatchCircleButton extends StatelessWidget {
  const _MatchCircleButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: 18, color: BbV5Colors.paperHi),
        ),
      ),
    );
  }
}

class _MatchBackground extends StatelessWidget {
  const _MatchBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.34),
          radius: 1.15,
          colors: [
            Color(0xCCC97A55),
            Color(0xEEB26F4A),
            BbV5Colors.ink,
          ],
          stops: [0, 0.58, 1],
        ),
      ),
      child: Stack(
        children: List.generate(20, (index) {
          final left = ((index * 53) % 100) / 100;
          final top = ((index * 37) % 100) / 100;
          final size = 4.0 + (index % 3) * 2;
          return Positioned(
            left: MediaQuery.sizeOf(context).width * left,
            top: MediaQuery.sizeOf(context).height * top,
            child: Opacity(
              opacity: 0.5,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: index % 3 == 0 ? BbV5Colors.gold : BbV5Colors.paperHi,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MatchEmptyState extends StatelessWidget {
  const _MatchEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(color: BbV5Colors.paperHi),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
