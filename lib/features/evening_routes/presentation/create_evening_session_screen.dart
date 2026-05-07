import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_screen.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/evening_route_template_plan_mapper.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateEveningSessionScreen extends ConsumerWidget {
  const CreateEveningSessionScreen({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(eveningRouteTemplateProvider(templateId));

    return detailAsync.when(
      data: (route) => EveningPlanScreen(
        routeId: routeIdFromTemplate(route),
        initialRoute: routeDataFromTemplate(route),
        autoOpenLaunch: true,
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => EveningPlanScreen(
        routeId: templateId,
        autoOpenLaunch: true,
      ),
    );
  }
}
