import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/event_detail/presentation/event_entry_requirements_card.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/widgets/async_value_view.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinRequestScreen extends ConsumerStatefulWidget {
  const JoinRequestScreen({
    required this.eventId,
    super.key,
  });

  final String eventId;

  @override
  ConsumerState<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends ConsumerState<JoinRequestScreen> {
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _V5JoinRequestColors.instance;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: AsyncValueView<EventDetail>(
          value: eventAsync,
          data: (event) {
            final compatibility = _compatibility(event);
            final isPending =
                event.joinRequestStatus == EventJoinRequestStatus.pending;
            final isApproved =
                event.joinRequestStatus == EventJoinRequestStatus.approved;
            final entryLocked = !event.isHost &&
                !event.joined &&
                !event.entryRequirements.canJoin;

            if (entryLocked) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: BbV5TopBar(
                      kicker: 'ЗАКРЫТАЯ ВСТРЕЧА',
                      title: 'Доступ',
                      onBack: () => context.pop(),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      children: [
                        _EventCard(event: event),
                        const SizedBox(height: AppSpacing.lg),
                        EventEntryRequirementsCard(
                          requirements: event.entryRequirements,
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: BbV5FixedBottomBar(
                      child: EventEntryRequirementActions(
                        requirements: event.entryRequirements,
                        onTap: (requirement) =>
                            _openEntryRequirement(event, requirement),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: BbV5TopBar(
                    kicker: 'ЗАКРЫТАЯ ВСТРЕЧА',
                    title: 'Заявка',
                    onBack: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _EventCard(event: event),
                      const SizedBox(height: AppSpacing.lg),
                      BbV5Card(
                        tint: BbV5Colors.brandSoft,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.secondary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$compatibility%',
                                style: AppTextStyles.itemTitle.copyWith(
                                  color: colors.secondaryForeground,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Высокая совместимость',
                                    style: AppTextStyles.itemTitle
                                        .copyWith(fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Оценка по интересам и текущему составу встречи',
                                    style: AppTextStyles.meta.copyWith(
                                      color: colors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              LucideIcons.sparkles,
                              color: colors.secondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Сообщение хосту',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      BbV5Card(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _noteController,
                              maxLines: 4,
                              maxLength: 200,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    'Привет 🙂 хочу присоединиться. Пара слов о себе...',
                                hintStyle: AppTextStyles.bodySoft
                                    .copyWith(color: colors.inkMute),
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: AppTextStyles.bodySoft,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_noteController.text.length}/200',
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Первый раз на встрече',
                          'Приду один',
                          'С другом, ок?',
                        ]
                            .map(
                              (template) => BbV5Chip(
                                label: template,
                                onTap: () {
                                  setState(() {
                                    _noteController.text = template;
                                    _noteController.selection =
                                        TextSelection.collapsed(
                                      offset: _noteController.text.length,
                                    );
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      BbV5Card(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.users,
                              size: 18,
                              color: colors.inkSoft,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Хост подтвердит заявку',
                                    style: AppTextStyles.itemTitle
                                        .copyWith(fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Обычно отвечают в течение 15 минут. Чат откроется сразу после подтверждения.',
                                    style: AppTextStyles.meta.copyWith(
                                      color: colors.inkSoft,
                                    ),
                                  ),
                                ],
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
                  child: BbV5FixedBottomBar(
                    child: SizedBox(
                      width: double.infinity,
                      child: BbV5PillButton(
                        label: isApproved
                            ? 'Открыть чат встречи'
                            : isPending
                                ? 'Заявка отправлена'
                                : 'Отправить заявку',
                        dark: true,
                        height: 56,
                        expanded: true,
                        onPressed: _submitting || isPending
                            ? null
                            : () async {
                                if (isApproved && event.chatId != null) {
                                  context.pushNamed(
                                    'meetupChat',
                                    pathParameters: {'chatId': event.chatId!},
                                  );
                                  return;
                                }

                                final eventId = widget.eventId;
                                final note = _noteController.text.trim();
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
                                  await repository.createJoinRequest(
                                    eventId,
                                    note: note,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  container.invalidate(
                                    eventDetailProvider(eventId),
                                  );
                                  container.invalidate(
                                    eventsProvider('nearby'),
                                  );
                                  container.invalidate(mapEventsProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text('Заявка отправлена'),
                                      ),
                                    );
                                    context.pop();
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Не получилось отправить заявку',
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
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _compatibility(EventDetail event) {
    final base = 68 + event.attendees.length * 4;
    return base.clamp(68, 95);
  }

  Future<void> _openEntryRequirement(
    EventDetail event,
    EventEntryRequirement requirement,
  ) async {
    final route = requirement == EventEntryRequirement.verification
        ? AppRoute.verification
        : AppRoute.paywall;
    await context.pushRoute(route);
    if (!mounted) {
      return;
    }
    ref.invalidate(verificationProvider);
    ref.invalidate(subscriptionStateProvider);
    ref.invalidate(eventDetailProvider(event.id));
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    final colors = _V5JoinRequestColors.instance;
    return BbV5Card(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.warmStart, colors.warmEnd],
                  ),
                  borderRadius: BorderRadius.circular(BbV5Radii.md),
                ),
                alignment: Alignment.center,
                child: Text(event.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: AppTextStyles.itemTitle),
                    const SizedBox(height: 6),
                    Text(event.time, style: AppTextStyles.meta),
                    const SizedBox(height: 2),
                    Text(
                      event.place,
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              BbAvatarStack(
                names: event.attendees
                    .map((item) => item.displayName)
                    .toList(growable: false),
                size: BbAvatarSize.sm,
                max: 4,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${event.going} из ${event.capacity}',
                  style: AppTextStyles.meta.copyWith(color: colors.inkSoft),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  event.vibe,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _V5JoinRequestColors {
  const _V5JoinRequestColors._();

  static const instance = _V5JoinRequestColors._();

  Color get inkMute => BbV5Colors.inkMute;
  Color get inkSoft => BbV5Colors.inkSoft;
  Color get primary => BbV5Colors.accent;
  Color get primarySoft => BbV5Colors.terraSoft;
  Color get secondary => BbV5Colors.sage;
  Color get secondaryForeground => BbV5Colors.paperHi;
  Color get warmEnd => BbV5Colors.accentDeep;
  Color get warmStart => BbV5Colors.terraSoft;
}
