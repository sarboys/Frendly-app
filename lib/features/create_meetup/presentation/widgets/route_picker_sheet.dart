import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/evening_routes/application/custom_route_controller.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/widgets/custom_evening_route_form.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/create_event_route.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ),
    ),
  );
}

class _RoutePickerSheet extends ConsumerStatefulWidget {
  const _RoutePickerSheet({
    this.initialValue,
  });

  final CreateMeetupRouteSelection? initialValue;

  @override
  ConsumerState<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends ConsumerState<_RoutePickerSheet> {
  final _searchController = TextEditingController();
  late final CustomEveningRouteDraft _customRouteDraft;
  _RoutePickerTab _tab = _RoutePickerTab.presets;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    if (initial?.custom == true) {
      _tab = _RoutePickerTab.custom;
      _customRouteDraft = CustomEveningRouteDraft(
        title: initial!.title,
        duration: initial.durationLabel,
        steps: _draftStepsFromInitialValue(initial),
      );
    } else {
      _customRouteDraft = CustomEveningRouteDraft();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customRouteDraft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final routesAsync = ref.watch(eveningRouteTemplatesProvider('Москва'));

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
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
                      gradient: LinearGradient(
                        colors: [colors.warmStart, colors.warmEnd],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.route,
                      size: 18,
                      color: colors.secondary,
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
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Готовый или свой — несколько мест за вечер',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.inkMute,
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
                        color: colors.inkSoft,
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
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _RouteTabButton(
                        active: _tab == _RoutePickerTab.presets,
                        icon: LucideIcons.sparkles,
                        label: 'Готовые',
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
                      draft: _customRouteDraft,
                      onChanged: () => setState(() {}),
                      onSave: _saveCustomRoute,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCustomRoute() async {
    if (!_customRouteDraft.valid) {
      return;
    }
    final route = _customRouteDraft.toRoute();
    await ref.read(customEveningRoutesProvider.notifier).save(route);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      _selectionFromCustomRoute(route),
    );
  }

  List<CustomEveningRouteStepDraft> _draftStepsFromInitialValue(
    CreateMeetupRouteSelection initial,
  ) {
    final steps = initial.steps
        .map(
          (step) => CustomEveningRouteStepDraft(
            iconIndex: customEveningRouteIconIndexForEmoji(step.emoji),
            place: step.title,
            subtitle: step.place,
          ),
        )
        .toList(growable: true);
    while (steps.length < 2) {
      steps.add(
        CustomEveningRouteStepDraft(iconIndex: steps.length),
      );
    }
    return steps;
  }

  CreateMeetupRouteSelection _selectionFromCustomRoute(
    CustomEveningRoute route,
  ) {
    return CreateMeetupRouteSelection(
      title: route.title,
      durationLabel: route.duration,
      custom: true,
      steps: [
        for (final step in route.steps)
          CreateMeetupRouteStep(
            time: '',
            emoji: customEveningRouteEmojiForIconKey(step.iconKey),
            title: step.place,
            place: step.subtitle,
          ),
      ],
    );
  }
}

enum _RoutePickerTab { presets, custom }

class _RouteTabButton extends StatelessWidget {
  const _RouteTabButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
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
          color: active ? colors.background : Colors.transparent,
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
              color: active ? colors.foreground : colors.inkMute,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: active ? colors.foreground : colors.inkMute,
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
    required this.onChanged,
    required this.onPick,
  });

  final String query;
  final TextEditingController controller;
  final AsyncValue<List<EveningRouteTemplateSummary>> routesAsync;
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
              color: colors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: colors.inkMute,
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
                        color: colors.inkMute,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    style: AppTextStyles.bodySoft.copyWith(
                      color: colors.foreground,
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
                      color: colors.inkMute,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: visible.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final route = visible[index];
                  return _ReadyRouteRow(
                    route: route,
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
                  color: colors.inkMute,
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

class _ReadyRouteRow extends StatelessWidget {
  const _ReadyRouteRow({
    required this.route,
    required this.onTap,
  });

  final EveningRouteTemplateSummary route;
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
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
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
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 14,
                            color: colors.inkMute,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              route.durationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: colors.inkMute,
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
                                color: colors.inkMute.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          Icon(
                            LucideIcons.map_pin,
                            size: 14,
                            color: colors.inkMute,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              route.area ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: colors.inkMute,
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
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${steps.length} шагов',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.inkMute,
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
                _RouteStepDots(steps: steps),
                const Spacer(),
                if (route.totalSavings > 0)
                  Text(
                    '−${route.totalSavings} ₽',
                    style: AppTextStyles.meta.copyWith(
                      color: colors.primary,
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
  });

  final List<EveningRouteTemplateStepPreview> steps;

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
              gradient: LinearGradient(
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
              color: colors.border,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
        ],
      ],
    );
  }
}

class _CustomRouteTab extends StatelessWidget {
  const _CustomRouteTab({
    required this.draft,
    required this.onChanged,
    required this.onSave,
  });

  final CustomEveningRouteDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomEveningRouteEditorList(
            draft: draft,
            onChanged: onChanged,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
        CustomEveningRouteSaveBar(
          enabled: draft.valid,
          onSave: onSave,
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
        ),
      ],
    );
  }
}
