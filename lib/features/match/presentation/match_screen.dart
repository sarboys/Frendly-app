import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MatchScreen extends ConsumerWidget {
  const MatchScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: matchesAsync.when(
          data: (matches) {
            if (matches.isEmpty) {
              return const _MatchEmptyState(text: 'Совпадений пока нет');
            }

            final match = matches.firstWhere(
              (item) => item.userId == userId,
              orElse: () => matches.first,
            );

            if (match.userId != userId) {
              return const _MatchEmptyState(text: 'Совпадение не найдено');
            }
            final shortName = match.displayName.split(' ').first;

            return Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
                      children: [
                        BbV5TopBar(
                          kicker: 'MATCH',
                          title: 'Совпадение',
                          onBack: () => context.pop(),
                        ),
                        const SizedBox(height: 22),
                        BbV5Card(
                          tint: BbV5Colors.terraSoft,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const BbAvatar(
                                    name: 'Ты',
                                    size: BbAvatarSize.lg,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 20,
                                    color: BbV5Colors.accent,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  BbAvatar(
                                    name: match.displayName,
                                    imageUrl: match.avatarUrl,
                                    size: BbAvatarSize.lg,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Ты и $shortName',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.itemTitle.copyWith(
                                  color: BbV5Colors.inkMute,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              SizedBox(
                                width: 164,
                                height: 164,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 164,
                                      height: 164,
                                      child: CircularProgressIndicator(
                                        value: match.score / 100,
                                        strokeWidth: 10,
                                        backgroundColor: BbV5Colors.hair,
                                        color: BbV5Colors.accent,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${match.score}%',
                                          textAlign: TextAlign.center,
                                          style: bbV5DisplayStyle(fontSize: 44),
                                        ),
                                        Text(
                                          'совпадение',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.caption.copyWith(
                                            color: BbV5Colors.inkMute,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Похожий вайб и ${match.commonInterests.length} общих интересов.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySoft.copyWith(
                                  color: BbV5Colors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        BbV5Section(
                          title: 'Что совпадает',
                          child: BbV5Card(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            child: Column(
                              children: [
                                _MatchTraitRow(
                                  label: 'Вайб',
                                  you: 'Спокойно',
                                  them: match.vibe ?? 'Спокойно',
                                  match: true,
                                ),
                                if (match.area != null)
                                  _MatchTraitRow(
                                    label: 'Район',
                                    you: 'Твой район',
                                    them: match.area!,
                                    match: true,
                                  ),
                                _MatchTraitRow(
                                  label: 'Общие интересы',
                                  you: '${match.commonInterests.length}',
                                  them: match.commonInterests.join(', '),
                                  match: match.commonInterests.isNotEmpty,
                                ),
                              ],
                            ),
                          ),
                        ),
                        BbV5Section(
                          title:
                              'Интересы · ${match.commonInterests.length} общих',
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: match.commonInterests
                                .map((interest) => BbV5Chip(label: interest))
                                .toList(growable: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: BbV5FixedBottomBar(
                    child: Row(
                      children: [
                        Expanded(
                          child: BbV5PillButton(
                            label: 'Написать',
                            icon: LucideIcons.message_circle,
                            dark: true,
                            height: 54,
                            expanded: true,
                            onPressed: () async {
                              final repository =
                                  ref.read(backendRepositoryProvider);
                              final chatId = await repository
                                  .createOrGetDirectChat(match.userId);
                              if (context.mounted) {
                                context.pushRoute(
                                  AppRoute.personalChat,
                                  pathParameters: {'chatId': chatId},
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: BbV5PillButton(
                            label: 'Пригласить на встречу',
                            icon: LucideIcons.calendar_plus,
                            height: 54,
                            expanded: true,
                            fontSize: 12,
                            onPressed: () => context.pushRoute(
                              AppRoute.createMeetup,
                              queryParameters: {'inviteeUserId': match.userId},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: BbV5Colors.accent),
          ),
          error: (error, _) => _MatchEmptyState(text: error.toString()),
        ),
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
        child: BbV5Card(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(color: BbV5Colors.inkSoft),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _MatchTraitRow extends StatelessWidget {
  const _MatchTraitRow({
    required this.label,
    required this.you,
    required this.them,
    required this.match,
  });

  final String label;
  final String you;
  final String them;
  final bool match;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.meta.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(you, style: AppTextStyles.meta),
          const SizedBox(width: 8),
          Text(
            them,
            style: AppTextStyles.meta.copyWith(
              color: match ? BbV5Colors.sage : BbV5Colors.inkMute,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: match ? BbV5Colors.sage : BbV5Colors.hair,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
