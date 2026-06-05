import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/meetings/application/new_meeting_payload.dart';
import 'package:mobile2/features/meetings/presentation/meeting_boost.dart';
import 'package:mobile2/shared/data/affiche_client_geo_enrichment_service.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

class NewMeetingScreen extends StatefulWidget {
  const NewMeetingScreen({
    super.key,
    this.editEventId,
    this.afficheEventId,
    this.inviteeUserId,
    this.sourceChatId,
    this.communityId,
    this.routeId,
  });

  final String? editEventId;
  final String? afficheEventId;
  final String? inviteeUserId;
  final String? sourceChatId;
  final String? communityId;
  final String? routeId;

  @override
  State<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends State<NewMeetingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _vibe = 'Кофе';
  String _place = '';
  String _address = '';
  String? _coverPath;
  String? _coverFileName;
  String? _coverImageUrl;
  double? _latitude;
  double? _longitude;
  int _capacity = 6;
  String _gender = 'any';
  String _joinPolicy = 'open';
  bool _verifiedOnly = false;
  bool _plusOnly = false;
  String _visibility = 'public';
  String? _coverAssetId;
  MeetingBoostTier? _boostTier;
  _AttachItem? _attached;
  bool _publishing = false;
  bool _loadingInitialHostEvent = false;
  bool _loadingInitialAffiche = false;
  bool _loadingInitialRoute = false;
  final _createIdempotency = NewMeetingCreateIdempotency();
  CancelToken? _afficheGeoCancelToken;
  Future<AfficheClientGeoResult?>? _afficheGeoFuture;

