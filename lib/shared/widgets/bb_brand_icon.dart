import 'package:flutter/material.dart';

class BbBrandIcon extends StatelessWidget {
  const BbBrandIcon({
    super.key,
    required this.size,
    this.radius = 24,
    this.boxShadow,
  });

  static const assetPath = 'assets/images/logo-fr-orange.jpg';

  final double size;
  final double radius;
  final List<BoxShadow>? boxShadow;

  static int cacheExtentFor(BuildContext context, double logicalSize) {
    return (logicalSize * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(64, 1024)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    final cacheExtent = cacheExtentFor(context, size);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: boxShadow,
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        cacheWidth: cacheExtent,
        cacheHeight: cacheExtent,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
