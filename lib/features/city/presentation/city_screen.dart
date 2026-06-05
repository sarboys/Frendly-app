import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/city_catalog.dart';
import 'package:mobile2/shared/data/city_search_service.dart';
import 'package:mobile2/shared/data/yandex_city_search_service.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});

  @override
  ConsumerState<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends ConsumerState<CityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCity = 'Москва';
  String? _selectedArea;
  bool _hydrated = false;
  bool _saving = false;
  bool _searching = false;
  String? _error;
  Timer? _searchDebounce;
  List<CitySearchResult> _remoteCities = const [];

  List<RussianCity> get _filteredCities {
    final query = _query.trim();
    if (query.isEmpty) {
      return allRussianCities;
    }

    return cityMatchesFor(query);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownProfileProvider).valueOrNull;
    final currentUser = ref.watch(currentUserProvider);
    final currentCity = profile?.city ?? currentUser?.city;
    if (!_hydrated && currentCity != null && currentCity.isNotEmpty) {
      _selectedCity = currentCity;
      _hydrated = true;
    }
    final filteredCities = _filteredCities;
    final searchResults = mergeCitySearchResults(
      catalogCitySearchResults(_query),
      _remoteCities,
    );

    return DateasyPhoneFrame(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CityHeader(
                saving: _saving,
                onClose: () => context.go('/'),
                onDone: _saveCity,
              ),
              const SizedBox(height: 16),
              _SearchField(
                controller: _searchController,
                onChanged: _onQueryChanged,
              ),
              const SizedBox(height: 12),
              _AutoDetectButton(
                onTap: () => setState(
                  () => _error = 'Выбери город из списка',
                ),
              ),
              if (_error != null) _InlineState(text: _error!),
              if (_query.isEmpty) ...[
                const SizedBox(height: 20),
                _PopularCities(
                  selectedCity: _selectedCity,
                  onSelect: _selectCity,
                ),
              ],
              const SizedBox(height: 20),
              if (_query.trim().isNotEmpty)
                _CitySearchResults(
                  results: searchResults,
                  searching: _searching,
                  selectedCity: _selectedCity,
                  onSelect: _selectCityResult,
                )
              else
                _AllCities(
                  cities: filteredCities,
                  selectedCity: _selectedCity,
                  onSelect: _selectCity,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectCity(RussianCity city) {
    setState(() {
      _selectedCity = city.city;
      _selectedArea = city.area;
      _error = null;
    });
  }

  void _selectCityResult(CitySearchResult city) {
    setState(() {
      _selectedCity = city.city;
      _selectedArea = city.area;
      _error = null;
    });
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _remoteCities = const [];
    });
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _searching = false);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }
      setState(() => _searching = true);
      try {
        final results = await ref
            .read(yandexCitySearchServiceProvider)
            .search(query, limit: 8);
        if (!mounted || _searchController.text.trim() != query) {
          return;
        }
        setState(() {
          _remoteCities = results;
          _searching = false;
        });
      } catch (_) {
        if (!mounted || _searchController.text.trim() != query) {
          return;
        }
        setState(() {
          _remoteCities = const [];
          _searching = false;
        });
      }
    });
  }

  Future<void> _saveCity() async {
    if (_saving) {
      return;
    }
    if (_selectedCity.trim().isEmpty) {
      setState(() => _error = 'Выберите город');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final catalogCity = cityForQuery(_selectedCity);
      await ref.read(profileActionsProvider).updateCity(
            _selectedCity.trim(),
            area: _selectedArea ?? catalogCity?.area,
          );
      if (mounted) {
        context.go('/');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить город';
        });
      }
    }
  }
}

class _CityHeader extends StatelessWidget {
  const _CityHeader({
    required this.saving,
    required this.onClose,
    required this.onDone,
  });

  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _GlassIconButton(
            icon: LucideIcons.chevronLeft,
            onTap: onClose,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Город',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: saving ? null : onDone,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Готово',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DateasyColors.lime,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

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
              color: DateasyColors.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DateasyColors.border),
            ),
            child: Icon(icon, size: 20, color: DateasyColors.foreground),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DateasyColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(
              LucideIcons.search,
              size: 16,
              color: DateasyColors.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: DateasyColors.lime,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: DateasyColors.foreground,
                    ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Найти город',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: DateasyColors.muted,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _AutoDetectButton extends StatelessWidget {
  const _AutoDetectButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DateasyColors.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DateasyColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: dateasyLimeGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.navigation,
                  size: 16,
                  color: DateasyColors.backgroundDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Определить автоматически',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: DateasyColors.foreground,
                      ),
                ),
              ),
              Text(
                'GPS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: DateasyColors.muted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.muted,
            ),
      ),
    );
  }
}

class _PopularCities extends StatelessWidget {
  const _PopularCities({
    required this.selectedCity,
    required this.onSelect,
  });

  final String selectedCity;
  final ValueChanged<RussianCity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Популярные'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final city in defaultRussianCities)
                _CityChip(
                  city: city.label,
                  selected: selectedCity == city.city,
                  onTap: () => onSelect(city),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final String city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? DateasyColors.lime : DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: DateasyColors.border),
        ),
        child: Text(
          city,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: selected
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
        ),
      ),
    );
  }
}

class _AllCities extends StatelessWidget {
  const _AllCities({
    required this.cities,
    required this.selectedCity,
    required this.onSelect,
  });

  final List<RussianCity> cities;
  final String selectedCity;
  final ValueChanged<RussianCity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Все города'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: DateasyColors.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DateasyColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: cities.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Center(
                      child: Text(
                        'Ничего не найдено',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DateasyColors.muted,
                              fontSize: 14,
                            ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < cities.length; index++) ...[
                        _CityRow(
                          city: cities[index].label,
                          selected: selectedCity == cities[index].city,
                          onTap: () => onSelect(cities[index]),
                        ),
                        if (index != cities.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0x0DFFFFFF),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CitySearchResults extends StatelessWidget {
  const _CitySearchResults({
    required this.results,
    required this.searching,
    required this.selectedCity,
    required this.onSelect,
  });

  final List<CitySearchResult> results;
  final bool searching;
  final String selectedCity;
  final ValueChanged<CitySearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Результаты'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: DateasyColors.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DateasyColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Center(
                      child: Text(
                        searching ? 'Ищу в Яндексе' : 'Ничего не найдено',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DateasyColors.muted,
                              fontSize: 14,
                            ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < results.length; index++) ...[
                        _CityRow(
                          city: results[index].label,
                          selected: selectedCity == results[index].city,
                          onTap: () => onSelect(results[index]),
                        ),
                        if (index != results.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0x0DFFFFFF),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final String city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              LucideIcons.mapPin,
              size: 16,
              color: DateasyColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                city,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: DateasyColors.foreground,
                    ),
              ),
            ),
            if (selected)
              const Icon(
                LucideIcons.check,
                size: 16,
                color: DateasyColors.lime,
              ),
          ],
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
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DateasyColors.muted,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
    );
  }
}
