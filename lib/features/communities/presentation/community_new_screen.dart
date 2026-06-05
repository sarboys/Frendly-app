import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/device/app_media_picker_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/communities/application/community_access.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

const _tags = [
  _CommunityTag(label: 'Кофе', icon: LucideIcons.coffee),
  _CommunityTag(label: 'Музыка', icon: LucideIcons.music2),
  _CommunityTag(label: 'Спорт', icon: LucideIcons.dumbbell),
  _CommunityTag(label: 'Арт', icon: LucideIcons.palette),
  _CommunityTag(label: 'Вино', icon: LucideIcons.wine),
  _CommunityTag(label: 'Прогулки', icon: LucideIcons.footprints),
  _CommunityTag(label: 'Фото', icon: LucideIcons.camera),
  _CommunityTag(label: 'Книги', icon: LucideIcons.book),
];

class CommunityNewScreen extends ConsumerStatefulWidget {
  const CommunityNewScreen({super.key});

  @override
  ConsumerState<CommunityNewScreen> createState() => _CommunityNewScreenState();
}

class _CommunityNewScreenState extends ConsumerState<CommunityNewScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _activeTags = {'Кофе'};
  var _visibility = _CommunityVisibility.public;
  String? _toastTitle;
  String? _toastDescription;
  String? _imageAssetId;
  String? _imageUrl;
  bool _creating = false;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_activeTags.contains(tag)) {
        _activeTags.remove(tag);
      } else {
        _activeTags.add(tag);
      }
    });
  }

  void _showToast(String title, [String? description]) {
    setState(() {
      _toastTitle = title;
      _toastDescription = description;
    });
  }

  Future<void> _pickCommunityImage() async {
    if (_uploadingImage || _creating) {
      return;
    }
    setState(() => _uploadingImage = true);
    try {
      final file = await ref.read(appMediaPickerServiceProvider).pickImage();
      if (file == null) {
        return;
      }
      final uploaded =
          await ref.read(backendRepositoryProvider).uploadCommunityImageFile(
                file,
              );
      final assetId = uploaded['assetId']?.toString();
      if (assetId == null || assetId.isEmpty) {
        _showToast('Не удалось загрузить изображение');
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _imageAssetId = assetId;
        _imageUrl = uploaded['url']?.toString();
      });
    } catch (_) {
      if (mounted) {
        _showToast('Не удалось загрузить изображение');
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _createCommunity(BuildContext context) async {
    if (_creating) {
      return;
    }
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty) {
      _showToast('Назови сообщество');
      return;
    }
    if (description.isEmpty) {
      _showToast('Добавь описание');
      return;
    }
    final imageError = communityImageRequiredError(_imageAssetId);
    if (imageError != null) {
      _showToast(imageError);
      return;
    }

    setState(() => _creating = true);
    try {
      final community =
          await ref.read(communityActionsProvider).createCommunity(
                data: communityCreatePayload(
                  name: name,
                  avatar: _avatarForTags(_activeTags),
                  imageAssetId: _imageAssetId!,
                  description: description,
                  privacy: _visibility.name,
                  purpose: _activeTags.isEmpty
                      ? 'Городской клуб'
                      : _activeTags.first,
                  tags: _activeTags.toList(growable: false),
                ),
                idempotencyKey:
                    'mobile2-community-${DateTime.now().microsecondsSinceEpoch}',
              );
      if (!mounted) {
        return;
      }
      _showToast('«$name» создано', 'Можно звать первых участников');
      if (!context.mounted) {
        return;
      }
      context.go('/communities/${community.id}');
    } on BackendActionException catch (error) {
      if (!mounted) {
        return;
      }
      _showToast(
        error.code == 'community_plus_required'
            ? 'Нужен Frendly Plus'
            : 'Не удалось создать сообщество',
        error.code == 'community_plus_required'
            ? 'Создание доступно с Frendly+'
            : null,
      );
      if (error.code == 'community_plus_required' && context.mounted) {
        context.push('/paywall');
      }
    } catch (_) {
      if (mounted) {
        _showToast('Не удалось создать сообщество');
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final subscription = subscriptionState.valueOrNull;
    if (subscriptionState.isLoading && subscription == null) {
      return const _CommunityPlusGateScaffold(
        title: 'Проверяем Frendly+',
        description: 'Создание сообщества доступно подписчикам.',
      );
    }
    if (!communityHasFrendlyPlusAccess(subscription)) {
      return _CommunityPlusGateScaffold(
        title: 'Нужен Frendly+',
        description: 'Создание сообществ доступно подписчикам Frendly+.',
        actionLabel: 'Открыть Frendly+',
        onAction: () => context.push('/paywall'),
      );
    }

    return DateasyPhoneFrame(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 16,
              bottom: 148,
            ),
            children: [
              const _TopBar(),
              _CoverPicker(
                activeTags: _activeTags,
                imageUrl: _imageUrl,
                uploading: _uploadingImage,
                onTap: _pickCommunityImage,
              ),
              _InputSection(
                nameController: _nameController,
                descriptionController: _descriptionController,
              ),
              _TagsSection(
                activeTags: _activeTags,
                onToggle: _toggleTag,
              ),
              _VisibilitySection(
                visibility: _visibility,
                onChanged: (visibility) {
                  setState(() => _visibility = visibility);
                },
              ),
              _InviteCard(
                onInvite: () => _showToast('Ссылка-приглашение скопирована'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: GestureDetector(
                  onTap: _creating || _uploadingImage
                      ? null
                      : () => _createCommunity(context),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: dateasyLimeGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: DateasyColors.lime.withValues(alpha: 0.28),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Text(
                      _creating ? 'Создаём' : 'Создать сообщество',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DateasyColors.backgroundDeep,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
          const DateasyBottomNav(),
          if (_toastTitle != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 104,
              child: _Toast(
                title: _toastTitle!,
                description: _toastDescription,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommunityPlusGateScaffold extends StatelessWidget {
  const _CommunityPlusGateScaffold({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 16,
              bottom: 148,
            ),
            children: [
              const _TopBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 96, 20, 0),
                child: _GlassPanel(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: dateasyLimeGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          LucideIcons.plus,
                          size: 26,
                          color: DateasyColors.backgroundDeep,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DateasyColors.muted,
                              height: 1.35,
                            ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 22),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onAction,
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: dateasyLimeGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              actionLabel!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: DateasyColors.backgroundDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const DateasyBottomNav(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/communities'),
              child: const _GlassSquare(
                child: Icon(
                  LucideIcons.arrowLeft,
                  size: 21,
                  color: DateasyColors.foreground,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Новое сообщество',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ));
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.activeTags,
    required this.imageUrl,
    required this.uploading,
    required this.onTap,
  });

  final Set<String> activeTags;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: uploading ? null : onTap,
        child: CustomPaint(
          painter: _DashedRoundedBorderPainter(
            color: DateasyColors.foreground.withValues(alpha: 0.2),
            radius: 24,
          ),
          child: Container(
            height: 176,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: DateasyColors.glass,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _selectedImageUrl(imageUrl) == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: DateasyColors.lime.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            uploading
                                ? LucideIcons.loaderCircle
                                : LucideIcons.imagePlus,
                            size: 25,
                            color: DateasyColors.lime,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          uploading
                              ? 'Загружаю изображение'
                              : 'Изображение сообщества',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: DateasyColors.foreground,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Нужно для создания и карточек списка',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DateasyColors.muted,
                                    fontSize: 12,
                                  ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      DateasyRemoteImage(
                        imageUrl: _selectedImageUrl(imageUrl),
                        usage: DateasyImageUsage.card,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x99000000),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Row(
                          children: [
                            Text(
                              _avatarForTags(activeTags),
                              style: const TextStyle(fontSize: 28, height: 1),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Заменить изображение',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
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
    );
  }
}

class _InputSection extends StatelessWidget {
  const _InputSection({
    required this.nameController,
    required this.descriptionController,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          _GlassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Название'),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'Wine & vinyl Patriki',
                    hintStyle: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color:
                              DateasyColors.foreground.withValues(alpha: 0.3),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                  cursorColor: DateasyColors.lime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GlassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('О чём'),
                const SizedBox(height: 6),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText:
                        'Собираемся слушать винил, пить natural wine и встречаться по пятницам...',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              DateasyColors.foreground.withValues(alpha: 0.4),
                        ),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  cursorColor: DateasyColors.lime,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({
    required this.activeTags,
    required this.onToggle,
  });

  final Set<String> activeTags;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Темы'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tags)
                _TagChip(
                  tag: tag,
                  active: activeTags.contains(tag.label),
                  onTap: () => onToggle(tag.label),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Справочник тем локальный. Backend endpoint не найден',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.active,
    required this.onTap,
  });

  final _CommunityTag tag;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? DateasyColors.lime : DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? DateasyColors.lime : DateasyColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tag.icon,
              size: 14,
              color: active
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.foreground,
            ),
            const SizedBox(width: 6),
            Text(
              tag.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: active
                        ? DateasyColors.backgroundDeep
                        : DateasyColors.foreground.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilitySection extends StatelessWidget {
  const _VisibilitySection({
    required this.visibility,
    required this.onChanged,
  });

  final _CommunityVisibility visibility;
  final ValueChanged<_CommunityVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Видимость'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _VisibilityCard(
                  icon: LucideIcons.globe,
                  title: 'Открытое',
                  description: 'Любой может вступить',
                  active: visibility == _CommunityVisibility.public,
                  onTap: () => onChanged(_CommunityVisibility.public),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VisibilityCard(
                  icon: LucideIcons.lock,
                  title: 'Закрытое',
                  description: 'По заявкам',
                  active: visibility == _CommunityVisibility.private,
                  onTap: () => onChanged(_CommunityVisibility.private),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? DateasyColors.lilac : DateasyColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? DateasyColors.lilac : DateasyColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: active
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.foreground,
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: active
                        ? DateasyColors.backgroundDeep
                        : DateasyColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: active
                        ? DateasyColors.backgroundDeep.withValues(alpha: 0.8)
                        : DateasyColors.foreground.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: _GlassPanel(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DateasyColors.pink.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.users,
                size: 21,
                color: DateasyColors.pink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пригласить друзей',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Минимум 3 человека, чтобы запустить',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onInvite,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: DateasyColors.foreground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+ Позвать',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.background,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.title,
    required this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: DateasyColors.surface.withValues(alpha: 0.92),
            border: Border.all(color: DateasyColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (description != null) ...[
                const SizedBox(height: 3),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DateasyColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
    );
  }
}

class _GlassSquare extends StatelessWidget {
  const _GlassSquare({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: child),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: DateasyColors.glass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: DateasyColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final dashEnd = (distance + 8).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, dashEnd), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}

enum _CommunityVisibility { public, private }

String _avatarForTags(Set<String> tags) {
  if (tags.contains('Вино')) {
    return '🍷';
  }
  if (tags.contains('Музыка')) {
    return '🎵';
  }
  if (tags.contains('Спорт')) {
    return '🏃';
  }
  if (tags.contains('Арт')) {
    return '🎨';
  }
  if (tags.contains('Фото')) {
    return '📷';
  }
  if (tags.contains('Книги')) {
    return '📚';
  }
  return '☕';
}

String? communityImageRequiredError(String? imageAssetId) {
  final value = imageAssetId?.trim() ?? '';
  if (value.isEmpty) {
    return 'Добавь изображение сообщества';
  }
  return null;
}

Map<String, Object?> communityCreatePayload({
  required String name,
  required String avatar,
  required String imageAssetId,
  required String description,
  required String privacy,
  required String purpose,
  required List<String> tags,
}) {
  return {
    'name': name,
    'avatar': avatar,
    'imageAssetId': imageAssetId,
    'description': description,
    'privacy': privacy,
    'purpose': purpose,
    'tags': tags,
  };
}

String? _selectedImageUrl(String? imageUrl) {
  final value = imageUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  return value;
}

class _CommunityTag {
  const _CommunityTag({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}
