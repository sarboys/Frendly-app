import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/evening_routes/application/custom_route_controller.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/widgets/custom_evening_route_form.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteFormScreen extends ConsumerStatefulWidget {
  const RouteFormScreen({super.key});

  @override
  ConsumerState<RouteFormScreen> createState() => _RouteFormScreenState();
}

class _RouteFormScreenState extends ConsumerState<RouteFormScreen> {
  late final CustomEveningRouteDraft _draft = CustomEveningRouteDraft();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BbV5Scaffold(
      child: Stack(
        children: [
          BbV5Page(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
            child: CustomEveningRouteEditorList(
              draft: _draft,
              onChanged: () => setState(() {}),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomEveningRouteSaveBar(
              enabled: _draft.valid,
              onSave: _save,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final route = _draft.toRoute();
    await ref.read(customEveningRoutesProvider.notifier).save(route);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Маршрут сохранён')),
    );
    context.goRoute(AppRoute.eveningRoutes);
  }
}
