import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/create_event_route.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _stepEmojis = [
  '🍷',
  '🍝',
  '⚽',
  '🥟',
  '☕',
  '🎬',
  '🎶',
  '🎨',
  '🌿',
  '🥂',
  '🌙',
  '🏃',
];

class CreateMeetupRouteSelection {
  const CreateMeetupRouteSelection({
    required this.title,
    required this.steps,
    this.routeId,
    this.durationLabel,
    this.totalSavings = 0,
    this.custom = false,
  });

  final String? routeId;
  final String title;
  final String? durationLabel;
  final int totalSavings;
  final bool custom;
  final List<CreateMeetupRouteStep> steps;

  CreateEventRoutePayload? toCustomPayload() {
    if (!custom) {
      return null;
    }

    return CreateEventRoutePayload(
      title: title,
      durationLabel: durationLabel,
      steps: steps
          .map(
            (step) => CreateEventRouteStepPayload(
              time: step.time,
              emoji: step.emoji,
              title: step.title,
              place: step.place,
            ),
          )
          .toList(growable: false),
    );
  }
}

class CreateMeetupRouteStep {
  const CreateMeetupRouteStep({
    required this.time,
    required this.emoji,
    required this.title,
    required this.place,
  });

  final String time;
  final String emoji;
  final String title;
  final String place;
}

Future<CreateMeetupRouteSelection?> showRoutePickerSheet(
  BuildContext context, {
  CreateMeetupRouteSelection? initialValue,
  bool dark = false,
}) {
  final container = ProviderScope.containerOf(context, listen: false);

  return showModalBottomSheet<CreateMeetupRouteSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: _RoutePickerSheet(
        initialValue: initialValue,
        dark: dark,
      ),
    ),
  );
}

class _RoutePickerSheet extends ConsumerStatefulWidget {
  const _RoutePickerSheet({
    this.initialValue,
    required this.dark,
  });

  final CreateMeetupRouteSelection? initialValue;
  final bool dark;

