// ignore_for_file: unused_element, unused_element_parameter

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_event_picker_sheet.dart';
import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/widgets/date_time_sheet.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/widgets/partner_picker_sheet.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/widgets/place_sheet.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/widgets/route_picker_sheet.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _CreateIconChoice {
  const _CreateIconChoice({
    required this.icon,
    required this.emoji,
  });

  final IconData icon;
  final String emoji;
}

const _createIconChoices = [
  _CreateIconChoice(icon: LucideIcons.wine, emoji: '🍷'),
  _CreateIconChoice(icon: LucideIcons.coffee, emoji: '☕'),
  _CreateIconChoice(icon: LucideIcons.film, emoji: '🎬'),
  _CreateIconChoice(icon: LucideIcons.music, emoji: '🎶'),
  _CreateIconChoice(icon: LucideIcons.palette, emoji: '🎨'),
  _CreateIconChoice(icon: LucideIcons.book_open, emoji: '📚'),
  _CreateIconChoice(icon: LucideIcons.footprints, emoji: '🚶'),
  _CreateIconChoice(icon: LucideIcons.sun, emoji: '☀️'),
];
const _createVibes = ['Спокойно', 'Шумно', 'Активно', 'Уютно', 'Свидание'];
const _dateIdeas = [
  ('wine', 'Винный бар', '🍷', 'Я оплачиваю бар или ужин'),
  ('coffee', 'Кофе и прогулка', '☕', 'Быстро, легко, без долгого сетапа'),
  ('cinema', 'Кино и разговор', '🎬', 'Сначала фильм, потом обсудить'),
];
const _fixedBottomCtaReserve = 360.0;
const _fixedBottomCtaGap = 24.0;

IconData _iconForEmoji(String value) {
  for (final item in _createIconChoices) {
    if (item.emoji == value) {
      return item.icon;
    }
  }
  return switch (value) {
    '💘' => LucideIcons.heart,
    '🖤' => LucideIcons.shield_check,
    '📍' => LucideIcons.map_pin,
    '🗺️' => LucideIcons.route,
    _ => LucideIcons.wine,
  };
}

enum CreateMeetupMode { meetup, dating }

CreateMeetupMode parseCreateMeetupMode(String? raw) {
  switch (raw) {
    case 'dating':
      return CreateMeetupMode.dating;
    default:
      return CreateMeetupMode.meetup;
  }
}

class CreateMeetupScreen extends ConsumerStatefulWidget {
  const CreateMeetupScreen({
    super.key,
    this.inviteeUserId,
    this.afficheEventId,
    this.communityId,
    this.editEventId,
    this.initialMode = CreateMeetupMode.meetup,
  });

  final String? inviteeUserId;
  final String? afficheEventId;
  final String? communityId;
  final String? editEventId;
  final CreateMeetupMode initialMode;

  @override
  ConsumerState<CreateMeetupScreen> createState() => _CreateMeetupScreenState();
}

