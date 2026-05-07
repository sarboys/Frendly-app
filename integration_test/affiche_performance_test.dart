import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_events_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('affiche long list scroll stays within simulator budgets', (
    tester,
  ) async {
    final imageServer = await _TestImageServer.start();
    addTearDown(imageServer.close);

    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_afficheApp(imageBaseUrl: imageServer.baseUrl));
    await tester.pumpAndSettle();

    await binding.watchPerformance(
      () async {
        for (var index = 0; index < 8; index += 1) {
          await tester.fling(
            find.byType(Scrollable).last,
            const Offset(0, -1100),
            2200,
          );
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'affiche_scroll',
    );

    final metrics = Map<String, dynamic>.from(
      binding.reportData!['affiche_scroll'] as Map,
    );
    debugPrint('affiche_scroll_metrics=$metrics');

    await tester.pumpAndSettle();
    final imageCache = PaintingBinding.instance.imageCache;
    final imageCacheMetrics = {
      'currentSize': imageCache.currentSize,
      'currentSizeBytes': imageCache.currentSizeBytes,
      'liveImageCount': imageCache.liveImageCount,
      'pendingImageCount': imageCache.pendingImageCount,
      'maximumSize': imageCache.maximumSize,
      'maximumSizeBytes': imageCache.maximumSizeBytes,
    };
    debugPrint('affiche_image_cache_metrics=$imageCacheMetrics');

    expect(metrics['frame_count'] as int, greaterThan(0));
    expect(
      metrics['90th_percentile_frame_build_time_millis'] as double,
      lessThan(16),
    );
    expect(
      metrics['90th_percentile_frame_rasterizer_time_millis'] as double,
      lessThan(16),
    );
    expect(imageCache.pendingImageCount, 0);
    expect(imageCache.currentSize, lessThanOrEqualTo(imageCache.maximumSize));
    expect(
      imageCache.currentSizeBytes,
      lessThanOrEqualTo(imageCache.maximumSizeBytes),
    );
  });
}

Widget _afficheApp({required String imageBaseUrl}) {
  final router = GoRouter(
    initialLocation: AppRoute.affiche.path,
    routes: [
      GoRoute(
        path: AppRoute.affiche.path,
        name: AppRoute.affiche.name,
        builder: (context, state) => const AfficheEventsScreen(),
      ),
      GoRoute(
        path: AppRoute.afficheEvent.path,
        name: AppRoute.afficheEvent.name,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('detail:${state.pathParameters['eventId']}'),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authBootstrapProvider.overrideWith((ref) async {}),
      backendRepositoryProvider.overrideWith(
        (ref) => _PagedAfficheRepository(
          ref: ref,
          imageBaseUrl: imageBaseUrl,
        ),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _PagedAfficheRepository extends BackendRepository {
  _PagedAfficheRepository({
    required super.ref,
    required this.imageBaseUrl,
  }) : super(dio: Dio());

  final String imageBaseUrl;

  @override
  Future<PaginatedResponse<AfficheEvent>> fetchAfficheEvents({
    String? city,
    String? q,
    String? date,
    String? priceMode,
    String? source,
    String? category,
    bool? featured,
    String? cursor,
    int limit = 24,
    CancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 8));
    final start = int.tryParse(cursor ?? '') ?? 0;
    final nextStart = start + limit;
    return PaginatedResponse<AfficheEvent>(
      items: List.generate(
        limit,
        (index) => _event(start + index, imageBaseUrl),
      ),
      nextCursor: nextStart >= 180 ? null : '$nextStart',
    );
  }
}

AfficheEvent _event(int index, String imageBaseUrl) {
  return AfficheEvent(
    id: 'affiche-$index',
    title: 'Афиша performance $index',
    description: null,
    city: 'Москва',
    venue: 'Сцена $index',
    address: 'Покровка $index',
    latitude: null,
    longitude: null,
    startsAt: DateTime(2026, 5, 10, 19),
    endsAt: null,
    dateLabel: '10 мая',
    timeLabel: '19:00',
    category: 'concert',
    priceFrom: 1200,
    priceMode: AffichePriceMode.paid,
    currency: 'RUB',
    imageUrl: '$imageBaseUrl/event-$index.png',
    provider: 'Ticketland',
    sourceCode: 'advcake_ticketland',
    actionUrl: 'https://tickets.example.com/$index',
    actionKind: 'affiliate_ticket',
    isAffiliate: true,
    tags: const [],
  );
}

class _TestImageServer {
  _TestImageServer._({
    required HttpServer server,
    required Uint8List imageBytes,
  })  : _server = server,
        _imageBytes = imageBytes;

  final HttpServer _server;
  final Uint8List _imageBytes;

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  static Future<_TestImageServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final imageServer = _TestImageServer._(
      server: server,
      imageBytes: await _buildImageBytes(),
    );
    imageServer._listen();
    return imageServer;
  }

  void _listen() {
    _server.listen((request) {
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.headers
          .set(HttpHeaders.cacheControlHeader, 'max-age=60');
      request.response.contentLength = _imageBytes.length;
      request.response.add(_imageBytes);
      unawaited(request.response.close());
    });
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

Future<Uint8List> _buildImageBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 900, 520),
    ui.Paint()..color = const ui.Color(0xFF245B64),
  );
  canvas.drawCircle(
    const ui.Offset(720, 140),
    180,
    ui.Paint()..color = const ui.Color(0xFFECC66D),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 340, 900, 180),
    ui.Paint()..color = const ui.Color(0xFF181B2A),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(900, 520);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}
