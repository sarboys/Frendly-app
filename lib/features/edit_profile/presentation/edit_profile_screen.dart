import 'dart:typed_data';

import 'package:big_break_mobile/app/core/device/app_media_picker_service.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _allInterests = [
  'Кофе',
  'Бары',
  'Настолки',
  'Кино',
  'Книги',
  'Велик',
  'Йога',
  'Бег',
  'Театр',
  'Готовка',
  'Музыка',
  'Выставки',
  'Походы',
  'Фото',
];

const _editVibes = ['Спокойно', 'Шумно', 'Активно', 'Уютно'];
const _editProfileMaxContentWidth = 390.0;

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _interests = <String>{};
  final _intent = <String>{};
  String vibe = 'Спокойно';
  bool _initialized = false;
  int _selectedPhotoIndex = 0;
  bool _photoBusy = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final mediaPicker = ref.read(appMediaPickerServiceProvider);
    final repository = ref.read(backendRepositoryProvider);
    final photoDraft = ref.read(profilePhotoDraftProvider.notifier);
    final photoPreview = ref.read(profilePhotoPreviewProvider.notifier);
    final file = await mediaPicker.pickFromGallery();
    if (!mounted) {
      return;
    }
    if (file == null) {
      return;
    }

    setState(() {
      _photoBusy = true;
    });
    try {
      final uploadedPhoto = await repository.uploadProfilePhotoFile(file);
      if (!mounted) {
        return;
      }
      final currentDraftPhotos = photoDraft.state;
      photoDraft.state = [
        ...currentDraftPhotos.where((photo) => photo.id != uploadedPhoto.id),
        uploadedPhoto,
      ]..sort((left, right) => left.order.compareTo(right.order));
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        final currentPreviews = photoPreview.state;
        photoPreview.state = {
          ...currentPreviews,
          uploadedPhoto.id: bytes,
        };
      }
      final mergedPhotos = photoDraft.state;
      final newIndex = mergedPhotos.indexWhere(
        (photo) => photo.id == uploadedPhoto.id,
      );
      if (mounted && newIndex >= 0) {
        setState(() {
          _selectedPhotoIndex = newIndex;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фото.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _photoBusy = false;
        });
      }
    }
  }

  Future<void> _makeSelectedPrimary(ProfileData profile) async {
    if (profile.photos.isEmpty) {
      return;
    }

    setState(() {
      _photoBusy = true;
    });
    try {
      final repository = ref.read(backendRepositoryProvider);
      final photoDraft = ref.read(profilePhotoDraftProvider.notifier);
      final selectedPhotoId = profile.photos[_selectedPhotoIndex].id;
      final updatedProfile =
          await repository.makePrimaryProfilePhoto(selectedPhotoId);
      if (!mounted) {
        return;
      }
      photoDraft.state = updatedProfile.photos;
      if (mounted) {
        setState(() {
          _selectedPhotoIndex = 0;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить фото.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _photoBusy = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedPhoto(ProfileData profile) async {
    if (profile.photos.isEmpty) {
      return;
    }

    setState(() {
      _photoBusy = true;
    });
    try {
      final repository = ref.read(backendRepositoryProvider);
      final photoDraft = ref.read(profilePhotoDraftProvider.notifier);
      final photoPreview = ref.read(profilePhotoPreviewProvider.notifier);
      final deletedPhotoId = profile.photos[_selectedPhotoIndex].id;
      final updatedProfile = await repository.deleteProfilePhoto(
        deletedPhotoId,
      );
      if (!mounted) {
        return;
      }
      photoDraft.state = updatedProfile.photos;
      final currentPreviews = photoPreview.state;
      if (currentPreviews.containsKey(deletedPhotoId)) {
        final nextPreviews = Map<String, Uint8List>.from(currentPreviews)
          ..remove(deletedPhotoId);
        photoPreview.state = nextPreviews;
      }
      if (mounted) {
        setState(() {
          _selectedPhotoIndex =
              _selectedPhotoIndex > 0 ? _selectedPhotoIndex - 1 : 0;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить фото.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _photoBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final photos = profile?.photos ?? const <ProfilePhoto>[];
    final photoPreviews = ref.watch(profilePhotoPreviewProvider);
    if (_selectedPhotoIndex >= photos.length && photos.isNotEmpty) {
      _selectedPhotoIndex = photos.length - 1;
    }
    if (photos.isEmpty) {
      _selectedPhotoIndex = 0;
    }

    if (profile != null && !_initialized) {
      _initialized = true;
      _nameController.text = profile.displayName;
      _ageController.text = '${profile.age ?? ''}';
      _bioController.text = profile.bio ?? '';
      _interests
        ..clear()
        ..addAll(profile.interests);
      _intent
        ..clear()
        ..addAll(profile.intent);
      vibe = profile.vibe ?? vibe;
    }

    final displayName = _nameController.text.trim().isEmpty
        ? 'Никита'
        : _nameController.text.trim();
    final selectedPhoto = photos.isEmpty ? null : photos[_selectedPhotoIndex];
    final selectedPreview =
        selectedPhoto == null ? null : photoPreviews[selectedPhoto.id];

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth > _editProfileMaxContentWidth
                    ? _editProfileMaxContentWidth
                    : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                  children: [
                    _EditTopBar(
                      saving: _saving,
                      onBack: () => context.pop(),
                      onSave: _photoBusy || _saving
                          ? null
                          : () => _saveProfile(profile),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      children: [
                        _EditHeroPhoto(
                          displayName: displayName,
                          photo: selectedPhoto,
                          previewBytes: selectedPreview,
                          busy: _photoBusy,
                          onAddPhoto: _photoBusy ? null : _addPhoto,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: 64,
                          child: ListView.separated(
                            key: const Key('edit-profile-photo-strip'),
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              if (index == photos.length) {
                                return _PhotoAddTile(
                                  onTap: _photoBusy ? null : _addPhoto,
                                );
                              }
                              final photo = photos[index];
                              return _PhotoThumbTile(
                                photo: photo,
                                fallbackText: displayName,
                                previewBytes: photoPreviews[photo.id],
                                selected: index == _selectedPhotoIndex,
                                onTap: () => setState(() {
                                  _selectedPhotoIndex = index;
                                }),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _PhotoActionButton(
                                label: 'Сделать первым',
                                icon: LucideIcons.star,
                                onPressed: _photoBusy ||
                                        photos.isEmpty ||
                                        _selectedPhotoIndex == 0
                                    ? null
                                    : () => _makeSelectedPrimary(profile!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PhotoActionButton(
                                label: 'Удалить',
                                icon: LucideIcons.trash_2,
                                destructive: true,
                                onPressed: _photoBusy || photos.isEmpty
                                    ? null
                                    : () => _deleteSelectedPhoto(profile!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      decoration: BoxDecoration(
                        color: BbV5Colors.paperHi,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BbV5Colors.hair),
                      ),
                      child: Column(
                        children: [
                          _EditRow(
                            label: 'Имя',
                            child: TextField(
                              key: const Key('edit-profile-name-field'),
                              controller: _nameController,
                              onChanged: (_) => setState(() {}),
                              textAlign: TextAlign.right,
                              cursorColor: BbV5Colors.terra,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              style: AppTextStyles.body.copyWith(
                                color: BbV5Colors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: BbV5Colors.hair,
                          ),
                          _EditRow(
                            label: 'Возраст',
                            child: TextField(
                              key: const Key('edit-profile-age-field'),
                              controller: _ageController,
                              onChanged: (value) {
                                final digitsOnly =
                                    value.replaceAll(RegExp(r'\D'), '');
                                final sanitized = digitsOnly.length > 2
                                    ? digitsOnly.substring(0, 2)
                                    : digitsOnly;
                                if (_ageController.text != sanitized) {
                                  _ageController.value = TextEditingValue(
                                    text: sanitized,
                                    selection: TextSelection.collapsed(
                                      offset: sanitized.length,
                                    ),
                                  );
                                }
                                setState(() {});
                              },
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.number,
                              cursorColor: BbV5Colors.terra,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              style: AppTextStyles.body.copyWith(
                                color: BbV5Colors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: BbV5Colors.hair,
                          ),
                          _EditRow(
                            label: 'Район',
                            child: Text(
                              profile?.area ?? 'Чистые пруды',
                              textAlign: TextAlign.right,
                              style: AppTextStyles.body.copyWith(
                                color: BbV5Colors.inkSoft,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _EditSection(
                      title: 'О себе',
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: BbV5Colors.paperHi,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: BbV5Colors.hair),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              key: const Key('edit-profile-bio-field'),
                              controller: _bioController,
                              onChanged: (_) => setState(() {}),
                              maxLines: 4,
                              maxLength: 300,
                              cursorColor: BbV5Colors.terra,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              style: AppTextStyles.bodySoft.copyWith(
                                color: BbV5Colors.inkSoft,
                              ),
                            ),
                            Text(
                              '${_bioController.text.length}/300',
                              style: AppTextStyles.caption.copyWith(
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _EditSection(
                      title: 'Настроение',
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: _editVibes
                            .map((item) => _togglePill(item, vibe == item,
                                () => setState(() => vibe = item)))
                            .toList(growable: false),
                      ),
                    ),
                    _EditSection(
                      title: 'Зачем здесь',
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: ['Друзья', 'Свидания']
                            .map(
                              (item) => _togglePill(
                                item,
                                _intent.contains(item),
                                () => setState(() {
                                  if (_intent.contains(item)) {
                                    _intent.remove(item);
                                  } else {
                                    _intent.add(item);
                                  }
                                }),
                                selectedBackground:
                                    BbV5Colors.terraSoft.withValues(
                                  alpha: 0.52,
                                ),
                                selectedForeground: BbV5Colors.ink,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    _EditSection(
                      title: 'Интересы · ${_interests.length}',
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: _allInterests
                            .map(
                              (item) => _togglePill(
                                item,
                                _interests.contains(item),
                                () => setState(() {
                                  if (_interests.contains(item)) {
                                    _interests.remove(item);
                                  } else {
                                    _interests.add(item);
                                  }
                                }),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _togglePill(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? selectedBackground,
    Color? selectedForeground,
  }) {
    final resolvedSelectedBackground = selectedBackground ?? BbV5Colors.accent;
    final resolvedSelectedForeground = selectedForeground ?? BbV5Colors.paperHi;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? resolvedSelectedBackground : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: selected ? resolvedSelectedBackground : BbV5Colors.hair,
            ),
            boxShadow: selected ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.meta.copyWith(
              color: selected ? resolvedSelectedForeground : BbV5Colors.inkSoft,
              fontFamily: 'Sora',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile(ProfileData? profile) async {
    setState(() {
      _saving = true;
    });
    try {
      final repository = ref.read(backendRepositoryProvider);
      await repository.updateProfile({
        'displayName': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'city': profile?.city ?? 'Москва',
        'area': profile?.area ?? 'Чистые пруды',
        'bio': _bioController.text.trim(),
        'vibe': vibe,
      });
      await repository.saveOnboarding(
        OnboardingData(
          intent: _intent.contains('Свидания') && _intent.contains('Друзья')
              ? 'both'
              : _intent.contains('Свидания')
                  ? 'dating'
                  : 'friendship',
          gender: profile?.gender,
          city: profile?.city ?? 'Москва',
          area: profile?.area ?? 'Чистые пруды',
          interests: _interests.toList(growable: false),
          vibe: vibe,
        ),
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(profileProvider);
      ref.invalidate(onboardingProvider);
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось сохранить профиль')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}

class _EditTopBar extends StatelessWidget {
  const _EditTopBar({
    required this.onBack,
    required this.onSave,
    required this.saving,
  });

  final VoidCallback onBack;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                LucideIcons.chevron_left,
                size: 26,
                color: BbV5Colors.ink,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Редактировать',
              textAlign: TextAlign.center,
              style: AppTextStyles.itemTitle.copyWith(
                color: BbV5Colors.inkSoft,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 74,
            height: 44,
            child: TextButton(
              onPressed: onSave,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: BbV5Colors.terra,
                disabledForegroundColor:
                    BbV5Colors.terra.withValues(alpha: 0.45),
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BbV5Colors.terra,
                      ),
                    )
                  : Text(
                      'Готово',
                      style: AppTextStyles.meta.copyWith(
                        color: onSave == null
                            ? BbV5Colors.terra.withValues(alpha: 0.45)
                            : BbV5Colors.terra,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditHeroPhoto extends StatelessWidget {
  const _EditHeroPhoto({
    required this.displayName,
    required this.photo,
    required this.previewBytes,
    required this.busy,
    required this.onAddPhoto,
  });

  final String displayName;
  final ProfilePhoto? photo;
  final Uint8List? previewBytes;
  final bool busy;
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.09,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (previewBytes != null)
              Image.memory(
                previewBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 1200,
                cacheHeight: 1100,
              )
            else if (photo != null)
              BbProfilePhotoImage(
                imageUrl: photo!.bestUrlFor(BbImageUsageProfile.hero),
                fallbackText: displayName,
                usageProfile: BbImageUsageProfile.hero,
                fit: BoxFit.cover,
              )
            else
              _EditHeroFallback(displayName: displayName),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 124,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.46),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 72,
              bottom: 22,
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1,
                  shadows: const [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 18,
              child: _HeroAddPhotoButton(
                busy: busy,
                onTap: onAddPhoto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditHeroFallback extends StatelessWidget {
  const _EditHeroFallback({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.characters.first.toUpperCase();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BbV5Colors.terraSoft,
            BbV5Colors.paperHi,
            BbV5Colors.brandSoft,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: bbV5DisplayStyle(
            fontSize: 72,
            color: BbV5Colors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _HeroAddPhotoButton extends StatelessWidget {
  const _HeroAddPhotoButton({
    required this.busy,
    required this.onTap,
  });

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: Color(0xFF171922),
            shape: BoxShape.circle,
            boxShadow: BbV5Shadows.ink,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  LucideIcons.plus,
                  size: 23,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

class _PhotoActionButton extends StatelessWidget {
  const _PhotoActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled
        ? destructive
            ? BbV5Colors.terra
            : BbV5Colors.ink
        : BbV5Colors.inkMute.withValues(alpha: 0.62);
    final borderColor = enabled
        ? destructive
            ? BbV5Colors.ink
            : BbV5Colors.hair
        : BbV5Colors.hair;

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: enabled
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.2),
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          side: BorderSide(color: borderColor, width: destructive ? 1.1 : 1),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.button.copyWith(
                  color: foreground,
                  fontSize: 15,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  const _EditSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbV5Kicker(title, color: BbV5Colors.inkSoft),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                label,
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.inkSoft,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbTile extends StatelessWidget {
  const _PhotoThumbTile({
    required this.photo,
    required this.fallbackText,
    required this.previewBytes,
    required this.selected,
    required this.onTap,
  });

  final ProfilePhoto photo;
  final String fallbackText;
  final Uint8List? previewBytes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cacheExtent =
        (56 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(112, 336);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? BbV5Colors.terra : BbV5Colors.hair,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? BbV5Shadows.pill : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: previewBytes != null
                ? Image.memory(
                    previewBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: cacheExtent,
                    cacheHeight: cacheExtent,
                  )
                : BbProfilePhotoImage(
                    imageUrl: photo.bestUrlFor(BbImageUsageProfile.avatar),
                    fallbackText: fallbackText,
                    usageProfile: BbImageUsageProfile.avatar,
                    fit: BoxFit.cover,
                    fallbackFontSize: 14,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhotoAddTile extends StatelessWidget {
  const _PhotoAddTile({
    required this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbV5Colors.paperHi,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: const Icon(
            LucideIcons.plus,
            color: BbV5Colors.terra,
            size: 22,
          ),
        ),
      ),
    );
  }
}
