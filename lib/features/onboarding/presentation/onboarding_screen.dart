import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/device/app_permission_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:big_break_mobile/shared/utils/location_label.dart';
import 'package:big_break_mobile/shared/widgets/bb_phone_number_field.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' show Point;

enum _OnboardingStep {
  profile,
  location,
  interests,
  vibe,
  birthday,
  contact,
  permissions,
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  String? intent;
  String? gender;
  String? birthDate;
  String city = 'Москва';
  String? area = 'Чистые пруды';
  String? email;
  String? phoneNumber;
  bool _geoPermissionDone = false;
  bool _notificationsPermissionDone = false;
  bool _contactsPermissionDone = false;
  final picked = <String>{};
  String? vibe;
  OnboardingContactRequirement? _requiredContact;
  late BbPhoneCountry _contactPhoneCountry = bbPhoneCountries.first;
  late final TextEditingController _emailController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _birthDayController;
  late final TextEditingController _birthMonthController;
  late final TextEditingController _birthYearController;
  Timer? _searchDebounce;
  bool _initializedFromBackend = false;
  bool _didTouchForm = false;
  bool _saving = false;
  bool _checkingContact = false;
  bool _resolvingLocation = false;
  bool _searchingLocationSuggestions = false;
  String? _contactError;
  List<ResolvedAddress> _locationSuggestions = const [];

  static const interests = [
    'Кофе',
    'Бары',
    'Бег',
    'Кино',
    'Музыка',
    'Настолки',
    'Йога',
    'Книги',
    'Выставки',
    'Велик',
    'Театр',
    'Готовка',
  ];

  static const cities = [
    'Москва',
    'Санкт-Петербург',
    'Тбилиси',
    'Ереван',
    'Белград',
  ];

  static const areas = [
    'Центр',
    'Чистые пруды',
    'Патрики',
    'Хамовники',
    'Сокол',
    'Замоскворечье',
  ];

  static const vibes = [
    ('calm', 'Спокойно', 'Камерные встречи, разговор'),
    ('active', 'Активно', 'Спорт, прогулки, движение'),
    ('social', 'Шумно', 'Бары, вечеринки, толпа'),
  ];

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _locationController =
        TextEditingController(text: _composeLocation(city, area));
    _birthDateController = TextEditingController();
    _birthDayController = TextEditingController();
    _birthMonthController = TextEditingController();
    _birthYearController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _emailController.dispose();
    _contactPhoneController.dispose();
    _locationController.dispose();
    _birthDateController.dispose();
    _birthDayController.dispose();
    _birthMonthController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  List<_OnboardingStep> get _steps {
    if (_requiredContact != null) {
      return const <_OnboardingStep>[
        _OnboardingStep.contact,
        _OnboardingStep.birthday,
        _OnboardingStep.profile,
        _OnboardingStep.location,
        _OnboardingStep.interests,
        _OnboardingStep.vibe,
        _OnboardingStep.permissions,
      ];
    }
    return const <_OnboardingStep>[
      _OnboardingStep.profile,
      _OnboardingStep.location,
      _OnboardingStep.interests,
      _OnboardingStep.vibe,
      _OnboardingStep.birthday,
      _OnboardingStep.contact,
      _OnboardingStep.permissions,
    ];
  }

  _OnboardingStep get _currentStep {
    final steps = _steps;
    final index = step >= steps.length ? steps.length - 1 : step;
    return steps[index];
  }

  bool get canContinue {
    switch (_currentStep) {
      case _OnboardingStep.profile:
        return intent != null && gender != null;
      case _OnboardingStep.location:
        return _locationController.text.trim().isNotEmpty ||
            (city.trim().isNotEmpty && area?.trim().isNotEmpty == true);
      case _OnboardingStep.interests:
        return picked.length >= 2;
      case _OnboardingStep.vibe:
        return vibe != null;
      case _OnboardingStep.birthday:
        return _birthDateIsoFromInput(_birthDateController.text) != null;
      case _OnboardingStep.contact:
        if (_requiredContact == OnboardingContactRequirement.phone) {
          return bbFullPhoneNumber(
                    _contactPhoneController.text,
                    _contactPhoneCountry,
                  ) !=
                  null &&
              !_checkingContact &&
              _contactError == null;
        }
        return _normalizedEmail(_emailController.text) != null &&
            !_checkingContact &&
            _contactError == null;
      case _OnboardingStep.permissions:
        return true;
    }
  }

