import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/city_catalog.dart';
import 'package:mobile2/shared/data/city_search_service.dart';
import 'package:mobile2/shared/data/yandex_city_search_service.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class DateasyTopBar extends ConsumerWidget {
  const DateasyTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(tokenWalletProvider);
    final balance = wallet.valueOrNull?.balance.toString() ?? '0';
    final unreadNotifications = ref.watch(
      notificationUnreadCountProvider.select(
        (value) => value.maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        ),
      ),
    );
    final user = ref.watch(currentUserProvider);
    final city = user?.city?.trim();
    final cityLabel = city == null || city.isEmpty ? 'Москва' : city;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CityPill(
                city: cityLabel,
                onTap: () => _showCityPicker(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/wallet'),
              child: _WalletPill(balance: balance),
            ),
          ),
          const SizedBox(width: 8),
          _IconButtonGlass(
            icon: LucideIcons.bell,
            showDot: unreadNotifications > 0,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/profile'),
            child: SizedBox.square(
              dimension: 48,
              child: Center(child: _ProfileAvatar(imageUrl: user?.avatarUrl)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CityPickerSheet(),
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.balance});

  final String balance;

  @override
  Widget build(BuildContext context) {
    return _GlassBox(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showIcon = constraints.maxWidth >= 54;
          final showUnit = constraints.maxWidth >= 82;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIcon) ...[
                      const Icon(
                        LucideIcons.coins,
                        color: DateasyColors.lime,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      balance,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'Sora',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (showUnit) ...[
                      const SizedBox(width: 4),
                      Text(
                        'FT',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CityPill extends StatelessWidget {
  const _CityPill({required this.city, required this.onTap});

  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        constraints: const BoxConstraints(maxWidth: 154),
        padding: const EdgeInsets.fromLTRB(7, 5, 11, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: DateasyColors.lime,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.mapPin,
                color: Color(0xFF241042),
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Transform.translate(
                offset: const Offset(0, 1.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.foreground,
                              fontFamily: 'Sora',
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              height: 1.1,
                            ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      LucideIcons.chevronDown,
                      color: Color(0xFFC8BEDB),
                      size: 17,
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
}

class _CityPickerSheet extends ConsumerStatefulWidget {
  const _CityPickerSheet();

  @override
  ConsumerState<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<_CityPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _detecting = false;
  bool _searching = false;
  String? _error;
  Timer? _searchDebounce;
  String _query = '';
  List<CitySearchResult> _remoteCities = const [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveCity(String city, {String? area}) async {
    setState(() {
      _detecting = true;
      _error = null;
    });
    try {
      await ref.read(profileActionsProvider).updateCity(
            city,
            area: area,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось сохранить город');
      }
    } finally {
      if (mounted) {
        setState(() => _detecting = false);
      }
    }
  }

  Future<void> _detectCity() async {
    setState(() {
      _detecting = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Разреши геолокацию или выбери город вручную');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final city = _cityFromPlacemark(places.isEmpty ? null : places.first);
      if (city == null) {
        setState(() => _error = 'Не смог определить город');
        return;
      }
      final catalogCity = cityForQuery(city);
      await _saveCity(city, area: catalogCity?.area);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось определить город');
      }
    } finally {
      if (mounted) {
        setState(() => _detecting = false);
      }
    }
  }

  void _onSearchChanged(String value) {
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

  Future<void> _saveCityResult(CitySearchResult city) {
    return _saveCity(city.city, area: city.area);
  }

  String? _cityFromPlacemark(Placemark? place) {
    final values = [
      place?.locality,
      place?.subAdministrativeArea,
      place?.administrativeArea,
    ];
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final currentCity = ref.watch(currentUserProvider)?.city?.trim();
    final searchResults = mergeCitySearchResults(
      catalogCitySearchResults(_query),
      _remoteCities,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: DateasyColors.backgroundDeep,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Город',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              _VpnNotice(),
              const SizedBox(height: 12),
              _DetectButton(
                busy: _detecting,
                onTap: _detecting ? null : _detectCity,
              ),
              const SizedBox(height: 12),
              _CitySearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.pink,
                      ),
                ),
              ],
              const SizedBox(height: 14),
              if (_query.trim().isEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final city in defaultRussianCities)
                      _CityChip(
                        city: city.label,
                        selected: currentCity == city.city,
                        onTap: _detecting
                            ? null
                            : () => _saveCity(city.city, area: city.area),
                      ),
                  ],
                )
              else
                _CitySearchResults(
                  results: searchResults,
                  searching: _searching,
                  currentCity: currentCity,
                  onSelect: _detecting
                      ? null
                      : (city) => unawaited(_saveCityResult(city)),
                ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _detecting
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        context.go('/city');
                      },
                child: const Text(
                  'Открыть полный выбор города',
                  style: TextStyle(
                    color: DateasyColors.lime,
                    fontWeight: FontWeight.w800,
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

class _VpnNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DateasyColors.lime.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DateasyColors.lime.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldAlert, color: DateasyColors.lime),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Если включен VPN, укажи город вручную.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitySearchField extends StatelessWidget {
  const _CitySearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 16, color: DateasyColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: DateasyColors.lime,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Найти город',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
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
    required this.currentCity,
    required this.onSelect,
  });

  final List<CitySearchResult> results;
  final bool searching;
  final String? currentCity;
  final ValueChanged<CitySearchResult>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          searching ? 'Ищу в Яндексе' : 'Ничего не найдено',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final city in results)
          _CityChip(
            city: city.label,
            selected: currentCity == city.city,
            onTap: onSelect == null ? null : () => onSelect!(city),
          ),
      ],
    );
  }
}

class _DetectButton extends StatelessWidget {
  const _DetectButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: DateasyColors.lime,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DateasyColors.backgroundDeep,
                  ),
                )
              : Text(
                  'Определить автоматически',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DateasyColors.backgroundDeep,
                        fontWeight: FontWeight.w900,
                      ),
                ),
        ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? DateasyColors.lime
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          city,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

class _IconButtonGlass extends StatelessWidget {
  const _IconButtonGlass({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Icon(icon, color: DateasyColors.foreground, size: 21),
              ),
            ),
          ),
          if (showDot)
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: DateasyColors.pink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Icon(
              LucideIcons.user,
              color: DateasyColors.muted,
              size: 22,
            )
          : DateasyRemoteImage(
              imageUrl: imageUrl!,
              usage: DateasyImageUsage.avatar,
              fit: BoxFit.cover,
            ),
    );
  }
}
