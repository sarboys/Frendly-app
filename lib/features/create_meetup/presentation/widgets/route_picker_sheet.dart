import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/evening_routes/application/custom_route_controller.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/widgets/custom_evening_route_form.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/create_event_route.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
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
    barrierColor: BbV5Colors.ink.withValues(alpha: 0.5),
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
  late bool _customMode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _customMode = initial?.custom == true;
    if (_customMode) {
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
    final routesAsync = ref.watch(eveningRouteTemplatesProvider('Москва'));
    final height = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            height: height,
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
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BbV5Colors.hair,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (_customMode)
                  Expanded(
                    child: _CustomRouteFlow(
                      draft: _customRouteDraft,
                      onBack: () => setState(() {
                        _customMode = false;
                      }),
                      onChanged: () => setState(() {}),
                      onSave: _saveCustomRoute,
                    ),
                  )
                else
                  Expanded(
                    child: _ReadyRouteFlow(
                      query: _query,
                      controller: _searchController,
                      routesAsync: routesAsync,
                      selectedRouteId: widget.initialValue?.custom == true
                          ? null
                          : widget.initialValue?.routeId,
                      onChanged: (value) => setState(() {
                        _query = value;
                      }),
                      onCreateRoute: () => setState(() {
                        _customMode = true;
                      }),
                      onPick: (route) => Navigator.of(context).pop(
                        _selectionFromTemplate(route),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

  CreateMeetupRouteSelection _selectionFromTemplate(
    EveningRouteTemplateSummary route,
  ) {
    return CreateMeetupRouteSelection(
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
    );
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

class _ReadyRouteFlow extends StatelessWidget {
  const _ReadyRouteFlow({
    required this.query,
    required this.controller,
    required this.routesAsync,
    required this.selectedRouteId,
    required this.onChanged,
    required this.onCreateRoute,
    required this.onPick,
  });

  final String query;
  final TextEditingController controller;
  final AsyncValue<List<EveningRouteTemplateSummary>> routesAsync;
  final String? selectedRouteId;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreateRoute;
  final ValueChanged<EveningRouteTemplateSummary> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BbV5Kicker('выбрать'),
                    const SizedBox(height: 8),
                    Text(
                      'Маршруты вечера',
                      style: bbV5DisplayStyle(
                        fontSize: 20,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _RouteSheetCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        _RouteSearchField(
          controller: controller,
          onChanged: onChanged,
        ),
        Expanded(
          child: routesAsync.when(
            data: (routes) {
              final visible = _filterRoutes(routes);
              return _ReadyRouteList(
                routes: visible,
                selectedRouteId: selectedRouteId,
                onCreateRoute: onCreateRoute,
                onPick: onPick,
              );
            },
            loading: () => _ReadyRouteLoadingList(
              onCreateRoute: onCreateRoute,
            ),
            error: (_, __) => _ReadyRouteErrorList(
              onCreateRoute: onCreateRoute,
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
        _routeSubtitle(route),
        route.stepsPreview.map((step) => step.venue).join(' '),
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList(growable: false);
  }
}

class _RouteSearchField extends StatelessWidget {
  const _RouteSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: BbV5Colors.paperHi,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: BbV5Colors.hair),
        ),
        child: Row(
          children: [
            const BbV5LucideIcon(
              LucideIcons.search,
              size: 16,
              color: BbV5Colors.inkMute,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Найти…',
                  hintStyle: AppTextStyles.bodySoft.copyWith(
                    color: BbV5Colors.inkMute,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.ink,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyRouteList extends StatelessWidget {
  const _ReadyRouteList({
    required this.routes,
    required this.selectedRouteId,
    required this.onCreateRoute,
    required this.onPick,
  });

  final List<EveningRouteTemplateSummary> routes;
  final String? selectedRouteId;
  final VoidCallback onCreateRoute;
  final ValueChanged<EveningRouteTemplateSummary> onPick;

  @override
  Widget build(BuildContext context) {
    final itemCount = routes.isEmpty ? 2 : routes.length + 1;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CreateRouteRow(onTap: onCreateRoute);
        }
        if (routes.isEmpty) {
          return const _RouteEmptyState();
        }
        final route = routes[index - 1];
        return _ReadyRouteRow(
          route: route,
          selected: route.routeId == selectedRouteId,
          onTap: () => onPick(route),
        );
      },
    );
  }
}

class _ReadyRouteLoadingList extends StatelessWidget {
  const _ReadyRouteLoadingList({
    required this.onCreateRoute,
  });

  final VoidCallback onCreateRoute;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _CreateRouteRow(onTap: onCreateRoute),
        const SizedBox(height: 28),
        const Center(
          child: CircularProgressIndicator(
            color: BbV5Colors.ink,
            strokeWidth: 2,
          ),
        ),
      ],
    );
  }
}

class _ReadyRouteErrorList extends StatelessWidget {
  const _ReadyRouteErrorList({
    required this.onCreateRoute,
  });

  final VoidCallback onCreateRoute;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _CreateRouteRow(onTap: onCreateRoute),
        const SizedBox(height: 28),
        Center(
          child: Text(
            'Не получилось загрузить маршруты',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateRouteRow extends StatelessWidget {
  const _CreateRouteRow({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BbV5Colors.accent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BbV5Colors.accent),
            boxShadow: [
              BoxShadow(
                color: BbV5Colors.ink.withValues(alpha: 0.22),
                blurRadius: 24,
                spreadRadius: -14,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BbV5Colors.paperHi.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const BbV5LucideIcon(
                  LucideIcons.plus,
                  size: 17,
                  color: BbV5Colors.paperHi,
                  weight: 400,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Создать свой маршрут',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: BbV5Colors.paperHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Из 2–6 шагов · сохраним в твоей коллекции',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        height: 1.25,
                        letterSpacing: 0,
                        color: BbV5Colors.paperHi.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const BbV5LucideIcon(
                LucideIcons.chevron_right,
                size: 17,
                color: BbV5Colors.paperHi,
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
    required this.selected,
    required this.onTap,
  });

  final EveningRouteTemplateSummary route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 0,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: const BbV5LucideIcon(
                  LucideIcons.route,
                  size: 17,
                  color: BbV5Colors.terra,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: BbV5Colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _routeSubtitle(route),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        height: 1.25,
                        letterSpacing: 0,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const BbV5LucideIcon(
                LucideIcons.chevron_right,
                size: 17,
                color: BbV5Colors.inkMute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteEmptyState extends StatelessWidget {
  const _RouteEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        'Ничего не нашли',
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(
          color: BbV5Colors.inkMute,
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
    );
  }
}

class _CustomRouteFlow extends StatelessWidget {
  const _CustomRouteFlow({
    required this.draft,
    required this.onBack,
    required this.onChanged,
    required this.onSave,
  });

  final CustomEveningRouteDraft draft;
  final VoidCallback onBack;
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
            onBack: onBack,
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

class _RouteSheetCloseButton extends StatelessWidget {
  const _RouteSheetCloseButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BbV5Colors.paperHi,
          shape: BoxShape.circle,
          border: Border.all(color: BbV5Colors.hair),
        ),
        child: IconButton(
          tooltip: 'Закрыть',
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          icon: const BbV5LucideIcon(
            LucideIcons.x,
            size: 16,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

String _routeSubtitle(EveningRouteTemplateSummary route) {
  final steps = route.stepsPreview
      .map((step) => step.title.trim())
      .where((value) => value.isNotEmpty)
      .take(3)
      .join(' → ');
  final lead = steps.isNotEmpty
      ? steps
      : route.area?.trim().isNotEmpty == true
          ? route.area!.trim()
          : route.blurb.trim();
  final duration = route.durationLabel.trim();
  if (lead.isEmpty) {
    return duration;
  }
  if (duration.isEmpty) {
    return lead;
  }
  return '$lead · $duration';
}
