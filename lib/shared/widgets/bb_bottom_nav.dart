import 'package:big_break_mobile/app/navigation/app_shell.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BbBottomNav extends ConsumerWidget {
  const BbBottomNav({
    required this.location,
    required this.onTap,
    super.key,
  });

  final String location;
  final ValueChanged<AppTab> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.exists(meetupChatsProvider) && ref.exists(personalChatsProvider)
            ? ref.watch(chatUnreadBadgeProvider)
            : 0;
    final hasLiveChat =
        ref.exists(meetupChatsProvider) && ref.watch(hasLiveMeetupChatProvider);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: AppTab.values.map((tab) {
          final homeStyle = location.startsWith(AppTab.tonight.route.path);
          final active = location.startsWith(tab.route.path);
          final showBadge = tab == AppTab.chats && unread > 0;
          final showLiveDot = tab == AppTab.chats && hasLiveChat;

          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(tab),
                borderRadius: BorderRadius.circular(BbV5Radii.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  decoration: BoxDecoration(
                    color: active ? BbV5Colors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            _iconFor(tab, homeStyle: homeStyle),
                            size: 16,
                            color: active
                                ? BbV5Colors.paperHi
                                : BbV5Colors.inkSoft,
                          ),
                          if (showLiveDot)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: BbV5Colors.terra,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: BbV5Colors.terra
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (showBadge)
                            Positioned(
                              right: -10,
                              top: -7,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? BbV5Colors.paperHi
                                      : BbV5Colors.accent,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(99),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$unread',
                                  style: AppTextStyles.caption.copyWith(
                                    fontFamily: 'Sora',
                                    fontSize: 10,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? BbV5Colors.accent
                                        : BbV5Colors.paperHi,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _labelFor(tab),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.meta.copyWith(
                          fontFamily: 'Sora',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.38,
                          color:
                              active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  IconData _iconFor(AppTab tab, {required bool homeStyle}) {
    switch (tab) {
      case AppTab.tonight:
        return LucideIcons.compass;
      case AppTab.communities:
        return LucideIcons.route;
      case AppTab.chats:
        return LucideIcons.message_circle;
      case AppTab.dating:
        return LucideIcons.heart;
      case AppTab.profile:
        return homeStyle ? LucideIcons.users : LucideIcons.user;
    }
  }

  String _labelFor(AppTab tab) {
    switch (tab) {
      case AppTab.tonight:
        return 'Радар';
      case AppTab.communities:
        return 'Клубы';
      case AppTab.chats:
        return 'Чаты';
      case AppTab.dating:
        return 'Дейт.';
      case AppTab.profile:
        return 'Я';
    }
  }
}
