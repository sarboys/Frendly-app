import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile2/features/onboarding/application/onboarding_permission_service.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/city_catalog.dart';
import 'package:mobile2/shared/data/city_search_service.dart';
import 'package:mobile2/shared/data/yandex_city_search_service.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/utils/phone_number_text_input_formatter.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

const _minimumOnboardingPhotoCount = 2;
final _generatedPhoneDisplayNamePattern = RegExp(r'^Пользователь \d{4}$');

String _onboardingNameInputFromStored(String? value) {
  final name = value?.trim() ?? '';
  if (_generatedPhoneDisplayNamePattern.hasMatch(name)) {
    return '';
  }
  return name;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  int _index = 0;
  bool _hydrated = false;
  bool _saving = false;
  bool _searchingCity = false;
  String? _error;
  String? _selectedCity;
  String? _selectedArea;
  String? _selectedLocationInput;
  Timer? _citySearchDebounce;
  List<CitySearchResult> _citySuggestions = const [];
  final Set<String> _goals = {};
  final Set<String> _interests = {};
  String? _gender;
  String? _vibe;
  String? _requiredContact;
  DateTime? _birthday;
  bool _uploadingPhoto = false;
  final ImagePicker _imagePicker = ImagePicker();
  final List<_OnboardingPhoto> _photos = [];

  List<_OnboardingStep> get _steps => [
        _OnboardingStep(
          key: 'goal',
          title: 'Зачем ты в Frendly?',
          subtitle: 'Можно выбрать несколько',
          child: _GoalsStep(
            selected: _goals,
            onToggle: _toggleGoal,
          ),
        ),
        _OnboardingStep(
          key: 'gender',
          title: 'Твой пол',
          child: _GenderStep(
            selected: _gender,
            onChanged: (value) => setState(() => _gender = value),
          ),
        ),
        _OnboardingStep(
          key: 'city',
          title: 'Где ты сейчас?',
          subtitle: 'Город или район',
          child: _CityStep(
            controller: _cityController,
            suggestions: _citySuggestions,
            searching: _searchingCity,
            onChanged: _handleCityChanged,
            onSelectCity: _applyCityValue,
            onSelect: _applyCitySuggestion,
          ),
        ),
        _OnboardingStep(
          key: 'interests',
          title: 'Что тебе по кайфу?',
          subtitle: 'Выбери 3 и больше',
          child: _InterestsStep(
            selected: _interests,
            onToggle: _toggleInterest,
          ),
        ),
        _OnboardingStep(
          key: 'vibe',
          title: 'Какой твой вайб?',
          child: _VibeStep(
            selected: _vibe,
            onChanged: (value) => setState(() => _vibe = value),
          ),
        ),
        _OnboardingStep(
          key: 'bday',
          title: 'Твой день рождения',
          subtitle: 'Покажем только возраст',
          child: _BirthdayStep(
            controller: _birthdayController,
            birthday: _birthday,
            onChanged: _handleBirthdayTextChanged,
            onPick: _pickBirthday,
          ),
        ),
        _OnboardingStep(
          key: 'photos',
          title: 'Добавь фото',
          subtitle: 'Минимум 2, можно до 6. Первое станет аватаркой',
          child: _PhotosStep(
            photos: _photos,
            uploading: _uploadingPhoto,
            onAdd: _addPhotos,
            onRemove: _removePhoto,
            onMakePrimary: _makePrimaryPhoto,
          ),
        ),
        _OnboardingStep(
          key: 'contact',
          title: 'Контакты',
          subtitle: 'Email и телефон — для входа и безопасности',
          child: _ContactStep(
            nameController: _nameController,
            emailController: _emailController,
            phoneController: _phoneController,
            onChanged: () => setState(() {}),
          ),
        ),
        _OnboardingStep(
          key: 'bio',
          title: 'Расскажите немного о себе',
          subtitle: 'Пара строк для профиля',
          child: _BioStep(
            controller: _bioController,
            onChanged: () => setState(() {}),
          ),
        ),
        const _OnboardingStep(
          key: 'perms',
          title: 'Разрешения',
          subtitle: 'Нужны для рекомендаций рядом',
          child: _PermissionsStep(),
        ),
      ];

  @override
  void dispose() {
    _citySearchDebounce?.cancel();
    _cityController.dispose();
    _birthdayController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);
    final existing = onboarding.valueOrNull;
    if (!_hydrated && existing != null) {
      _hydrate(existing);
    }
    final step = _steps[_index];
    final progress = (_index + 1) / _steps.length;
    final isLast = _index == _steps.length - 1;
    final canContinue = _canContinueCurrentStep;

    return DateasyPhoneFrame(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          child: Column(
            children: [
              _OnboardingTopBar(
                progress: progress,
                current: _index + 1,
                total: _steps.length,
                onBack: _handleBack,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40, bottom: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Column(
                      key: ValueKey('${step.key}-${_error ?? ''}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (onboarding.isLoading && existing == null) ...[
                          const _InlineLoadingState(),
                          const SizedBox(height: 20),
                        ],
                        _OnboardingStepBody(step: step),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _InlineError(text: _error!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _PrimaryButton(
                label: _saving
                    ? 'Сохраняем...'
                    : (isLast ? 'В Frendly' : 'Дальше'),
                enabled: canContinue && !_saving,
                onTap: _handleNext,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hydrate(OnboardingData onboarding) {
    _hydrated = true;
    _goals
      ..clear()
      ..addAll(_splitIntent(onboarding.intent));
    _interests
      ..clear()
      ..addAll(onboarding.interests);
    _gender = onboarding.gender;
    _vibe = onboarding.vibe;
    _requiredContact = onboarding.requiredContact;
    _cityController.text = onboarding.city ?? '';
    _selectedCity = onboarding.city;
    _selectedArea = onboarding.area;
    _selectedLocationInput = onboarding.city;
    _nameController.text = _onboardingNameInputFromStored(onboarding.name);
    _bioController.text = onboarding.bio ?? '';
    _emailController.text = onboarding.email ?? '';
    _phoneController.text =
        _phoneInputTextFromStored(onboarding.phoneNumber ?? '');
    _birthday = _parseDate(onboarding.birthDate);
    _birthdayController.text = _birthDateInputFromStored(onboarding.birthDate);
    _photos
      ..clear()
      ..addAll(_profilePhotosFromOnboarding(onboarding));
  }

  Future<void> _handleNext() async {
    if (_saving || !_canContinueCurrentStep) {
      return;
    }
    final isLast = _index == _steps.length - 1;
    if (!isLast) {
      if (_steps[_index].key == 'city') {
        await _resolveTypedCityBeforeContinue();
        if (!mounted) {
          return;
        }
      }
      if (_steps[_index].key == 'bday' && !_validateBirthdayInput()) {
        return;
      }
      setState(() {
        _error = null;
        _index += 1;
      });
      return;
    }
    await _submit();
  }

  bool get _canContinueCurrentStep {
    final key = _steps[_index].key;
    return switch (key) {
      'goal' => _goals.isNotEmpty,
      'gender' => _gender == 'male' || _gender == 'female',
      'city' => (_selectedCity != null && _selectedCity!.trim().isNotEmpty) ||
          _cityController.text.trim().isNotEmpty,
      'interests' => _interests.length >= 3,
      'vibe' => _vibe != null && _vibe!.trim().isNotEmpty,
      'bday' => _birthday != null || _birthdayController.text.trim().isNotEmpty,
      'photos' =>
        _photos.length >= _minimumOnboardingPhotoCount && !_uploadingPhoto,
      'contact' => _isNameFilled && _isRequiredContactFilled,
      _ => true,
    };
  }

  bool get _isNameFilled {
    final name = _nameController.text.trim();
    return name.isNotEmpty && !_generatedPhoneDisplayNamePattern.hasMatch(name);
  }

  bool get _isRequiredContactFilled {
    return switch (_requiredContact) {
      'email' => _emailController.text.trim().isNotEmpty,
      'phone' => _phoneController.text.trim().isNotEmpty,
      _ => true,
    };
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = _emptyToNull(_nameController.text.trim());
      final email = _emptyToNull(_emailController.text.trim());
      final bio = _emptyToNull(_bioController.text.trim());
      final phoneNumber = _normalizedRussianPhoneNumber(_phoneController.text);
      if (email != null || phoneNumber != null) {
        await ref.read(onboardingFlowControllerProvider).checkContact(
              email: email,
              phoneNumber: phoneNumber,
            );
      }
      await ref.read(onboardingFlowControllerProvider).save(
            OnboardingData(
              name: name,
              intent: _goals.isEmpty ? null : _goals.join(', '),
              gender: _gender,
              birthDate: _birthDateIsoFromInput(_birthdayController.text),
              city: _emptyToNull(_selectedCity ?? _cityController.text.trim()),
              area: _emptyToNull(_selectedArea ?? ''),
              interests: _interests.toList(growable: false),
              vibe: _vibe,
              bio: bio,
              email: email,
              phoneNumber: phoneNumber,
            ),
          );
      if (mounted) {
        context.go('/');
      }
    } catch (error) {
      if (mounted) {
        final contactError = _onboardingContactErrorMessage(error);
        final requiredContact = _requiredContactFromOnboardingError(error);
        setState(() {
          if (contactError != null) {
            _index = _steps.indexWhere((step) => step.key == 'contact');
          }
          if (requiredContact != null) {
            _requiredContact = requiredContact;
          }
          _error = contactError ?? 'Не получилось сохранить onboarding';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _handleBack() {
    if (_index > 0) {
      setState(() => _index -= 1);
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  String? _onboardingContactErrorMessage(Object error) {
    if (error is! BackendActionException) {
      return null;
    }

    if (error.code == 'required_email') {
      return 'Укажи email, чтобы закончить onboarding.';
    }
    if (error.code == 'required_phone_number') {
      return 'Укажи телефон, чтобы закончить onboarding.';
    }
    if (error.code != 'contact_already_used') {
      return null;
    }

    final field = error.details?['field']?.toString();
    final contactField =
        field == 'email' || field == 'phoneNumber' ? field : _requiredContact;
    return switch (contactField) {
      'email' =>
        'Этот email уже привязан к другому аккаунту. Войди через Google или Yandex с этим email.',
      'phone' ||
      'phoneNumber' =>
        'Этот телефон уже привязан к другому аккаунту. Войди по этому номеру на экране входа.',
      _ => 'Этот email или телефон уже привязан к другому аккаунту.',
    };
  }

  String? _requiredContactFromOnboardingError(Object error) {
    if (error is! BackendActionException) {
      return null;
    }
    return switch (error.code) {
      'required_email' => 'email',
      'required_phone_number' => 'phone',
      _ => null,
    };
  }

  void _toggleGoal(String goal) {
    setState(() {
      if (_goals.contains(goal)) {
        _goals.remove(goal);
      } else {
        _goals.add(goal);
      }
    });
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_interests.contains(interest)) {
        _interests.remove(interest);
      } else {
        _interests.add(interest);
      }
    });
  }

  void _handleBirthdayTextChanged(String value) {
    setState(() {
      _birthday = _parseBirthdayInput(value);
      if (_error == 'Введите реальную дату рождения') {
        _error = null;
      }
    });
  }

  bool _validateBirthdayInput() {
    final value = _birthdayController.text.trim();
    final birthday = _parseBirthdayInput(value);
    if (birthday == null) {
      setState(() {
        _birthday = null;
        _error = 'Введите реальную дату рождения';
      });
      return false;
    }
    setState(() {
      _birthday = birthday;
      _error = null;
    });
    return true;
  }

  void _handleCityChanged(String value) {
    final query = value.trim();
    final exactCity = cityForQuery(query, cities: defaultRussianCities);
    final cityMatches = cityMatchesFor(query, cities: defaultRussianCities);
    _citySearchDebounce?.cancel();
    setState(() {
      _selectedCity = null;
      _selectedArea = null;
      _selectedLocationInput = null;
      if (exactCity != null && cityMatches.length == 1) {
        _searchingCity = false;
        _citySuggestions = const [];
      }
    });
    if (exactCity != null && cityMatches.length == 1) {
      return;
    }
    _queueCitySearch(query);
  }

  void _queueCitySearch(String query) {
    _citySearchDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchingCity = false;
        _citySuggestions = const [];
      });
      return;
    }

    setState(() {
      _searchingCity = true;
    });

    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || !identical(_citySearchDebounce, timer)) {
        return;
      }
      try {
        final remote = await ref
            .read(yandexCitySearchServiceProvider)
            .search(query, limit: 8);
        if (!mounted ||
            !identical(_citySearchDebounce, timer) ||
            _cityController.text.trim() != query) {
          return;
        }
        setState(() {
          _searchingCity = false;
          _citySuggestions = remote;
        });
      } catch (_) {
        if (!mounted ||
            !identical(_citySearchDebounce, timer) ||
            _cityController.text.trim() != query) {
          return;
        }
        setState(() {
          _searchingCity = false;
          _citySuggestions = const [];
        });
      }
    });
    _citySearchDebounce = timer;
  }

  Future<void> _resolveTypedCityBeforeContinue() async {
    final query = _cityController.text.trim();
    if (query.isEmpty || _selectedLocationInput == query) {
      return;
    }
    final exactCity = cityForQuery(query, cities: defaultRussianCities);
    if (exactCity != null) {
      _applyCityValue(exactCity);
      return;
    }
    final cityMatches = cityMatchesFor(query, cities: defaultRussianCities);
    if (cityMatches.length == 1) {
      _applyCityValue(cityMatches.single);
      return;
    }

    try {
      final remote = await ref
          .read(yandexCitySearchServiceProvider)
          .search(query, limit: 1);
      if (!mounted || _cityController.text.trim() != query) {
        return;
      }
      final first = remote.isEmpty ? null : remote.first;
      if (first != null) {
        setState(() {
          _applyCitySuggestionValue(first);
        });
      } else {
        setState(() {
          _selectedCity = query;
          _selectedArea = null;
          _selectedLocationInput = query;
        });
      }
    } catch (_) {
      if (!mounted || _cityController.text.trim() != query) {
        return;
      }
      setState(() {
        _selectedCity = query;
        _selectedArea = null;
        _selectedLocationInput = query;
      });
    }
  }

  void _applyCitySuggestion(CitySearchResult item) {
    setState(() {
      _applyCitySuggestionValue(item);
    });
  }

  void _applyCityValue(RussianCity city) {
    setState(() {
      _cityController.text = city.label;
      _selectedCity = city.city;
      _selectedArea = city.area;
      _selectedLocationInput = city.label;
      _citySuggestions = const [];
      _searchingCity = false;
      _citySearchDebounce?.cancel();
    });
  }

  void _applyCitySuggestionValue(CitySearchResult item) {
    final input =
        item.label.trim().isNotEmpty ? item.label.trim() : item.city.trim();
    final city = item.city.trim();

    _cityController.text = input;
    _selectedCity = city.isNotEmpty ? city : input;
    _selectedArea = item.area?.trim();
    _selectedLocationInput = input;
    _citySuggestions = const [];
    _searchingCity = false;
  }

  Future<void> _pickBirthday() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthday ?? DateTime(today.year - 24, today.month, today.day),
      firstDate: DateTime(1940),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: DateasyTheme.theme.copyWith(
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: DateasyColors.surface,
              headerBackgroundColor: DateasyColors.surface2,
              headerForegroundColor: DateasyColors.foreground,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _birthday = picked;
      _birthdayController.text = _birthDateInputFromDate(picked);
      _error = null;
    });
  }

  Future<void> _addPhotos() async {
    if (_uploadingPhoto || _photos.length >= 6) {
      return;
    }
    setState(() {
      _uploadingPhoto = true;
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
      final remaining = 6 - _photos.length;
      for (final file in picked.take(remaining)) {
        final uploaded =
            await ref.read(profileActionsProvider).uploadProfilePhoto(
                  filePath: file.path,
                  fileName: file.name,
                  mimeType: _mimeTypeForPickedFile(file),
                );
        if (!mounted) {
          return;
        }
        final photo = uploaded['photo'];
        final id = photo is Map
            ? photo['id']?.toString()
            : uploaded['photoId']?.toString();
        final url = photo is Map
            ? (photo['url'] ?? (photo['media'] as Map?)?['url'])?.toString()
            : uploaded['url']?.toString();
        setState(() {
          _photos.add(
            _OnboardingPhoto(
              id: id ?? uploaded['assetId']?.toString() ?? file.path,
              url: url,
              localPath: file.path,
            ),
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Не получилось загрузить фото';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _removePhoto(_OnboardingPhoto photo) async {
    setState(() {
      _photos.removeWhere((item) => item.id == photo.id);
    });
    unawaited(ref.read(profileActionsProvider).deleteProfilePhoto(photo.id));
  }

  Future<void> _makePrimaryPhoto(_OnboardingPhoto photo) async {
    if (_photos.isEmpty || _photos.first.id == photo.id) {
      return;
    }
    setState(() {
      _photos.removeWhere((item) => item.id == photo.id);
      _photos.insert(0, photo);
    });
    unawaited(
        ref.read(profileActionsProvider).makePrimaryProfilePhoto(photo.id));
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String key;
  final String title;
  final String? subtitle;
  final Widget child;
}

class _OnboardingStepBody extends StatelessWidget {
  _OnboardingStepBody({required this.step}) : super(key: ValueKey(step.key));

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(step.key),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
        ),
        if (step.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            step.subtitle!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: DateasyColors.muted,
                ),
          ),
        ],
        const SizedBox(height: 32),
        step.child,
      ],
    );
  }
}

class _InlineLoadingState extends StatelessWidget {
  const _InlineLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _GlassBox(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.pink,
              ),
        ),
      ),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.progress,
    required this.current,
    required this.total,
    required this.onBack,
  });

  final double progress;
  final int current;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BackButton(onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x1AFFFFFF)),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(gradient: dateasyLimeGradient),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$current/$total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ],
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const goals = [
      'Знакомиться',
      'Ходить на встречи',
      'Найти отношения',
      'Создавать движ',
      'Спорт',
      'Камерные вечера',
    ];

    return Column(
      children: [
        for (final goal in goals) ...[
          _ChoiceTile(
            label: goal,
            active: selected.contains(goal),
            onTap: () => onToggle(goal),
          ),
          if (goal != goals.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _GenderStep extends StatelessWidget {
  const _GenderStep({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LargeChoiceButton(
            label: 'Мужской',
            active: selected == 'male',
            onTap: () => onChanged('male'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LargeChoiceButton(
            label: 'Женский',
            active: selected == 'female',
            onTap: () => onChanged('female'),
          ),
        ),
      ],
    );
  }
}

class _CityStep extends StatelessWidget {
  const _CityStep({
    required this.controller,
    required this.suggestions,
    required this.searching,
    required this.onChanged,
    required this.onSelectCity,
    required this.onSelect,
  });

  final TextEditingController controller;
  final List<CitySearchResult> suggestions;
  final bool searching;
  final ValueChanged<String> onChanged;
  final ValueChanged<RussianCity> onSelectCity;
  final ValueChanged<CitySearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    final cityMatches = cityMatchesFor(
      controller.text,
      cities: defaultRussianCities,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassInputShell(
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: DateasyColors.lime,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(
                    color: DateasyColors.foreground,
                    fontSize: 18,
                    height: 1.2,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (searching || cityMatches.isNotEmpty || suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GlassBox(
            borderRadius: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: searching && suggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Ищем место',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DateasyColors.muted,
                                    ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (final city in cityMatches)
                          _CityOptionTile(
                            city: city,
                            onTap: () => onSelectCity(city),
                          ),
                        for (final item in suggestions)
                          _CitySuggestionTile(
                            item: item,
                            onTap: () => onSelect(item),
                          ),
                      ],
                    ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final city in defaultRussianCities)
              _ChipButton(
                label: city.label,
                active: controller.text == city.label,
                onTap: () {
                  onSelectCity(city);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _CityOptionTile extends StatelessWidget {
  const _CityOptionTile({
    required this.city,
    required this.onTap,
  });

  final RussianCity city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.location_city_rounded,
              color: DateasyColors.lime,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.label,
                    style: const TextStyle(
                      color: DateasyColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Выбрать город',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitySuggestionTile extends StatelessWidget {
  const _CitySuggestionTile({
    required this.item,
    required this.onTap,
  });

  final CitySearchResult item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      item.area,
      item.source == CitySearchSource.yandex ? 'Yandex' : null,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.place_rounded,
              color: DateasyColors.lime,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: DateasyColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const interests = [
      '🎵 Музыка',
      '☕ Кофе',
      '🍷 Вино',
      '🏃 Спорт',
      '🎨 Арт',
      '🎬 Кино',
      '📚 Книги',
      '🍣 Еда',
      '🌃 Тусовки',
      '🎯 Тематические встречи',
      '🧘 Йога',
      '🎮 Игры',
      '✈️ Путешествия',
      '🎤 Караоке',
      '🎲 Настолки',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final interest in interests)
          _ChipButton(
            label: interest,
            active: selected.contains(interest),
            onTap: () => onToggle(interest),
          ),
      ],
    );
  }
}

class _VibeStep extends StatelessWidget {
  const _VibeStep({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const vibes = [
      ('Чилл', '🌿'),
      ('Движ', '🔥'),
      ('Романтик', '💌'),
      ('Авантюрист', '🚀'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.22,
      children: [
        for (final vibe in vibes)
          _VibeCard(
            label: vibe.$1,
            emoji: vibe.$2,
            active: selected == vibe.$1,
            onTap: () => onChanged(vibe.$1),
          ),
      ],
    );
  }
}

class _BirthdayStep extends StatelessWidget {
  const _BirthdayStep({
    required this.controller,
    required this.birthday,
    required this.onChanged,
    required this.onPick,
  });

  final TextEditingController controller;
  final DateTime? birthday;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassInputShell(
          child: Row(
            children: [
              const Icon(
                Icons.cake_rounded,
                color: DateasyColors.lime,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    _BirthdayTextInputFormatter(),
                  ],
                  style: const TextStyle(
                    color: DateasyColors.foreground,
                    fontSize: 18,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'ДД.ММ.ГГГГ',
                    hintStyle: TextStyle(
                      color: DateasyColors.muted.withValues(alpha: 0.72),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Выбрать дату',
                onPressed: onPick,
                icon: const Icon(
                  Icons.calendar_today_rounded,
                  color: DateasyColors.muted,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Например, 21.05.1998',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontSize: 11,
                ),
          ),
        ),
        if (birthday != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Возраст: '),
                  TextSpan(
                    text: '${_ageFor(birthday!)}',
                    style: const TextStyle(
                      color: DateasyColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' лет, видно другим'),
                ],
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  int _ageFor(DateTime date) {
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age -= 1;
    }
    return age;
  }
}

class _BioStep extends StatelessWidget {
  const _BioStep({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassInputShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.edit_note_rounded,
              color: DateasyColors.lime,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: DateasyColors.foreground,
                fontSize: 16,
                height: 1.35,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Люблю камерные встречи, кофе и прогулки.',
                hintStyle: TextStyle(
                  color: DateasyColors.muted.withValues(alpha: 0.72),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatBirthdayDigits(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatBirthdayDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
  if (limited.length <= 2) {
    return limited;
  }
  if (limited.length <= 4) {
    return '${limited.substring(0, 2)}.${limited.substring(2)}';
  }
  return '${limited.substring(0, 2)}.${limited.substring(2, 4)}.${limited.substring(4)}';
}

DateTime? _parseBirthdayInput(String value) {
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  final age = _ageForBirthDate(date);
  if (age < 18 || age > 100) {
    return null;
  }
  return date;
}

int _ageForBirthDate(DateTime date) {
  final now = DateTime.now();
  var age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age -= 1;
  }
  return age;
}

String _birthDateInputFromDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().padLeft(4, '0')}';
}

String _birthDateInputFromStored(String? value) {
  final date = _parseDate(value);
  return date == null ? '' : _birthDateInputFromDate(date);
}

String? _birthDateIsoFromInput(String value) {
  final date = _parseBirthdayInput(value.trim());
  if (date == null) {
    return null;
  }
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.photos,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
    required this.onMakePrimary,
  });

  final List<_OnboardingPhoto> photos;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<_OnboardingPhoto> onRemove;
  final ValueChanged<_OnboardingPhoto> onMakePrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final photo = index < photos.length ? photos[index] : null;
            if (photo == null) {
              return _AddPhotoSlot(
                first: photos.isEmpty && index == 0,
                loading: uploading && index == photos.length,
                enabled: photos.length < 6 && !uploading,
                onTap: onAdd,
              );
            }
            return _PhotoSlot(
              photo: photo,
              primary: index == 0,
              onTap: () => onMakePrimary(photo),
              onRemove: () => onRemove(photo),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Лица без масок и фильтров проходят верификацию быстрее.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.photo,
    required this.primary,
    required this.onTap,
    required this.onRemove,
  });

  final _OnboardingPhoto photo;
  final bool primary;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo.localPath.isNotEmpty && File(photo.localPath).existsSync()
                ? Image.file(File(photo.localPath), fit: BoxFit.cover)
                : DateasyRemoteImage(
                    imageUrl: photo.url,
                    usage: DateasyImageUsage.card,
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            if (primary)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: dateasyLimeGradient,
                  ),
                  child: Text(
                    'Главное',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.backgroundDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: DateasyColors.background.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoSlot extends StatelessWidget {
  const _AddPhotoSlot({
    required this.first,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final bool first;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: DateasyColors.glass,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  first ? Icons.photo_camera_outlined : Icons.add_rounded,
                  size: first ? 26 : 24,
                  color: DateasyColors.muted,
                ),
        ),
      ),
    );
  }
}

class _ContactStep extends StatelessWidget {
  const _ContactStep({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.onChanged,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassInputShell(
          child: Row(
            children: [
              const Icon(Icons.person_rounded,
                  color: DateasyColors.lime, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: nameController,
                  onChanged: (_) => onChanged(),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  style: const TextStyle(
                    color: DateasyColors.foreground,
                    fontSize: 18,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Ваше имя',
                    hintStyle: TextStyle(
                      color: DateasyColors.muted.withValues(alpha: 0.72),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassInputShell(
          child: Row(
            children: [
              const Icon(Icons.mail_rounded,
                  color: DateasyColors.lime, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: emailController,
                  onChanged: (_) => onChanged(),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(
                    color: DateasyColors.foreground,
                    fontSize: 18,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'you@frendly.app',
                    hintStyle: TextStyle(
                      color: DateasyColors.muted.withValues(alpha: 0.72),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassInputShell(
          child: Row(
            children: [
              const Icon(Icons.phone_rounded,
                  color: DateasyColors.lime, size: 20),
              const SizedBox(width: 12),
              const Text(
                '+7',
                style: TextStyle(
                  color: DateasyColors.foreground,
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 22,
                color: Colors.white24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  onChanged: (_) => onChanged(),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    PhoneNumberTextInputFormatter(),
                  ],
                  style: const TextStyle(
                    color: DateasyColors.foreground,
                    fontSize: 18,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: '999 000-00-00',
                    hintStyle: TextStyle(
                      color: DateasyColors.muted.withValues(alpha: 0.72),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Email и телефон не показываем в профиле. Используем только для входа, восстановления и SOS.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontSize: 11,
                ),
          ),
        ),
      ],
    );
  }
}

class _PermissionsStep extends ConsumerStatefulWidget {
  const _PermissionsStep();

  @override
  ConsumerState<_PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends ConsumerState<_PermissionsStep> {
  final Map<_OnboardingPermissionKind, _PermissionRequestState> _states = {
    for (final kind in _OnboardingPermissionKind.values)
      kind: _PermissionRequestState.idle,
  };
  final Map<_OnboardingPermissionKind, int> _generations = {
    for (final kind in _OnboardingPermissionKind.values) kind: 0,
  };

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        _OnboardingPermissionKind.location,
        Icons.location_on_rounded,
        'Геолокация',
        'Встречи и события рядом',
      ),
      (
        _OnboardingPermissionKind.push,
        Icons.notifications_rounded,
        'Уведомления',
        'Приглашения, лайки, чаты',
      ),
      (
        _OnboardingPermissionKind.contacts,
        Icons.groups_rounded,
        'Контакты',
        'Найти друзей в Frendly',
      ),
    ];

    return Column(
      children: [
        for (final item in items) ...[
          _PermissionTile(
            icon: item.$2,
            title: item.$3,
            subtitle: item.$4,
            status: _states[item.$1] ?? _PermissionRequestState.idle,
            onTap: () => _request(item.$1),
          ),
          if (item != items.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _request(_OnboardingPermissionKind kind) async {
    final service = ref.read(onboardingPermissionServiceProvider);
    final generation = (_generations[kind] ?? 0) + 1;
    _generations[kind] = generation;
    setState(() {
      _states[kind] = _PermissionRequestState.requesting;
    });

    final result = switch (kind) {
      _OnboardingPermissionKind.location => await service.requestLocation(),
      _OnboardingPermissionKind.push => await service.requestPush(),
      _OnboardingPermissionKind.contacts => await service.requestContacts(),
    };

    if (!mounted || _generations[kind] != generation) {
      return;
    }
    setState(() {
      _states[kind] = _stateFromRequestResult(result);
    });
  }
}

enum _OnboardingPermissionKind { location, push, contacts }

enum _PermissionRequestState {
  idle,
  requesting,
  granted,
  denied,
  permanentlyDenied,
  unavailable,
  error,
}

_PermissionRequestState _stateFromRequestResult(
  OnboardingPermissionRequestResult result,
) {
  return switch (result) {
    OnboardingPermissionRequestResult.granted =>
      _PermissionRequestState.granted,
    OnboardingPermissionRequestResult.denied => _PermissionRequestState.denied,
    OnboardingPermissionRequestResult.permanentlyDenied =>
      _PermissionRequestState.permanentlyDenied,
    OnboardingPermissionRequestResult.unavailable =>
      _PermissionRequestState.unavailable,
    OnboardingPermissionRequestResult.error => _PermissionRequestState.error,
  };
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _PermissionRequestState status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusText = _permissionStatusText(status);
    final buttonLabel = _permissionButtonLabel(status);
    return _GlassBox(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: DateasyColors.lime, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: DateasyColors.foreground,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
                  if (statusText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _permissionStatusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SmallGlassButton(label: buttonLabel, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

String _permissionButtonLabel(_PermissionRequestState status) {
  return switch (status) {
    _PermissionRequestState.requesting => 'Ждём',
    _PermissionRequestState.granted => 'Разрешено',
    _PermissionRequestState.permanentlyDenied => 'Открыть настройки',
    _PermissionRequestState.unavailable => 'Недоступно',
    _ => 'Разрешить',
  };
}

String? _permissionStatusText(_PermissionRequestState status) {
  return switch (status) {
    _PermissionRequestState.requesting => 'Ждём ответ системы',
    _PermissionRequestState.granted => 'Доступ есть',
    _PermissionRequestState.denied => 'Не разрешено',
    _PermissionRequestState.permanentlyDenied => 'Доступ выключен в настройках',
    _PermissionRequestState.unavailable => 'Недоступно на этом устройстве',
    _PermissionRequestState.error => 'Не получилось запросить доступ',
    _PermissionRequestState.idle => null,
  };
}

Color _permissionStatusColor(_PermissionRequestState status) {
  return switch (status) {
    _PermissionRequestState.granted => DateasyColors.lime,
    _PermissionRequestState.requesting => DateasyColors.muted,
    _PermissionRequestState.idle => DateasyColors.muted,
    _ => DateasyColors.pink,
  };
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableSurface(
      active: active,
      borderRadius: 16,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.foreground,
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeChoiceButton extends StatelessWidget {
  const _LargeChoiceButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableSurface(
      active: active,
      borderRadius: 16,
      onTap: onTap,
      child: SizedBox(
        height: 84,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.foreground,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.label,
    required this.emoji,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableSurface(
      active: active,
      borderRadius: 24,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30, height: 1)),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground,
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          decoration: BoxDecoration(
            gradient: active ? dateasyLimeGradient : null,
            color: active ? null : DateasyColors.glass,
            borderRadius: BorderRadius.circular(99),
            border: active
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: active ? _activeShadow : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.foreground,
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: enabled ? dateasyLimeGradient : null,
            color: enabled ? null : DateasyColors.glass.withValues(alpha: 0.52),
            boxShadow: enabled ? _activeShadow : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: enabled
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground.withValues(alpha: 0.38),
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallGlassButton extends StatelessWidget {
  const _SmallGlassButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          decoration: BoxDecoration(
            color: DateasyColors.glass,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: DateasyColors.foreground,
              fontSize: 14,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: DateasyColors.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Icon(
            Icons.chevron_left_rounded,
            size: 24,
            color: DateasyColors.foreground,
          ),
        ),
      ),
    );
  }
}

class _PressableSurface extends StatelessWidget {
  const _PressableSurface({
    required this.active,
    required this.borderRadius,
    required this.onTap,
    required this.child,
  });

  final bool active;
  final double borderRadius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: active ? dateasyLimeGradient : null,
            color: active ? null : DateasyColors.glass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: active
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: active ? _activeShadow : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassInputShell extends StatelessWidget {
  const _GlassInputShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _GlassBox(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: child,
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({
    required this.borderRadius,
    required this.child,
  });

  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

Set<String> _splitIntent(String? intent) {
  if (intent == null || intent.trim().isEmpty) {
    return <String>{};
  }
  return intent
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String? _emptyToNull(String value) {
  return value.isEmpty ? null : value;
}

String _phoneInputTextFromStored(String value) {
  final digits = PhoneNumberTextInputFormatter.digitsOnly(value);
  if (digits.length == 11 &&
      (digits.startsWith('7') || digits.startsWith('8'))) {
    return PhoneNumberTextInputFormatter.formatDigits(digits.substring(1));
  }
  if (digits.length >= 10) {
    return PhoneNumberTextInputFormatter.formatDigits(
      digits.substring(digits.length - 10),
    );
  }
  return PhoneNumberTextInputFormatter.formatDigits(digits);
}

String? _normalizedRussianPhoneNumber(String value) {
  final digits = PhoneNumberTextInputFormatter.digitsOnly(value);
  if (digits.isEmpty) {
    return null;
  }
  if (digits.length == 11 && digits.startsWith('7')) {
    return '+$digits';
  }
  if (digits.length == 11 && digits.startsWith('8')) {
    return '+7${digits.substring(1)}';
  }
  if (digits.length == 10) {
    return '+7$digits';
  }
  return value.trim();
}

List<_OnboardingPhoto> _profilePhotosFromOnboarding(
  OnboardingData onboarding,
) {
  final rawPhotos = onboarding.raw['photos'];
  if (rawPhotos is! List) {
    return const [];
  }
  final photos = <_OnboardingPhoto>[];
  for (final rawPhoto in rawPhotos) {
    final photo = _mapValue(rawPhoto);
    if (photo == null) {
      continue;
    }
    final id = photo['id']?.toString();
    if (id == null || id.isEmpty) {
      continue;
    }
    final url = _profilePhotoUrl(photo);
    photos.add(
      _OnboardingPhoto(
        id: id,
        localPath: '',
        url: url,
      ),
    );
  }
  return photos;
}

String? _profilePhotoUrl(Map<Object?, Object?> photo) {
  final direct = photo['url']?.toString();
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final media = _mapValue(photo['media']);
  final mediaUrl = media?['url']?.toString();
  return mediaUrl != null && mediaUrl.isNotEmpty ? mediaUrl : null;
}

Map<Object?, Object?>? _mapValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<Object?, Object?>();
  }
  return null;
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

class _OnboardingPhoto {
  const _OnboardingPhoto({
    required this.id,
    required this.localPath,
    this.url,
  });

  final String id;
  final String localPath;
  final String? url;
}

const _activeShadow = [
  BoxShadow(
    color: Color(0x59BEFF67),
    blurRadius: 60,
    spreadRadius: -20,
    offset: Offset(0, 20),
  ),
];
