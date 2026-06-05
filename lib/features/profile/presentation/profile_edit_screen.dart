import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/features/profile/presentation/profile_helpers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _interests = <String>{};
  bool _hydrated = false;
  bool _saving = false;
  bool _photoBusy = false;
  List<_EditableProfilePhoto>? _photoOrder;
  String? _photoOrderSignature;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(ownProfileProvider);
    final profile = profileState.valueOrNull;
    if (!_hydrated && profile != null) {
      _hydrate(profile);
    }
    final profilePhotos =
        profile == null ? <_EditableProfilePhoto>[] : _profilePhotos(profile);
    final photoSignature = _photoSignature(profilePhotos);
    if (!_photoBusy && _photoOrderSignature != photoSignature) {
      _photoOrder = profilePhotos;
      _photoOrderSignature = photoSignature;
    }
    final photos = _photoOrder ?? profilePhotos;
    return DateasyPhoneFrame(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 16,
          20,
          34,
        ),
        children: [
          _Header(
            saving: _saving,
            onSave: profile == null ? null : _save,
          ),
          const SizedBox(height: 28),
          if (profileState.isLoading && profile == null)
            const ProfileInlineState(text: 'Загружаем профиль')
          else if (profile == null)
            ProfileInlineState(
              text: profileState.hasError
                  ? 'Не удалось загрузить профиль'
                  : 'Профиль не найден',
            )
          else
            _PhotoGrid(
              photos: photos,
              busy: _photoBusy,
              onAdd: _addPhotos,
              onRemove: _removePhoto,
              onMakePrimary: _makePrimaryPhoto,
              onReorder: _reorderPhotos,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ProfileInlineState(text: _error!),
          ],
          const SizedBox(height: 28),
          _FieldsBlock(
            nameController: _nameController,
            ageController: _ageController,
            bioController: _bioController,
          ),
          const SizedBox(height: 28),
          _InterestsBlock(
            selected: _interests,
            onToggle: (value) {
              setState(() {
                if (_interests.contains(value)) {
                  _interests.remove(value);
                } else {
                  _interests.add(value);
                }
              });
            },
          ),
          const SizedBox(height: 42),
          _DeleteButton(
            onTap: () => _showNotice('Delete account endpoint не найден'),
          ),
        ],
      ),
    );
  }

  void _hydrate(BackendCardItem profile) {
    _nameController.text = profile.title;
    _ageController.text = _stringFrom(profile.raw['age']);
    _bioController.text = profile.subtitle ?? '';
    final rawInterests = profile.raw['interests'];
    if (rawInterests is List) {
      _interests
        ..clear()
        ..addAll(rawInterests.map((value) => value.toString()));
    }
    _hydrated = true;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final age = int.tryParse(_ageController.text.trim());
      await ref.read(profileActionsProvider).updateProfileAndInterests(
        profileData: {
          'displayName': _nameController.text.trim(),
          if (age != null) 'age': age,
          'bio': _bioController.text.trim(),
        },
        interests: _interests.toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      context.go('/profile');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Не удалось сохранить профиль';
      });
    }
  }

  Future<void> _addPhotos() async {
    if (_photoBusy) {
      return;
    }
    final profile = ref.read(ownProfileProvider).valueOrNull;
    final currentCount = profile == null ? 0 : _profilePhotos(profile).length;
    if (currentCount >= 6) {
      return;
    }
    setState(() {
      _photoBusy = true;
      _error = null;
    });
    try {
      final picked = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || picked.isEmpty) {
        return;
      }
      final remaining = 6 - currentCount;
      for (final file in picked.take(remaining)) {
        await ref.read(profileActionsProvider).uploadProfilePhoto(
              filePath: file.path,
              fileName: file.name,
              mimeType: _mimeTypeForPickedFile(file),
            );
        if (!mounted) {
          return;
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Не получилось загрузить фото');
    } finally {
      if (mounted) {
        setState(() => _photoBusy = false);
      }
    }
  }

  Future<void> _removePhoto(_EditableProfilePhoto photo) async {
    final photoId = photo.id;
    if (_photoBusy || photoId == null) {
      _showNotice('Photo delete endpoint требует id фото');
      return;
    }
    setState(() {
      _photoBusy = true;
      _error = null;
    });
    try {
      await ref.read(profileActionsProvider).deleteProfilePhoto(photoId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Не получилось удалить фото');
    } finally {
      if (mounted) {
        setState(() => _photoBusy = false);
      }
    }
  }

  Future<void> _makePrimaryPhoto(_EditableProfilePhoto photo) async {
    final photoId = photo.id;
    if (_photoBusy || photo.primary || photoId == null) {
      return;
    }
    setState(() {
      _photoBusy = true;
      _error = null;
    });
    try {
      await ref.read(profileActionsProvider).makePrimaryProfilePhoto(photoId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Не получилось сделать фото главным');
    } finally {
      if (mounted) {
        setState(() => _photoBusy = false);
      }
    }
  }

  Future<void> _reorderPhotos(List<_EditableProfilePhoto> photos) async {
    if (_photoBusy) {
      return;
    }
    final photoIds = photos.map((photo) => photo.id).toList(growable: false);
    if (photoIds.any((id) => id == null || id.isEmpty)) {
      _showNotice('Сначала обнови фото, у части снимков нет id');
      return;
    }
    final current = _photoOrder ?? <_EditableProfilePhoto>[];
    if (_photoSignature(current) == _photoSignature(photos)) {
      return;
    }
    final previous = List<_EditableProfilePhoto>.of(current);
    setState(() {
      _photoOrder = photos;
      _photoBusy = true;
      _error = null;
    });
    try {
      await ref.read(profileActionsProvider).reorderProfilePhotos(
            photoIds.cast<String>(),
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _photoOrder = previous;
        _error = 'Не получилось сохранить порядок фото';
      });
    } finally {
      if (mounted) {
        setState(() => _photoBusy = false);
      }
    }
  }

  void _showNotice(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: DateasyColors.surface2,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.saving,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileGlassIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        const Spacer(),
        Text(
          'Редактировать',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'Sora',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: saving ? null : onSave,
          child: SizedBox(
            width: 58,
            child: saving
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(
                    'Готово',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onSave == null
                              ? DateasyColors.muted
                              : DateasyColors.lime,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    required this.onMakePrimary,
    required this.onReorder,
  });

  final List<_EditableProfilePhoto> photos;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<_EditableProfilePhoto> onRemove;
  final ValueChanged<_EditableProfilePhoto> onMakePrimary;
  final ValueChanged<List<_EditableProfilePhoto>> onReorder;

  @override
  Widget build(BuildContext context) {
    final reorderEnabled = !busy &&
        photos.length > 1 &&
        photos.every((photo) => photo.id != null && photo.id!.isNotEmpty);
    return _Section(
      label: 'Фото',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          if (index < photos.length) {
            final photo = photos[index];
            return _ReorderablePhotoTile(
              index: index,
              photos: photos,
              enabled: reorderEnabled,
              onReorder: onReorder,
              child: _PhotoTile(
                photo: photo,
                busy: busy,
                onRemove: () => onRemove(photo),
                onMakePrimary: () => onMakePrimary(photo),
              ),
            );
          }

          return _AddPhotoTile(busy: busy, onTap: onAdd);
        },
      ),
    );
  }
}

class _ReorderablePhotoTile extends StatelessWidget {
  const _ReorderablePhotoTile({
    required this.index,
    required this.photos,
    required this.enabled,
    required this.onReorder,
    required this.child,
  });

  final int index;
  final List<_EditableProfilePhoto> photos;
  final bool enabled;
  final ValueChanged<List<_EditableProfilePhoto>> onReorder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        return enabled && details.data != index;
      },
      onAcceptWithDetails: (details) {
        onReorder(_swapPhotos(photos, details.data, index));
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: highlighted ? const EdgeInsets.all(2) : EdgeInsets.zero,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: highlighted
                ? Border.all(color: DateasyColors.lime, width: 2)
                : null,
          ),
          child: LongPressDraggable<int>(
            data: index,
            maxSimultaneousDrags: enabled ? 1 : 0,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 104,
                height: 104,
                child: Opacity(opacity: 0.9, child: child),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: child),
            child: child,
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.busy,
    required this.onRemove,
    required this.onMakePrimary,
  });

  final _EditableProfilePhoto photo;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback onMakePrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onMakePrimary,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DateasyRemoteImage(
              imageUrl: photo.url,
              usage: DateasyImageUsage.avatar,
            ),
            Positioned(
              top: 5,
              right: 5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: busy ? null : onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DateasyColors.background.withValues(alpha: 0.82),
                  ),
                  child: const Icon(LucideIcons.x, size: 14),
                ),
              ),
            ),
            if (photo.primary)
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: DateasyColors.lime,
                  ),
                  child: Text(
                    'Главное',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.backgroundDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: CustomPaint(
        painter: ProfileDashedBorderPainter(
          color: Colors.white.withValues(alpha: 0.15),
          radius: 16,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: DateasyColors.glass.withValues(alpha: 0.4),
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    LucideIcons.plus,
                    size: 22,
                    color: DateasyColors.muted,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FieldsBlock extends StatelessWidget {
  const _FieldsBlock({
    required this.nameController,
    required this.ageController,
    required this.bioController,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController bioController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditField(label: 'Имя', controller: nameController),
        const SizedBox(height: 16),
        _EditField(
          label: 'Возраст',
          controller: ageController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _EditField(
          label: 'О себе',
          controller: bioController,
          maxLines: 4,
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
                fontSize: 12,
              ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: DateasyColors.glass,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: DateasyColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: DateasyColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: DateasyColors.lime),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
              ),
        ),
      ],
    );
  }
}

class _InterestsBlock extends StatelessWidget {
  const _InterestsBlock({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final options = {
      ..._allInterests,
      ...selected,
    }.toList(growable: false);
    return _Section(
      label: 'Интересы · выбрано ${selected.length}',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((interest) {
          final active = selected.contains(interest);
          return GestureDetector(
            onTap: () => onToggle(interest),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active ? DateasyColors.lime : DateasyColors.glass,
                border: active ? null : Border.all(color: DateasyColors.border),
              ),
              child: Text(
                interest,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: active
                          ? DateasyColors.backgroundDeep
                          : DateasyColors.foreground,
                      fontWeight: active ? FontWeight.w600 : null,
                    ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const destructive = Color(0xFFFF6B8A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: destructive.withValues(alpha: 0.32)),
        ),
        child: Text(
          'Удалить аккаунт',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: destructive,
                fontSize: 14,
              ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
                fontSize: 14,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

const _allInterests = [
  'Speciality coffee',
  'Винил',
  'Галереи',
  'Прогулки',
  'Кино',
  'Йога',
  'Бег',
  'Гастро',
  'Книги',
  'Серфинг',
  'Театр',
  'Кофе',
  'Музеи',
  'Стендап',
];

List<_EditableProfilePhoto> _profilePhotos(BackendCardItem profile) {
  final photos = profile.raw['photos'];
  if (photos is! List) {
    final avatar = profile.imageUrl;
    return avatar == null || avatar.isEmpty
        ? const []
        : [_EditableProfilePhoto(url: avatar, primary: true)];
  }
  final parsed = <_EditableProfilePhoto>[];
  for (final item in photos) {
    if (item is! Map) {
      continue;
    }
    final url = (item['url'] ?? (item['media'] as Map?)?['url'])?.toString();
    if (url == null || url.isEmpty) {
      continue;
    }
    parsed.add(
      _EditableProfilePhoto(
        id: _stringOrNull(item['id']),
        url: url,
        primary: item['isPrimary'] == true ||
            item['primary'] == true ||
            item['is_primary'] == true,
      ),
    );
  }
  if (parsed.any((photo) => photo.primary)) {
    return parsed;
  }
  if (parsed.isNotEmpty) {
    return [
      for (var index = 0; index < parsed.length; index += 1)
        _EditableProfilePhoto(
          id: parsed[index].id,
          url: parsed[index].url,
          primary: index == 0,
        ),
    ];
  }
  final avatar = profile.imageUrl;
  return avatar == null || avatar.isEmpty
      ? const []
      : [_EditableProfilePhoto(url: avatar, primary: true)];
}

String _stringFrom(Object? value) {
  return value?.toString() ?? '';
}

String? _stringOrNull(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

String _photoSignature(List<_EditableProfilePhoto> photos) {
  return photos
      .map((photo) => '${photo.id ?? ''}:${photo.url}:${photo.primary}')
      .join('|');
}

List<_EditableProfilePhoto> _swapPhotos(
  List<_EditableProfilePhoto> photos,
  int from,
  int to,
) {
  if (from == to || from < 0 || to < 0) {
    return photos;
  }
  if (from >= photos.length || to >= photos.length) {
    return photos;
  }
  final reordered = List<_EditableProfilePhoto>.of(photos);
  final source = reordered[from];
  reordered[from] = reordered[to];
  reordered[to] = source;
  return [
    for (var index = 0; index < reordered.length; index += 1)
      reordered[index].copyWith(primary: index == 0),
  ];
}

String _mimeTypeForPickedFile(XFile file) {
  final explicit = file.mimeType;
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) {
    return 'image/png';
  }
  if (name.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

class _EditableProfilePhoto {
  const _EditableProfilePhoto({
    required this.url,
    required this.primary,
    this.id,
  });

  final String? id;
  final String url;
  final bool primary;

  _EditableProfilePhoto copyWith({
    String? id,
    String? url,
    bool? primary,
  }) {
    return _EditableProfilePhoto(
      id: id ?? this.id,
      url: url ?? this.url,
      primary: primary ?? this.primary,
    );
  }
}
