import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/evening_route_publish_draft.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _aiPromptExamples = [
  '2 человека, вечер пятницы. Хочу 4 точки: прогулка по центру, недорогая паста до 1500, театр, потом тихий бар. Без музеев и катков.',
  'Компания 4 человека, суббота. 5 точек: кофе, выставка, прогулка у воды, ужин 1500-3500, джаз. Район Патрики или центр.',
  'Свидание на двоих завтра вечером. 3 точки: красивый парк, итальянский ресторан, спектакль. Бюджет средний, не шумно.',
];

class AiCreateScreen extends ConsumerStatefulWidget {
  const AiCreateScreen({super.key});

  @override
  ConsumerState<AiCreateScreen> createState() => _AiCreateScreenState();
}

class _AiCreateScreenState extends ConsumerState<AiCreateScreen> {
  final _promptController = TextEditingController();
  CancelToken? _resolveCancelToken;

  var _loading = false;
  var _confirming = false;
  int? _busyStepIndex;
  String? _errorText;
  AiRouteDraft? _draft;

  @override
  void dispose() {
    _cancelResolveRequest('ai_create_disposed');
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    final prompt = _resolvePrompt;
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опиши вечер, чтобы AI собрал маршрут')),
      );
      return;
    }

    _cancelResolveRequest('ai_create_replaced');
    final cancelToken = CancelToken();
    _resolveCancelToken = cancelToken;

    setState(() {
      _loading = true;
      _draft = null;
      _errorText = null;
    });

    try {
      final manualLocation = ref.read(manualLocationProvider);
      final json = await ref.read(backendRepositoryProvider).createAiRouteDraft(
            prompt: prompt,
            city: manualLocation?.city,
            cancelToken: cancelToken,
          );
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return;
      }
      final draft = AiRouteDraft.fromJson(json);
      if (draft.route.steps.isEmpty) {
        setState(() {
          _loading = false;
          _errorText = 'Не удалось собрать маршрут. Попробуй уточнить запрос.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Маршрут не собран')),
        );
        return;
      }
      setState(() {
        _loading = false;
        _draft = draft;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Готово · ${draft.route.steps.length} шага собраны'),
        ),
      );
    } catch (error) {
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return;
      }
      final errorText = _aiRouteDraftErrorText(error);
      setState(() {
        _loading = false;
        _errorText = errorText;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText)),
      );
    } finally {
      if (identical(_resolveCancelToken, cancelToken)) {
        _resolveCancelToken = null;
      }
    }
  }

  String _aiRouteDraftErrorText(Object error) {
    if (error is DioException &&
        _apiErrorCode(error) == 'evening_ai_candidates_not_found') {
      return 'В вашем регионе пока нет подходящих мест или событий. Попробуй другую дату или город.';
    }
    return 'Сервер не ответил. Попробуй еще раз.';
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

  Future<void> _regenerateDraftPlan() async {
    final draft = _draft;
    if (draft == null) {
      await _generatePlan();
      return;
    }
    if (_loading || _busyStepIndex != null) {
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .regenerateAiRouteDraft(draft.draftId);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _draft = AiRouteDraft.fromJson(json);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Собрал другой вариант')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = 'Не удалось заменить маршрут. Попробуй еще раз.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось заменить маршрут')),
      );
    }
  }

  String get _resolvePrompt {
    return _promptController.text.trim();
  }

  void _cancelResolveRequest(String reason) {
    final cancelToken = _resolveCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
  }

  Future<void> _acceptStep(int index) async {
    final draft = _draft;
    if (draft == null || _busyStepIndex != null) {
      return;
    }
    setState(() => _busyStepIndex = index);
    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .acceptAiRouteDraftStep(draft.draftId, index);
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = AiRouteDraft.fromJson(json);
        _busyStepIndex = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busyStepIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось принять шаг')),
      );
    }
  }

  Future<void> _regenerateStep(int index) async {
    final draft = _draft;
    if (draft == null || _busyStepIndex != null) {
      return;
    }
    setState(() => _busyStepIndex = index);
    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .regenerateAiRouteDraftStep(draft.draftId, index);
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = AiRouteDraft.fromJson(json);
        _busyStepIndex = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busyStepIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось заменить шаг')),
      );
    }
  }

  Future<void> _openDraftRoute({required bool launch}) async {
    final draft = _draft;
    if (draft == null || _confirming) {
      return;
    }
    if (!draft.canConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала прими все шаги маршрута')),
      );
      return;
    }

    setState(() => _confirming = true);
    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .confirmAiRouteDraft(draft.draftId);
      if (!mounted) {
        return;
      }
      final confirmed = AiRouteDraft.fromJson(json);
      setState(() {
        _draft = confirmed;
        _confirming = false;
      });
      _openRoute(confirmed.route, launch: launch);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось подтвердить маршрут')),
      );
    }
  }

  void _openRoute(EveningRouteData route, {required bool launch}) {
    if (route.id.isEmpty) {
      context.pushRoute(AppRoute.createMeetup);
      return;
    }
    if (launch) {
      context.pushRoute(
        AppRoute.publishMeetup,
        extra: publishDraftFromEveningRoute(route),
      );
      return;
    }
    context.pushRoute(
      AppRoute.eveningPlan,
      pathParameters: {'routeId': route.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final route = draft?.route;
    final bottomPadding = 120 + MediaQuery.paddingOf(context).bottom;

    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: BbV5TopBar(
                  kicker: 'Frendly · AI compass',
                  title: 'Опиши вечер',
                  accent: 'я соберу план',
                  right: BbV5IconButton(
                    icon: LucideIcons.sparkles,
                    dark: true,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: BbV5Card(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: BbV5Kicker('твой запрос')),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: BbV5Colors.paperHi,
                              shape: BoxShape.circle,
                              border: Border.all(color: BbV5Colors.hair),
                              boxShadow: BbV5Shadows.pill,
                            ),
                            child: IconButton(
                              tooltip: 'Сказать вслух',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => context.pushRoute(
                                AppRoute.aiVoice,
                              ),
                              icon: const Icon(
                                LucideIcons.mic,
                                size: 15,
                                color: BbV5Colors.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _promptController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Например: 2 человека, вечер пятницы, прогулка по центру, паста до 1500, театр, без музеев',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: BbV5Colors.inkMute,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: AppTextStyles.body.copyWith(
                        color: BbV5Colors.ink,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: BbV5Colors.hairSoft),
                    const SizedBox(height: 12),
                    const _PromptGuideBlock(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: BbV5Section(
                title: 'примеры хороших запросов',
                margin: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    for (final entry in _aiPromptExamples.asMap().entries) ...[
                      _PromptExampleCard(
                        index: entry.key + 1,
                        text: entry.value,
                      ),
                      if (entry.key != _aiPromptExamples.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: BbV5PillButton(
                  label: _loading ? 'Собираю вечер…' : 'Собрать план',
                  icon: _loading ? LucideIcons.loader : LucideIcons.wand,
                  dark: true,
                  height: 56,
                  fontSize: 14,
                  expanded: true,
                  onPressed: _loading ? null : _generatePlan,
                ),
              ),
            ),
            if (route == null && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 13,
                        color: BbV5Colors.inkMute,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'AI учитывает погоду, твой круг, афишу города',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11.5,
                            color: BbV5Colors.inkMute,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_errorText != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: BbV5Card(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorText!,
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkMute,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
            if (route != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _GeneratedPlanCard(
                    draft: draft!,
                    route: route,
                    busyStepIndex: _busyStepIndex,
                    confirming: _confirming,
                    refreshing: _loading,
                    onRefresh: _regenerateDraftPlan,
                    onAcceptStep: _acceptStep,
                    onRegenerateStep: _regenerateStep,
                    onEdit: () => _openDraftRoute(launch: false),
                    onCreate: () => _openDraftRoute(launch: true),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
          ],
        ),
      ),
    );
  }
}

class _PromptGuideBlock extends StatelessWidget {
  const _PromptGuideBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5Kicker('что написать'),
        SizedBox(height: 8),
        Text(
          'Опиши вечер одним сообщением. Чем больше деталей, тем точнее AI подберет места.',
          style: TextStyle(
            color: BbV5Colors.inkSoft,
            fontSize: 12.5,
            height: 1.4,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 12),
        _PromptGuideLine(
          icon: LucideIcons.users,
          title: 'Люди',
          text: 'сколько вас и какой формат, свидание, друзья или компания',
        ),
        _PromptGuideLine(
          icon: LucideIcons.map_pin,
          title: 'Места',
          text: 'район, тип точек, что обязательно добавить и что исключить',
        ),
        _PromptGuideLine(
          icon: LucideIcons.wallet,
          title: 'Бюджет',
          text: 'бесплатно, недорого, до 1500, средний или без лимита',
        ),
        _PromptGuideLine(
          icon: LucideIcons.route,
          title: 'Маршрут',
          text: 'сколько точек нужно и в каком порядке они должны идти',
        ),
      ],
    );
  }
}

class _PromptGuideLine extends StatelessWidget {
  const _PromptGuideLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, size: 14, color: BbV5Colors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkSoft,
                  fontSize: 12,
                  height: 1.35,
                  letterSpacing: 0,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: BbV5Colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptExampleCard extends StatelessWidget {
  const _PromptExampleCard({
    required this.index,
    required this.text,
  });

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BbV5Colors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.paperHi,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.meta.copyWith(
                color: BbV5Colors.ink,
                height: 1.42,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedPlanCard extends StatelessWidget {
  const _GeneratedPlanCard({
    required this.draft,
    required this.route,
    required this.busyStepIndex,
    required this.confirming,
    required this.refreshing,
    required this.onRefresh,
    required this.onAcceptStep,
    required this.onRegenerateStep,
    required this.onEdit,
    required this.onCreate,
  });

  final AiRouteDraft draft;
  final EveningRouteData route;
  final int? busyStepIndex;
  final bool confirming;
  final bool refreshing;
  final VoidCallback onRefresh;
  final ValueChanged<int> onAcceptStep;
  final ValueChanged<int> onRegenerateStep;
  final VoidCallback onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final steps = route.steps;
    final hasPlan = steps.isNotEmpty;

    return BbV5Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BbV5Kicker('AI · план вечера'),
                      const SizedBox(height: 6),
                      Text(
                        hasPlan
                            ? '${steps.length} шага · AI маршрут'
                            : 'План пока не собран',
                        style: bbV5DisplayStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
                BbV5IconButton(
                  icon: LucideIcons.refresh_cw,
                  size: 36,
                  iconSize: 14,
                  onPressed: refreshing ? null : onRefresh,
                ),
              ],
            ),
          ),
          if (!hasPlan)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                'План появится после ответа AI.',
                style: AppTextStyles.meta.copyWith(
                  color: BbV5Colors.inkMute,
                  height: 1.45,
                ),
              ),
            )
          else
            for (final entry in steps.asMap().entries)
              _PlanStepRow(
                index: entry.key,
                step: entry.value,
                accepted: draft.acceptedStepIndexes.contains(entry.key),
                active: draft.currentStepIndex == entry.key,
                busy: busyStepIndex == entry.key,
                locked: draft.currentStepIndex != null &&
                    entry.key > draft.currentStepIndex!,
                onAccept: () => onAcceptStep(entry.key),
                onRegenerate: () => onRegenerateStep(entry.key),
              ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: BbV5PillButton(
                    label: 'Править вручную',
                    height: 48,
                    fontSize: 12.5,
                    expanded: true,
                    onPressed: hasPlan && draft.canConfirm && !confirming
                        ? onEdit
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: BbV5PillButton(
                    label: confirming ? 'Готовлю…' : 'Создать встречу',
                    icon: LucideIcons.arrow_up_right,
                    dark: true,
                    height: 48,
                    fontSize: 12.5,
                    expanded: true,
                    onPressed: hasPlan && draft.canConfirm && !confirming
                        ? onCreate
                        : null,
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

class _PlanStepRow extends StatelessWidget {
  const _PlanStepRow({
    required this.index,
    required this.step,
    required this.accepted,
    required this.active,
    required this.busy,
    required this.locked,
    required this.onAccept,
    required this.onRegenerate,
  });

  final int index;
  final EveningRouteStep step;
  final bool accepted;
  final bool active;
  final bool busy;
  final bool locked;
  final VoidCallback onAccept;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final color = _stepColor(step.kind);
    final place = step.venue.trim().isNotEmpty ? step.venue : step.title;
    final subtitle = step.description?.trim().isNotEmpty == true
        ? step.description!.trim()
        : step.address.trim().isNotEmpty
            ? step.address
            : step.distance;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BbV5Colors.hairSoft)),
      ),
      child: Opacity(
        opacity: locked ? 0.58 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.time,
                          style: AppTextStyles.body.copyWith(
                            fontFamily: 'Sora',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: BbV5Colors.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          eveningKindLabel(step.kind).toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontSize: 9,
                            letterSpacing: 1.44,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: color,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontFamily: 'Sora',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: BbV5Colors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkMute,
                            fontSize: 11,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    accepted ? LucideIcons.check : LucideIcons.arrow_up_right,
                    size: accepted ? 18 : 14,
                    color: accepted ? BbV5Colors.accent : BbV5Colors.inkMute,
                  ),
                ],
              ),
              if (active && !accepted) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: BbV5PillButton(
                        label: busy ? 'Меняю…' : 'Заменить',
                        height: 40,
                        fontSize: 12,
                        expanded: true,
                        onPressed: busy ? null : onRegenerate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BbV5PillButton(
                        label: busy ? 'Сохраняю…' : 'Принять шаг',
                        dark: true,
                        height: 40,
                        fontSize: 12,
                        expanded: true,
                        onPressed: busy ? null : onAccept,
                      ),
                    ),
                  ],
                ),
              ] else if (locked) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Сначала прими предыдущий шаг',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _stepColor(EveningStepKind kind) {
  return switch (kind) {
    EveningStepKind.bar => BbV5Colors.terra,
    EveningStepKind.show => BbV5Colors.brandDeep,
    EveningStepKind.active => BbV5Colors.gold,
    EveningStepKind.dinner => BbV5Colors.accent,
    EveningStepKind.wellness => BbV5Colors.rose,
    EveningStepKind.afterparty => BbV5Colors.ink,
    EveningStepKind.followup => BbV5Colors.inkSoft,
  };
}
