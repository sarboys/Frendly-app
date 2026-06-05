import 'package:flutter/material.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';

class DateasyRefreshIndicator extends StatelessWidget {
  const DateasyRefreshIndicator({
    super.key,
    required this.child,
    this.onRefresh,
  });

  final Widget child;
  final RefreshCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final refresh = onRefresh;
    if (refresh == null) {
      return child;
    }
    return RefreshIndicator(
      onRefresh: refresh,
      color: DateasyColors.lime,
      backgroundColor: DateasyColors.surface,
      child: child,
    );
  }
}