  bool get _isEditing => widget.editEventId?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    final editEventId = widget.editEventId?.trim();
    if (editEventId != null && editEventId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadInitialHostEvent(editEventId));
        }
      });
      return;
    }
    final eventId = widget.afficheEventId?.trim();
    if (eventId != null && eventId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadInitialAffiche(eventId));
        }
      });
      return;
    }
    _applyDefaultStartsAt();
    final routeId = widget.routeId?.trim();
    if (routeId != null && routeId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadInitialRoute(routeId));
        }
      });
    }
  }

  void _applyDefaultStartsAt() {
    final startsAt = _defaultMeetingStart();
    if (_dateController.text.trim().isEmpty) {
      _dateController.text = _formatDateInput(startsAt);
    }
    if (_timeController.text.trim().isEmpty) {
      _timeController.text = _formatTimeInput(startsAt);
    }
  }

  @override
  void dispose() {
    _afficheGeoCancelToken?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: Stack(
        children: [
          ListView(
            key: PageStorageKey<String>(
              [
                'new-meeting',
                widget.communityId ?? '',
                widget.editEventId ?? '',
                widget.afficheEventId ?? '',
                widget.routeId ?? '',
              ].join(':'),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 16,
              bottom: 168,
            ),
            children: [
              _Header(
                title: _isEditing ? 'Редактировать встречу' : 'Новая встреча',
                onBack: () => context.go('/meetings'),
              ),
              const SizedBox(height: 20),
              _CoverPicker(
                coverPath: _coverPath,
                coverImageUrl: _coverImageUrl,
                onPick: _pickCover,
              ),
              const SizedBox(height: 20),
              _TitleBlock(
                titleController: _titleController,
                descriptionController: _descriptionController,
              ),
              const SizedBox(height: 22),
              _VibePills(
                active: _vibe,
                onChanged: (value) => setState(() => _vibe = value),
              ),
              const SizedBox(height: 18),
              _FieldsBlock(
                dateController: _dateController,
                timeController: _timeController,
                place: _place,
                address: _address,
                capacity: _capacity,
                onDate: _pickDate,
                onTime: _pickTime,
                onPlace: () => _openSheet(_SheetKind.place),
                onMinus: () => setState(() {
                  _capacity = (_capacity - 1).clamp(2, 50);
                }),
                onPlus: () => setState(() {
                  _capacity = (_capacity + 1).clamp(2, 50);
                }),
              ),
              const SizedBox(height: 22),
              _AttachBlock(
                attached: _attached,
                loading: _loadingInitialHostEvent ||
                    _loadingInitialAffiche ||
                    _loadingInitialRoute,
                onOpen: _openSheet,
                onClear: _clearAttachment,
              ),
              const SizedBox(height: 22),
              _AudienceBlock(
                gender: _gender,
                verifiedOnly: _verifiedOnly,
                plusOnly: _plusOnly,
                onGender: (value) => setState(() => _gender = value),
                onVerified: _toggleVerifiedOnly,
                onPlus: _togglePlusOnly,
              ),
              const SizedBox(height: 22),
              _VisibilityBlock(
                visibility: _visibility,
                onChanged: (value) => setState(() => _visibility = value),
              ),
              const SizedBox(height: 22),
              _JoinPolicyBlock(
                joinPolicy: _joinPolicy,
                onChanged: (value) => setState(() => _joinPolicy = value),
              ),
              const SizedBox(height: 20),
              _BoostTierGrid(
                selected: _boostTier,
                onChanged: (tier) => setState(() {
                  _boostTier =
                      _boostTier?.optionId == tier.optionId ? null : tier;
                }),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _GradientButton(
                      label: _publishing
                          ? 'Публикуем'
                          : _isEditing
                              ? 'Сохранить изменения'
                              : 'Опубликовать встречу${_boostTier == null ? '' : ' · −${_boostTier!.price} FT'}',
                      onTap: _publishing ? null : _publishMeeting,
                    ),
                    const SizedBox(height: 10),
                    Consumer(
                      builder: (context, ref, _) {
                        final balance = ref
                                .watch(tokenWalletProvider)
                                .valueOrNull
                                ?.balance ??
                            0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Баланс: $balance FT · ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: DateasyColors.muted,
                                    fontSize: 11,
                                  ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/wallet'),
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: DateasyColors.lime,
                              ),
                              child: Text(
                                'пополнить',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: DateasyColors.lime,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const DateasyBottomNav(),
        ],
      ),
    );
  }

  Future<void> _loadInitialHostEvent(String eventId) async {
    setState(() => _loadingInitialHostEvent = true);
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final event = await container
          .read(meetingActionsProvider)
          .fetchHostedEvent(eventId);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyHostedEvent(event);
        _loadingInitialHostEvent = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingInitialHostEvent = false);
      _showNotice('Не удалось загрузить встречу');
    }
  }

  void _applyHostedEvent(BackendCardItem event) {
    _titleController.text = event.title;
    final description = _stringValue(event.raw['description']);
    _descriptionController.text =
        description.isNotEmpty ? description : event.subtitle ?? '';
    final startsAt = event.startsAt;
    if (startsAt != null) {
      _dateController.text = _formatDateInput(startsAt);
      _timeController.text = _formatTimeInput(startsAt);
    }

    _place = _stringValue(event.raw['place']);
    _address = _stringValue(event.raw['address']);
    _latitude = _doubleValue(event.raw['latitude']);
    _longitude = _doubleValue(event.raw['longitude']);
    if (_place.isEmpty && event.city?.isNotEmpty == true) {
      _place = event.city!;
    }

    final capacity = _intValue(event.raw['capacity']);
    if (capacity != null) {
      _capacity = capacity.clamp(2, 50);
    }

    final genderMode = _stringValue(event.raw['genderMode']);
    _gender = switch (genderMode) {
      'male' => 'male',
      'female' => 'female',
      _ => 'any',
    };
    final vibe = _stringValue(event.raw['vibe']);
    if (vibe.isNotEmpty) {
      _vibe = vibe;
    }
    final joinMode = _stringValue(event.raw['joinMode']);
    final accessMode = _stringValue(event.raw['accessMode']);
    _joinPolicy =
        joinMode == 'request' || accessMode == 'request' ? 'request' : 'open';

    final visibilityMode = _stringValue(
      event.raw['visibilityMode'] ?? event.raw['visibility'],
    );
    _visibility = visibilityMode == 'public' || visibilityMode.isEmpty
        ? 'public'
        : 'link';
    _verifiedOnly = event.raw['requiresVerification'] == true;
    _plusOnly = event.raw['requiresFrendlyPlus'] == true;
    _coverAssetId = _stringValue(event.raw['coverAssetId']);
    _coverImageUrl = event.imageUrl;
    _attached = null;
  }

  Future<void> _loadInitialAffiche(String eventId) async {
    setState(() => _loadingInitialAffiche = true);
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final event = await container.read(posterDetailProvider(eventId).future);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyAfficheEvent(event);
        _loadingInitialAffiche = false;
      });
      _startAfficheGeoEnrichment(event);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingInitialAffiche = false);
      _showNotice('Не удалось загрузить афишу');
    }
  }

  void _applyAfficheEvent(BackendCardItem event) {
    final draft = buildNewMeetingAffichePrefill(event);

    _attached = _AttachItem(
      id: draft.id,
      kind: _SheetKind.afisha,
      title: draft.attachedTitle,
      sub: draft.attachedSubtitle,
      icon: LucideIcons.ticket,
      place: draft.place,
      address: draft.address,
      city: draft.city,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
    if (draft.title.isNotEmpty && _titleController.text.trim().isEmpty) {
      _titleController.text = draft.title;
    }
    if (draft.description.isNotEmpty &&
        _descriptionController.text.trim().isEmpty) {
      _descriptionController.text = draft.description;
    }
    if (draft.dateInput.isNotEmpty && _dateController.text.trim().isEmpty) {
      _dateController.text = draft.dateInput;
    }
    if (draft.timeInput.isNotEmpty && _timeController.text.trim().isEmpty) {
      _timeController.text = draft.timeInput;
    }
    if (draft.place.isNotEmpty && _place.trim().isEmpty) {
      _place = draft.place;
    }
    if (draft.address.isNotEmpty && _address.trim().isEmpty) {
      _address = draft.address;
    }
    if (draft.latitude != null && draft.longitude != null) {
      _latitude = draft.latitude;
      _longitude = draft.longitude;
    }
  }

  Future<AfficheClientGeoResult?>? _startAfficheGeoEnrichment(
    BackendCardItem event,
  ) {
    if (event.latitude != null && event.longitude != null) {
      return null;
    }
    final request = afficheClientGeoRequestFromCard(event);
    if (request == null) {
      return null;
    }
    _afficheGeoCancelToken?.cancel();
    final cancelToken = CancelToken();
    _afficheGeoCancelToken = cancelToken;
    final container = ProviderScope.containerOf(context, listen: false);
    final future =
        container.read(afficheClientGeoEnrichmentServiceProvider).enrich(
      request,
      cancelToken: cancelToken,
      onLocalResult: (result) {
        if (!mounted || cancelToken.isCancelled) {
          return;
        }
        setState(() => _applyAfficheGeoResult(result));
      },
    );
    _afficheGeoFuture = future;
    unawaited(
      future.then((result) {
        if (result != null) {
          container.invalidate(posterDetailProvider(event.id));
          container.invalidate(postersProvider);
          container.invalidate(mapEventsProvider);
        }
      }).catchError((_) => null),
    );
    return future;
  }

  void _applyAfficheGeoResult(AfficheClientGeoResult result) {
    _latitude = result.latitude;
    _longitude = result.longitude;
    final displayName = result.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty && _address.isEmpty) {
      _address = displayName;
    }
    final attached = _attached;
    if (attached != null && attached.kind == _SheetKind.afisha) {
      _attached = attached.copyWith(
        address: _address,
        latitude: result.latitude,
        longitude: result.longitude,
      );
    }
  }

  Future<void> _ensureAfficheGeoBeforePublish(
    ProviderContainer container,
  ) async {
    if (_latitude != null && _longitude != null) {
      return;
    }
    final attached = _attached;
    if (attached == null ||
        attached.kind != _SheetKind.afisha ||
        attached.id == null) {
      return;
    }
    var future = _afficheGeoFuture;
    if (future == null) {
      try {
        final event =
            await container.read(posterDetailProvider(attached.id!).future);
        if (!mounted) {
          return;
        }
        future = _startAfficheGeoEnrichment(event);
      } catch (_) {
        return;
      }
    }
    if (future == null) {
      return;
    }
    try {
      final result = await future;
      if (result == null || !mounted) {
        return;
      }
      setState(() => _applyAfficheGeoResult(result));
    } catch (_) {}
  }

  Future<void> _loadInitialRoute(String routeId) async {
    setState(() => _loadingInitialRoute = true);
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final route = await _loadRoutePrefillSource(container, routeId);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyRouteTemplate(route);
        _loadingInitialRoute = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingInitialRoute = false);
      _showNotice('Не удалось загрузить маршрут');
    }
  }

  Future<BackendCardItem> _loadRoutePrefillSource(
    ProviderContainer container,
    String routeId,
  ) async {
    try {
      return await container.read(routeDetailProvider(routeId).future);
    } catch (_) {
      return container
          .read(backendRepositoryProvider)
          .fetchEveningRoute(routeId);
    }
  }

  void _applyRouteTemplate(BackendCardItem route) {
    final draft = buildNewMeetingRoutePrefill(route);
    final item = _AttachItem(
      id: draft.id,
      kind: _SheetKind.route,
      title: draft.attachedTitle,
      sub: draft.attachedSubtitle,
      icon: LucideIcons.route,
      description: draft.description,
      place: draft.place,
      address: draft.address,
      city: draft.city,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );

    _attached = item;
    _applyAttachedItem(item);
  }

  Future<void> _openSheet(_SheetKind kind) async {
    final item = await showModalBottomSheet<_AttachItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: DateasyColors.background.withValues(alpha: 0.78),
      builder: (context) => _AttachSheet(kind: kind),
    );

    if (item == null || !mounted) return;

    setState(() {
      if (kind == _SheetKind.place) {
        _place = item.title;
        _address = item.sub.split(' · ').first;
        _latitude = item.latitude;
        _longitude = item.longitude;
      } else {
        _attached = item;
        _applyAttachedItem(item, overwriteLocation: true);
      }
    });
  }

  void _clearAttachment() {
    setState(() {
      final attached = _attached;
      _attached = null;
      if (attached == null || attached.kind == _SheetKind.route) {
        return;
      }

      final attachedPlace = attached.place ?? attached.title;
      if (_place.trim() == attachedPlace.trim()) {
        _place = '';
      }
      final attachedAddress = attached.address;
      if (attachedAddress != null &&
          _address.trim() == attachedAddress.trim()) {
        _address = '';
      }
      if (_latitude == attached.latitude && _longitude == attached.longitude) {
        _latitude = null;
        _longitude = null;
      }
    });
  }

  Future<void> _pickCover() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _coverPath = picked.path;
      _coverFileName = picked.name;
      _coverAssetId = null;
      _coverImageUrl = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_dateController.text.trim()) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: DateasyTheme.theme,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _dateController.text = _formatDateInput(picked));
  }

  Future<void> _pickTime() async {
    final currentParts = _timeController.text.trim().split(':');
    final initial = currentParts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(currentParts[0])?.clamp(0, 23) ?? 19,
            minute: int.tryParse(currentParts[1])?.clamp(0, 59) ?? 0,
          )
        : const TimeOfDay(hour: 19, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: DateasyTheme.theme,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _timeController.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  void _applyAttachedItem(
    _AttachItem item, {
    bool overwriteLocation = false,
  }) {
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = switch (item.kind) {
        _SheetKind.afisha => 'Идем на ${item.title}',
        _SheetKind.promo => 'Встречаемся в ${item.place ?? item.title}',
        _SheetKind.route => item.title,
        _SheetKind.place => _titleController.text,
      };
    }
    if (_descriptionController.text.trim().isEmpty) {
      final description = item.description;
      if (description != null && description.trim().isNotEmpty) {
        _descriptionController.text = description.trim();
      }
    }
    final startsAt = item.startsAt ?? _defaultMeetingStart();
    if (_dateController.text.trim().isEmpty) {
      _dateController.text = _formatDateInput(startsAt);
    }
    if (_timeController.text.trim().isEmpty) {
      _timeController.text = _formatTimeInput(startsAt);
    }
    final place = item.place ?? item.title;
    if (place.trim().isNotEmpty &&
        (overwriteLocation || _place.trim().isEmpty)) {
      _place = place.trim();
    }
    final address = item.address;
    if (address != null &&
        address.trim().isNotEmpty &&
        (overwriteLocation || _address.trim().isEmpty)) {
      _address = address.trim();
    }
    if (overwriteLocation) {
      _latitude = item.latitude;
      _longitude = item.longitude;
    } else if (item.latitude != null && item.longitude != null) {
      _latitude = item.latitude;
      _longitude = item.longitude;
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTopUpNotice() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Пополните баланс'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Пополнить',
          textColor: DateasyColors.lime,
          onPressed: () {
            if (mounted) {
              context.push('/wallet');
            }
          },
        ),
      ),
    );
  }

  Future<void> _publishMeeting() async {
    if (_publishing) {
      return;
    }
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final place = _place.trim();
    final container = ProviderScope.containerOf(context, listen: false);
    final attachedCity = _attached?.city?.trim();
    final profileCity = container.read(currentUserProvider)?.city?.trim();
    final currentCity = attachedCity != null && attachedCity.isNotEmpty
        ? attachedCity
        : profileCity;
    final startsAt = _parseStartsAt(city: currentCity);

    final validation = validateNewMeetingDraft(
      title: title,
      description: description,
      place: place,
      startsAt: startsAt,
    );
    if (validation != NewMeetingDraftValidation.valid) {
      _showNotice(validation.message);
      return;
    }

    setState(() => _publishing = true);
    try {
      final selectedBoostTier = _boostTier;
      if (selectedBoostTier != null) {
        container.invalidate(tokenWalletProvider);
        final wallet = await container.read(tokenWalletProvider.future);
        if (!canPublishMeetingWithBoost(
          boostPrice: selectedBoostTier.price,
          walletBalance: wallet.balance,
        )) {
          if (mounted) {
            _showTopUpNotice();
          }
          return;
        }
      }
      await _ensureAfficheGeoBeforePublish(container);
      final coverAssetId = await _ensureCoverAssetId(container);
      final payload = {
        ...buildNewMeetingBasePayload(
          title: title,
          description: description,
          vibe: _vibe,
          place: place,
          address: _address,
          startsAt: startsAt!,
          capacity: _capacity,
          gender: _gender,
          visibility: _visibility,
          city: currentCity == null || currentCity.isEmpty ? null : currentCity,
          joinPolicy: _joinPolicy,
          requiresVerification: _verifiedOnly,
          requiresFrendlyPlus: _plusOnly,
        ),
        if (_latitude != null && _longitude != null) 'latitude': _latitude,
        if (_latitude != null && _longitude != null) 'longitude': _longitude,
        if (coverAssetId != null) 'coverAssetId': coverAssetId,
        if (_attached?.kind == _SheetKind.afisha && _attached?.id != null)
          'afficheEventId': _attached?.id,
        ...buildNewMeetingSourcePayload(
          inviteeUserId: widget.inviteeUserId,
          sourceChatId: widget.sourceChatId,
          communityId: widget.communityId,
          routeId: widget.routeId,
          attachedRouteId:
              _attached?.kind == _SheetKind.route ? _attached?.id : null,
        ),
        if (_attached?.kind == _SheetKind.promo &&
            _attached?.externalPlaceId != null)
          'externalPlaceId': _attached?.externalPlaceId,
        if (_attached?.kind == _SheetKind.place && _attached?.id != null)
          'externalPlaceId': _attached?.id,
      };
      final editEventId = widget.editEventId?.trim();
      final event = editEventId != null && editEventId.isNotEmpty
          ? await container.read(meetingActionsProvider).updateHostedEvent(
                eventId: editEventId,
                data: payload,
              )
          : await container.read(meetingActionsProvider).createEvent(
                idempotencyKey: _ensureCreateIdempotencyKey(),
                data: payload,
              );
      if (selectedBoostTier != null) {
        unawaited(() async {
          try {
            await container.read(meetingActionsProvider).boostEvent(
                  event.id,
                  optionId: selectedBoostTier.optionId,
                );
          } catch (_) {}
        }());
      }
      if (!mounted) {
        return;
      }
      context.go('/meetings/${event.id}');
    } on BackendActionException catch (error) {
      if (!mounted) {
        return;
      }
      _showNotice(
        newMeetingCreateFailureMessage(
          code: error.code,
          message: error.message,
          details: error.details,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showNotice(newMeetingCreateFailureMessage());
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  Future<String?> _ensureCoverAssetId(ProviderContainer container) async {
    final existing = _coverAssetId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final coverPath = _coverPath;
    if (coverPath == null || coverPath.isEmpty) {
      return null;
    }
    final fileName =
        _coverFileName ?? coverPath.split(Platform.pathSeparator).last;
    final uploaded =
        await container.read(backendRepositoryProvider).uploadEventCoverFile(
              filePath: coverPath,
              fileName: fileName,
              mimeType: _guessMimeType(fileName, null),
            );
    final assetId = uploaded['assetId']?.toString();
    if (assetId == null || assetId.isEmpty) {
      throw StateError('Event cover upload did not return assetId');
    }
    _coverAssetId = assetId;
    return assetId;
  }

  Future<void> _toggleVerifiedOnly() async {
    if (_verifiedOnly) {
      setState(() => _verifiedOnly = false);
      return;
    }
    if (!await _hostVerified()) {
      if (mounted) {
        _showNotice('Сначала пройди верификацию');
      }
      return;
    }
    if (mounted) {
      setState(() => _verifiedOnly = true);
    }
  }

  Future<void> _togglePlusOnly() async {
    if (_plusOnly) {
      setState(() => _plusOnly = false);
      return;
    }
    if (!await _hostHasFrendlyPlus()) {
      if (mounted) {
        _showNotice('Frendly+ доступен только подписчикам');
      }
      return;
    }
    if (mounted) {
      setState(() => _plusOnly = true);
    }
  }

  Future<bool> _hostVerified() async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final verification = await container.read(verificationProvider.future);
      return verification.status == 'verified';
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hostHasFrendlyPlus() async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final subscription = await container.read(subscriptionProvider.future);
      return newMeetingHasFrendlyPlusAccess(subscription);
    } catch (_) {
      return false;
    }
  }

  DateTime? _parseStartsAt({String? city}) {
    return parseNewMeetingStartsAt(
      date: _dateController.text,
      time: _timeController.text,
      city: city,
    );
  }

  String _ensureCreateIdempotencyKey() {
    return _createIdempotency.currentKey();
  }
}

String _stringValue(Object? value) {
  return value is String ? value.trim() : '';
}

String _guessMimeType(String fileName, String? provided) {
  if (provided != null && provided.trim().isNotEmpty) {
    return provided;
  }
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _doubleValue(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

bool newMeetingHasFrendlyPlusAccess(SubscriptionStateData? subscription) {
  final status = subscription?.status.toLowerCase();
  return status == 'active' || status == 'trial';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _GlassIconButton(icon: LucideIcons.arrowLeft, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 18,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: dateasyLimeGradient,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55BEFF67),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.sparkles,
              color: DateasyColors.backgroundDeep,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.coverPath,
    required this.coverImageUrl,
    required this.onPick,
  });

  final String? coverPath;
  final String? coverImageUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onPick,
        child: Container(
          height: 176,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: DateasyColors.surface.withValues(alpha: 0.58),
            border: Border.all(color: DateasyColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: coverPath != null
                    ? Image.file(
                        File(coverPath!),
                        fit: BoxFit.cover,
                      )
                    : coverImageUrl != null
                        ? DateasyRemoteImage(
                            imageUrl: coverImageUrl,
                            usage: DateasyImageUsage.hero,
                            fit: BoxFit.cover,
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  DateasyColors.lime.withValues(alpha: 0.18),
                                  DateasyColors.pink.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
              ),
              if (coverPath != null || coverImageUrl != null)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xAA15082C),
                          Color(0x0015082C),
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.image,
                      size: 28,
                      color: DateasyColors.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      coverPath == null && coverImageUrl == null
                          ? 'Добавить обложку'
                          : 'Сменить обложку',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DateasyColors.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.titleController,
    required this.descriptionController,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            controller: titleController,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Название встречи',
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Короткое описание',
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DateasyColors.muted,
                ),
          ),
        ],
      ),
    );
  }
}

