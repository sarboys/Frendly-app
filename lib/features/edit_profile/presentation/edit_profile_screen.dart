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
  'Музыка',
  'Кино',
  'Книги',
  'Велик',
  'Йога',
  'Бег',
  'Театр',
  'Готовка',
  'Выставки',
  'Походы',
  'Фото',
  'Настолки',
];

const _editVibes = [
  _EditVibe('Спокойно', 'Тихие бары, прогулки', '🌿'),
  _EditVibe('Уютно', 'Кофе, разговоры', '🕯️'),
  _EditVibe('Активно', 'Спорт, движение', '🚴'),
  _EditVibe('Громко', 'Тусовки, бары', '🎉'),
];

const _editIntents = [
  _EditIntent('Друзья', LucideIcons.users),
  _EditIntent('Свидания', LucideIcons.heart),
  _EditIntent('Нетворк', LucideIcons.briefcase),
];

const _editProfileMaxContentWidth = 390.0;
const _editProfileBioMaxLength = 280;

class _EditVibe {
  const _EditVibe(this.label, this.hint, this.emoji);

  final String label;
  final String hint;
  final String emoji;
}

class _EditIntent {
  const _EditIntent(this.label, this.icon);

  final String label;
  final IconData icon;
}

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
  bool _hideAge = false;
  bool _showOnRadar = true;
  bool _voiceOn = false;

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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    _EditTopBar(
                      saving: _saving,
                      onBack: () => context.pop(),
                      onSave: _photoBusy || _saving
                          ? null
                          : () => _saveProfile(profile),
                    ),
                    const SizedBox(height: AppSpacing.md),
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
                    _EditSection(
                      title: 'Основа',
                      child: _buildBasicsCard(profile),
                    ),
                    _EditSection(
                      title: 'Какое у тебя настроение чаще',
                      child: _buildVibeGrid(),
                    ),
                    _EditSection(
                      title: 'Зачем ты здесь',
                      child: _buildIntentRow(),
                    ),
                    _EditSection(
                      title: 'О себе',
                      right: _SuggestBioButton(onTap: _suggestBio),
                      child: _buildBioCard(),
                    ),
                    _EditSection(
                      title: 'Интересы · ${_interests.length}',
                      right: Text(
                        'выбери минимум 3',
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          fontSize: 10.5,
                        ),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
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
                                selectedBackground: BbV5Colors.ink,
                                selectedForeground: BbV5Colors.paperHi,
                                showCheck: true,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    _EditSection(
                      title: 'Видимость',
                      child: _buildVisibilityCard(),
                    ),
                    const SizedBox(height: 28),
                    BbV5PillButton(
                      label: 'Сохранить профиль',
                      icon: LucideIcons.check,
                      dark: true,
                      height: 52,
                      expanded: true,
                      onPressed: _photoBusy || _saving
                          ? null
                          : () => _saveProfile(profile),
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

  Widget _buildBasicsCard(ProfileData? profile) {
    final area = profile?.area?.trim();
    final city = profile?.city?.trim();
    final location = [
      if (city != null && city.isNotEmpty) city else 'Москва',
      if (area != null && area.isNotEmpty) area else 'Чистые пруды',
    ].join(' · ');

    return BbV5Card(
      padding: EdgeInsets.zero,
      radius: 24,
      child: Column(
        children: [
          _EditRow(
            label: 'Как тебя зовут',
            child: TextField(
              key: const Key('edit-profile-name-field'),
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              maxLength: 32,
              textAlign: TextAlign.right,
              cursorColor: BbV5Colors.terra,
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                isCollapsed: true,
              ),
              style: AppTextStyles.body.copyWith(
                color: BbV5Colors.ink,
                fontFamily: 'Sora',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: BbV5Colors.hairSoft),
          _EditRow(
            label: 'Возраст',
            child: TextField(
              key: const Key('edit-profile-age-field'),
              controller: _ageController,
              onChanged: (value) {
                final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
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
                fontFamily: 'Sora',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: BbV5Colors.hairSoft),
          _EditRow(
            label: 'Город · район',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.map_pin,
                  size: 14,
                  color: BbV5Colors.inkMute,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.body.copyWith(
                      color: BbV5Colors.ink,
                      fontFamily: 'Sora',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  LucideIcons.chevron_down,
                  size: 14,
                  color: BbV5Colors.inkMute,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _editVibes
              .map(
                (item) => SizedBox(
                  width: tileWidth,
                  child: _VibeCard(
                    vibe: item,
                    selected: vibe == item.label,
                    onTap: () => setState(() => vibe = item.label),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildIntentRow() {
    return Row(
      children: [
        for (var index = 0; index < _editIntents.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _IntentButton(
              intent: _editIntents[index],
              selected: _intent.contains(_editIntents[index].label),
              onTap: () => setState(() {
                final label = _editIntents[index].label;
                if (_intent.contains(label)) {
                  _intent.remove(label);
                } else {
                  _intent.add(label);
                }
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBioCard() {
    return BbV5Card(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            key: const Key('edit-profile-bio-field'),
            controller: _bioController,
            onChanged: (_) => setState(() {}),
            maxLines: 4,
            maxLength: _editProfileBioMaxLength,
            cursorColor: BbV5Colors.terra,
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: '2-3 предложения о тебе. Что любишь, чего ищешь.',
              hintStyle: AppTextStyles.bodySoft.copyWith(
                color: BbV5Colors.inkMute.withValues(alpha: 0.5),
                fontSize: 13.5,
              ),
            ),
            style: AppTextStyles.bodySoft.copyWith(
              color: BbV5Colors.inkSoft,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          Row(
            children: [
              BbV5PillButton(
                label: _voiceOn ? 'Запись...' : 'Голосом',
                icon: LucideIcons.mic,
                dark: _voiceOn,
                height: 32,
                fontSize: 11,
                iconSize: 13,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () => setState(() => _voiceOn = !_voiceOn),
              ),
              const Spacer(),
              Text(
                '${_bioController.text.length}/$_editProfileBioMaxLength',
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityCard() {
    return BbV5Card(
      padding: EdgeInsets.zero,
      radius: 24,
      child: Column(
        children: [
          _ToggleRow(
            icon: _hideAge ? LucideIcons.eye_off : LucideIcons.eye,
            label: 'Скрыть возраст',
            subtitle: 'Покажем только имя',
            value: _hideAge,
            onChanged: (value) => setState(() => _hideAge = value),
          ),
          const Divider(height: 1, thickness: 1, color: BbV5Colors.hairSoft),
          _ToggleRow(
            icon: LucideIcons.map_pin,
            label: 'Показывать на радаре',
            subtitle: 'Тебя смогут найти рядом',
            value: _showOnRadar,
            onChanged: (value) => setState(() => _showOnRadar = value),
          ),
        ],
      ),
    );
  }

  void _suggestBio() {
    setState(() {
      _bioController.text =
          'Легкий на подъем. Кофе с утра, бар вечером, и кто-то рядом.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Готовый текст подставлен')),
    );
  }

  Widget _togglePill(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? selectedBackground,
    Color? selectedForeground,
    bool showCheck = false,
  }) {
    final resolvedSelectedBackground = selectedBackground ?? BbV5Colors.accent;
    final resolvedSelectedForeground = selectedForeground ?? BbV5Colors.paperHi;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? resolvedSelectedBackground : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: selected ? resolvedSelectedBackground : BbV5Colors.hair,
            ),
            boxShadow: selected ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && showCheck) ...[
                Icon(
                  LucideIcons.check,
                  size: 13,
                  color: resolvedSelectedForeground,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.meta.copyWith(
                  color: selected
                      ? resolvedSelectedForeground
                      : BbV5Colors.inkSoft,
                  fontFamily: 'Sora',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
      final profileLocalState = ref.read(profileLocalStateProvider.notifier);
      final onboardingLocalState =
          ref.read(onboardingLocalStateProvider.notifier);
      final updatedProfile = await repository.updateProfile({
        'displayName': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'city': profile?.city ?? 'Москва',
        'area': profile?.area ?? 'Чистые пруды',
        'bio': _bioController.text.trim(),
        'vibe': vibe,
      });
      final savedOnboarding = await repository.saveOnboarding(
        OnboardingData(
          intent: _resolveIntent(),
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
      onboardingLocalState.state = savedOnboarding;
      profileLocalState.state = updatedProfile.withOnboarding(savedOnboarding);
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

  String? _resolveIntent() {
    final tokens = <String>[
      if (_intent.contains('Свидания')) 'dating',
      if (_intent.contains('Друзья')) 'friendship',
      if (_intent.contains('Нетворк')) 'network',
    ];
    if (tokens.isEmpty) {
      return null;
    }
    if (tokens.length == 2 &&
        tokens.contains('dating') &&
        tokens.contains('friendship')) {
      return 'both';
    }
    if (tokens.length == 1) {
      return tokens.single;
    }
    return tokens.join(',');
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
    return BbV5TopBar(
      onBack: onBack,
      kicker: 'Профиль',
      title: 'Расскажи',
      accent: 'о себе',
      right: BbV5PillButton(
        label: saving ? '...' : 'Готово',
        icon: saving ? null : LucideIcons.check,
        dark: true,
        height: 40,
        fontSize: 12.5,
        iconSize: 15,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onPressed: onSave,
      ),
    );
  }
}

class _SuggestBioButton extends StatelessWidget {
  const _SuggestBioButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        foregroundColor: BbV5Colors.terra,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(LucideIcons.sparkles, size: 13),
      label: Text(
        'ПОДСКАЗАТЬ',
        style: AppTextStyles.caption.copyWith(
          color: BbV5Colors.terra,
          fontFamily: 'Sora',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.vibe,
    required this.selected,
    required this.onTap,
  });

  final _EditVibe vibe;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? BbV5Colors.terraSoft.withValues(alpha: 0.5)
                : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? BbV5Colors.accent : BbV5Colors.hair,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F1F241D),
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(vibe.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vibe.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.ink,
                        fontFamily: 'Sora',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                vibe.hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentButton extends StatelessWidget {
  const _IntentButton({
    required this.intent,
    required this.selected,
    required this.onTap,
  });

  final _EditIntent intent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5PillButton(
      label: intent.label,
      icon: intent.icon,
      dark: selected,
      height: 48,
      fontSize: 12.5,
      iconSize: 15,
      iconGap: 5,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      expanded: true,
      onPressed: onTap,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BbV5Colors.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, size: 15, color: BbV5Colors.inkSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.ink,
                    fontFamily: 'Sora',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeThumbColor: BbV5Colors.paperHi,
            activeTrackColor: BbV5Colors.accent,
            inactiveThumbColor: BbV5Colors.paperHi,
            inactiveTrackColor: const Color(0x2E3C281C),
            onChanged: onChanged,
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
    this.right,
  });

  final String title;
  final Widget child;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: BbV5Kicker(title)),
                if (right != null) right!,
              ],
            ),
          ),
          const SizedBox(height: 10),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                label,
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.inkSoft,
                  fontSize: 12.5,
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
