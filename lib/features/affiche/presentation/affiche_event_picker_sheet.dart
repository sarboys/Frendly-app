import 'dart:async';

import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_event_card.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_filters.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<AfficheEvent?> showAfficheEventPickerSheet(
  BuildContext context, {
  AfficheEvent? initialValue,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showModalBottomSheet<AfficheEvent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: _AfficheEventPickerSheet(initialValue: initialValue),
    ),
  );
}

class _AfficheEventPickerSheet extends ConsumerStatefulWidget {
  const _AfficheEventPickerSheet({
    this.initialValue,
  });

  final AfficheEvent? initialValue;

  @override
  ConsumerState<_AfficheEventPickerSheet> createState() =>
      _AfficheEventPickerSheetState();
}

class _AfficheEventPickerSheetState
    extends ConsumerState<_AfficheEventPickerSheet> {
  final _queryController = TextEditingController();
  Timer? _queryDebounce;
  String _debouncedQuery = '';
  String? _date;
  String _priceMode = 'any';
  String? _category;

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String value) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final trimmed = value.trim();
      if (_debouncedQuery == trimmed) {
        return;
      }
      setState(() {
        _debouncedQuery = trimmed;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final city = afficheCity(ref);
    final eventsAsync = ref.watch(
      afficheEventsProvider(
        AfficheEventsQuery(
          city: city,
          query: _debouncedQuery,
          date: _date,
          priceMode: _priceMode,
          category: _category,
          limit: 30,
        ),
      ),
    );
    final events = eventsAsync.valueOrNull ?? const <AfficheEvent>[];

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Выбрать из афиши',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.itemTitle.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$city · события и билеты',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.meta.copyWith(
                            color: colors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: AfficheSearchField(
                controller: _queryController,
                onChanged: _handleQueryChanged,
                hintText: 'Концерт, спектакль, матч',
                height: 48,
                iconSize: 18,
                fontSize: 14,
              ),
            ),
            AfficheFilterSection(
              options: afficheDateOptions(),
              activeValue: _date,
              onChanged: (value) => setState(() => _date = value),
            ),
            const SizedBox(height: AppSpacing.xs),
            AfficheFilterSection(
              options: affichePriceOptions,
              activeValue: _priceMode,
              onChanged: (value) => setState(() => _priceMode = value ?? 'any'),
            ),
            const SizedBox(height: AppSpacing.xs),
            AfficheFilterSection(
              options: afficheCategoryOptions,
              activeValue: _category,
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: eventsAsync.isLoading && events.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    )
                  : eventsAsync.hasError
                      ? const _AffichePickerEmpty(
                          message: 'Не получилось загрузить афишу',
                        )
                      : events.isEmpty
                          ? const _AffichePickerEmpty(
                              message:
                                  'Ничего не нашли. Попробуй другую дату или категорию.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemBuilder: (context, index) {
                                final event = events[index];
                                final selected =
                                    widget.initialValue?.id == event.id;
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: selected
                                          ? colors.primary
                                          : Colors.transparent,
                                      width: selected ? 2 : 0,
                                    ),
                                  ),
                                  child: AfficheEventCard(
                                    event: event,
                                    onTap: () =>
                                        Navigator.of(context).pop(event),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemCount: events.length,
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffichePickerEmpty extends StatelessWidget {
  const _AffichePickerEmpty({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.meta.copyWith(
            color: colors.inkMute,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
