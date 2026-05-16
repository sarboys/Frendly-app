import 'dart:async';

import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showMeetupInviteSheet(
  BuildContext context, {
  required String eventId,
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    isScrollControlled: true,
    useSafeArea: false,
    builder: (context) => _MeetupInviteSheet(
      eventId: eventId,
      title: title,
    ),
  );
}

class _MeetupInviteSheet extends ConsumerStatefulWidget {
  const _MeetupInviteSheet({
    required this.eventId,
    this.title,
  });

  final String eventId;
  final String? title;

  @override
  ConsumerState<_MeetupInviteSheet> createState() => _MeetupInviteSheetState();
}

class _MeetupInviteSheetState extends ConsumerState<_MeetupInviteSheet> {
  static const _pageLimit = 20;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _sentIds = <String>{};
  final _sendingIds = <String>{};

  Timer? _debounce;
  CancelToken? _cancelToken;
  List<FollowingPerson> _people = const [];
  String? _nextCursor;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel('invite_sheet_disposed');
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_loadFirstPage());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loadingInitial ||
        _loadingMore ||
        _nextCursor == null) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadFirstPage() async {
    _cancelToken?.cancel('invite_sheet_replaced');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    if (mounted) {
      setState(() {
        _loadingInitial = true;
        _loadingMore = false;
        _failed = false;
        _nextCursor = null;
      });
    }

    try {
      final result =
          await ref.read(backendRepositoryProvider).fetchFollowingPeople(
                eventId: widget.eventId,
                q: _query,
                limit: _pageLimit,
                cancelToken: cancelToken,
              );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      setState(() {
        _people = result.items;
        _nextCursor = result.nextCursor;
        _loadingInitial = false;
      });
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _failed = true;
        _loadingInitial = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failed = true;
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) {
      return;
    }
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _loadingMore = true;
    });

    try {
      final result =
          await ref.read(backendRepositoryProvider).fetchFollowingPeople(
                eventId: widget.eventId,
                q: _query,
                cursor: cursor,
                limit: _pageLimit,
                cancelToken: cancelToken,
              );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      setState(() {
        _people = [..._people, ...result.items];
        _nextCursor = result.nextCursor;
        _loadingMore = false;
      });
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
      });
      _showSnackBar('Не получилось загрузить ещё');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
      });
      _showSnackBar('Не получилось загрузить ещё');
    }
  }

  Future<void> _invite(FollowingPerson person) async {
    if (_sendingIds.contains(person.id) || _sentIds.contains(person.id)) {
      return;
    }
    setState(() {
      _sendingIds.add(person.id);
    });
    try {
      await ref
          .read(backendRepositoryProvider)
          .inviteUserToEvent(widget.eventId, person.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _sentIds.add(person.id);
        _sendingIds.remove(person.id);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sendingIds.remove(person.id);
      });
      _showSnackBar('Не получилось отправить приглашение');
    }
  }

  String? get _query {
    final value = _searchController.text.trim();
    return value.isEmpty ? null : value;
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BbV5BottomSheet(
      maxHeightFactor: 0.92,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Кого позвать',
                      style: bbV5DisplayStyle(fontSize: 20),
                    ),
                    if ((widget.title ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.meta.copyWith(
                          color: BbV5Colors.inkMute,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              BbV5IconButton(
                icon: LucideIcons.x,
                onPressed: () => Navigator.of(context).pop(),
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InviteSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingInitial) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: BbV5Colors.ink,
          ),
        ),
      );
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Не получилось загрузить подписки',
              textAlign: TextAlign.center,
              style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
            ),
            const SizedBox(height: 12),
            BbV5PillButton(
              label: 'Повторить',
              icon: LucideIcons.refresh_cw,
              onPressed: () => unawaited(_loadFirstPage()),
            ),
          ],
        ),
      );
    }
    if (_people.isEmpty) {
      return Center(
        child: Text(
          _query == null ? 'Подписок пока нет' : 'Никого не нашли',
          textAlign: TextAlign.center,
          style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _people.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index >= _people.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BbV5Colors.ink,
                ),
              ),
            ),
          );
        }
        final person = _people[index];
        return _InviteCandidateRow(
          person: person,
          sent: _sentIds.contains(person.id),
          sending: _sendingIds.contains(person.id),
          onInvite: () => unawaited(_invite(person)),
        );
      },
    );
  }
}

class _InviteSearchField extends StatelessWidget {
  const _InviteSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.md),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 16,
            color: BbV5Colors.inkMute,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по подпискам',
                hintStyle: AppTextStyles.meta.copyWith(
                  color: BbV5Colors.inkMute,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTextStyles.meta.copyWith(
                color: BbV5Colors.ink,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCandidateRow extends StatelessWidget {
  const _InviteCandidateRow({
    required this.person,
    required this.sent,
    required this.sending,
    required this.onInvite,
  });

  final FollowingPerson person;
  final bool sent;
  final bool sending;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final available =
        person.inviteState == FollowingInviteState.available && !sent;
    final label = sent ? 'Приглашение отправлено' : _stateLabel(person);
    final disabled = !available || sending;

    return Opacity(
      opacity: disabled && !sending ? 0.7 : 1,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              BbAvatar(
                name: person.name,
                imageUrl: person.avatarUrl,
                online: person.online,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle.copyWith(
                        color: BbV5Colors.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(person),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkMute,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                height: 34,
                child: FilledButton(
                  onPressed: disabled ? null : onInvite,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: BbV5Colors.ink,
                    foregroundColor: BbV5Colors.paperHi,
                    disabledBackgroundColor: BbV5Colors.paperHi,
                    disabledForegroundColor: BbV5Colors.inkMute,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: const StadiumBorder(
                      side: BorderSide(color: BbV5Colors.hair),
                    ),
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BbV5Colors.paperHi,
                          ),
                        )
                      : Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stateLabel(FollowingPerson person) {
    return switch (person.inviteState) {
      FollowingInviteState.available => 'Пригласить',
      FollowingInviteState.alreadyJoined => 'Уже в встрече',
      FollowingInviteState.pendingInvite => 'Уже приглашён',
      FollowingInviteState.pendingRequest => 'Заявка уже есть',
    };
  }

  String _subtitle(FollowingPerson person) {
    final parts = <String>[
      if ((person.area ?? '').trim().isNotEmpty) person.area!.trim(),
      if ((person.vibe ?? '').trim().isNotEmpty) person.vibe!.trim(),
      ...person.common.take(2),
    ];
    if (parts.isEmpty) {
      return person.online ? 'Сейчас онлайн' : 'Подписка';
    }
    return parts.join(' · ');
  }
}
