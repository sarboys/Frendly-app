import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({
    super.key,
    this.userId,
    this.chatId,
  });

  final String? userId;
  final String? chatId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DateasyColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth > 420 ? 420.0 : constraints.maxWidth;

          return Center(
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: DecoratedBox(
                decoration: const BoxDecoration(gradient: dateasyHeroGradient),
                child: Stack(
                  children: [
                    const _Glow(
                      alignment: Alignment(-1.2, -1.16),
                      gradient: dateasyLimeGradient,
                      opacity: 0.5,
                    ),
                    const _Glow(
                      alignment: Alignment(1.16, 1.18),
                      gradient: dateasyPinkGradient,
                      opacity: 0.42,
                    ),
                    _Content(userId: userId, chatId: chatId),
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

class _Content extends ConsumerWidget {
  const _Content({
    required this.userId,
    required this.chatId,
  });

  final String? userId;
  final String? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final matches = ref.watch(matchesProvider);
    final match = _findMatch(matches.valueOrNull?.items ?? const []);
    final resolvedUserId = userId ?? _matchUserId(match);
    final resolvedChatId = chatId ?? _matchChatId(match);
    final title = match == null
        ? 'Новый мэтч'
        : 'Вы совпали с ${match.title.split(',').first}';
    final subtitle = match?.subtitle ?? match?.city ?? 'Можно начать диалог';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 4),
            Text(
              'match'.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.lime,
                    fontSize: 14,
                    letterSpacing: 4.2,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: dateasyLimeGradient,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55BEFF67),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Text(
                "It's a vibe!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: DateasyColors.backgroundDeep,
                      fontFamily: 'Sora',
                      fontSize: 60,
                      height: 1.04,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 286,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$title. '),
                    TextSpan(
                      text: subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DateasyColors.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DateasyColors.muted,
                      height: 1.35,
                    ),
              ),
            ),
            const SizedBox(height: 40),
            _AvatarPair(
              currentAvatarUrl: currentUser?.avatarUrl,
              matchAvatarUrl: match?.imageUrl,
            ),
            const Spacer(flex: 3),
            _PrimaryAction(
              icon: LucideIcons.messageCircle,
              label: 'Написать сообщение',
              onTap: () => _openChat(context, resolvedChatId),
            ),
            const SizedBox(height: 12),
            _GlassAction(
              icon: LucideIcons.sparkles,
              label: 'Позвать на встречу',
              onTap: () => _openMeetingInvite(
                context,
                userId: resolvedUserId,
                chatId: resolvedChatId,
              ),
            ),
            const SizedBox(height: 12),
            _TextAction(
              icon: LucideIcons.x,
              label: 'Свайпать дальше',
              onTap: () => context.go('/dating'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  BackendCardItem? _findMatch(List<BackendCardItem> matches) {
    final expectedId = userId;
    if (expectedId == null || expectedId.isEmpty) {
      return matches.firstOrNull;
    }
    for (final match in matches) {
      if (_matchUserId(match) == expectedId) {
        return match;
      }
    }
    return matches.firstOrNull;
  }

  String? _matchUserId(BackendCardItem? match) {
    if (match == null) {
      return null;
    }
    final profile = _map(match.raw['profile']);
    final user = _map(match.raw['user']);
    final candidate = match.raw['userId'] ??
        match.raw['peerUserId'] ??
        match.raw['targetUserId'] ??
        profile['userId'] ??
        profile['id'] ??
        user['id'] ??
        match.id;
    final value = candidate.toString();
    return value.isEmpty ? null : value;
  }

  String? _matchChatId(BackendCardItem? match) {
    if (match == null) {
      return null;
    }
    final chat = _map(match.raw['chat']);
    final candidate = match.raw['chatId'] ?? chat['id'];
    final value = candidate?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  void _openChat(BuildContext context, String? chatId) {
    if (chatId == null || chatId.isEmpty) {
      context.go('/chats');
      return;
    }
    context.push('/chats/${Uri.encodeComponent(chatId)}');
  }

  void _openMeetingInvite(
    BuildContext context, {
    required String? userId,
    required String? chatId,
  }) {
    context.go(
      Uri(
        path: '/meetings/new',
        queryParameters: {
          if (userId != null && userId.isNotEmpty) 'inviteeUserId': userId,
          if (chatId != null && chatId.isNotEmpty) 'sourceChatId': chatId,
        },
      ).toString(),
    );
  }
}

class _AvatarPair extends StatelessWidget {
  const _AvatarPair({
    required this.currentAvatarUrl,
    required this.matchAvatarUrl,
  });

  final String? currentAvatarUrl;
  final String? matchAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 288,
      height: 224,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 16,
            child: Transform.rotate(
              angle: -0.14,
              child: _RoundAvatar(
                imageUrl: currentAvatarUrl,
                glow: false,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Transform.rotate(
              angle: 0.14,
              child: _RoundAvatar(
                imageUrl: matchAvatarUrl,
                glow: true,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: dateasyLimeGradient,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66BEFF67),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite,
                size: 30,
                color: DateasyColors.backgroundDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAvatar extends StatelessWidget {
  const _RoundAvatar({
    required this.imageUrl,
    required this.glow,
  });

  final String? imageUrl;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DateasyColors.background, width: 4),
        boxShadow: [
          BoxShadow(
            color: (glow ? DateasyColors.lime : Colors.black)
                .withValues(alpha: glow ? 0.38 : 0.28),
            blurRadius: glow ? 28 : 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: DateasyRemoteImage(
        imageUrl: imageUrl,
        usage: DateasyImageUsage.avatar,
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: dateasyLimeGradient,
          boxShadow: const [
            BoxShadow(
              color: Color(0x55BEFF67),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: DateasyColors.backgroundDeep),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: DateasyColors.backgroundDeep,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: DateasyColors.glass,
          border: Border.all(color: DateasyColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: DateasyColors.lime),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: DateasyColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.alignment,
    required this.gradient,
    required this.opacity,
  });

  final Alignment alignment;
  final Gradient gradient;
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
              imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const {};
}