  @override
  ConsumerState<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends ConsumerState<_RoutePickerSheet> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController(text: 'Свой маршрут');
  late final List<_EditableRouteStep> _steps;
  _RoutePickerTab _tab = _RoutePickerTab.presets;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    if (initial?.custom == true) {
      _tab = _RoutePickerTab.custom;
      _titleController.text = initial!.title;
      _steps = initial.steps
          .map(
            (step) => _EditableRouteStep(
              time: step.time,
              emoji: step.emoji,
              title: step.title,
              place: step.place,
            ),
          )
          .toList(growable: true);
    } else {
      _steps = [
        _EditableRouteStep(
          time: '19:00',
          emoji: '🍷',
          title: 'Аперитив',
          place: '',
        ),
        _EditableRouteStep(
          time: '21:00',
          emoji: '🍝',
          title: 'Ужин',
          place: '',
        ),
      ];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final routesAsync = ref.watch(eveningRouteTemplatesProvider('Москва'));
    final dark = widget.dark;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: dark ? AppColors.adBg : colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? AppColors.adBorder : colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.adSurface : null,
                      gradient: dark
                          ? null
                          : LinearGradient(
                              colors: [colors.warmStart, colors.warmEnd],
                            ),
                      border:
                          dark ? Border.all(color: AppColors.adBorder) : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.route,
                      size: 18,
                      color: dark ? AppColors.adMagenta : colors.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Маршрут вечера',
                          style: AppTextStyles.itemTitle.copyWith(
                            fontSize: 18,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: dark ? AppColors.adFg : colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Готовый или свой — несколько мест за вечер',
                          style: AppTextStyles.caption.copyWith(
                            color: dark ? AppColors.adFgMute : colors.inkMute,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(context).pop(),
                      constraints:
                          const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: dark ? AppColors.adFgSoft : colors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dark ? AppColors.adSurface : colors.muted,
                  borderRadius: BorderRadius.circular(18),
                  border: dark ? Border.all(color: AppColors.adBorder) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _RouteTabButton(
                        active: _tab == _RoutePickerTab.presets,
                        icon: LucideIcons.sparkles,
                        label: 'Готовые',
                        dark: dark,
                        onTap: () =>
                            setState(() => _tab = _RoutePickerTab.presets),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _RouteTabButton(
                        active: _tab == _RoutePickerTab.custom,
                        icon: LucideIcons.pencil,
                        label: 'Свой',
                        dark: dark,
                        onTap: () =>
                            setState(() => _tab = _RoutePickerTab.custom),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _tab == _RoutePickerTab.presets
                  ? _ReadyRoutesTab(
                      query: _query,
                      controller: _searchController,
                      routesAsync: routesAsync,
                      dark: dark,
                      onChanged: (value) => setState(() {
                        _query = value;
                      }),
                      onPick: (route) => Navigator.of(context).pop(
                        CreateMeetupRouteSelection(
                          routeId: route.routeId,
                          title: route.title,
                          durationLabel: route.durationLabel,
                          totalSavings: route.totalSavings,
                          steps: route.stepsPreview
                              .map(
                                (step) => CreateMeetupRouteStep(
                                  time: step.time ?? '',
                                  emoji: step.emoji,
                                  title: step.title,
                                  place: step.venue,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    )
                  : _CustomRouteTab(
                      titleController: _titleController,
                      steps: _steps,
                      dark: dark,
                      onChanged: () => setState(() {}),
                      onAddStep: _addStep,
                      onRemoveStep: _removeStep,
                      onSave: _saveCustomRoute,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addStep() {
    setState(() {
      _steps.add(
        _EditableRouteStep(
          time: '22:00',
          emoji: '🌙',
          title: '',
          place: '',
        ),
      );
    });
  }

  void _removeStep(_EditableRouteStep step) {
    if (_steps.length <= 1) {
      return;
    }
    setState(() {
      _steps.remove(step);
      step.dispose();
    });
  }

  void _saveCustomRoute() {
    if (_steps.length < 2 ||
        _steps.any((step) => step.titleController.text.trim().isEmpty)) {
      return;
    }
    final steps = _steps.map((step) => step.value()).toList(growable: false);
    final title = _titleController.text.trim().isEmpty
        ? 'Свой маршрут'
        : _titleController.text.trim();
    Navigator.of(context).pop(
      CreateMeetupRouteSelection(
        title: title,
        durationLabel: '${steps.length} шага',
        custom: true,
        steps: steps,
      ),
    );
  }
}

enum _RoutePickerTab { presets, custom }

class _RouteTabButton extends StatelessWidget {
  const _RouteTabButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.dark,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: active
              ? dark
                  ? AppColors.adBg
                  : colors.background
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: colors.foreground.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active
                  ? dark
                      ? AppColors.adFg
                      : colors.foreground
                  : dark
                      ? AppColors.adFgMute
                      : colors.inkMute,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: active
                    ? dark
                        ? AppColors.adFg
                        : colors.foreground
                    : dark
                        ? AppColors.adFgMute
                        : colors.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyRoutesTab extends StatelessWidget {
  const _ReadyRoutesTab({
    required this.query,
    required this.controller,
    required this.routesAsync,
    required this.dark,
    required this.onChanged,
    required this.onPick,
  });

  final String query;
  final TextEditingController controller;
  final AsyncValue<List<EveningRouteTemplateSummary>> routesAsync;
  final bool dark;
  final ValueChanged<String> onChanged;
  final ValueChanged<EveningRouteTemplateSummary> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: dark ? AppColors.adSurface : colors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dark ? AppColors.adBorder : colors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: dark ? AppColors.adFgMute : colors.inkMute,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Найти маршрут или место',
                      hintStyle: AppTextStyles.bodySoft.copyWith(
                        color: dark ? AppColors.adFgMute : colors.inkMute,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    style: AppTextStyles.bodySoft.copyWith(
                      color: dark ? AppColors.adFg : colors.foreground,
                      fontSize: 13.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: routesAsync.when(
            data: (routes) {
              final visible = _filterRoutes(routes);
              if (visible.isEmpty) {
                return Center(
                  child: Text(
                    'Ничего не нашлось — попробуй собрать свой маршрут',
                    style: AppTextStyles.body.copyWith(
                      color: dark ? AppColors.adFgMute : colors.inkMute,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: visible.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CreateCustomRouteRow(dark: dark);
                  }
                  final route = visible[index - 1];
                  return _ReadyRouteRow(
                    route: route,
                    dark: dark,
                    onTap: () => onPick(route),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                'Не получилось загрузить маршруты',
                style: AppTextStyles.body.copyWith(
                  color: dark ? AppColors.adFgMute : colors.inkMute,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<EveningRouteTemplateSummary> _filterRoutes(
    List<EveningRouteTemplateSummary> routes,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return routes;
    }
    return routes.where((route) {
      final haystack = [
        route.title,
        route.blurb,
        route.area,
        route.stepsPreview.map((step) => step.venue).join(' '),
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList(growable: false);
  }
}

class _CreateCustomRouteRow extends StatelessWidget {
  const _CreateCustomRouteRow({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark ? AppColors.adMagenta : BbV5Colors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.pushRoute(AppRoute.newEveningRoute);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: background),
            boxShadow: BbV5Shadows.ink,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.plus,
                  size: 18,
                  color: BbV5Colors.paperHi,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Создать свой маршрут',
                      style: AppTextStyles.itemTitle.copyWith(
                        fontSize: 13.5,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: dark ? AppColors.adFg : BbV5Colors.paperHi,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Из 2–6 шагов · сохраним в твоей коллекции',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        height: 1.25,
                        color: (dark ? AppColors.adFg : BbV5Colors.paperHi)
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevron_right,
                size: 17,
                color: dark ? AppColors.adFg : BbV5Colors.paperHi,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyRouteRow extends StatelessWidget {
  const _ReadyRouteRow({
    required this.route,
    required this.dark,
    required this.onTap,
  });

  final EveningRouteTemplateSummary route;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final steps = route.stepsPreview.take(4).toList(growable: false);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? AppColors.adSurface : colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? AppColors.adBorder : colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.itemTitle.copyWith(
                          fontSize: 14.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: dark ? AppColors.adFg : colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 14,
                            color: dark ? AppColors.adFgMute : colors.inkMute,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              route.durationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color:
                                    dark ? AppColors.adFgMute : colors.inkMute,
                                fontSize: 11.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '·',
                              style: AppTextStyles.caption.copyWith(
                                color:
                                    (dark ? AppColors.adFgMute : colors.inkMute)
                                        .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          Icon(
                            LucideIcons.map_pin,
                            size: 14,
                            color: dark ? AppColors.adFgMute : colors.inkMute,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              route.area ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color:
                                    dark ? AppColors.adFgMute : colors.inkMute,
                                fontSize: 11.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.adBg : colors.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${steps.length} шагов',
                    style: AppTextStyles.caption.copyWith(
                      color: dark ? AppColors.adFgMute : colors.inkMute,
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.42,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _RouteStepDots(steps: steps, dark: dark),
                const Spacer(),
                if (route.totalSavings > 0)
                  Text(
                    '−${route.totalSavings} ₽',
                    style: AppTextStyles.meta.copyWith(
                      color: dark ? AppColors.adCyan : colors.primary,
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
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

class _RouteStepDots extends StatelessWidget {
  const _RouteStepDots({
    required this.steps,
    required this.dark,
  });

  final List<EveningRouteTemplateStepPreview> steps;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: dark ? AppColors.adBg : null,
              gradient: dark
                  ? null
                  : LinearGradient(
                      colors: [colors.warmStart, colors.warmEnd],
                    ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              steps[index].emoji,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          if (index != steps.length - 1)
            Container(
              width: 12,
              height: 1,
              color: dark ? AppColors.adBorder : colors.border,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
        ],
      ],
    );
  }
}

class _CustomRouteTab extends StatelessWidget {
  const _CustomRouteTab({
    required this.titleController,
    required this.steps,
    required this.dark,
    required this.onChanged,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onSave,
  });

  final TextEditingController titleController;
  final List<_EditableRouteStep> steps;
  final bool dark;
  final VoidCallback onChanged;
  final VoidCallback onAddStep;
  final ValueChanged<_EditableRouteStep> onRemoveStep;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final canSave = steps.length >= 2 &&
        steps.every((step) => step.titleController.text.trim().isNotEmpty);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            children: [
              _RouteSectionLabel('Название', dark: dark),
              const SizedBox(height: 6),
              _RouteBoxTextField(
                controller: titleController,
                hint: 'Свой маршрут',
                dark: dark,
                height: 44,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 12),
              _RouteSectionLabel('Шаги вечера', dark: dark),
              const SizedBox(height: 6),
              for (var index = 0; index < steps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CustomStepRow(
                    step: steps[index],
                    index: index,
                    canRemove: steps.length > 1,
                    dark: dark,
                    onChanged: onChanged,
                    onRemove: () => onRemoveStep(steps[index]),
                  ),
                ),
              const SizedBox(height: 6),
              _DashedBorder(
                color: dark ? AppColors.adBorder : colors.border,
                radius: 16,
                child: InkWell(
                  onTap: onAddStep,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.plus,
                          size: 16,
                          color: dark ? AppColors.adFgSoft : colors.inkSoft,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Добавить шаг',
                          style: AppTextStyles.bodySoft.copyWith(
                            color: dark ? AppColors.adFgSoft : colors.inkSoft,
                            fontSize: 12.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Этот маршрут будет только в твоей встрече и не появится в общей вкладке «Маршруты».',
                  style: AppTextStyles.bodySoft.copyWith(
                    color: dark ? AppColors.adFgMute : colors.inkMute,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: InkWell(
            onTap: canSave ? onSave : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: canSave
                    ? dark
                        ? AppColors.adMagenta
                        : colors.foreground
                    : dark
                        ? AppColors.adSurfaceElev
                        : colors.muted,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                'Сохранить маршрут',
                style: AppTextStyles.button.copyWith(
                  color: canSave
                      ? dark
                          ? AppColors.adFg
                          : colors.background
                      : dark
                          ? AppColors.adFgMute
                          : colors.inkMute,
                  fontSize: 14,
                  height: 1.1,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomStepRow extends StatelessWidget {
  const _CustomStepRow({
    required this.step,
    required this.index,
    required this.canRemove,
    required this.dark,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableRouteStep step;
  final int index;
  final bool canRemove;
  final bool dark;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? AppColors.adSurface : colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? AppColors.adBorder : colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: _RouteBoxTextField(
              controller: step.timeController,
              hint: '19:00',
              dark: dark,
              height: 40,
              contentPadding: EdgeInsets.zero,
              borderRadius: 12,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.datetime,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          _EmojiPickerButton(
            value: step.emojiController.text,
            dark: dark,
            onChanged: (emoji) {
              step.emojiController.text = emoji;
              onChanged();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteInlineTextField(
                  controller: step.titleController,
                  hint: index == 0 ? 'Например: футбол' : 'Что делаем',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: dark ? AppColors.adFg : colors.foreground,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 2),
                _RouteInlineTextField(
                  controller: step.placeController,
                  hint: 'Место (необязательно)',
                  fontSize: 11.5,
                  color: dark ? AppColors.adFgMute : colors.inkMute,
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              onPressed: onRemove,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              icon: Icon(
                LucideIcons.trash_2,
                size: 16,
                color: dark ? AppColors.adFgMute : colors.inkMute,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmojiPickerButton extends StatelessWidget {
  const _EmojiPickerButton({
    required this.value,
    required this.dark,
    required this.onChanged,
  });

  final String value;
  final bool dark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final emoji = value.trim().isEmpty ? '✨' : value.trim();

    return PopupMenuButton<String>(
      tooltip: 'Выбрать emoji',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 44),
      color: dark ? AppColors.adBg : colors.background,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? AppColors.adBorder : colors.border),
      ),
      constraints: const BoxConstraints.tightFor(width: 230),
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.all(6),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final item in _stepEmojis)
                _EmojiMenuButton(
                  emoji: item,
                  selected: item == emoji,
                  dark: dark,
                  onTap: () => Navigator.of(context).pop(item),
                ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: dark ? AppColors.adBg : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? AppColors.adBorder : colors.border),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _EmojiMenuButton extends StatelessWidget {
  const _EmojiMenuButton({
    required this.emoji,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected
              ? dark
                  ? AppColors.adSurface
                  : colors.muted
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _RouteSectionLabel extends StatelessWidget {
  const _RouteSectionLabel(
    this.text, {
    required this.dark,
  });

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text.toUpperCase(),
      style: bbV5KickerStyle(
        color: dark ? AppColors.adFgMute : colors.inkMute,
      ),
    );
  }
}

class _RouteBoxTextField extends StatelessWidget {
  const _RouteBoxTextField({
    required this.controller,
    required this.hint,
    required this.dark,
    required this.onChanged,
    this.height = 40,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w600,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 14),
    this.borderRadius = 16,
    this.keyboardType,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String hint;
  final bool dark;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry contentPadding;
  final double borderRadius;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: textAlign,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: contentPadding,
          hintText: hint,
          hintStyle: AppTextStyles.meta.copyWith(
            color: dark ? AppColors.adFgMute : colors.inkMute,
            fontSize: fontSize,
            height: 1.15,
          ),
          filled: true,
          fillColor: dark ? AppColors.adBg : colors.background,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: dark ? AppColors.adBorder : colors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: dark ? AppColors.adMagenta : colors.foreground,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: dark ? AppColors.adBorder : colors.border,
            ),
          ),
        ),
        style: AppTextStyles.body.copyWith(
          color: dark ? AppColors.adFg : colors.foreground,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.15,
          letterSpacing: 0,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _RouteInlineTextField extends StatelessWidget {
  const _RouteInlineTextField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.fontSize,
    required this.color,
    this.fontWeight = FontWeight.w500,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SizedBox(
      height: 20,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: AppTextStyles.bodySoft.copyWith(
            color: colors.inkMute,
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
        style: AppTextStyles.bodySoft.copyWith(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.15,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.child,
    required this.color,
    required this.radius,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 6;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _EditableRouteStep {
  _EditableRouteStep({
    required String time,
    required String emoji,
    required String title,
    required String place,
  })  : timeController = TextEditingController(text: time),
        emojiController = TextEditingController(text: emoji),
        titleController = TextEditingController(text: title),
        placeController = TextEditingController(text: place);

  final TextEditingController timeController;
  final TextEditingController emojiController;
  final TextEditingController titleController;
  final TextEditingController placeController;

  CreateMeetupRouteStep value() {
    final emoji = emojiController.text.trim();
    return CreateMeetupRouteStep(
      time: timeController.text.trim(),
      emoji: emoji.isEmpty ? '✨' : emoji,
      title: titleController.text.trim(),
      place: placeController.text.trim(),
    );
  }

  void dispose() {
    timeController.dispose();
    emojiController.dispose();
    titleController.dispose();
    placeController.dispose();
  }
}
