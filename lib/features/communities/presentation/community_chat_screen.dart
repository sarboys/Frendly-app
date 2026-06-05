import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';

class CommunityChatScreen extends ConsumerWidget {
  const CommunityChatScreen({super.key, required this.communityId});

  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityState = ref.watch(communityDetailProvider(communityId));
    final community = communityState.valueOrNull;
    final chatId = _chatId(community);

    if (chatId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/chats/${Uri.encodeComponent(chatId)}');
        }
      });
    }

    return DateasyPhoneFrame(
      child: Center(
        child: Text(
          communityState.hasError
              ? 'Чат сообщества недоступен'
              : 'Открываю чат',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

String? _chatId(BackendCardItem? community) {
  final value = community?.raw['chatId']?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String communityChatRouteFor(BackendCardItem community) {
  final chatId = _chatId(community);
  if (chatId == null) {
    return '/communities/${Uri.encodeComponent(community.id)}/chat';
  }
  return '/chats/${Uri.encodeComponent(chatId)}';
}