class _VibePills extends StatelessWidget {
  const _VibePills({required this.active, required this.onChanged});

  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Категория'),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final item = _vibes[index];
              final selected = item.label == active;
              return GestureDetector(
                onTap: () => onChanged(item.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: selected ? dateasyLimeGradient : null,
                    color: selected
                        ? null
                        : DateasyColors.surface.withValues(alpha: 0.7),
                    border: Border.all(
                      color:
                          selected ? Colors.transparent : DateasyColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: selected
                            ? DateasyColors.backgroundDeep
                            : DateasyColors.foreground,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: selected
                                  ? DateasyColors.backgroundDeep
                                  : DateasyColors.foreground,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _vibes.length,
          ),
        ),
      ],
    );
  }
}

class _FieldsBlock extends StatelessWidget {
  const _FieldsBlock({
    required this.dateController,
    required this.timeController,
    required this.place,
    required this.address,
    required this.capacity,
    required this.onDate,
    required this.onTime,
    required this.onPlace,
    required this.onMinus,
    required this.onPlus,
  });

  final TextEditingController dateController;
  final TextEditingController timeController;
  final String place;
  final String address;
  final int capacity;
  final VoidCallback onDate;
  final VoidCallback onTime;
  final VoidCallback onPlace;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _GlassCard(
            child: Row(
              children: [
                const _FieldIcon(LucideIcons.calendar),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TinyLabel('Когда'),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _SmallField(
                              controller: dateController,
                              onTap: onDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 86,
                            child: _SmallField(
                              controller: timeController,
                              onTap: onTime,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onPlace,
            child: _GlassCard(
              child: Row(
                children: [
                  const _FieldIcon(LucideIcons.mapPin),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TinyLabel('Где'),
                        const SizedBox(height: 4),
                        Text(
                          place.isEmpty ? 'Выбери место' : place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          address.isEmpty
                              ? 'Адрес появится после выбора'
                              : address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DateasyColors.muted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _GhostPill('Сменить'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GlassCard(
            child: Row(
              children: [
                const _FieldIcon(LucideIcons.users),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TinyLabel('Сколько людей'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _RoundCounterButton(label: '−', onTap: onMinus),
                          SizedBox(
                            width: 58,
                            child: Text(
                              'до $capacity',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          _RoundCounterButton(label: '+', onTap: onPlus),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachBlock extends StatelessWidget {
  const _AttachBlock({
    required this.attached,
    required this.loading,
    required this.onOpen,
    required this.onClear,
  });

  final _AttachItem? attached;
  final bool loading;
  final ValueChanged<_SheetKind> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Прикрепить'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _AttachButton(
                  icon: LucideIcons.ticket,
                  label: 'Афиша',
                  active: attached?.kind == _SheetKind.afisha,
                  onTap: () => onOpen(_SheetKind.afisha),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachButton(
                  icon: LucideIcons.percent,
                  label: 'Промо',
                  active: attached?.kind == _SheetKind.promo,
                  onTap: () => onOpen(_SheetKind.promo),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachButton(
                  icon: LucideIcons.route,
                  label: 'Маршрут',
                  active: attached?.kind == _SheetKind.route,
                  onTap: () => onOpen(_SheetKind.route),
                ),
              ),
            ],
          ),
        ),
        if (loading) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _GlassCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DateasyColors.lime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Загружаю афишу',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (attached != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _GlassCard(
              borderColor: DateasyColors.lime.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: dateasyLimeGradient,
                    ),
                    child: Icon(
                      attached!.icon,
                      size: 18,
                      color: DateasyColors.backgroundDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attached!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          attached!.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DateasyColors.muted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.x, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AudienceBlock extends StatelessWidget {
  const _AudienceBlock({
    required this.gender,
    required this.verifiedOnly,
    required this.plusOnly,
    required this.onGender,
    required this.onVerified,
    required this.onPlus,
  });

  final String gender;
  final bool verifiedOnly;
  final bool plusOnly;
  final ValueChanged<String> onGender;
  final VoidCallback onVerified;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Кому доступно'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Segmented(
            value: gender,
            items: const [
              _SegmentItem('any', 'Любой', null),
              _SegmentItem('male', 'Парни', null),
              _SegmentItem('female', 'Девушки', null),
            ],
            onChanged: onGender,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _ToggleRow(
                icon: LucideIcons.shieldCheck,
                title: 'Только верифицированные',
                subtitle: 'Прошли проверку Frendly',
                value: verifiedOnly,
                onTap: onVerified,
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                icon: LucideIcons.crown,
                title: 'Только Frendly+',
                subtitle: 'Подписчики премиум',
                value: plusOnly,
                onTap: onPlus,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisibilityBlock extends StatelessWidget {
  const _VisibilityBlock({
    required this.visibility,
    required this.onChanged,
  });

  final String visibility;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Кто может видеть'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Segmented(
            value: visibility,
            items: const [
              _SegmentItem('public', 'Все рядом', LucideIcons.globe),
              _SegmentItem('link', 'По ссылке', LucideIcons.lock),
            ],
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 8, 21, 0),
          child: Text(
            visibility == 'public'
                ? 'Появится в радаре у людей рядом'
                : 'Видят только те, кому отправишь ссылку',
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

class _JoinPolicyBlock extends StatelessWidget {
  const _JoinPolicyBlock({
    required this.joinPolicy,
    required this.onChanged,
  });

  final String joinPolicy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Кто может присоединиться'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Segmented(
            value: joinPolicy,
            items: const [
              _SegmentItem('open', 'Все', LucideIcons.users),
              _SegmentItem('request', 'По заявке', LucideIcons.userCheck),
            ],
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 8, 21, 0),
          child: Text(
            joinPolicy == 'request'
                ? 'Хост одобрит заявку перед входом во встречу'
                : 'Люди смогут вступить сразу, если подходят условия',
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

class _BoostTierGrid extends StatelessWidget {
  const _BoostTierGrid({
    required this.selected,
    required this.onChanged,
  });

  final MeetingBoostTier? selected;
  final ValueChanged<MeetingBoostTier> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.zap,
                size: 17,
                color: DateasyColors.pink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Продвинуть встречу',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: () => onChanged(selected!),
                  child: Text(
                    'Без буста',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Чем дольше, тем больше охват',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final tier in meetingBoostTiers) ...[
                Expanded(
                  child: _BoostTierCard(
                    tier: tier,
                    selected: selected?.optionId == tier.optionId,
                    onTap: () => onChanged(tier),
                  ),
                ),
                if (tier != meetingBoostTiers.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BoostTierCard extends StatelessWidget {
  const _BoostTierCard({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final MeetingBoostTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = meetingBoostVisual(tier);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 128),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    visual.primary.withValues(alpha: 0.26),
                    DateasyColors.surface.withValues(alpha: 0.72),
                  ],
                )
              : null,
          color:
              selected ? null : DateasyColors.surface.withValues(alpha: 0.72),
          border: Border.all(
            color: selected
                ? visual.primary.withValues(alpha: 0.58)
                : DateasyColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: visual.glow.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: selected ? visual.gradient : null,
                    color: selected ? null : DateasyColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tier.icon,
                    color:
                        selected ? visual.foreground : DateasyColors.foreground,
                    size: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tier.hours}ч',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tier.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              tier.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 10,
                    height: 1.18,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  LucideIcons.coins,
                  size: 12,
                  color: DateasyColors.lime,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tier.price} FT',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachSheet extends ConsumerStatefulWidget {
  const _AttachSheet({required this.kind});

  final _SheetKind kind;

  @override
  ConsumerState<_AttachSheet> createState() => _AttachSheetState();
}

class _AttachSheetState extends ConsumerState<_AttachSheet> {
  final _placeQueryController = TextEditingController();
  final _placeSearchDebouncer = NewMeetingPlaceSearchDebouncer();
  int? _afishaDayOffset;
  String _afishaCategory = 'Все';
  List<_AttachItem> _yandexPlaceItems = const [];
  bool _yandexPlaceLoading = false;
  String _lastYandexQuery = '';
  int _yandexSearchToken = 0;

  @override
  void initState() {
    super.initState();
    _placeSearchDebouncer.addListener(_onPlaceSearchChanged);
  }

  @override
  void dispose() {
    _placeSearchDebouncer.removeListener(_onPlaceSearchChanged);
    _placeSearchDebouncer.dispose();
    _placeQueryController.dispose();
    super.dispose();
  }

  void _onPlaceSearchChanged() {
    if (mounted) {
      final query = _placeSearchDebouncer.query;
      setState(() {});
      if (widget.kind == _SheetKind.place) {
        unawaited(_searchYandexPlaces(query));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      _SheetKind.afisha => 'Прикрепить из афиши',
      _SheetKind.promo => 'Промо · заведения со скидками',
      _SheetKind.route => 'Прикрепить маршрут',
      _SheetKind.place => 'Выбери место встречи',
    };
    final query = _placeSearchDebouncer.query;
    final listState = switch (widget.kind) {
      _SheetKind.afisha => ref.watch(
          postersQueryProvider(
            PostersQuery(
              limit: 20,
              date: _afishaDayOffset == null
                  ? null
                  : _dateQueryForOffset(_afishaDayOffset!),
              category: _afishaCategory == 'Все' ? null : _afishaCategory,
            ),
          ),
        ),
      _SheetKind.promo => ref.watch(perksProvider),
      _SheetKind.route => ref.watch(routeTemplatesProvider),
      _SheetKind.place => query.length < 2
          ? const AsyncValue<CardPage>.data(BackendPage(items: []))
          : ref.watch(placeSearchProvider(query)),
    };
    final items = listState.valueOrNull?.items ?? const <BackendCardItem>[];
    final attachItems = _attachItemsForSheet(widget.kind, items, query);
    final visibleItems = widget.kind == _SheetKind.place
        ? _mergeAttachItems(attachItems, _yandexPlaceItems)
        : attachItems;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final sheetMaxHeight = viewportHeight * 0.88;
    final listMaxHeight = viewportHeight * 0.66;

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: sheetMaxHeight,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding + 24),
            decoration: const BoxDecoration(
              color: DateasyColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: DateasyColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _GlassIconButton(
                        icon: LucideIcons.x,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (widget.kind == _SheetKind.afisha) ...[
                    _AfishaFilters(
                      dayOffset: _afishaDayOffset,
                      category: _afishaCategory,
                      onDayChanged: (value) => setState(() {
                        _afishaDayOffset = value;
                      }),
                      onCategoryChanged: (value) => setState(() {
                        _afishaCategory = value;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.kind == _SheetKind.place) ...[
                    _GlassCard(
                      child: TextField(
                        controller: _placeQueryController,
                        onChanged: _placeSearchDebouncer.update,
                        decoration: const InputDecoration(
                          hintText: 'Введите название или адрес',
                          border: InputBorder.none,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: listMaxHeight),
                      child: _SheetList(
                        listState: _yandexPlaceLoading &&
                                widget.kind == _SheetKind.place &&
                                listState.valueOrNull == null
                            ? const AsyncValue<CardPage>.loading()
                            : listState,
                        items: visibleItems,
                        emptyText: _emptyText(widget.kind, query),
                        onTap: (item) => Navigator.of(context).pop(item),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _searchYandexPlaces(String query) async {
    final trimmed = query.trim();
    final city = ref.read(currentUserProvider)?.city?.trim();
    final effectiveCity = city == null || city.isEmpty ? 'Москва' : city;
    if (trimmed.length < 2) {
      setState(() {
        _lastYandexQuery = trimmed;
        _yandexPlaceItems = const [];
        _yandexPlaceLoading = false;
      });
      return;
    }
    if (trimmed == _lastYandexQuery) {
      return;
    }
    final token = ++_yandexSearchToken;
    _lastYandexQuery = trimmed;
    setState(() {
      _yandexPlaceLoading = true;
    });
    try {
      final search = await ym.YandexSearch.searchByText(
        searchText: _cityScopedYandexQuery(trimmed, effectiveCity),
        geometry: ym.Geometry.fromBoundingBox(
          const ym.BoundingBox(
            northEast: ym.Point(latitude: 85, longitude: 180),
            southWest: ym.Point(latitude: -85, longitude: -180),
          ),
        ),
        searchOptions: const ym.SearchOptions(
          searchType: ym.SearchType.biz,
          resultPageSize: 8,
        ),
      );
      final result = await search.$2;
      if (!mounted || token != _yandexSearchToken) {
        return;
      }
      setState(() {
        _yandexPlaceItems = (result.items ?? const <ym.SearchItem>[])
            .map((item) => _attachFromYandexPlace(item, effectiveCity))
            .whereType<_AttachItem>()
            .toList(growable: false);
        _yandexPlaceLoading = false;
      });
    } catch (_) {
      if (!mounted || token != _yandexSearchToken) {
        return;
      }
      setState(() {
        _yandexPlaceItems = const [];
        _yandexPlaceLoading = false;
      });
    }
  }

  _AttachItem _attachFromBackend(_SheetKind kind, BackendCardItem item) {
    return _AttachItem(
      id: _attachId(kind, item),
      kind: kind,
      title: item.title.isEmpty ? 'Без названия' : item.title,
      sub: _attachSubtitle(kind, item),
      icon: switch (kind) {
        _SheetKind.afisha => LucideIcons.ticket,
        _SheetKind.promo => LucideIcons.percent,
        _SheetKind.route => LucideIcons.route,
        _SheetKind.place => LucideIcons.mapPin,
      },
      description: _attachDescription(kind, item),
      place: _attachPlace(kind, item),
      address: _attachAddress(kind, item),
      city: item.city,
      startsAt: item.startsAt,
      externalPlaceId: _attachExternalPlaceId(kind, item),
      latitude: item.latitude,
      longitude: item.longitude,
    );
  }

  _AttachItem? _attachFromYandexPlace(ym.SearchItem item, String city) {
    final point = item.geometry
            .map((geometry) => geometry.point)
            .whereType<ym.Point>()
            .firstOrNull ??
        item.toponymMetadata?.balloonPoint;
    if (point == null) {
      return null;
    }
    final address = item.businessMetadata?.address.formattedAddress ??
        item.toponymMetadata?.address.formattedAddress;
    final formattedAddress = _formatCityAddress(city, address);
    final title = item.businessMetadata?.shortName ??
        item.businessMetadata?.name ??
        item.name;
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return null;
    }
    return _AttachItem(
      kind: _SheetKind.place,
      title: cleanTitle,
      sub: [
        formattedAddress,
        'Yandex Maps',
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · '),
      icon: LucideIcons.mapPin,
      place: cleanTitle,
      address: formattedAddress,
      city: city,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  List<_AttachItem> _attachItemsForSheet(
    _SheetKind kind,
    List<BackendCardItem> items,
    String query,
  ) {
    final result = items
        .map((item) => _attachFromBackend(kind, item))
        .toList(growable: true);
    if (kind == _SheetKind.place && _shouldOfferTypedAddress(query)) {
      final typedAddress = _typedAddressItem(query);
      final key = _attachDedupeKey(typedAddress);
      final exists = result.any((item) => _attachDedupeKey(item) == key);
      if (!exists) {
        result.insert(0, typedAddress);
      }
    }
    return result;
  }

  String _attachSubtitle(_SheetKind kind, BackendCardItem item) {
    final raw = item.raw;
    return switch (kind) {
      _SheetKind.afisha => [
          _formatAttachDate(item.startsAt),
          item.subtitle ?? item.city,
        ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
      _SheetKind.promo => [
          item.subtitle,
          raw['validUntil'] == null ? null : 'до ${raw['validUntil']}',
        ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
      _SheetKind.route => [
          raw['area']?.toString(),
          raw['durationLabel']?.toString(),
        ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
      _SheetKind.place => [
          _formatCityAddress(item.city, item.subtitle),
        ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
    };
  }

  String _emptyText(_SheetKind kind, String query) {
    if (kind == _SheetKind.place && query.length < 2) {
      return 'Введите минимум 2 символа';
    }
    if (kind == _SheetKind.promo) {
      return 'В вашем городе нет промо';
    }
    return 'Backend вернул пустой список';
  }
}

bool _shouldOfferTypedAddress(String query) {
  return query.trim().length >= 2;
}

_AttachItem _typedAddressItem(String query) {
  final address = query.trim();
  return _AttachItem(
    kind: _SheetKind.place,
    title: address,
    sub: 'Использовать введённый адрес',
    icon: LucideIcons.mapPin,
    place: address,
    address: null,
  );
}

List<_AttachItem> _mergeAttachItems(
  List<_AttachItem> primary,
  List<_AttachItem> fallback,
) {
  final result = [...primary];
  final keys = result.map(_attachDedupeKey).toSet();
  for (final item in fallback) {
    final key = _attachDedupeKey(item);
    if (keys.add(key)) {
      result.add(item);
    }
  }
  return result;
}

String _attachDedupeKey(_AttachItem item) {
  return '${item.title}|${item.sub}|${item.place}|${item.address}'
      .toLowerCase();
}

String? _attachDescription(_SheetKind kind, BackendCardItem item) {
  final raw = item.raw;
  return switch (kind) {
    _SheetKind.afisha => _afficheDescription(item),
    _SheetKind.promo =>
      _rawString(raw, const ['description', 'shortSummary']) ?? item.subtitle,
    _SheetKind.route =>
      _rawString(raw, const ['blurb', 'description']) ?? 'Маршрут для встречи',
    _SheetKind.place => null,
  };
}

String? _attachPlace(_SheetKind kind, BackendCardItem item) {
  final raw = item.raw;
  return switch (kind) {
    _SheetKind.afisha => _affichePlace(item),
    _SheetKind.promo => _rawString(
          raw,
          const ['venueName', 'placeName', 'partnerName'],
        ) ??
        item.title,
    _SheetKind.route => item.title,
    _SheetKind.place => item.title,
  };
}

String? _attachAddress(_SheetKind kind, BackendCardItem item) {
  final raw = item.raw;
  return switch (kind) {
    _SheetKind.afisha => _afficheAddress(item),
    _SheetKind.promo =>
      _rawString(raw, const ['address', 'placeAddress']) ?? item.city,
    _SheetKind.route => item.subtitle ?? item.city,
    _SheetKind.place => _formatCityAddress(item.city, item.subtitle),
  };
}

String _cityScopedYandexQuery(String query, String city) {
  final trimmed = query.trim();
  final normalizedQuery = trimmed.toLowerCase();
  final normalizedCity = city.trim().toLowerCase();
  if (normalizedCity.isEmpty || normalizedQuery.contains(normalizedCity)) {
    return trimmed;
  }
  return '$city, $trimmed';
}

String? _formatCityAddress(String? city, String? address) {
  final cleanCity = city?.trim();
  final cleanAddress = address?.trim();
  if (cleanAddress == null || cleanAddress.isEmpty) {
    return cleanCity == null || cleanCity.isEmpty ? null : cleanCity;
  }

  final parts = cleanAddress
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .where((part) => !_isAdministrativeAddressPart(part))
      .toList(growable: false);

  if (parts.isEmpty) {
    return cleanCity == null || cleanCity.isEmpty ? cleanAddress : cleanCity;
  }

  final cityIndex = cleanCity == null || cleanCity.isEmpty
      ? -1
      : parts.indexWhere(
          (part) => part.toLowerCase() == cleanCity.toLowerCase(),
        );
  final usefulParts = cityIndex >= 0 ? parts.skip(cityIndex).toList() : parts;
  if (cleanCity != null &&
      cleanCity.isNotEmpty &&
      (usefulParts.isEmpty ||
          usefulParts.first.toLowerCase() != cleanCity.toLowerCase())) {
    return [cleanCity, ...usefulParts].join(', ');
  }
  return usefulParts.join(', ');
}

bool _isAdministrativeAddressPart(String part) {
  final value = part.toLowerCase();
  return value == 'россия' ||
      value.contains('республика') ||
      value.contains('область') ||
      value.contains('край') ||
      value.contains('автономный округ');
}

String? _attachExternalPlaceId(_SheetKind kind, BackendCardItem item) {
  if (kind != _SheetKind.promo) {
    return null;
  }
  return _rawString(item.raw, const ['placeId', 'externalPlaceId']);
}

String? _attachId(_SheetKind kind, BackendCardItem item) {
  if (kind == _SheetKind.route) {
    return _rawString(item.raw, const ['routeId', 'currentRouteId']) ?? item.id;
  }
  return item.id;
}

class _SheetList extends StatelessWidget {
  const _SheetList({
    required this.listState,
    required this.items,
    required this.emptyText,
    required this.onTap,
  });

  final AsyncValue<CardPage> listState;
  final List<_AttachItem> items;
  final String emptyText;
  final ValueChanged<_AttachItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (listState.isLoading && items.isEmpty) {
      return const _SheetStatus(text: 'Загружаем из backend');
    }
    if (listState.hasError && items.isEmpty) {
      return const _SheetStatus(text: 'Backend список недоступен');
    }
    if (items.isEmpty) {
      return _SheetStatus(text: emptyText);
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          key: ValueKey(
            'attach-${item.kind.name}-${item.id ?? _attachDedupeKey(item)}',
          ),
          onTap: () => onTap(item),
          child: _GlassCard(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: dateasyLimeGradient,
                  ),
                  child: Icon(
                    item.icon,
                    color: DateasyColors.backgroundDeep,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        item.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.muted,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.plus,
                  size: 18,
                  color: DateasyColors.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AfishaFilters extends StatelessWidget {
  const _AfishaFilters({
    required this.dayOffset,
    required this.category,
    required this.onDayChanged,
    required this.onCategoryChanged,
  });

  final int? dayOffset;
  final String category;
  final ValueChanged<int?> onDayChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final value = index == 0 ? null : index - 1;
              final selected = dayOffset == value;
              return _SheetChip(
                label: value == null ? 'Все' : _dayChipLabel(value),
                selected: selected,
                gradient: true,
                onTap: () => onDayChanged(value),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _afishaCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = _afishaCategories[index];
              return _SheetChip(
                label: item,
                selected: category == item,
                gradient: false,
                onTap: () => onCategoryChanged(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected && gradient ? dateasyLimeGradient : null,
          color: selected && !gradient
              ? DateasyColors.foreground
              : selected
                  ? null
                  : DateasyColors.glass,
          border: selected ? null : Border.all(color: DateasyColors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected
                    ? gradient
                        ? DateasyColors.backgroundDeep
                        : DateasyColors.background
                    : DateasyColors.foreground,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _SheetStatus extends StatelessWidget {
  const _SheetStatus({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.muted,
            ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
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
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: DateasyColors.backgroundDeep,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 82,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: active ? dateasyLimeGradient : null,
          color: active ? null : DateasyColors.surface.withValues(alpha: 0.7),
          border: active ? null : Border.all(color: DateasyColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.foreground,
              size: 22,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: active
                        ? DateasyColors.backgroundDeep
                        : DateasyColors.foreground,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassCard(
        child: Row(
          children: [
            _FieldIcon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: value ? dateasyLimeGradient : null,
                color: value ? null : DateasyColors.surface2,
                border: value ? null : Border.all(color: DateasyColors.border),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DateasyColors.background,
                  ),
                  child: value
                      ? const Icon(
                          LucideIcons.check,
                          size: 13,
                          color: DateasyColors.lime,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<_SegmentItem> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: DateasyColors.surface.withValues(alpha: 0.7),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Row(
        children: items.map((item) {
          final selected = value == item.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: selected ? dateasyLimeGradient : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 15,
                        color: selected
                            ? DateasyColors.backgroundDeep
                            : DateasyColors.muted,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? DateasyColors.backgroundDeep
                                  : DateasyColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField({required this.controller, this.onTap});

  final TextEditingController controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: onTap != null,
      onTap: onTap,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: DateasyColors.surface2.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.borderColor = DateasyColors.border,
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: DateasyColors.surface.withValues(alpha: 0.7),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _FieldIcon extends StatelessWidget {
  const _FieldIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: DateasyColors.surface2,
      ),
      child: Icon(icon, size: 20, color: DateasyColors.lime),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: DateasyColors.glass,
              border: Border.all(color: DateasyColors.border),
            ),
            child: Icon(icon, size: 20, color: DateasyColors.foreground),
          ),
        ),
      ),
    );
  }
}

class _RoundCounterButton extends StatelessWidget {
  const _RoundCounterButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: DateasyColors.surface2,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _GhostPill extends StatelessWidget {
  const _GhostPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: DateasyColors.surface2.withValues(alpha: 0.72),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.muted,
              fontSize: 11,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.muted,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _TinyLabel extends StatelessWidget {
  const _TinyLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DateasyColors.muted,
            fontSize: 10,
            letterSpacing: 1.1,
          ),
    );
  }
}

class _VibeItem {
  const _VibeItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _SegmentItem {
  const _SegmentItem(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData? icon;
}

class _AttachItem {
  const _AttachItem({
    required this.kind,
    required this.title,
    required this.sub,
    required this.icon,
    this.id,
    this.description,
    this.place,
    this.address,
    this.city,
    this.startsAt,
    this.externalPlaceId,
    this.latitude,
    this.longitude,
  });

  final _SheetKind kind;
  final String title;
  final String sub;
  final IconData icon;
  final String? id;
  final String? description;
  final String? place;
  final String? address;
  final String? city;
  final DateTime? startsAt;
  final String? externalPlaceId;
  final double? latitude;
  final double? longitude;

  _AttachItem copyWith({
    String? address,
    String? city,
    double? latitude,
    double? longitude,
  }) {
    return _AttachItem(
      id: id,
      kind: kind,
      title: title,
      sub: sub,
      icon: icon,
      description: description,
      place: place,
      address: address ?? this.address,
      city: city ?? this.city,
      startsAt: startsAt,
      externalPlaceId: externalPlaceId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

enum _SheetKind { afisha, promo, route, place }

String _formatAttachDate(DateTime? value) {
  if (value == null) {
    return 'Время уточняется';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}.${local.month} · $hour:$minute';
}

String _formatDateInput(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _formatTimeInput(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

DateTime _defaultMeetingStart() {
  return DateTime.now().add(const Duration(hours: 3));
}

String? _rawString(Map<String, Object?> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _affichePlace(BackendCardItem event) {
  return _rawString(event.raw, const ['venue', 'venueName', 'placeName']) ??
      _nestedRawString(event.raw, 'place', const ['name', 'title']) ??
      event.subtitle ??
      '';
}

String _afficheAddress(BackendCardItem event) {
  return _rawString(event.raw, const ['address', 'locationAddress']) ??
      _nestedRawString(event.raw, 'place', const ['address']) ??
      event.city ??
      '';
}

String _afficheDescription(BackendCardItem event) {
  return _rawString(event.raw, const ['description', 'body', 'details']) ?? '';
}

String? _nestedRawString(
  Map<String, Object?> raw,
  String key,
  List<String> fields,
) {
  final nested = raw[key];
  if (nested is! Map) {
    return null;
  }
  return _rawString(
    nested.map((key, value) => MapEntry('$key', value)),
    fields,
  );
}

String _dateQueryForOffset(int offset) {
  final day = DateTime.now().add(Duration(days: offset));
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

String _dayChipLabel(int offset) {
  if (offset == 0) {
    return 'Сегодня';
  }
  if (offset == 1) {
    return 'Завтра';
  }
  final day = DateTime.now().add(Duration(days: offset));
  return '${_weekdays[day.weekday % 7]} ${day.day}';
}

const _weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
const _afishaCategories = [
  'Все',
  'Музыка',
  'Бар',
  'Арт',
  'Стендап',
  'Спорт',
  'Кино'
];

const _vibes = [
  _VibeItem('Кофе', LucideIcons.coffee),
  _VibeItem('Музыка', LucideIcons.music2),
  _VibeItem('Спорт', LucideIcons.dumbbell),
  _VibeItem('Бар', LucideIcons.wine),
  _VibeItem('Арт', LucideIcons.palette),
  _VibeItem('Прогулка', LucideIcons.footprints),
  _VibeItem('Гастро', LucideIcons.pizza),
  _VibeItem('Кино', LucideIcons.film),
  _VibeItem('Книги', LucideIcons.bookOpen),
  _VibeItem('Фото', LucideIcons.camera),
  _VibeItem('Игры', LucideIcons.gamepad2),
  _VibeItem('Outdoor', LucideIcons.mountain),
  _VibeItem('Вело', LucideIcons.bike),
  _VibeItem('Свидание', LucideIcons.heart),
];
