import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class DateasyMediaItem {
  const DateasyMediaItem({
    this.imageUrl,
    this.localPath,
    this.cacheKey,
    this.cacheManager,
  });

  final String? imageUrl;
  final String? localPath;
  final String? cacheKey;
  final BaseCacheManager? cacheManager;

  bool get hasSource =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (localPath != null && localPath!.isNotEmpty);
}

Future<void> showDateasyMediaViewer(
  BuildContext context, {
  required List<DateasyMediaItem> items,
  int initialIndex = 0,
}) {
  final visibleItems =
      items.where((item) => item.hasSource).toList(growable: false);
  if (visibleItems.isEmpty) {
    return Future<void>.value();
  }
  final safeInitialIndex =
      initialIndex.clamp(0, visibleItems.length - 1).toInt();
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (_) => DateasyMediaViewer(
      items: visibleItems,
      initialIndex: safeInitialIndex,
    ),
  );
}

class DateasyMediaViewer extends StatefulWidget {
  const DateasyMediaViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  final List<DateasyMediaItem> items;
  final int initialIndex;

  @override
  State<DateasyMediaViewer> createState() => _DateasyMediaViewerState();
}

class _DateasyMediaViewerState extends State<DateasyMediaViewer> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                return _MediaPage(item: widget.items[index]);
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  _ViewerIconButton(
                    key: const ValueKey('dateasy-media-viewer-close'),
                    icon: LucideIcons.x,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.items.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPage extends StatelessWidget {
  const _MediaPage({required this.item});

  final DateasyMediaItem item;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _MediaImage(item: item),
        ),
      ),
    );
  }
}

class _MediaImage extends StatelessWidget {
  const _MediaImage({required this.item});

  final DateasyMediaItem item;

  @override
  Widget build(BuildContext context) {
    final localPath = item.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      }
    }
    return DateasyRemoteImage(
      imageUrl: item.imageUrl,
      usage: DateasyImageUsage.fullscreen,
      fit: BoxFit.contain,
      cacheKey: item.cacheKey,
      cacheManager: item.cacheManager,
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  const _ViewerIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
