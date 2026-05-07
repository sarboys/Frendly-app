import 'dart:typed_data';

import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class BbProfilePhotoGallery extends StatefulWidget {
  const BbProfilePhotoGallery({
    required this.displayName,
    required this.photos,
    super.key,
    this.height = 320,
    this.initialPage = 0,
    this.photoPreviews = const {},
    this.onPageChanged,
  });

  final String displayName;
  final List<ProfilePhoto> photos;
  final double height;
  final int initialPage;
  final Map<String, Uint8List> photoPreviews;
  final ValueChanged<int>? onPageChanged;

  @override
  State<BbProfilePhotoGallery> createState() => _BbProfilePhotoGalleryState();
}

class _BbProfilePhotoGalleryState extends State<BbProfilePhotoGallery> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(
      0,
      widget.photos.isEmpty ? 0 : widget.photos.length - 1,
    );
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BbProfilePhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxPage = widget.photos.isEmpty ? 0 : widget.photos.length - 1;
    final nextPage = widget.initialPage.clamp(0, maxPage);
    final lengthChanged = oldWidget.photos.length != widget.photos.length;
    final pageChanged = oldWidget.initialPage != widget.initialPage;

    if (pageChanged || lengthChanged) {
      _currentPage = nextPage;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(nextPage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ClipRRect(
      borderRadius: AppRadii.cardBorder,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.photos.isEmpty)
              _EmptyPhotoSurface(displayName: widget.displayName)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cacheSize = _galleryCacheSize(
                    width: constraints.maxWidth,
                    height: widget.height,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  );
                  return PageView.builder(
                    key: const ValueKey('profile-photo-gallery-pageview'),
                    controller: _pageController,
                    itemCount: widget.photos.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      widget.onPageChanged?.call(index);
                    },
                    itemBuilder: (context, index) {
                      final photo = widget.photos[index];
                      final previewBytes = widget.photoPreviews[photo.id];
                      return DecoratedBox(
                        decoration: BoxDecoration(color: colors.muted),
                        child: previewBytes != null
                            ? Image.memory(
                                previewBytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                cacheWidth: cacheSize.width,
                                cacheHeight: cacheSize.height,
                              )
                            : CachedNetworkImage(
                                imageUrl: photo.url,
                                cacheKey: 'profile-gallery-${photo.id}-'
                                    '${photo.url}',
                                fit: BoxFit.cover,
                                memCacheWidth: cacheSize.width,
                                memCacheHeight: cacheSize.height,
                                maxWidthDiskCache: cacheSize.width,
                                maxHeightDiskCache: cacheSize.height,
                                placeholder: (context, _) => _EmptyPhotoSurface(
                                  displayName: widget.displayName,
                                ),
                                errorWidget: (context, _, __) =>
                                    _EmptyPhotoSurface(
                                  displayName: widget.displayName,
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.displayName,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      if (widget.photos.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_currentPage + 1}/${widget.photos.length}',
                            style: AppTextStyles.meta.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.photos.length > 1)
              Positioned(
                left: 16,
                right: 16,
                top: 12,
                child: Row(
                  children: [
                    for (var index = 0;
                        index < widget.photos.length;
                        index++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      if (index != widget.photos.length - 1)
                        const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

_GalleryCacheSize _galleryCacheSize({
  required double width,
  required double height,
  required double devicePixelRatio,
}) {
  final logicalWidth = width.isFinite && width > 0 ? width : 390.0;
  return _GalleryCacheSize(
    width: _cacheExtent(
      logicalWidth,
      devicePixelRatio,
      min: 480,
      max: 1400,
    ),
    height: _cacheExtent(
      height,
      devicePixelRatio,
      min: 480,
      max: 1800,
    ),
  );
}

int _cacheExtent(
  double logicalSize,
  double devicePixelRatio, {
  required int min,
  required int max,
}) {
  final extent = (logicalSize * devicePixelRatio).ceil();
  if (extent < min) {
    return min;
  }
  if (extent > max) {
    return max;
  }
  return extent;
}

class _GalleryCacheSize {
  const _GalleryCacheSize({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

class _EmptyPhotoSurface extends StatelessWidget {
  const _EmptyPhotoSurface({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primarySoft,
            colors.background,
            colors.secondarySoft,
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initials(displayName),
          style: AppTextStyles.screenTitle.copyWith(
            color: colors.inkSoft,
            fontSize: 40,
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1))
        .join()
        .toUpperCase();
  }
}