@visibleForTesting
DateTime? parseCreateMeetupEventStartsAtForTest(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  return DateTime(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

class _CreateMeetupScreenState extends ConsumerState<CreateMeetupScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeController = TextEditingController();
  final _priceFromController = TextEditingController();
  final _priceToController = TextEditingController();
  late CreateMeetupMode _mode = widget.initialMode;
  String emoji = '🍷';
  String vibe = 'Спокойно';
  String visibility = 'public';
  String lifestyle = 'neutral';
  String priceMode = 'free';
  String accessMode = 'open';
  String genderMode = 'all';
  String priceFrom = '';
  String priceTo = '';
  String dateIdea = _dateIdeas.first.$1;
  bool unlimited = false;
  PlaceSelection placeSelection = const PlaceSelection(
    name: '',
    address: '',
  );
  PartnerVenue? _partnerVenue;
  double capacity = 8;
  DateTime startsAt = DateTime.now().add(const Duration(hours: 2));
  AfficheEvent? _afficheEvent;
  CreateMeetupRouteSelection? _routeSelection;
  bool _creating = false;
  bool _loadingAfficheEvent = false;
  String? _createIdempotencyKey;
  String? _editSeededEventId;

  @override
  void initState() {
    super.initState();
    _applyModeDefaults(widget.initialMode);
    _loadInitialAfficheEvent();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _placeController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialAfficheEvent() async {
    final eventId = widget.afficheEventId;
    if (eventId == null || eventId.isEmpty) {
      return;
    }

    setState(() {
      _loadingAfficheEvent = true;
    });

    try {
      final eventFuture = ref.read(afficheEventDetailProvider(eventId).future);
      final event = await eventFuture;
      if (!mounted) {
        return;
      }
      _applyAfficheSelection(event);
    } finally {
      if (mounted) {
        setState(() {
          _loadingAfficheEvent = false;
        });
      }
    }
  }

  void _applyModeDefaults(CreateMeetupMode mode) {
    if (mode == CreateMeetupMode.dating) {
      emoji = '💘';
      vibe = 'Свидание';
      visibility = 'friends';
      accessMode = 'request';
      priceMode = 'host_pays';
      capacity = 2;
      _titleController.text = 'Свидание на двоих';
      _descriptionController.text = '';
      placeSelection = const PlaceSelection(
        name: 'Tilda Bistro',
        address: 'Патриаршие, Спиридоньевский 10А',
        distance: '1.4 км',
        distanceKm: 1.4,
        emoji: '🍷',
      );
      _placeController.text = _placeLabel();
      return;
    }
  }

  void _applyEditEvent(EventDetail event) {
    _editSeededEventId = event.id;
    _mode = event.vibe == 'Свидание'
        ? CreateMeetupMode.dating
        : CreateMeetupMode.meetup;
    emoji = event.emoji;
    vibe = event.vibe;
    visibility = event.visibilityMode ?? 'public';
    lifestyle = event.lifestyle ?? 'neutral';
    priceMode = event.priceMode ?? 'free';
    accessMode = event.accessMode ?? 'open';
    genderMode = event.genderMode ?? 'all';
    capacity = event.capacity <= 0 ? 8 : event.capacity.toDouble();
    unlimited = false;
    _titleController.text = event.title;
    _descriptionController.text = event.description;
    startsAt = _parseEventStartsAt(event.startsAtIso) ?? startsAt;
    placeSelection = PlaceSelection(
      name: event.place,
      address: '',
      distance: event.distance,
      distanceKm: _parseDistanceKm(event.distance),
      latitude: event.latitude,
      longitude: event.longitude,
      emoji: event.emoji,
    );
    _placeController.text = _placeLabel();
    final from = event.priceAmountFrom;
    final to = event.priceAmountTo;
    priceFrom = from?.toString() ?? '';
    priceTo = to?.toString() ?? '';
    _priceFromController.text = priceFrom;
    _priceToController.text = priceTo;
  }

  DateTime? _parseEventStartsAt(String? value) {
    return parseCreateMeetupEventStartsAtForTest(value);
  }

  double _parseDistanceKm(String value) {
    final match = RegExp(r'(\d+(?:[,.]\d+)?)').firstMatch(value);
    if (match == null) {
      return 1;
    }
    return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final editEventAsync = widget.editEventId == null
        ? null
        : ref.watch(eventDetailProvider(widget.editEventId!));
    final editingEvent = editEventAsync?.valueOrNull;
    if (editingEvent != null && _editSeededEventId != editingEvent.id) {
      _applyEditEvent(editingEvent);
    }
    final isEditMode = widget.editEventId != null;
    final isDatingMode = _mode == CreateMeetupMode.dating;
    final subscription = !isEditMode && isDatingMode
        ? ref.watch(subscriptionStateProvider).valueOrNull
        : null;
    final isPremium =
        subscription?.status == 'trial' || subscription?.status == 'active';
    final titleText = isEditMode
        ? 'Редактировать встречу'
        : isDatingMode
            ? 'Новое свидание'
            : 'Новая встреча';
    final publishText = isEditMode
        ? 'Сохранить'
        : isDatingMode
            ? 'Отправить инвайт'
            : 'Дальше · превью';
    final canSubmit = isEditMode || (!isDatingMode || isPremium);

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildV5Header(
                  titleText: titleText,
                  isEditMode: isEditMode,
                  isDatingMode: isDatingMode,
                ),
                Expanded(
                  child: ListView(
                    cacheExtent: 1400,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      _listBottomPadding(context),
                    ),
                    children: [
                      if (!isEditMode) ...[
                        _buildV5ModeTabs(),
                        const SizedBox(height: 20),
                      ],
                      _buildV5PreviewCard(
                        isDatingMode: isDatingMode,
                      ),
                      _buildV5TitleSection(isDatingMode: isDatingMode),
                      if (!isDatingMode) _buildV5EmojiSection(),
                      _buildV5WhenWhereSection(),
                      if (!isDatingMode) _buildV5AttachSection(),
                      _buildV5VibeSection(),
                      _buildV5CapacitySection(
                        isDatingMode: isDatingMode,
                      ),
                      if (!isDatingMode) _buildV5LifestyleSection(),
                      _buildV5PriceSection(isDatingMode: isDatingMode),
                      _buildV5AccessSection(
                        isDatingMode: isDatingMode,
                      ),
                      if (!isDatingMode) _buildV5GenderSection(),
                      if (isDatingMode) _buildV5DateIdeasSection(),
                      _buildV5DescriptionSection(
                        isDatingMode: isDatingMode,
                      ),
                      _buildV5AiHelper(),
                      _buildV5VisibilitySection(
                        isDatingMode: isDatingMode,
                      ),
                    ],
                  ),
                ),
                _buildV5BottomCta(
                  publishText: publishText,
                  canSubmit: canSubmit,
                  isDatingMode: isDatingMode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildV5Header({
    required String titleText,
    required bool isEditMode,
    required bool isDatingMode,
  }) {
    final headerTitle = isEditMode
        ? titleText
        : isDatingMode
            ? 'Свидание'
            : 'Собрать своих';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: Row(
        children: [
          BbV5IconButton(
            icon: LucideIcons.arrow_left,
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BbV5Kicker(isEditMode ? 'редактирование' : 'новая встреча'),
                const SizedBox(height: 2),
                Text(
                  headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5DisplayStyle(fontSize: 15, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BbV5PillButton(
            label: isEditMode ? 'Правка' : 'Черновик',
            onPressed: null,
            height: 36,
            fontSize: 11.5,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildV5ModeTabs() {
    return _V5SegmentedTabs(
      items: [
        _V5TabItem(
          label: 'Обычная',
          active: _mode == CreateMeetupMode.meetup,
          onTap: () => setState(() {
            _mode = CreateMeetupMode.meetup;
            _applyModeDefaults(_mode);
          }),
        ),
        _V5TabItem(
          label: 'Свидание',
          active: _mode == CreateMeetupMode.dating,
          onTap: () => setState(() {
            _mode = CreateMeetupMode.dating;
            _applyModeDefaults(_mode);
          }),
        ),
        _V5TabItem(
          label: 'After Dark',
          active: false,
          afterDark: true,
          onTap: () => context.pushRoute(AppRoute.afterDark),
        ),
      ],
    );
  }

  Widget _buildV5PreviewCard({
    required bool isDatingMode,
  }) {
    return BbV5Card(
      tint: isDatingMode ? BbV5Colors.rose : BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbV5Kicker(isDatingMode ? 'frendly+ date' : 'превью'),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _titleController,
            builder: (context, _) {
              return RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: bbV5DisplayStyle(fontSize: 24, height: 1.25),
                  children: [
                    TextSpan(
                      text: _previewTitle(
                        isDatingMode: isDatingMode,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                LucideIcons.map_pin,
                size: 12,
                color: BbV5Colors.inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _previewSubtitle(isDatingMode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkSoft,
                    fontSize: 11.5,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _V5Tag(vibe),
              if (!isDatingMode) _V5Tag(_lifestyleTag()),
              _V5Tag(_accessTag(isDatingMode)),
              _V5Tag(_priceTag()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildV5TitleSection({required bool isDatingMode}) {
    return BbV5Section(
      title: 'Название и иконка',
      child: SizedBox(
        height: 86,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _V5EmojiButton(
              icon: _iconForEmoji(emoji),
              onTap: isDatingMode ? null : _showEmojiPickerHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BbV5Card(
                radius: BbV5Radii.md,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BbV5Kicker('название'),
                    TextField(
                      controller: _titleController,
                      maxLength: 60,
                      decoration: InputDecoration(
                        hintText: isDatingMode
                            ? 'Например: вино на двоих'
                            : 'Коротко и по-человечески',
                        counterText: '',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.only(top: 4),
                        hintStyle: AppTextStyles.body.copyWith(
                          fontFamily: 'Sora',
                          color: BbV5Colors.inkMute,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      style: bbV5DisplayStyle(fontSize: 15, height: 1.25),
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

  Widget _buildV5EmojiSection() {
    return BbV5Section(
      title: 'Иконка вечера',
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemBuilder: (context, index) {
            final item = _createIconChoices[index];
            final active = emoji == item.emoji;
            return _V5RoundChoice(
              active: active,
              child: Icon(item.icon, size: 16),
              onTap: () => setState(() => emoji = item.emoji),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemCount: _createIconChoices.length,
        ),
      ),
    );
  }

  Widget _buildV5WhenWhereSection() {
    return BbV5Section(
      title: 'Где и когда',
      child: Column(
        children: [
          BbV5Card(
            radius: BbV5Radii.md,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _V5FieldRow(
                  icon: LucideIcons.calendar_days,
                  label: 'Когда',
                  value: _formatStartsAt(startsAt),
                  onTap: () async {
                    final next = await showDateTimeSheet(
                      context,
                      initialValue: startsAt,
                    );
                    if (next != null && mounted) {
                      setState(() {
                        startsAt = next;
                      });
                    }
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1, color: BbV5Colors.hairSoft),
                ),
                _V5FieldRow(
                  icon: LucideIcons.map_pin,
                  label: 'Где',
                  value: _placeLabel(),
                  onTap: () async {
                    final next = await showPlaceSheet(
                      context,
                      initialValue: placeSelection,
                      onPickAfficheEvent: () async {
                        final event = await showAfficheEventPickerSheet(
                          context,
                          initialValue: _afficheEvent,
                        );
                        if (event == null || !mounted) {
                          return;
                        }
                        _applyAfficheSelection(event);
                      },
                    );
                    if (next != null && mounted) {
                      setState(() {
                        _clearSourceSelection(resetPlace: false);
                        placeSelection = next;
                        _placeController.text = _placeLabel();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _V5SoftActionRow(
            icon: LucideIcons.plus,
            label: 'Указать свой адрес или ориентир',
            onTap: _openCustomAddressSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildV5AttachSection() {
    return BbV5Section(
      title: 'Прикрепить',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _V5AttachButton(
                  icon: LucideIcons.ticket,
                  label: 'Афиша',
                  active: _afficheEvent != null,
                  onTap: _openAffichePicker,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _V5AttachButton(
                  icon: LucideIcons.gift,
                  label: 'Партнёр',
                  active: _partnerVenue != null,
                  onTap: _openPartnerPicker,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _V5AttachButton(
                  icon: LucideIcons.route,
                  label: 'Маршрут',
                  active: _routeSelection != null,
                  onTap: _openRoutePicker,
                ),
              ),
            ],
          ),
          if (_loadingAfficheEvent)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: CircularProgressIndicator(
                  color: BbV5Colors.ink,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_afficheEvent != null)
            _V5AttachedSourceCard(
              icon: LucideIcons.ticket,
              kicker: 'событие',
              title: _afficheEvent!.title,
              subtitle: _afficheEvent!.placeLabel,
              onOpen: _openAffichePicker,
              onClear: () => setState(_clearSourceSelection),
            )
          else if (_partnerVenue != null)
            _V5AttachedSourceCard(
              icon: LucideIcons.gift,
              kicker: 'партнёр frendly',
              title: '${_partnerVenue!.name} · ${_partnerVenue!.perkShort}',
              onOpen: _openPartnerPicker,
              onClear: () => setState(_clearSourceSelection),
            )
          else if (_routeSelection != null)
            _V5AttachedSourceCard(
              icon: LucideIcons.route,
              kicker: 'маршрут вечера',
              title:
                  '${_routeSelection!.title} · ${_routeSelection!.steps.length} шага',
              onOpen: _openRoutePicker,
              onClear: () => setState(_clearSourceSelection),
            ),
        ],
      ),
    );
  }

  Widget _buildV5CapacitySection({required bool isDatingMode}) {
    return BbV5Section(
      title: 'Сколько вас',
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.users,
                  size: 14,
                  color: BbV5Colors.inkSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Максимум гостей',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (unlimited)
                  const Icon(
                    Icons.all_inclusive_rounded,
                    color: BbV5Colors.ink,
                    size: 26,
                  )
                else
                  Text(
                    '${isDatingMode ? 2 : capacity.round()}',
                    style: bbV5DisplayStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: BbV5Colors.ink,
                inactiveTrackColor: BbV5Colors.hair,
                thumbColor: BbV5Colors.ink,
                overlayColor: BbV5Colors.ink.withValues(alpha: 0.08),
              ),
              child: Slider(
                value: isDatingMode ? 2 : capacity,
                min: 2,
                max: isDatingMode ? 2 : 20,
                divisions: isDatingMode ? 1 : 18,
                onChanged: unlimited || isDatingMode
                    ? null
                    : (value) => setState(() => capacity = value),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  isDatingMode ? '2' : '20',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (!isDatingMode) ...[
              const SizedBox(height: 12),
              _V5WidePill(
                label: 'Без ограничения',
                icon: Icons.all_inclusive_rounded,
                active: unlimited,
                onTap: () => setState(() {
                  unlimited = !unlimited;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildV5LifestyleSection() {
    return BbV5Section(
      title: 'Образ жизни',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _V5SegmentButton(
                  label: 'ЗОЖ',
                  icon: Icons.eco_outlined,
                  active: lifestyle == 'zozh',
                  onTap: () => setState(() => lifestyle = 'zozh'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _V5SegmentButton(
                  label: 'Нейтр.',
                  active: lifestyle == 'neutral',
                  onTap: () => setState(() => lifestyle = 'neutral'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _V5SegmentButton(
                  label: 'Не ЗОЖ',
                  icon: Icons.wine_bar_outlined,
                  active: lifestyle == 'anti',
                  onTap: () => setState(() => lifestyle = 'anti'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _lifestyleHint(),
              style: AppTextStyles.meta.copyWith(
                color: BbV5Colors.inkMute,
                fontSize: 11.5,
                height: 1.625,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildV5PriceSection({required bool isDatingMode}) {
    final options = isDatingMode
        ? const [
            ('host_pays', 'Я оплачиваю всё'),
            ('fifty_fifty', '50/50'),
          ]
        : const [
            ('free', 'Бесплатно'),
            ('fixed', 'Фикс'),
            ('from', 'От'),
            ('upto', 'До'),
            ('range', 'От–До'),
            ('split', 'Скидываемся'),
          ];
    return BbV5Section(
      title: 'Стоимость',
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: options
                  .map(
                    (item) => _V5CreateChip(
                      label: item.$2,
                      active: priceMode == item.$1,
                      height: 36,
                      fontSize: 12,
                      onTap: () => setState(() {
                        priceMode = item.$1;
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (!isDatingMode &&
                priceMode != 'free' &&
                priceMode != 'split') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (priceMode == 'fixed' ||
                      priceMode == 'from' ||
                      priceMode == 'range')
                    Expanded(
                      child: _PriceInput(
                        placeholder: priceMode == 'fixed' ? 'Сумма' : 'От',
                        controller: _priceFromController,
                        onChanged: (value) => setState(() {
                          priceFrom = value;
                        }),
                      ),
                    ),
                  if (priceMode == 'range') ...[
                    const SizedBox(width: 8),
                    Text(
                      '—',
                      style: AppTextStyles.meta
                          .copyWith(color: BbV5Colors.inkMute),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (priceMode == 'upto' || priceMode == 'range')
                    Expanded(
                      child: _PriceInput(
                        placeholder: 'До',
                        controller: _priceToController,
                        onChanged: (value) => setState(() {
                          priceTo = value;
                        }),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '₽',
                    style: AppTextStyles.body.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 14,
                      color: BbV5Colors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _priceHint(isDatingMode),
              style: AppTextStyles.meta.copyWith(
                color: BbV5Colors.inkMute,
                fontSize: 11.5,
                height: 1.625,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildV5AccessSection({
    required bool isDatingMode,
  }) {
    return BbV5Section(
      title: 'Как присоединяются',
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _V5AccessRow(
              active: isDatingMode ? true : accessMode == 'open',
              disabled: isDatingMode,
              icon: Icons.door_front_door_outlined,
              title:
                  isDatingMode ? 'Личное приглашение' : 'Открытое вступление',
              subtitle: isDatingMode
                  ? 'Доступно только приглашённому'
                  : 'Любой может присоединиться сразу',
              onTap: () => setState(() => accessMode = 'open'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1, color: BbV5Colors.hairSoft),
            ),
            _V5AccessRow(
              active: accessMode == 'request' || isDatingMode,
              icon: LucideIcons.shield_check,
              title: 'По заявке',
              subtitle: 'Ты подтверждаешь каждого участника',
              onTap: () => setState(() => accessMode = 'request'),
            ),
            if (!isDatingMode) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: BbV5Colors.hairSoft),
              ),
              _V5AccessRow(
                active: accessMode == 'free',
                icon: LucideIcons.globe,
                title: 'Свободный приход',
                subtitle: 'Без подтверждения, можно прийти и уйти',
                onTap: () => setState(() => accessMode = 'free'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildV5GenderSection() {
    return BbV5Section(
      title: 'Кого приглашаешь',
      child: Row(
        children: [
          Expanded(
            child: _V5SegmentButton(
              label: 'Все',
              active: genderMode == 'all',
              onTap: () => setState(() => genderMode = 'all'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _V5SegmentButton(
              label: 'Девушки',
              active: genderMode == 'female',
              onTap: () => setState(() => genderMode = 'female'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _V5SegmentButton(
              label: 'Парни',
              active: genderMode == 'male',
              onTap: () => setState(() => genderMode = 'male'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildV5DateIdeasSection() {
    return BbV5Section(
      title: 'Сценарий свидания',
      child: Column(
        children: _dateIdeas.map((idea) {
          final active = dateIdea == idea.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _V5DateIdeaCard(
              emoji: idea.$3,
              title: idea.$2,
              subtitle: idea.$4,
              active: active,
              onTap: () => setState(() {
                dateIdea = idea.$1;
                emoji = idea.$3;
                if (_titleController.text.trim().isEmpty ||
                    _titleController.text == 'Свидание на двоих') {
                  _titleController.text = idea.$2;
                }
              }),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildV5VibeSection() {
    return BbV5Section(
      title: 'Настроение',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _createVibes
            .map(
              (item) => _V5CreateChip(
                label: item,
                active: vibe == item,
                height: 40,
                fontSize: 12.5,
                onTap: () => setState(() => vibe = item),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildV5DescriptionSection({
    required bool isDatingMode,
  }) {
    const maxLength = 500;
    return BbV5Section(
      title: 'Описание',
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: _descriptionController,
          builder: (context, _) {
            return Column(
              children: [
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: maxLength,
                  decoration: InputDecoration(
                    hintText: isDatingMode
                        ? 'Как хочешь провести свидание? Что оплачиваешь, какой темп, что важно?'
                        : 'Что за встреча? Чего ждать?',
                    hintStyle: AppTextStyles.bodySoft.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 13.5,
                      height: 1.625,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTextStyles.bodySoft.copyWith(
                    color: BbV5Colors.ink,
                    fontSize: 13.5,
                    height: 1.625,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_descriptionController.text.length}/$maxLength',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildV5AiHelper() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: BbV5Card(
        radius: BbV5Radii.md,
        borderColor: BbV5Colors.hair,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _V5IconBubble(
              icon: LucideIcons.sparkles,
              color: BbV5Colors.terra,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BbV5Kicker('AI compass'),
                  const SizedBox(height: 2),
                  Text(
                    'Напишет описание за тебя',
                    style: bbV5DisplayStyle(fontSize: 13, height: 1.25),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'в твоём тоне, на основе вайба и места',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 10.5,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.arrow_up_right,
              size: 16,
              color: BbV5Colors.inkMute,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildV5VisibilitySection({
    required bool isDatingMode,
  }) {
    return BbV5Section(
      title: 'Кто увидит',
      child: Row(
        children: [
          Expanded(
            child: _V5VisibilityTile(
              active: isDatingMode ? false : visibility == 'public',
              disabled: isDatingMode,
              icon: LucideIcons.globe,
              title: 'Все рядом',
              subtitle: 'видно на радаре',
              onTap: () => setState(() => visibility = 'public'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _V5VisibilityTile(
              active: visibility == 'friends',
              icon: LucideIcons.lock,
              title: isDatingMode ? 'Только приглашённому' : 'По ссылке',
              subtitle: 'по приглашению',
              onTap: () => setState(() => visibility = 'friends'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildV5BottomCta({
    required String publishText,
    required bool canSubmit,
    required bool isDatingMode,
  }) {
    final accent = BbV5Colors.accent;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BbV5Colors.paper.withValues(alpha: 0),
                    BbV5Colors.paper.withValues(alpha: 0.96),
                    BbV5Colors.paper,
                  ],
                  stops: const [0, 0.34, 1],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 20 + safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _creating || !canSubmit ? null : _submitCreate,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: accent,
                    foregroundColor: BbV5Colors.paperHi,
                    disabledBackgroundColor: accent.withValues(alpha: 0.42),
                    disabledForegroundColor:
                        BbV5Colors.paperHi.withValues(alpha: 0.7),
                    textStyle: AppTextStyles.button.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BbV5Colors.paperHi,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isDatingMode) ...[
                              const Icon(LucideIcons.heart, size: 16),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                publishText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(LucideIcons.chevron_right, size: 16),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              IgnorePointer(
                child: Text(
                  isDatingMode
                      ? 'Чат откроется только после принятия инвайта'
                      : 'Чат откроется автоматически, когда кто-то присоединится',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    fontSize: 10.5,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _listBottomPadding(BuildContext context) {
    return _fixedBottomCtaReserve +
        MediaQuery.paddingOf(context).bottom +
        _fixedBottomCtaGap;
  }

  String _previewTitle({
    required bool isDatingMode,
  }) {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      return title;
    }
    if (isDatingMode) {
      return 'Свидание на двоих';
    }
    return 'Название появится здесь';
  }

  String _previewSubtitle(bool isDatingMode) {
    final place = _placeLabel();
    final cap = isDatingMode
        ? '2 человека'
        : unlimited
            ? 'без лимита'
            : 'до ${capacity.round()}';
    return '$place · ${_formatStartsAt(startsAt).toLowerCase()} · $cap';
  }

  String _lifestyleTag() {
    switch (lifestyle) {
      case 'zozh':
        return 'ЗОЖ';
      case 'anti':
        return 'не ЗОЖ';
      case 'neutral':
      default:
        return 'нейтрально';
    }
  }

  String _accessTag(bool isDatingMode) {
    if (isDatingMode) {
      return 'личное';
    }
    switch (accessMode) {
      case 'request':
        return 'по заявке';
      case 'free':
        return 'свободный приход';
      case 'open':
      default:
        return 'открытая';
    }
  }

  String _priceTag() {
    switch (priceMode) {
      case 'split':
        return 'скидываемся';
      case 'host_pays':
        return 'я плачу';
      case 'fifty_fifty':
        return '50/50';
      case 'fixed':
        return priceFrom.isEmpty ? 'фикс' : '$priceFrom ₽';
      case 'from':
        return priceFrom.isEmpty ? 'от суммы' : 'от $priceFrom ₽';
      case 'upto':
        return priceTo.isEmpty ? 'до суммы' : 'до $priceTo ₽';
      case 'range':
        if (priceFrom.isEmpty && priceTo.isEmpty) {
          return 'диапазон';
        }
        return '${priceFrom.isEmpty ? '?' : priceFrom}–${priceTo.isEmpty ? '?' : priceTo} ₽';
      case 'free':
      default:
        return 'бесплатно';
    }
  }

  void _showEmojiPickerHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Выбери иконку в ряду ниже.')),
    );
  }

  Future<void> _submitCreate() async {
    if (_creating) {
      return;
    }

    final isEditMode = widget.editEventId != null;
    final isDatingMode = _mode == CreateMeetupMode.dating;
    final subscription =
        isDatingMode ? ref.read(subscriptionStateProvider).valueOrNull : null;
    final isPremium =
        subscription?.status == 'trial' || subscription?.status == 'active';

    if (isEditMode) {
      if (_titleController.text.trim().isEmpty) {
        _showSubmitError('Добавь название встречи.');
        return;
      }
      if (placeSelection.name.trim().isEmpty) {
        _showSubmitError('Выбери место встречи.');
        return;
      }
      setState(() {
        _creating = true;
      });
      final repository = ref.read(backendRepositoryProvider);
      final submitPlace = placeSelection;
      try {
        await repository.updateHostedEvent(
          widget.editEventId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          emoji: emoji,
          vibe: vibe,
          place: _placeLabel(submitPlace),
          startsAt: startsAt,
          capacity: capacity.round(),
          distanceKm: submitPlace.distanceKm,
          latitude: submitPlace.latitude,
          longitude: submitPlace.longitude,
          lifestyle: lifestyle,
          priceMode: priceMode,
          priceAmountFrom: _priceAmountFrom(),
          priceAmountTo: _priceAmountTo(),
          accessMode: accessMode,
          genderMode: genderMode,
          visibilityMode: visibility,
          joinMode: visibility == 'friends' || accessMode == 'request'
              ? EventJoinMode.request
              : EventJoinMode.open,
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        _showSubmitError('Не получилось сохранить встречу.');
        return;
      } finally {
        if (mounted) {
          setState(() {
            _creating = false;
          });
        }
      }
      if (!mounted) {
        return;
      }
      ref.invalidate(eventDetailProvider(widget.editEventId!));
      ref.invalidate(eventsProvider('nearby'));
      ref.invalidate(mapEventsProvider);
      ref.invalidate(meetupChatsProvider);
      ref.invalidate(hostDashboardProvider);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed(
            AppRoute.eventDetail.name,
            pathParameters: {'eventId': widget.editEventId!},
          );
        }
      }
      return;
    }

    if (isDatingMode && !isPremium) {
      if (!mounted) {
        return;
      }
      context.pushRoute(AppRoute.paywall);
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showSubmitError('Добавь название встречи.');
      return;
    }

    if (placeSelection.name.trim().isEmpty) {
      _showSubmitError('Выбери место встречи.');
      return;
    }

    if (!isDatingMode) {
      ref.read(createMeetupDraftProvider.notifier).state = _buildPublishDraft();
      context.pushRoute(AppRoute.publishMeetup);
      return;
    }

    setState(() {
      _creating = true;
    });

    final repository = ref.read(backendRepositoryProvider);
    try {
      final submitPlace = placeSelection;
      if (!mounted) {
        return;
      }
      final event = await repository.createEvent(
        title: _titleController.text.trim(),
        description: _submitDescription(submitPlace),
        emoji: emoji,
        vibe: vibe,
        place: _placeLabel(submitPlace),
        startsAt: startsAt,
        capacity: isDatingMode ? 2 : capacity.round(),
        distanceKm: submitPlace.distanceKm,
        latitude: submitPlace.latitude,
        longitude: submitPlace.longitude,
        mode: switch (_mode) {
          CreateMeetupMode.dating => 'dating',
          CreateMeetupMode.meetup => 'default',
        },
        lifestyle: lifestyle,
        priceMode: priceMode,
        priceAmountFrom: _priceAmountFrom(),
        priceAmountTo: _priceAmountTo(),
        accessMode: isDatingMode ? 'request' : accessMode,
        genderMode: genderMode,
        visibilityMode: isDatingMode ? 'friends' : visibility,
        joinMode:
            isDatingMode || visibility == 'friends' || accessMode == 'request'
                ? EventJoinMode.request
                : EventJoinMode.open,
        inviteeUserId: widget.inviteeUserId,
        afficheEventId: _afficheEvent?.id,
        routeId:
            _routeSelection?.custom == true ? null : _routeSelection?.routeId,
        route: _routeSelection?.toCustomPayload(),
        communityId: widget.communityId,
        idempotencyKey: _ensureCreateIdempotencyKey(),
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(eventsProvider('nearby'));
      ref.invalidate(mapEventsProvider);
      ref.invalidate(datingDiscoverProvider);
      ref.invalidate(datingLikesProvider);
      ref.invalidate(meetupChatsProvider);
      ref.invalidate(hostDashboardProvider);
      if (widget.communityId case final communityId?) {
        ref.invalidate(communityProvider(communityId));
        ref.invalidate(communitiesFeedProvider);
        ref.invalidate(communitiesProvider);
      }
      if (!mounted) return;
      context.pushReplacementNamed(
        AppRoute.eventDetail.name,
        pathParameters: {'eventId': event.id},
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSubmitError('Не получилось опубликовать встречу.');
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  String _submitDescription(PlaceSelection submitPlace) {
    final cleanDescription = _descriptionController.text.trim();
    if (cleanDescription.isNotEmpty) {
      return cleanDescription;
    }

    final cleanPlace = _placeLabel(submitPlace).trim();
    if (cleanPlace.isNotEmpty) {
      return 'Встречаемся: $cleanPlace';
    }

    final cleanTitle = _titleController.text.trim();
    return cleanTitle.isEmpty ? 'Встреча в Frendly' : cleanTitle;
  }

  CreateMeetupDraft _buildPublishDraft() {
    final submitPlace = placeSelection;
    return CreateMeetupDraft(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      emoji: emoji,
      vibe: vibe,
      place: _placeLabel(submitPlace),
      startsAt: startsAt,
      capacity: capacity.round(),
      distanceKm: submitPlace.distanceKm,
      latitude: submitPlace.latitude,
      longitude: submitPlace.longitude,
      mode: 'default',
      lifestyle: lifestyle,
      priceMode: priceMode,
      priceAmountFrom: _priceAmountFrom(),
      priceAmountTo: _priceAmountTo(),
      accessMode: accessMode,
      genderMode: genderMode,
      visibilityMode: visibility,
      joinMode: visibility == 'friends' || accessMode == 'request'
          ? EventJoinMode.request
          : EventJoinMode.open,
      afficheEventId: _afficheEvent?.id,
      routeId:
          _routeSelection?.custom == true ? null : _routeSelection?.routeId,
      route: _routeSelection?.toCustomPayload(),
      communityId: widget.communityId,
      idempotencyKey: _ensureCreateIdempotencyKey(),
      attachmentTitle: _publishAttachmentTitle(),
      attachmentSubtitle: _publishAttachmentSubtitle(),
      attachmentIcon: _publishAttachmentIcon(),
    );
  }

  String? _publishAttachmentTitle() {
    if (_afficheEvent != null) {
      return 'Афиша · ${_afficheEvent!.title}';
    }
    if (_routeSelection != null) {
      return 'Маршрут · ${_routeSelection!.title}';
    }
    if (_partnerVenue != null) {
      return 'Партнёр · ${_partnerVenue!.name}';
    }
    return null;
  }

  String? _publishAttachmentSubtitle() {
    if (_afficheEvent != null) {
      return _afficheEvent!.venue ?? _afficheEvent!.city;
    }
    if (_routeSelection != null) {
      return _routeSelection!.durationLabel ??
          '${_routeSelection!.steps.length} шага';
    }
    if (_partnerVenue != null) {
      return _partnerVenue!.perkShort;
    }
    return null;
  }

  IconData _publishAttachmentIcon() {
    if (_routeSelection != null) {
      return LucideIcons.route;
    }
    if (_partnerVenue != null) {
      return LucideIcons.gift;
    }
    return LucideIcons.ticket;
  }

  String _ensureCreateIdempotencyKey() {
    return _createIdempotencyKey ??=
        'mobile-create-event-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _showSubmitError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatStartsAt(DateTime value) {
    final now = DateTime.now();
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    if (target == today) {
      return 'Сегодня · $hh:$mm';
    }
    if (target == today.add(const Duration(days: 1))) {
      return 'Завтра · $hh:$mm';
    }
    return '${local.day}.${local.month} · $hh:$mm';
  }

  String _placeLabel([PlaceSelection? selection]) {
    if (_routeSelection case final route?) {
      if (route.custom) {
        return 'Свой маршрут · ${route.steps.length} шага';
      }
      return 'Маршрут: ${route.title}';
    }
    final value = selection ?? placeSelection;
    if (value.address.isEmpty) {
      return value.name;
    }
    return '${value.name} · ${value.address}';
  }

  double? _distanceKmFromLabel(String value) {
    final normalized = value.replaceAll(',', '.');
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  void _applyPartnerVenue(PartnerVenue venue) {
    _partnerVenue = venue;
    _afficheEvent = null;
    _routeSelection = null;
    placeSelection = PlaceSelection(
      name: venue.name,
      address: venue.address,
      distance: venue.distance,
      distanceKm: _distanceKmFromLabel(venue.distance),
      category: 'Партнёр Frendly',
      emoji: venue.emoji,
    );
    _placeController.text = _placeLabel();
    emoji = venue.emoji;
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = 'Встреча в ${venue.name}';
    }
    if (_descriptionController.text.trim().isEmpty) {
      _descriptionController.text = venue.perk;
    }
  }

  String _lifestyleHint() {
    switch (lifestyle) {
      case 'zozh':
        return 'Без алкоголя и курения. Спорт, здоровая еда.';
      case 'anti':
        return 'Можно расслабиться: бар, вино, кальян.';
      case 'neutral':
      default:
        return 'Без ограничений — каждый сам решает.';
    }
  }

  String _priceHint(bool isDatingMode) {
    if (isDatingMode) {
      return priceMode == 'fifty_fifty'
          ? 'Счёт делится поровну.'
          : 'Ты берёшь счёт на себя — это видно сразу.';
    }
    if (priceMode == 'split') {
      return 'Считаем счёт на месте и делим поровну.';
    }
    if (priceMode == 'free') {
      return 'Никаких трат — только компания.';
    }
    return 'Заранее обозначь диапазон, чтобы людям было проще решить.';
  }

  int? _priceAmountFrom() {
    final parsed = int.tryParse(priceFrom);
    return parsed;
  }

  int? _priceAmountTo() {
    final parsed = int.tryParse(priceTo);
    return parsed;
  }

  void _applyAfficheSelection(AfficheEvent event) {
    final previousTitle =
        _afficheEvent == null ? null : _afficheAutoTitle(_afficheEvent!);
    final previousDescription = _afficheEvent?.description;
    final shouldReplaceTitle = _titleController.text.trim().isEmpty ||
        (previousTitle != null &&
            _titleController.text.trim() == previousTitle);
    final shouldReplaceDescription =
        _descriptionController.text.trim().isEmpty ||
            (previousDescription != null &&
                _descriptionController.text.trim() == previousDescription);

    setState(() {
      _afficheEvent = event;
      _partnerVenue = null;
      _routeSelection = null;
      emoji = _emojiForAfficheCategory(event.category);
      startsAt = event.startsAt ?? startsAt;
      priceMode = event.isFree ? 'free' : 'from';
      priceFrom = event.priceFrom?.toString() ?? priceFrom;
      placeSelection = PlaceSelection(
        name: event.venue ?? event.title,
        address: event.address ?? event.city,
        distance: 'Афиша',
        distanceKm: null,
        emoji: emoji,
        latitude: event.latitude,
        longitude: event.longitude,
      );
      _placeController.text = _placeLabel();
      if (shouldReplaceTitle) {
        _titleController.text = _afficheAutoTitle(event);
      }
      if (shouldReplaceDescription) {
        _descriptionController.text = event.description ?? '';
      }
    });
  }

  String _afficheAutoTitle(AfficheEvent event) => 'Идем на ${event.title}';

  String _emojiForAfficheCategory(String category) {
    switch (category) {
      case 'concert':
        return '🎶';
      case 'theatre':
      case 'comedy':
        return '🎭';
      case 'cinema':
        return '🎬';
      case 'festival':
        return '🎪';
      default:
        return '🎟️';
    }
  }

  Future<void> _openAffichePicker() async {
    final event = await showAfficheEventPickerSheet(
      context,
      initialValue: _afficheEvent,
    );
    if (event == null || !mounted) {
      return;
    }
    _applyAfficheSelection(event);
  }

  Future<void> _openPartnerPicker() async {
    final venue = await showPartnerPickerSheet(
      context,
      initialValue: _partnerVenue,
    );
    if (venue == null || !mounted) {
      return;
    }
    setState(() {
      _applyPartnerVenue(venue);
    });
  }

  Future<void> _openRoutePicker() async {
    final route = await showRoutePickerSheet(
      context,
      initialValue: _routeSelection,
    );
    if (route == null || !mounted) {
      return;
    }
    setState(() {
      _applyRouteSelection(route);
    });
  }

  Future<void> _openCustomAddressSheet() async {
    final next = await showModalBottomSheet<PlaceSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CustomAddressSheet(),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() {
      _clearSourceSelection(resetPlace: false);
      placeSelection = next;
      _placeController.text = _placeLabel();
    });
  }

  void _applyRouteSelection(CreateMeetupRouteSelection route) {
    final firstStep = route.steps.isNotEmpty ? route.steps.first : null;
    final firstEmoji = firstStep?.emoji ?? '🗺️';
    final firstPlace = firstStep == null
        ? route.title
        : firstStep.place.trim().isEmpty
            ? firstStep.title
            : firstStep.place.trim();

    _routeSelection = route;
    _afficheEvent = null;
    _partnerVenue = null;
    emoji = firstEmoji;
    placeSelection = PlaceSelection(
      name: firstPlace,
      address: route.custom ? 'Маршрут · ${route.steps.length} шага' : '',
      distance: route.durationLabel ?? '',
      distanceKm: 0,
      category: route.custom ? 'Свой маршрут' : 'Старт маршрута',
      emoji: firstEmoji,
    );
    _placeController.text = _placeLabel();
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = route.title;
    }
  }

  void _clearSourceSelection({bool resetPlace = true}) {
    _afficheEvent = null;
    _partnerVenue = null;
    _routeSelection = null;
    if (resetPlace) {
      placeSelection = _defaultPlaceSelection();
      _placeController.text = _placeLabel();
    }
  }

  PlaceSelection _defaultPlaceSelection() {
    return const PlaceSelection(
      name: '',
      address: '',
    );
  }
}

class _V5TabItem {
  const _V5TabItem({
    required this.label,
    required this.active,
    required this.onTap,
    this.afterDark = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool afterDark;
}

class _V5SegmentedTabs extends StatelessWidget {
  const _V5SegmentedTabs({required this.items});

  final List<_V5TabItem> items;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: BbV5Radii.pill,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _V5TabButton(item: item),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _V5TabButton extends StatelessWidget {
  const _V5TabButton({required this.item});

  final _V5TabItem item;

  @override
  Widget build(BuildContext context) {
    final isAfterDark = item.afterDark;
    return SizedBox(
      height: 40,
      child: FilledButton(
        onPressed: item.onTap,
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          foregroundColor: item.active || isAfterDark
              ? BbV5Colors.paperHi
              : BbV5Colors.inkSoft,
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button.copyWith(
            fontFamily: 'Sora',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: item.active ? BbV5Colors.accent : null,
            gradient: isAfterDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8D5BFF), Color(0xFFFF3EA5)],
                  )
                : null,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            boxShadow: isAfterDark
                ? const [
                    BoxShadow(
                      color: Color(0x66FF3EA5),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAfterDark) ...[
                  const Icon(LucideIcons.moon, size: 13),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _V5Tag extends StatelessWidget {
  const _V5Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontFamily: 'Sora',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: BbV5Colors.inkSoft,
        ),
      ),
    );
  }
}

class _V5CreateChip extends StatelessWidget {
  const _V5CreateChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.height,
    required this.fontSize,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _V5EmojiButton extends StatelessWidget {
  const _V5EmojiButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: BbV5Card(
                radius: BbV5Radii.md,
                padding: EdgeInsets.zero,
                child: Center(
                  child: Icon(
                    icon,
                    size: 24,
                    color: BbV5Colors.ink,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: BbV5Colors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.paper, width: 2),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 12,
                  color: BbV5Colors.paperHi,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _V5RoundChoice extends StatelessWidget {
  const _V5RoundChoice({
    required this.active,
    required this.child,
    required this.onTap,
  });

  final bool active;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          alignment: Alignment.center,
          child: IconTheme.merge(
            data: IconThemeData(
              color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
              size: 18,
            ),
            child: DefaultTextStyle.merge(
              style: AppTextStyles.bodySoft.copyWith(
                color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _V5FieldRow extends StatelessWidget {
  const _V5FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              _V5IconBubble(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bbV5KickerStyle(letterSpacing: 1.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bbV5DisplayStyle(fontSize: 13.5, height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevron_right,
                size: 16,
                color: BbV5Colors.inkMute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5SoftActionRow extends StatelessWidget {
  const _V5SoftActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: BbV5Colors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: BbV5Colors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkSoft,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5IconBubble extends StatelessWidget {
  const _V5IconBubble({
    required this.icon,
    this.color = BbV5Colors.ink,
    this.backgroundColor = BbV5Colors.paper,
    this.borderColor = BbV5Colors.hair,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _CustomAddressSheet extends StatefulWidget {
  const _CustomAddressSheet();

  @override
  State<_CustomAddressSheet> createState() => _CustomAddressSheetState();
}

class _CustomAddressSheetState extends State<_CustomAddressSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canSave = _controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottom),
            decoration: const BoxDecoration(
              color: BbV5Colors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: Offset(0, -20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BbV5Colors.hair,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const BbV5Kicker('выбрать'),
                const SizedBox(height: 4),
                const BbV5HeroTitle(
                  title: 'Свой адрес или ориентир',
                  fontSize: 20,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BbV5Colors.paperHi,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BbV5Colors.hair),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Например: Покровка 12, у входа в Brix',
                      hintStyle: AppTextStyles.body.copyWith(
                        fontFamily: 'Sora',
                        color: BbV5Colors.inkMute,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    style: bbV5DisplayStyle(fontSize: 14, height: 1.25),
                  ),
                ),
                const SizedBox(height: 14),
                BbV5PillButton(
                  label: 'Сохранить адрес',
                  icon: LucideIcons.check,
                  dark: true,
                  height: 48,
                  expanded: true,
                  onPressed: canSave
                      ? () {
                          final value = _controller.text.trim();
                          Navigator.of(context).pop(
                            PlaceSelection(
                              name: value,
                              address: 'Свой адрес',
                              distance: 'Свой адрес',
                              emoji: '📍',
                            ),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _V5AttachButton extends StatelessWidget {
  const _V5AttachButton({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BbV5Radii.md),
        boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
      ),
      child: SizedBox(
        height: 86,
        child: IconButton(
          tooltip: label,
          onPressed: onTap,
          style: IconButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            backgroundColor: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            foregroundColor: active ? BbV5Colors.paperHi : BbV5Colors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BbV5Radii.md),
              side: BorderSide(
                color: active ? BbV5Colors.accent : BbV5Colors.hair,
              ),
            ),
          ),
          icon: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5AttachedSourceCard extends StatelessWidget {
  const _V5AttachedSourceCard({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.onOpen,
    required this.onClear,
    this.subtitle,
  });

  final IconData icon;
  final String kicker;
  final String title;
  final String? subtitle;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: const EdgeInsets.all(14),
        onTap: onOpen,
        child: Row(
          children: [
            _V5IconBubble(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BbV5Kicker(kicker),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bbV5DisplayStyle(fontSize: 13, height: 1.25),
                  ),
                  if (subtitle case final subtitle?) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.inkMute,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            BbV5IconButton(
              icon: LucideIcons.x,
              onPressed: onClear,
              size: 32,
              iconSize: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _V5WidePill extends StatelessWidget {
  const _V5WidePill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: active ? BbV5Colors.accent : BbV5Colors.paperHi,
          foregroundColor: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
          shape: StadiumBorder(
            side: BorderSide(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
          ),
          textStyle: AppTextStyles.button.copyWith(
            fontFamily: 'Sora',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _V5SegmentButton extends StatelessWidget {
  const _V5SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5AccessRow extends StatelessWidget {
  const _V5AccessRow({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _V5IconBubble(
                  icon: icon,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                  backgroundColor:
                      active ? BbV5Colors.accent : BbV5Colors.paper,
                  borderColor: active ? BbV5Colors.accent : BbV5Colors.hair,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bbV5DisplayStyle(fontSize: 13.5, height: 1.25),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          letterSpacing: 0,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: active ? BbV5Colors.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? BbV5Colors.accent : BbV5Colors.hair,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: active
                      ? Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: BbV5Colors.paperHi,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _V5DateIdeaCard extends StatelessWidget {
  const _V5DateIdeaCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: BbV5Radii.md,
      padding: const EdgeInsets.all(12),
      borderColor: active ? BbV5Colors.accent : BbV5Colors.hair,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? BbV5Colors.accent : BbV5Colors.paper,
              borderRadius: BorderRadius.circular(BbV5Radii.sm),
              border: Border.all(color: BbV5Colors.hair),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5DisplayStyle(fontSize: 13.5, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _V5VisibilityTile extends StatelessWidget {
  const _V5VisibilityTile({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(BbV5Radii.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(BbV5Radii.md),
              border: Border.all(
                color: active ? BbV5Colors.accent : BbV5Colors.hair,
              ),
              boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0,
                    color: active
                        ? BbV5Colors.paperHi.withValues(alpha: 0.72)
                        : BbV5Colors.inkMute,
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

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.inkMute),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.caption.copyWith(letterSpacing: 0)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.inkMute,
            ),
          ],
        ),
      ),
    );
  }
}

class _AffichePreviewCard extends StatelessWidget {
  const _AffichePreviewCard({
    required this.event,
    required this.onClear,
  });

  final AfficheEvent event;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final subtitle = [
      if (event.dateLabel != null) event.dateLabel!,
      if (event.timeLabel != null) event.timeLabel!,
      event.priceLabel,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.ticket, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Афиша',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.inkMute,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.meta.copyWith(color: colors.inkMute),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: Icon(Icons.close_rounded, color: colors.inkMute),
          ),
        ],
      ),
    );
  }
}

class _RoutePreviewCard extends StatelessWidget {
  const _RoutePreviewCard({
    required this.route,
    required this.onOpen,
    required this.onClear,
  });

  final CreateMeetupRouteSelection route;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final steps = route.steps.take(5).toList(growable: false);
    final firstEmoji = route.steps.isEmpty ? '🗺️' : route.steps.first.emoji;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.foreground.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.warmStart, colors.warmEnd],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(firstEmoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.route,
                      size: 12,
                      color: colors.foreground.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      route.custom ? 'Свой маршрут' : 'Маршрут вечера',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.foreground.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  route.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySoft.copyWith(
                    color: colors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var index = 0; index < steps.length; index++) ...[
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          steps[index].emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (index != steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            width: 6,
                            height: 1,
                            color: colors.border,
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Заменить'),
              ),
              IconButton(
                tooltip: 'Убрать маршрут',
                onPressed: onClear,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
                padding: EdgeInsets.zero,
                icon: Icon(LucideIcons.x, size: 18, color: colors.inkMute),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerVenueField extends StatelessWidget {
  const _PartnerVenueField({
    required this.venue,
    required this.onOpen,
    required this.onClear,
  });

  final PartnerVenue? venue;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selected = venue;
    if (selected == null) {
      return InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LucideIcons.sparkles,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Партнёрские места',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Список мест с перками по клику',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.inkMute,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(selected.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 12,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Партнёр Frendly',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    if (selected.verified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.badge_check,
                        size: 13,
                        color: colors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selected.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                Text(
                  '${selected.area} · ${selected.distance}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: colors.inkMute,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.gift,
                        size: 13,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          selected.perk,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            children: [
              TextButton(
                onPressed: onOpen,
                child: const Text('Заменить'),
              ),
              IconButton(
                tooltip: 'Убрать партнёра',
                onPressed: onClear,
                icon: Icon(
                  LucideIcons.x,
                  size: 18,
                  color: colors.inkMute,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  const _SegmentCell({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.foreground : colors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? colors.foreground : colors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: active ? colors.primaryForeground : colors.inkSoft,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.meta.copyWith(
                  color: active ? colors.primaryForeground : colors.inkSoft,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopModeCell extends StatelessWidget {
  const _TopModeCell({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: active ? colors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(
            fontSize: 13,
            color: active ? colors.foreground : colors.inkMute,
          ),
        ),
      ),
    );
  }
}

class _PriceModeChip extends StatelessWidget {
  const _PriceModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.foreground : colors.background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? colors.foreground : colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.meta.copyWith(
              color: active ? colors.primaryForeground : colors.inkSoft,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceInput extends StatelessWidget {
  const _PriceInput({
    required this.placeholder,
    required this.controller,
    required this.onChanged,
  });

  final String placeholder;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: TextField(
        controller: controller,
        onChanged: (next) {
          final digitsOnly = next.replaceAll(RegExp(r'\D'), '');
          final sanitized =
              digitsOnly.length > 6 ? digitsOnly.substring(0, 6) : digitsOnly;
          if (controller.text != sanitized) {
            controller.value = TextEditingValue(
              text: sanitized,
              selection: TextSelection.collapsed(offset: sanitized.length),
            );
          }
          onChanged(sanitized);
        },
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: AppTextStyles.body.copyWith(
            fontFamily: 'Sora',
            color: BbV5Colors.inkMute,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
          constraints: const BoxConstraints(minHeight: 44),
        ),
        style: AppTextStyles.body.copyWith(
          fontFamily: 'Sora',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BbV5Colors.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? colors.muted : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.inkSoft),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.body
                          .copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: AppTextStyles.meta),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: active ? colors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: active ? colors.primary : colors.border, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