  Future<void> next() async {
    if (_saving || _checkingContact) {
      return;
    }
    if (step < _steps.length - 1) {
      if (_currentStep == _OnboardingStep.contact &&
          !await _checkContactBeforeContinue()) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        step += 1;
      });
      return;
    }

    _save();
  }

  void previous() {
    if (_saving || _checkingContact || step == 0) {
      return;
    }
    setState(() {
      step -= 1;
    });
  }

  Future<bool> _checkContactBeforeContinue() async {
    final requirement = _requiredContact;
    if (requirement == null) {
      return true;
    }

    final email = _normalizedEmail(_emailController.text);
    final phoneNumber = bbFullPhoneNumber(
      _contactPhoneController.text,
      _contactPhoneCountry,
    );
    final repository = ref.read(backendRepositoryProvider);
    setState(() {
      _checkingContact = true;
      _contactError = null;
    });

    try {
      await repository.checkOnboardingContact(
        email: requirement == OnboardingContactRequirement.email ? email : null,
        phoneNumber: requirement == OnboardingContactRequirement.phone
            ? phoneNumber
            : null,
      );
      if (!mounted) {
        return false;
      }
      return true;
    } on DioException catch (error) {
      final message = _contactValidationMessage(error, requirement);
      if (mounted) {
        setState(() {
          _contactError = message;
        });
      }
      return false;
    } catch (_) {
      const message = 'Не получилось проверить контакт';
      if (mounted) {
        setState(() {
          _contactError = message;
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _checkingContact = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final repository = ref.read(backendRepositoryProvider);
    final onboardingLocalState =
        ref.read(onboardingLocalStateProvider.notifier);
    final rawCity =
        city.trim().isNotEmpty ? city.trim() : _locationController.text.trim();
    final normalizedCity = normalizeCityLabel(rawCity);
    final normalizedArea = normalizeAreaLabel(area, city: normalizedCity);
    setState(() {
      _saving = true;
    });
    try {
      final saved = await repository.saveOnboarding(
        OnboardingData(
          intent: intent,
          gender: gender,
          birthDate: _birthDateIsoFromInput(_birthDateController.text),
          city: normalizedCity.isNotEmpty ? normalizedCity : rawCity,
          area: normalizedArea,
          interests: picked.toList(growable: false),
          vibe: vibe,
          email: _normalizedEmail(_emailController.text) ?? email,
          phoneNumber: bbFullPhoneNumber(
                  _contactPhoneController.text, _contactPhoneCountry) ??
              phoneNumber,
        ),
      );
      if (!mounted) {
        return;
      }
      onboardingLocalState.state = saved;
      ref.invalidate(profileProvider);
      await _goToTonightAfterRouterRefresh();
    } catch (error) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_saveErrorMessage(error))),
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

  Future<void> _goToTonightAfterRouterRefresh() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future;
    if (!mounted || !context.mounted) {
      return;
    }
    context.goRoute(AppRoute.tonight);
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider).valueOrNull;
    if (onboarding != null && !_initializedFromBackend && !_didTouchForm) {
      _initializedFromBackend = true;
      intent = onboarding.intent;
      gender = onboarding.gender;
      birthDate = onboarding.birthDate;
      city =
          onboarding.city?.trim().isNotEmpty == true ? onboarding.city! : city;
      area =
          onboarding.area?.trim().isNotEmpty == true ? onboarding.area : area;
      email = onboarding.email;
      phoneNumber = onboarding.phoneNumber;
      _requiredContact = onboarding.requiredContact;
      _emailController.text = onboarding.email ?? '';
      _contactPhoneCountry = bbCountryForPhoneNumber(onboarding.phoneNumber);
      _contactPhoneController.text = _contactPhoneCountry.formatDigits(
        bbLocalDigitsForPhoneNumber(
          onboarding.phoneNumber,
          _contactPhoneCountry,
        ),
      );
      _birthDateController.text =
          _formatBirthDateForInput(onboarding.birthDate);
      _syncBirthPartControllers(_birthDateController.text);
      _locationController.text =
          _composeLocation(onboarding.city, onboarding.area);
      picked
        ..clear()
        ..addAll(onboarding.interests);
      vibe = onboarding.vibe;
    }

    final steps = _steps;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: BbV5Scaffold(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _OnboardingFrame(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                child: Row(
                  children: [
                    if (step > 0) ...[
                      BbV5IconButton(
                        key: const Key('onboarding-back-button'),
                        icon: Icons.arrow_back_rounded,
                        onPressed: previous,
                        size: 40,
                        iconSize: 18,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Row(
                        children: List.generate(
                          steps.length,
                          (index) => Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              height: 4,
                              margin: EdgeInsets.only(
                                right: index == steps.length - 1 ? 0 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: index <= step
                                    ? BbV5Colors.ink
                                    : BbV5Colors.ink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _OnboardingFrame(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildStep(context),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      BbV5Colors.paper.withValues(alpha: 0),
                      BbV5Colors.paper.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: _OnboardingFrame(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: BbV5PillButton(
                      label: _actionButtonLabel(steps.length),
                      icon: _saving || _checkingContact
                          ? Icons.hourglass_top_rounded
                          : Icons.arrow_forward_rounded,
                      dark: true,
                      height: 56,
                      expanded: true,
                      fontSize: 14,
                      onPressed: canContinue && !_saving ? next : null,
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

  Widget _buildStepHeading(String title, String subtitle) {
    final words = title.trim().split(RegExp(r'\s+'));
    final accent = words.length <= 1 ? null : words.last;
    final lead =
        words.length <= 1 ? title : words.take(words.length - 1).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5Kicker('Шаг ${step + 1} из ${_steps.length}'),
        const SizedBox(height: 6),
        _OnboardingTitle(
          title: lead,
          accent: accent,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTextStyles.bodySoft.copyWith(
            fontSize: 13,
            color: BbV5Colors.inkSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context) {
    final colors = AppColors.of(context);
    switch (_currentStep) {
      case _OnboardingStep.profile:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeading(
              'Зачем ты здесь?',
              'Это можно поменять позже.',
            ),
            const SizedBox(height: 24),
            const BbV5Kicker('Пол'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _GenderChoice(
                    key: const Key('onboarding-gender-male'),
                    active: gender == 'male',
                    label: 'М',
                    onTap: () => setState(() {
                      _didTouchForm = true;
                      gender = 'male';
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderChoice(
                    key: const Key('onboarding-gender-female'),
                    active: gender == 'female',
                    label: 'Ж',
                    onTap: () => setState(() {
                      _didTouchForm = true;
                      gender = 'female';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const BbV5Kicker('Цель'),
            const SizedBox(height: 8),
            _ChoiceCard(
              active: intent == 'dating',
              icon: Icons.favorite_border_rounded,
              title: 'Свидания',
              subtitle: 'Знакомства один на один',
              onTap: () => setState(() {
                _didTouchForm = true;
                intent = 'dating';
              }),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              active: intent == 'friendship',
              icon: Icons.groups_rounded,
              title: 'Друзья',
              subtitle: 'Новые люди и компании',
              onTap: () => setState(() {
                _didTouchForm = true;
                intent = 'friendship';
              }),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              active: intent == 'both',
              icon: Icons.auto_awesome_outlined,
              title: 'И то и другое',
              subtitle: 'Открыт ко всему',
              onTap: () => setState(() {
                _didTouchForm = true;
                intent = 'both';
              }),
            ),
          ],
        );
      case _OnboardingStep.location:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeading(
              'Где ты?',
              'Покажем встречи рядом с тобой.',
            ),
            const SizedBox(height: 24),
            const BbV5Kicker('Город'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cities
                  .map(
                    (item) => _PillButton(
                      active: city == item,
                      label: item,
                      onTap: () => _selectCity(item),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 20),
            const BbV5Kicker('Район'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: areas
                  .map(
                    (item) => _PillButton(
                      active: area == item,
                      label: item,
                      onTap: () => _selectArea(item),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 24),
            const BbV5Kicker('Адрес вручную'),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: _handleLocationChanged,
              decoration: InputDecoration(
                hintText: 'Например, Покровка 17',
                filled: true,
                fillColor: BbV5Colors.paperHi,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: BbV5Colors.hair),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: BbV5Colors.hair),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: BbV5Colors.ink),
                ),
              ),
              style: AppTextStyles.body.copyWith(color: BbV5Colors.ink),
            ),
            if (_searchingLocationSuggestions ||
                _locationSuggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    if (_searchingLocationSuggestions &&
                        _locationSuggestions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Ищем адрес в Яндекс Картах',
                                style: AppTextStyles.meta.copyWith(
                                  color: colors.inkMute,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._locationSuggestions.map(
                        (item) => InkWell(
                          onTap: () => _applyLocationSuggestion(item),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colors.primarySoft,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.place_outlined,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.address,
                                        style: AppTextStyles.meta.copyWith(
                                          color: colors.inkMute,
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
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resolvingLocation ? null : _resolveLocation,
                icon: _resolvingLocation
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.foreground,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(
                  _resolvingLocation
                      ? 'Определяем локацию'
                      : 'Определить по гео',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.foreground,
                  side: BorderSide(color: colors.border),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            if (area != null && area!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Определили: $area',
                style: AppTextStyles.meta.copyWith(color: colors.inkMute),
              ),
            ],
            if (_locationController.text.trim().isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ничего не выбрано, пока ты сам не укажешь место.',
                style: AppTextStyles.meta.copyWith(color: colors.inkMute),
              ),
            ],
          ],
        );
      case _OnboardingStep.interests:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeading(
              'Что тебе нравится?',
              'Выбери от двух интересов. Без них сложнее найти своих.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interests
                  .map(
                    (item) => _PillButton(
                      active: picked.contains(item),
                      label: item,
                      activeBackground: colors.primarySoft,
                      activeForeground: colors.primary,
                      activeBorder: colors.primary,
                      onTap: () {
                        setState(() {
                          _didTouchForm = true;
                          if (picked.contains(item)) {
                            picked.remove(item);
                          } else {
                            picked.add(item);
                          }
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        );
      case _OnboardingStep.vibe:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeading(
              'Какой вечер ближе?',
              'Подберём встречи под твоё настроение.',
            ),
            const SizedBox(height: 24),
            for (final item in vibes) ...[
              _ChoiceCard(
                active: vibe == item.$1,
                icon: null,
                title: item.$2,
                subtitle: item.$3,
                subtitleFontSize: 12.5,
                subtitleTopSpacing: 4,
                onTap: () => setState(() {
                  _didTouchForm = true;
                  vibe = item.$1;
                }),
              ),
              if (item != vibes.last) const SizedBox(height: 12),
            ],
          ],
        );
      case _OnboardingStep.birthday:
        return _buildBirthdayStep();
      case _OnboardingStep.contact:
        return _buildContactStep(context);
      case _OnboardingStep.permissions:
        return _buildPermissionsStep();
    }
  }

  Widget _buildBirthdayStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading(
          'Когда у тебя день рождения?',
          'Покажем встречи 18+ корректно. Дату не публикуем.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BbV5Colors.hair),
              ),
              child: const Icon(
                Icons.cake_outlined,
                color: BbV5Colors.terra,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Дата нужна для возрастных встреч и подсказок. В профиле она не видна.',
                style: AppTextStyles.meta.copyWith(
                  color: BbV5Colors.inkSoft,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _BirthPartField(
                label: 'День',
                hint: 'ДД',
                maxLength: 2,
                controller: _birthDayController,
                onChanged: (_) => _handleBirthPartsChanged(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BirthPartField(
                label: 'Месяц',
                hint: 'ММ',
                maxLength: 2,
                controller: _birthMonthController,
                onChanged: (_) => _handleBirthPartsChanged(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BirthPartField(
                label: 'Год',
                hint: 'ГГГГ',
                maxLength: 4,
                controller: _birthYearController,
                onChanged: (_) => _handleBirthPartsChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const Key('onboarding-birth-date-picker'),
          onPressed: _showBirthDatePicker,
          child: Text(
            'Выбрать в календаре',
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.terra,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading(
          'Несколько разрешений',
          'Без них Frendly работает, но хуже подбирает.',
        ),
        const SizedBox(height: 24),
        _PermissionCard(
          icon: Icons.place_outlined,
          title: 'Геолокация',
          subtitle: 'Покажем встречи и людей рядом.',
          color: BbV5Colors.terra,
          done: _geoPermissionDone,
          onTap: () => _requestPermission(
            type: _PermissionType.geo,
            request: ref.read(appPermissionServiceProvider).requestLocation,
          ),
        ),
        const SizedBox(height: 12),
        _PermissionCard(
          icon: Icons.notifications_none_rounded,
          title: 'Уведомления',
          subtitle: 'Сообщения в чате и подтверждения встреч.',
          color: BbV5Colors.gold,
          done: _notificationsPermissionDone,
          onTap: () => _requestPermission(
            type: _PermissionType.notifications,
            request:
                ref.read(appPermissionServiceProvider).requestNotifications,
          ),
        ),
        const SizedBox(height: 12),
        _PermissionCard(
          icon: Icons.contacts_outlined,
          title: 'Контакты',
          subtitle: 'Покажем, кто из друзей уже в Frendly.',
          color: BbV5Colors.brand,
          done: _contactsPermissionDone,
          onTap: () => _requestPermission(
            type: _PermissionType.contacts,
            request: ref.read(appPermissionServiceProvider).requestContacts,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: _save,
            child: Text(
              'Пропустить и настроить позже',
              style: AppTextStyles.meta.copyWith(
                color: BbV5Colors.inkMute,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactStep(BuildContext context) {
    final colors = AppColors.of(context);
    final requirement = _requiredContact;
    if (requirement == OnboardingContactRequirement.phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeading(
            'Укажи телефон',
            'Телефон нужен для входа и восстановления доступа.',
          ),
          const SizedBox(height: 24),
          BbPhoneNumberField(
            fieldKey: const Key('onboarding-phone-field'),
            controller: _contactPhoneController,
            country: _contactPhoneCountry,
            onCountryTap: _pickContactCountry,
            onChanged: _handleContactPhoneChanged,
          ),
          const SizedBox(height: 12),
          Text(
            'Номер не показываем другим людям.',
            style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
          ),
          if (_contactError != null) ...[
            const SizedBox(height: 8),
            Text(
              _contactError!,
              style: AppTextStyles.meta.copyWith(color: colors.destructive),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading(
          'Укажи email',
          'Только для уведомлений и восстановления доступа.',
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('onboarding-email-field'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onChanged: (value) {
            setState(() {
              _didTouchForm = true;
              _contactError = null;
              email = value.trim();
            });
          },
          decoration: InputDecoration(
            hintText: 'name@example.com',
            filled: true,
            fillColor: BbV5Colors.paperHi,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: BbV5Colors.hair),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: BbV5Colors.hair),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: BbV5Colors.ink),
            ),
          ),
          style: AppTextStyles.body.copyWith(
            fontFamily: 'Sora',
            color: BbV5Colors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Почту не показываем другим людям.',
          style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
        ),
        if (_contactError != null) ...[
          const SizedBox(height: 8),
          Text(
            _contactError!,
            style: AppTextStyles.meta.copyWith(color: colors.destructive),
          ),
        ],
      ],
    );
  }

  void _handleContactPhoneChanged(String value) {
    final formatted = bbFormatPhoneInput(value, _contactPhoneCountry);

    if (_contactPhoneController.text != formatted) {
      _contactPhoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    setState(() {
      _didTouchForm = true;
      _contactError = null;
      phoneNumber = bbFullPhoneNumber(
        _contactPhoneController.text,
        _contactPhoneCountry,
      );
    });
  }

  Future<void> _pickContactCountry() async {
    final next = await showBbPhoneCountryPicker(
      context: context,
      selected: _contactPhoneCountry,
    );

    if (next == null || !mounted || next == _contactPhoneCountry) {
      return;
    }

    final digitsOnly = bbPhoneDigits(_contactPhoneController.text);
    final truncated = digitsOnly.length > next.localLength
        ? digitsOnly.substring(0, next.localLength)
        : digitsOnly;

    setState(() {
      _didTouchForm = true;
      _contactError = null;
      _contactPhoneCountry = next;
      _contactPhoneController.text = next.formatDigits(truncated);
      phoneNumber = bbFullPhoneNumber(_contactPhoneController.text, next);
    });
  }

  String? _normalizedEmail(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailPattern.hasMatch(normalized) ? normalized : null;
  }

  String _contactValidationMessage(
    DioException error,
    OnboardingContactRequirement requirement,
  ) {
    final code = _apiErrorCode(error);
    if (code == 'contact_already_used') {
      return requirement == OnboardingContactRequirement.email
          ? 'Эта почта уже привязана к другому аккаунту'
          : 'Этот телефон уже привязан к другому аккаунту';
    }
    if (code == 'invalid_email') {
      return 'Проверь почту';
    }
    if (code == 'invalid_phone_number') {
      return 'Проверь телефон';
    }
    return 'Не получилось проверить контакт';
  }

  String _saveErrorMessage(Object error) {
    if (error is DioException) {
      final code = _apiErrorCode(error);
      if (code == 'contact_already_used') {
        return _requiredContact == OnboardingContactRequirement.phone
            ? 'Этот телефон уже привязан к другому аккаунту'
            : 'Эта почта уже привязана к другому аккаунту';
      }
      if (code == 'required_email') {
        return 'Укажи почту';
      }
      if (code == 'required_phone_number') {
        return 'Укажи телефон';
      }
      if (code == 'invalid_birth_date') {
        return 'Проверь дату рождения';
      }
    }
    return 'Не получилось сохранить onboarding';
  }

  String? _apiErrorCode(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final code = data['code'];
      if (code is String) {
        return code;
      }
    }
    return null;
  }

  String _actionButtonLabel(int stepsLength) {
    if (_saving) {
      return 'Сохраняем';
    }
    if (_checkingContact) {
      return 'Проверяем';
    }
    return step < stepsLength - 1 ? 'Дальше' : 'Войти в Frendly';
  }

  Future<void> _resolveLocation() async {
    final locationService = ref.read(appLocationServiceProvider);
    final mapService = ref.read(yandexMapServiceProvider);
    setState(() {
      _resolvingLocation = true;
    });

    try {
      final position = await locationService.getCurrentPosition();
      if (!mounted) {
        return;
      }
      if (position == null) {
        _showHint('Не получилось определить гео');
        return;
      }

      final resolved = await mapService.reverseGeocode(
        Point(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      final location = resolved?.address ??
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      final normalizedCity = normalizeCityLabel(location);
      if (!mounted) {
        return;
      }
      setState(() {
        _didTouchForm = true;
        city = normalizedCity.isNotEmpty ? normalizedCity : location;
        area = normalizeAreaLabel(
          resolved?.name,
          city: normalizedCity,
        );
        _locationController.text = location;
        _locationSuggestions = const [];
        _searchingLocationSuggestions = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _resolvingLocation = false;
        });
      }
    }
  }

  String _composeLocation(String? nextCity, String? nextArea) {
    final parts = [nextCity, nextArea]
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return parts.join(', ');
  }

  void _selectCity(String value) {
    setState(() {
      _didTouchForm = true;
      city = value;
      area ??= areas.first;
      _locationController.text = _composeLocation(city, area);
      _locationSuggestions = const [];
      _searchingLocationSuggestions = false;
    });
  }

  void _selectArea(String value) {
    setState(() {
      _didTouchForm = true;
      area = value;
      if (city.trim().isEmpty) {
        city = cities.first;
      }
      _locationController.text = _composeLocation(city, area);
      _locationSuggestions = const [];
      _searchingLocationSuggestions = false;
    });
  }

  void _handleLocationChanged(String value) {
    setState(() {
      _didTouchForm = true;
      city = value.trim();
      area = null;
    });
    _queueLocationSearch(value);
  }

  Future<void> _showBirthDatePicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showBirthDateSheet(
      context,
      initialValue: _birthDateFromIso(birthDate) ?? _defaultBirthDate(),
      firstDate: _birthDateYearsAgo(100),
      lastDate: _birthDateYearsAgo(18),
    );
    if (selected == null || !mounted) {
      return;
    }

    final iso = _birthDateIsoFromDate(selected);
    setState(() {
      _didTouchForm = true;
      birthDate = iso;
      _birthDateController.text = _formatBirthDateForInput(iso);
      _syncBirthPartControllers(_birthDateController.text);
    });
  }

  void _handleBirthPartsChanged() {
    final day = _birthDayController.text.replaceAll(RegExp(r'\D'), '');
    final month = _birthMonthController.text.replaceAll(RegExp(r'\D'), '');
    final year = _birthYearController.text.replaceAll(RegExp(r'\D'), '');
    final nextValue = [day, month, year].join('.');
    setState(() {
      _didTouchForm = true;
      _birthDateController.text = nextValue;
      birthDate = _birthDateIsoFromInput(nextValue);
    });
  }

  void _syncBirthPartControllers(String value) {
    final parts = value.split('.');
    if (parts.length != 3) {
      return;
    }
    _birthDayController.text = parts[0];
    _birthMonthController.text = parts[1];
    _birthYearController.text = parts[2];
  }

  Future<void> _requestPermission({
    required _PermissionType type,
    required Future<bool> Function() request,
  }) async {
    try {
      await request();
    } catch (_) {
      // The onboarding step should not block if the OS dialog fails.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      switch (type) {
        case _PermissionType.geo:
          _geoPermissionDone = true;
          break;
        case _PermissionType.notifications:
          _notificationsPermissionDone = true;
          break;
        case _PermissionType.contacts:
          _contactsPermissionDone = true;
          break;
      }
    });
  }

  String _formatBirthDateForInput(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    final parts = value.split('-');
    if (parts.length != 3) {
      return value;
    }
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  DateTime? _birthDateFromIso(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parts = value.split('-');
    if (parts.length != 3) {
      return null;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  DateTime _defaultBirthDate() {
    return _birthDateYearsAgo(25);
  }

  DateTime _birthDateYearsAgo(int years) {
    final now = DateTime.now();
    final year = now.year - years;
    final lastDayOfMonth = DateTime(year, now.month + 1, 0).day;
    final day = now.day > lastDayOfMonth ? lastDayOfMonth : now.day;
    return DateTime(year, now.month, day);
  }

  String _birthDateIsoFromDate(DateTime date) {
    final monthText = date.month.toString().padLeft(2, '0');
    final dayText = date.day.toString().padLeft(2, '0');
    return '${date.year}-$monthText-$dayText';
  }

  String? _birthDateIsoFromInput(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }

    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    final now = DateTime.now().toUtc();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age -= 1;
    }
    if (age < 18 || age > 100) {
      return null;
    }

    final monthText = month.toString().padLeft(2, '0');
    final dayText = day.toString().padLeft(2, '0');
    return '$year-$monthText-$dayText';
  }

  void _queueLocationSearch(String value) {
    final trimmed = value.trim();
    _searchDebounce?.cancel();

    if (trimmed.length < 3) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchingLocationSuggestions = false;
        _locationSuggestions = const [];
      });
      return;
    }

    setState(() {
      _searchingLocationSuggestions = true;
    });

    final mapService = ref.read(yandexMapServiceProvider);
    late final Timer searchTimer;
    searchTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || !identical(_searchDebounce, searchTimer)) {
        return;
      }

      List<ResolvedAddress> resolved;
      try {
        resolved = await mapService.searchPlaces(trimmed);
      } catch (_) {
        if (mounted &&
            identical(_searchDebounce, searchTimer) &&
            _locationController.text.trim() == trimmed) {
          setState(() {
            _searchingLocationSuggestions = false;
            _locationSuggestions = const [];
          });
        }
        return;
      }

      if (!mounted ||
          !identical(_searchDebounce, searchTimer) ||
          _locationController.text.trim() != trimmed) {
        return;
      }

      setState(() {
        _searchingLocationSuggestions = false;
        _locationSuggestions = resolved;
      });
    });
    _searchDebounce = searchTimer;
  }

  void _applyLocationSuggestion(ResolvedAddress suggestion) {
    final normalizedCity = normalizeCityLabel(suggestion.address);
    setState(() {
      _didTouchForm = true;
      city = normalizedCity.isNotEmpty
          ? normalizedCity
          : suggestion.address.trim();
      area = normalizeAreaLabel(
        suggestion.name.trim().isEmpty ? null : suggestion.name.trim(),
        city: normalizedCity,
      );
      _locationController.text = suggestion.name;
      _locationSuggestions = const [];
      _searchingLocationSuggestions = false;
    });
  }

  void _showHint(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

Future<DateTime?> showBirthDateSheet(
  BuildContext context, {
  required DateTime initialValue,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BirthDateSheet(
      initialValue: initialValue,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

enum _PermissionType {
  geo,
  notifications,
  contacts,
}

class _OnboardingFrame extends StatelessWidget {
  const _OnboardingFrame({
    required this.child,
    required this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: AppTextStyles.body.copyWith(color: BbV5Colors.ink),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _OnboardingTitle extends StatelessWidget {
  const _OnboardingTitle({
    required this.title,
    required this.accent,
  });

  final String title;
  final String? accent;

  @override
  Widget build(BuildContext context) {
    final base = bbV5DisplayStyle(fontSize: 26, height: 1.1);
    final accentText = accent;
    if (accentText == null || accentText.isEmpty) {
      return Text(title, style: base);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: title),
          const TextSpan(text: ' '),
          TextSpan(
            text: accentText,
            style: base.copyWith(
              fontFamily: 'InstrumentSerif',
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}

class _BirthPartField extends StatelessWidget {
  const _BirthPartField({
    required this.label,
    required this.hint,
    required this.maxLength,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final int maxLength;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: bbV5KickerStyle(letterSpacing: 1.6),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textInputAction:
                maxLength == 4 ? TextInputAction.done : TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxLength),
            ],
            textAlign: TextAlign.center,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              filled: true,
              fillColor: BbV5Colors.paperHi,
              contentPadding: const EdgeInsets.symmetric(vertical: 17),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: BbV5Colors.hair),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: BbV5Colors.hair),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: BbV5Colors.ink),
              ),
            ),
            style: bbV5DisplayStyle(fontSize: 16, height: 1).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: BbV5Colors.inkMute,
                    height: 1.375,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BbV5PillButton(
            label: done ? 'Готово' : 'Разрешить',
            icon: done ? Icons.check_rounded : null,
            dark: !done,
            height: 36,
            fontSize: 11.5,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: done ? null : onTap,
          ),
        ],
      ),
    );
  }
}

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({
    required this.initialValue,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialValue;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  late DateTime _date = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      'Дата рождения',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.itemTitle.copyWith(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: AppRadii.cardBorder,
                        border: Border.all(color: colors.border),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: colors.primary,
                            onPrimary: colors.primaryForeground,
                            surface: colors.card,
                            onSurface: colors.foreground,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: _date,
                          firstDate: widget.firstDate,
                          lastDate: widget.lastDate,
                          initialCalendarMode: DatePickerMode.year,
                          onDateChanged: (value) {
                            setState(() => _date = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _formatDate(_date),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        key: const Key('birth-date-sheet-submit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(_date),
                        child: Text(
                          'Выбрать',
                          style: AppTextStyles.button.copyWith(
                            color: colors.primaryForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

class _GenderChoice extends StatelessWidget {
  const _GenderChoice({
    required this.active,
    required this.label,
    required this.onTap,
    super.key,
  });

  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BbV5Colors.paperHi, BbV5Colors.paper],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? BbV5Colors.ink : BbV5Colors.hair,
              width: active ? 2 : 1,
            ),
            boxShadow: BbV5Shadows.card,
          ),
          child: Text(
            label,
            style: bbV5DisplayStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: BbV5Colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleFontSize = 12,
    this.subtitleTopSpacing = 2,
  });

  final bool active;
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double subtitleFontSize;
  final double subtitleTopSpacing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BbV5Colors.paperHi, BbV5Colors.paper],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? BbV5Colors.ink : BbV5Colors.hair,
              width: active ? 2 : 1,
            ),
            boxShadow: BbV5Shadows.card,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: active ? BbV5Colors.ink : BbV5Colors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BbV5Colors.hair),
                  ),
                  child: Icon(
                    icon,
                    color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.itemTitle.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BbV5Colors.ink,
                      ),
                    ),
                    SizedBox(height: subtitleTopSpacing),
                    Text(
                      subtitle,
                      style: AppTextStyles.meta.copyWith(
                        fontSize: subtitleFontSize,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                const Icon(
                  Icons.check_rounded,
                  color: BbV5Colors.ink,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.active,
    required this.label,
    required this.onTap,
    this.activeBackground,
    this.activeForeground,
    this.activeBorder,
  });

  final bool active;
  final String label;
  final VoidCallback onTap;
  final Color? activeBackground;
  final Color? activeForeground;
  final Color? activeBorder;

  @override
  Widget build(BuildContext context) {
    return BbV5Chip(
      label: label,
      active: active,
      onTap: onTap,
    );
  }
}
