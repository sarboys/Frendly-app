import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile2/shared/data/affiche_client_geo_enrichment_service.dart';
import 'package:mobile2/shared/models/backend_models.dart';

Map<String, Object?> buildMapEventsQueryParameters({
  String? city,
  String? date,
  double? centerLatitude,
  double? centerLongitude,
  double? radiusKm,
  double? southWestLatitude,
  double? southWestLongitude,
  double? northEastLatitude,
  double? northEastLongitude,
  int limit = 80,
}) {
  return {
    if (city != null && city.isNotEmpty) 'city': city,
    'filter': 'nearby',
    if (date != null && date.isNotEmpty) 'date': date,
    'latitude': centerLatitude,
    'longitude': centerLongitude,
    'radiusKm': radiusKm,
    'southWestLatitude': southWestLatitude,
    'southWestLongitude': southWestLongitude,
    'northEastLatitude': northEastLatitude,
    'northEastLongitude': northEastLongitude,
    'limit': limit,
  };
}

class _RadarCoordinate {
  const _RadarCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _RadarMapViewport {
  const _RadarMapViewport({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
    required this.southWestLatitude,
    required this.southWestLongitude,
    required this.northEastLatitude,
    required this.northEastLongitude,
  });

  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;
  final double? southWestLatitude;
  final double? southWestLongitude;
  final double? northEastLatitude;
  final double? northEastLongitude;

  bool get hasRadius =>
      centerLatitude != null &&
      centerLongitude != null &&
      radiusKm != null &&
      radiusKm! > 0;

  bool get hasBounds =>
      southWestLatitude != null &&
      southWestLongitude != null &&
      northEastLatitude != null &&
      northEastLongitude != null;

  bool get isEmpty => !hasBounds && !hasRadius;

  bool contains({
    required double latitude,
    required double longitude,
  }) {
    if (!hasBounds) {
      return true;
    }
    final minLatitude = math.min(southWestLatitude!, northEastLatitude!);
    final maxLatitude = math.max(southWestLatitude!, northEastLatitude!);
    final minLongitude = math.min(southWestLongitude!, northEastLongitude!);
    final maxLongitude = math.max(southWestLongitude!, northEastLongitude!);
    return latitude >= minLatitude &&
        latitude <= maxLatitude &&
        longitude >= minLongitude &&
        longitude <= maxLongitude;
  }
}

class BackendRepository {
  BackendRepository(this._dio);

  static const _eveningAiRequestTimeout = Duration(seconds: 210);

  final Dio _dio;

  Future<BackendUser> fetchMe({CancelToken? cancelToken}) async {
    final json = await _getMap('/me', cancelToken: cancelToken);
    return BackendUser.fromJson(json);
  }

  Future<AppOverlayResponse> fetchAppOverlay({
    required String platform,
    required int buildNumber,
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/app/overlay',
      query: {
        'platform': platform,
        'buildNumber': buildNumber,
      },
      cancelToken: cancelToken,
    );
    return AppOverlayResponse.fromJson(json);
  }

  Future<Map<String, Object?>> recordAppOverlayEvent({
    required String overlayId,
    required String source,
    required String event,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/app/overlay/events',
      data: {
        'overlayId': overlayId,
        'source': source,
        'event': event,
      },
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> fetchOwnProfile({CancelToken? cancelToken}) async {
    final json = await _getMap('/profile/me', cancelToken: cancelToken);
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> updateOwnProfile({
    required Map<String, Object?> data,
    CancelToken? cancelToken,
  }) async {
    final json = await _patchMap(
      '/profile/me',
      data: data,
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<AuthTokens> refreshTokens(AuthTokens tokens) async {
    final json = await _postMap(
      '/auth/refresh',
      data: {'refreshToken': tokens.refreshToken},
      options: Options(extra: {
        'skipAuthHeader': true,
        'skipAuthRefresh': true,
        'skipRequestDeduplication': true,
      }),
    );
    return AuthTokens.fromJson(json);
  }

  Future<AuthSession> verifyPhone({
    required String challengeId,
    required String code,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/phone/verify',
      data: {
        'challengeId': challengeId,
        'code': code,
        'acceptedTerms': acceptedTerms,
      },
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> loginWithTestPhoneShortcut(
    String phoneNumber, {
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/phone/test-login',
      data: {'phoneNumber': phoneNumber, 'acceptedTerms': acceptedTerms},
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(json);
  }

  Future<PhoneAuthChallenge> requestPhoneCode(
    String phoneNumber, {
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/phone/request',
      data: {'phoneNumber': phoneNumber, 'acceptedTerms': acceptedTerms},
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return PhoneAuthChallenge.fromJson(json);
  }

  Future<TelegramAuthStart> startTelegramAuth({
    String? startToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/telegram/start',
      data: {
        if (startToken != null) 'startToken': startToken,
        'acceptedTerms': acceptedTerms,
      },
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return TelegramAuthStart.fromJson(json);
  }

  Future<TelegramSupportStart> startTelegramSupport({
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/support/telegram/start',
      data: const {},
      cancelToken: cancelToken,
    );
    return TelegramSupportStart.fromJson(json);
  }

  Future<AuthSession> verifyTelegramAuth({
    required String loginSessionId,
    required String code,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/telegram/verify',
      data: {
        'loginSessionId': loginSessionId,
        'code': code,
        'acceptedTerms': acceptedTerms,
      },
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> verifyGoogleAuth({
    required String idToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/google/verify',
      data: {'idToken': idToken, 'acceptedTerms': acceptedTerms},
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> verifyYandexAuth({
    required String oauthToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/yandex/verify',
      data: {'oauthToken': oauthToken, 'acceptedTerms': acceptedTerms},
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> verifyAppleAuth({
    required String identityToken,
    String? authorizationCode,
    String? fullName,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/auth/apple/verify',
      data: {
        'identityToken': identityToken,
        if (authorizationCode != null && authorizationCode.isNotEmpty)
          'authorizationCode': authorizationCode,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        'acceptedTerms': acceptedTerms,
      },
      options:
          Options(extra: {'skipAuthHeader': true, 'skipAuthRefresh': true}),
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(json);
  }

  Future<OnboardingData> fetchOnboarding({CancelToken? cancelToken}) async {
    final json = await _getMap('/onboarding/me', cancelToken: cancelToken);
    return OnboardingData.fromJson(json);
  }

  Future<OnboardingData> saveOnboarding(
    OnboardingData data, {
    CancelToken? cancelToken,
  }) async {
    final json = await _putMap(
      '/onboarding/me',
      data: data.toJson(),
      cancelToken: cancelToken,
    );
    return OnboardingData.fromJson(json);
  }

  Future<Map<String, Object?>> checkOnboardingContact({
    String? email,
    String? phoneNumber,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/onboarding/contact/check',
      data: {
        if (email != null && email.isNotEmpty) 'email': email,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
      cancelToken: cancelToken,
    );
  }

  Future<AppSettingsData> fetchSettings({CancelToken? cancelToken}) async {
    final json = await _getMap('/settings/me', cancelToken: cancelToken);
    return AppSettingsData.fromJson(json);
  }

  Future<AppSettingsData> updateSettings(
    Map<String, Object?> data, {
    CancelToken? cancelToken,
  }) async {
    final json = await _putMap(
      '/settings/me',
      data: data,
      cancelToken: cancelToken,
    );
    return AppSettingsData.fromJson(json);
  }

  Future<SafetyData> fetchSafety({CancelToken? cancelToken}) async {
    final json = await _getMap('/safety/me', cancelToken: cancelToken);
    return SafetyData.fromJson(json);
  }

  Future<SafetyData> updateSafety(
    Map<String, Object?> data, {
    CancelToken? cancelToken,
  }) async {
    await _putMap(
      '/safety/me',
      data: data,
      cancelToken: cancelToken,
    );
    return fetchSafety(cancelToken: cancelToken);
  }

  Future<Map<String, Object?>> logout({CancelToken? cancelToken}) {
    return _postMap('/auth/logout', cancelToken: cancelToken);
  }

  Future<BackendPage<BackendCardItem>> fetchEvents({
    String? city,
    String? filter,
    String? query,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    String? sort,
    String? date,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/events',
      query: {
        'city': city,
        'filter': filter,
        'q': query,
        'lifestyle': lifestyle,
        'price': price,
        'gender': gender,
        'access': access,
        if (requiresVerification) 'requiresVerification': true,
        if (requiresFrendlyPlus) 'requiresFrendlyPlus': true,
        'sort': sort,
        'date': date,
        'limit': limit,
        'cursor': cursor,
      },
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/events/$eventId', cancelToken: cancelToken);
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> createEvent({
    required Map<String, Object?> data,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/events',
      data: data,
      options: Options(headers: {'idempotency-key': idempotencyKey}),
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> fetchHostedEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final json =
        await _getMap('/host/events/$eventId', cancelToken: cancelToken);
    return BackendCardItem.fromJson(_hostedEventJson(json));
  }

  Future<BackendCardItem> updateHostedEvent(
    String eventId, {
    required Map<String, Object?> data,
    CancelToken? cancelToken,
  }) async {
    final json = await _patchMap(
      '/host/events/$eventId',
      data: data,
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(_hostedEventJson(json));
  }

  Future<Map<String, Object?>> finishHostedEvent(
    String eventId, {
    required List<String> attendedUserIds,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/host/events/$eventId/live/finish',
      data: {'attendedUserIds': attendedUserIds},
      cancelToken: cancelToken,
    );
  }

  Map<String, Object?> _hostedEventJson(Map<String, Object?> json) {
    final event = _asMap(json['event']);
    if (event.isEmpty) {
      return json;
    }
    return {
      ...event,
      if (json.containsKey('chatId')) 'chatId': json['chatId'],
      if (json.containsKey('liveStatus')) 'liveStatus': json['liveStatus'],
      if (json.containsKey('requests')) 'requests': json['requests'],
      if (json.containsKey('attendees')) 'attendees': json['attendees'],
    };
  }

  Future<BackendCardItem> joinEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/events/$eventId/join',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> leaveEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _deleteMap(
      '/events/$eventId/join',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> createJoinRequest(
    String eventId, {
    String? note,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/events/$eventId/join-request',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> cancelJoinRequest(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _deleteMap(
      '/events/$eventId/join-request',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendPage<BackendCardItem>> fetchFollowingPeople({
    required String eventId,
    String? q,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/people/following',
      query: {
        'eventId': eventId,
        'q': q,
        'cursor': cursor,
        'limit': limit,
      },
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> inviteUserToEvent(
    String eventId,
    String userId, {
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/events/$eventId/invites',
      data: {'userId': userId},
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> acceptEventInvite({
    required String eventId,
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/events/$eventId/invites/$requestId/accept',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<Map<String, Object?>> declineEventInvite({
    required String eventId,
    required String requestId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/events/$eventId/invites/$requestId/decline',
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchAffiche({
    String? city,
    String? query,
    String? date,
    String? dateFrom,
    String? dateTo,
    String? priceMode,
    String? category,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/affiche/events',
      query: {
        'city': city,
        'q': query,
        'date': date,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'priceMode': priceMode,
        'category': category,
        'limit': limit,
        'cursor': cursor,
      },
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> fetchAfficheDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/affiche/events/$eventId',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<AfficheClientGeoSaveResult> saveAfficheClientGeo(
    AfficheClientGeoSaveRequest request, {
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/affiche/events/${request.id}/client-geo',
      data: {
        'lat': request.latitude,
        'lng': request.longitude,
        'provider': 'yandex_mapkit_client',
        'query': request.query,
        'displayName': request.displayName,
        'venueName': request.venueName,
      },
      cancelToken: cancelToken,
    );
    return AfficheClientGeoSaveResult(
      id: json['id']?.toString() ?? request.id,
      latitude: _doubleOrNull(json['lat']),
      longitude: _doubleOrNull(json['lng']),
      address: json['address']?.toString(),
      saved: json['saved'] == true,
      code: json['code']?.toString() ?? '',
    );
  }

  Future<BackendPage<BackendCardItem>> fetchRoutes({
    String? city,
    String? query,
    int limit = 20,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/evening/route-templates',
      query: {'city': city, 'q': query, 'limit': limit},
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> fetchRouteDetail(
    String routeId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/evening/route-templates/$routeId',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> fetchEveningRoute(
    String routeId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/evening/routes/$routeId',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendPage<BackendChatSummary>> fetchMeetupChats({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/chats/meetups',
      query: const {'includeSocial': false},
      cancelToken: cancelToken,
    );
    return _chatPage(json);
  }

  Future<BackendPage<BackendChatSummary>> fetchPersonalChats({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/chats/personal', cancelToken: cancelToken);
    return _chatPage(json);
  }

  Future<BackendPage<BackendChatSummary>> fetchCommunityChats({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/chats/communities', cancelToken: cancelToken);
    return _chatPage(json);
  }

  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/chats/$chatId/messages',
      query: {'cursor': cursor, 'limit': limit},
      cancelToken: cancelToken,
    );
    final currentUserId = _stringOrNull(json['currentUserId']);
    return BackendPage(
      items: _items(json).map((item) {
        final raw = {
          ...item,
          if (currentUserId != null) 'mine': item['senderId'] == currentUserId,
        };
        return BackendChatMessage.fromJson(chatId, raw);
      }).toList(growable: false),
      nextCursor: _stringOrNull(json['nextCursor']),
      raw: json,
    );
  }

  Future<Map<String, Object?>> markChatRead(
    String chatId, {
    required String messageId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/chats/$chatId/read',
      data: {'messageId': messageId},
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> setChatPinned(
    String chatId, {
    required bool isPinned,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/chats/$chatId/pin',
      data: {'isPinned': isPinned},
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> deleteChat(
    String chatId, {
    CancelToken? cancelToken,
  }) {
    return _deleteMap('/chats/$chatId', cancelToken: cancelToken);
  }

  Future<Map<String, Object?>> uploadChatAttachmentFile({
    required String chatId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String kind = 'chat_attachment',
    int? durationMs,
    List<double> waveform = const [],
    CancelToken? cancelToken,
  }) async {
    final uploadData = await _postMap(
      '/uploads/chat-attachment/upload-url',
      data: {
        'chatId': chatId,
        'kind': kind,
        'fileName': fileName,
        'contentType': mimeType,
        if (durationMs != null) 'durationMs': durationMs,
        if (waveform.isNotEmpty) 'waveform': waveform,
      },
      cancelToken: cancelToken,
    );
    final uploadUrl = uploadData['uploadUrl']?.toString();
    final objectKey = uploadData['objectKey']?.toString();
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw StateError('Attachment upload did not return uploadUrl');
    }
    if (objectKey == null || objectKey.isEmpty) {
      throw StateError('Attachment upload did not return objectKey');
    }
    final headers = _stringMap(uploadData['headers']);
    final byteSize = await _putPresignedFile(
      uploadUrl: uploadUrl,
      filePath: filePath,
      headers: headers,
      cancelToken: cancelToken,
    );
    return _postMap(
      '/uploads/chat-attachment/complete',
      data: {
        'chatId': chatId,
        'kind': kind,
        'objectKey': objectKey,
        'mimeType': mimeType,
        'byteSize': byteSize,
        'fileName': fileName,
        if (durationMs != null) 'durationMs': durationMs,
        if (waveform.isNotEmpty) 'waveform': waveform,
      },
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> uploadProfilePhotoFile({
    required String filePath,
    required String fileName,
    required String mimeType,
    CancelToken? cancelToken,
  }) async {
    try {
      final uploadData = await _postMap(
        '/uploads/media/upload-url',
        data: {
          'scope': 'profile_photo',
          'fileName': fileName,
          'contentType': mimeType,
        },
        cancelToken: cancelToken,
      );
      final uploadUrl = uploadData['uploadUrl']?.toString();
      final objectKey = uploadData['objectKey']?.toString();
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw StateError('Profile photo upload did not return uploadUrl');
      }
      if (objectKey == null || objectKey.isEmpty) {
        throw StateError('Profile photo upload did not return objectKey');
      }
      final completeUrl =
          uploadData['completeUrl']?.toString() ?? '/uploads/media/complete';
      final headers = _stringMap(uploadData['headers']);
      final byteSize = await _putPresignedFile(
        uploadUrl: uploadUrl,
        filePath: filePath,
        headers: headers,
        cancelToken: cancelToken,
      );
      return _postMap(
        completeUrl,
        data: {
          'scope': 'profile_photo',
          'objectKey': objectKey,
          'mimeType': mimeType,
          'byteSize': byteSize,
          'fileName': fileName,
        },
        cancelToken: cancelToken,
      );
    } on DioException {
      return _uploadProfilePhotoMultipart(
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        cancelToken: cancelToken,
      );
    } on SocketException {
      return _uploadProfilePhotoMultipart(
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        cancelToken: cancelToken,
      );
    }
  }

  Future<Map<String, Object?>> uploadEventCoverFile({
    required String filePath,
    required String fileName,
    required String mimeType,
    CancelToken? cancelToken,
  }) async {
    final uploadData = await _postMap(
      '/uploads/media/upload-url',
      data: {
        'scope': 'event_cover',
        'fileName': fileName,
        'contentType': mimeType,
      },
      cancelToken: cancelToken,
    );
    final uploadUrl = uploadData['uploadUrl']?.toString();
    final objectKey = uploadData['objectKey']?.toString();
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw StateError('Event cover upload did not return uploadUrl');
    }
    if (objectKey == null || objectKey.isEmpty) {
      throw StateError('Event cover upload did not return objectKey');
    }
    final completeUrl =
        uploadData['completeUrl']?.toString() ?? '/uploads/media/complete';
    final headers = _stringMap(uploadData['headers']);
    final byteSize = await _putPresignedFile(
      uploadUrl: uploadUrl,
      filePath: filePath,
      headers: headers,
      cancelToken: cancelToken,
    );
    return _postMap(
      completeUrl,
      data: {
        'scope': 'event_cover',
        'objectKey': objectKey,
        'mimeType': mimeType,
        'byteSize': byteSize,
        'fileName': fileName,
      },
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> _uploadProfilePhotoMultipart({
    required String filePath,
    required String fileName,
    required String mimeType,
    CancelToken? cancelToken,
  }) async {
    return _postMap(
      '/profile/me/photos/file',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      }),
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> deleteProfilePhoto(
    String photoId, {
    CancelToken? cancelToken,
  }) {
    return _deleteMap('/profile/me/photos/$photoId', cancelToken: cancelToken);
  }

  Future<Map<String, Object?>> makePrimaryProfilePhoto(
    String photoId, {
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/profile/me/photos/$photoId/primary',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> reorderProfilePhotos(
    List<String> photoIds, {
    CancelToken? cancelToken,
  }) {
    return _patchMap(
      '/profile/me/photos/order',
      data: {'photoIds': photoIds},
      cancelToken: cancelToken,
    );
  }

  Future<TokenWalletData> fetchTokenWallet({CancelToken? cancelToken}) async {
    final json = await _getMap('/tokens/wallet', cancelToken: cancelToken);
    return TokenWalletData.fromJson(json);
  }

  Future<TokenWalletData> createPromotion({
    required String targetKind,
    required String targetId,
    String optionId = 'boost-24',
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/tokens/promotions',
      data: {
        'targetKind': targetKind,
        'targetId': targetId,
        'optionId': optionId,
      },
      cancelToken: cancelToken,
    );
    return TokenWalletData.fromJson(json);
  }

  Future<PaymentsCatalog> fetchPaymentsCatalog({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/payments/catalog', cancelToken: cancelToken);
    return PaymentsCatalog.fromJson(json);
  }

  Future<PaymentOrderData> initTokenPayment({
    required String productId,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/payments/init',
      data: {'productKind': 'tokens', 'productId': productId},
      cancelToken: cancelToken,
    );
    return PaymentOrderData.fromJson(json);
  }

  Future<PaymentOrderData> checkPayment({
    required String orderId,
    CancelToken? cancelToken,
  }) async {
    final encodedOrderId = Uri.encodeComponent(orderId);
    final json = await _getMap(
      '/payments/check/$encodedOrderId',
      cancelToken: cancelToken,
    );
    return PaymentOrderData.fromJson(json);
  }

  Future<PaymentOrderData> confirmAppleIapPurchase({
    required String productKind,
    required String productId,
    required String appleProductId,
    required String transactionId,
    required String verificationData,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/payments/apple/confirm',
      data: {
        'productKind': productKind,
        'productId': productId,
        'appleProductId': appleProductId,
        'transactionId': transactionId,
        'verificationData': verificationData,
      },
      cancelToken: cancelToken,
    );
    return PaymentOrderData.fromJson(json);
  }

  Future<SubscriptionStateData> fetchSubscription({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/subscription/me', cancelToken: cancelToken);
    return SubscriptionStateData.fromJson(json);
  }

  Future<List<SubscriptionPlan>> fetchSubscriptionPlans({
    CancelToken? cancelToken,
  }) async {
    final items = await _getList(
      '/subscription/plans',
      cancelToken: cancelToken,
    );
    return items.map(SubscriptionPlan.fromJson).toList(growable: false);
  }

  Future<SubscriptionStateData> subscribeWithTokens({
    required String plan,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/subscription/subscribe',
      data: {'plan': plan},
      cancelToken: cancelToken,
    );
    return SubscriptionStateData.fromJson(json);
  }

  Future<VerificationStateData> fetchVerification({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/verification/me', cancelToken: cancelToken);
    return VerificationStateData.fromJson(json);
  }

  Future<String> uploadVerificationFile(
    PlatformFile file, {
    required String scope,
    CancelToken? cancelToken,
  }) async {
    final mimeType = _resolveMimeType(file.name);
    try {
      final uploadData = await _postMap(
        '/uploads/media/upload-url',
        data: {
          'scope': scope,
          'fileName': file.name,
          'contentType': mimeType,
        },
        cancelToken: cancelToken,
      );
      final uploadUrl = uploadData['uploadUrl']?.toString();
      final objectKey = uploadData['objectKey']?.toString();
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw StateError('Verification upload did not return uploadUrl');
      }
      if (objectKey == null || objectKey.isEmpty) {
        throw StateError('Verification upload did not return objectKey');
      }
      final completeUrl =
          uploadData['completeUrl']?.toString() ?? '/uploads/media/complete';
      final headers = _stringMap(uploadData['headers']);
      final byteSize = await _putPresignedPlatformFile(
        uploadUrl: uploadUrl,
        file: file,
        headers: headers,
        cancelToken: cancelToken,
      );

      final json = await _postMap(
        completeUrl,
        data: {
          'scope': scope,
          'objectKey': objectKey,
          'mimeType': mimeType,
          'byteSize': byteSize,
          'fileName': file.name,
        },
        cancelToken: cancelToken,
      );
      return _requireAssetId(json);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        rethrow;
      }
      return _uploadVerificationFileViaApiFile(
        file,
        scope: scope,
        mimeType: mimeType,
        cancelToken: cancelToken,
      );
    } on SocketException {
      return _uploadVerificationFileViaApiFile(
        file,
        scope: scope,
        mimeType: mimeType,
        cancelToken: cancelToken,
      );
    }
  }

  Future<String> _uploadVerificationFileViaApiFile(
    PlatformFile file, {
    required String scope,
    required String mimeType,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/uploads/media/file',
      data: FormData.fromMap({
        'scope': scope,
        'contentType': mimeType,
        'file': await _platformMultipartFile(file, mimeType),
      }),
      cancelToken: cancelToken,
    );
    return _requireAssetId(json);
  }

  Future<Map<String, Object?>> uploadCommunityImageFile(
    PlatformFile file, {
    CancelToken? cancelToken,
  }) async {
    final mimeType = _resolveMimeType(file.name);
    try {
      final uploadData = await _postMap(
        '/uploads/media/upload-url',
        data: {
          'scope': 'community_image',
          'fileName': file.name,
          'contentType': mimeType,
        },
        cancelToken: cancelToken,
      );
      final uploadUrl = uploadData['uploadUrl']?.toString();
      final objectKey = uploadData['objectKey']?.toString();
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw StateError('Community image upload did not return uploadUrl');
      }
      if (objectKey == null || objectKey.isEmpty) {
        throw StateError('Community image upload did not return objectKey');
      }
      final completeUrl =
          uploadData['completeUrl']?.toString() ?? '/uploads/media/complete';
      final headers = _stringMap(uploadData['headers']);
      final byteSize = await _putPresignedPlatformFile(
        uploadUrl: uploadUrl,
        file: file,
        headers: headers,
        cancelToken: cancelToken,
      );

      return _postMap(
        completeUrl,
        data: {
          'scope': 'community_image',
          'objectKey': objectKey,
          'mimeType': mimeType,
          'byteSize': byteSize,
          'fileName': file.name,
        },
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        rethrow;
      }
      return _uploadCommunityImageFileViaApiFile(
        file,
        mimeType: mimeType,
        cancelToken: cancelToken,
      );
    } on SocketException {
      return _uploadCommunityImageFileViaApiFile(
        file,
        mimeType: mimeType,
        cancelToken: cancelToken,
      );
    }
  }

  Future<Map<String, Object?>> _uploadCommunityImageFileViaApiFile(
    PlatformFile file, {
    required String mimeType,
    CancelToken? cancelToken,
  }) async {
    return _postMap(
      '/uploads/media/file',
      data: FormData.fromMap({
        'scope': 'community_image',
        'contentType': mimeType,
        'file': await _platformMultipartFile(file, mimeType),
      }),
      cancelToken: cancelToken,
    );
  }

  String _requireAssetId(Map<String, Object?> json) {
    final assetId = json['assetId']?.toString();
    if (assetId == null || assetId.isEmpty) {
      throw StateError('Verification upload did not return assetId');
    }
    return assetId;
  }

  Future<VerificationStateData> submitVerification({
    required String step,
    required String assetId,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/verification/submit',
      data: {'step': step, 'assetId': assetId},
      cancelToken: cancelToken,
    );
    return VerificationStateData.fromJson(json);
  }

  Future<DropsHomeData> fetchDropsHome({CancelToken? cancelToken}) async {
    final json = await _getMap('/drops/home', cancelToken: cancelToken);
    return DropsHomeData.fromJson(json);
  }

  Future<Map<String, Object?>> claimDropsVerification({
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/drops/tasks/verification/claim',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> claimDropsDailyLogin({
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/drops/tasks/daily-login/claim',
      cancelToken: cancelToken,
    );
  }

  Future<DropApplyResult> applyDropTickets({
    required String dropId,
    required int ticketCount,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/drops/$dropId/tickets/apply',
      data: {'ticketCount': ticketCount},
      cancelToken: cancelToken,
    );
    return DropApplyResult.fromJson(json);
  }

  Future<DropReferralLinkData> createDropsReferralLink({
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/drops/referral-link/create',
      cancelToken: cancelToken,
    );
    return DropReferralLinkData.fromJson(json);
  }

  Future<BackendPage<BackendCardItem>> fetchNotifications({
    int limit = 30,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/notifications',
      query: {'limit': limit},
      cancelToken: cancelToken,
    );
  }

  Future<int> fetchNotificationUnreadCount({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/notifications/unread-count',
      cancelToken: cancelToken,
    );
    return int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0;
  }

  Future<Map<String, Object?>> markNotificationRead(
    String notificationId, {
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/notifications/$notificationId/read',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> markAllNotificationsRead({
    CancelToken? cancelToken,
  }) {
    return _postMap('/notifications/read-all', cancelToken: cancelToken);
  }

  Future<Map<String, Object?>> registerPushToken({
    required String token,
    String provider = 'fcm',
    String? deviceId,
    String? platform,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/push-tokens',
      data: {
        'token': token,
        'provider': provider,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
      },
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> deletePushTokenByDeviceId(
    String deviceId, {
    CancelToken? cancelToken,
  }) {
    return _deleteMap(
      '/push-tokens/device/$deviceId',
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchCommunities({
    int limit = 20,
    String? cursor,
    String? q,
    List<String> topics = const [],
    String? privacy,
    String? sort,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/communities',
      query: {
        'limit': limit,
        'cursor': cursor,
        'q': q,
        'topics': topics.isEmpty ? null : topics,
        'privacy': privacy,
        'sort': sort,
      },
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> fetchCommunityDetail(
    String communityId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/communities/$communityId',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> createCommunity({
    required Map<String, Object?> data,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/communities',
      data: data,
      options: Options(headers: {'idempotency-key': idempotencyKey}),
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> joinCommunity(
    String communityId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/communities/$communityId/join',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> leaveCommunity(
    String communityId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _deleteMap(
      '/communities/$communityId/join',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> createCommunityJoinRequest(
    String communityId, {
    String? note,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/communities/$communityId/join-request',
      data: {'note': note},
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> cancelCommunityJoinRequest(
    String communityId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _deleteMap(
      '/communities/$communityId/join-request',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<Map<String, Object?>> fetchCommunityAdminOverview(
    String communityId, {
    CancelToken? cancelToken,
  }) {
    return _getMap(
      '/communities/$communityId/admin/overview',
      cancelToken: cancelToken,
    );
  }

  Future<List<Map<String, Object?>>> fetchCommunityAdminMembers(
    String communityId, {
    CancelToken? cancelToken,
  }) {
    return _getList(
      '/communities/$communityId/admin/members',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> updateCommunityAdminMemberRole({
    required String communityId,
    required String memberId,
    required String role,
    CancelToken? cancelToken,
  }) {
    return _patchMap(
      '/communities/$communityId/admin/members/$memberId/role',
      data: {'role': role},
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> removeCommunityAdminMember({
    required String communityId,
    required String memberId,
    CancelToken? cancelToken,
  }) {
    return _deleteMap(
      '/communities/$communityId/admin/members/$memberId',
      cancelToken: cancelToken,
    );
  }

  Future<List<Map<String, Object?>>> fetchCommunityAdminJoinRequests(
    String communityId, {
    CancelToken? cancelToken,
  }) {
    return _getList(
      '/communities/$communityId/admin/join-requests',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> reviewCommunityAdminJoinRequest({
    required String communityId,
    required String requestId,
    required bool approve,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/communities/$communityId/admin/join-requests/$requestId/${approve ? 'approve' : 'reject'}',
      cancelToken: cancelToken,
    );
  }

  Future<List<Map<String, Object?>>> fetchCommunityAdminNews(
    String communityId, {
    CancelToken? cancelToken,
  }) {
    return _getList(
      '/communities/$communityId/admin/news',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> createCommunityAdminNews({
    required String communityId,
    required String title,
    required String body,
    bool pinned = false,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/communities/$communityId/admin/news',
      data: {'title': title, 'body': body, 'pinned': pinned},
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> updateCommunityAdminNews({
    required String communityId,
    required String newsId,
    String? title,
    String? body,
    bool? pinned,
    CancelToken? cancelToken,
  }) {
    return _patchMap(
      '/communities/$communityId/admin/news/$newsId',
      data: {'title': title, 'body': body, 'pinned': pinned},
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> deleteCommunityAdminNews({
    required String communityId,
    required String newsId,
    CancelToken? cancelToken,
  }) {
    return _deleteMap(
      '/communities/$communityId/admin/news/$newsId',
      cancelToken: cancelToken,
    );
  }

  Future<List<Map<String, Object?>>> fetchCommunityAdminMeetups(
    String communityId, {
    CancelToken? cancelToken,
  }) {
    return _getList(
      '/communities/$communityId/admin/meetups',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> cancelCommunityAdminMeetup({
    required String communityId,
    required String eventId,
    CancelToken? cancelToken,
  }) {
    return _deleteMap(
      '/communities/$communityId/admin/meetups/$eventId',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> updateCommunityAdminSettings({
    required String communityId,
    required Map<String, Object?> data,
    CancelToken? cancelToken,
  }) {
    return _patchMap(
      '/communities/$communityId/admin/settings',
      data: data,
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> archiveCommunityAdmin(
    String communityId, {
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/communities/$communityId/admin/archive',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> transferCommunityAdminOwner({
    required String communityId,
    required String userId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/communities/$communityId/admin/transfer-owner',
      data: {'userId': userId},
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchCommunityMedia(
    String communityId, {
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/communities/$communityId/media',
      query: {'limit': limit, 'cursor': cursor},
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> createCommunityNews({
    required String communityId,
    required String title,
    required String body,
    bool pin = true,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/communities/$communityId/news',
      data: {'title': title, 'body': body, 'pin': pin},
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<EveningRouteSessionData> createRouteTemplateSession({
    required String templateId,
    required DateTime startsAt,
    String privacy = 'open',
    int? capacity,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/evening/route-templates/$templateId/sessions',
      data: {
        'startsAt': startsAt.toUtc().toIso8601String(),
        'privacy': privacy,
        if (capacity != null) 'capacity': capacity,
      },
      cancelToken: cancelToken,
    );
    return EveningRouteSessionData.fromJson(json);
  }

  Future<Map<String, Object?>> startEveningSession(
    String sessionId, {
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/start',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> joinEveningSession(
    String sessionId, {
    String? inviteToken,
    String? note,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/join',
      data: {
        if (inviteToken != null && inviteToken.isNotEmpty)
          'inviteToken': inviteToken,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> checkInEveningStep({
    required String sessionId,
    required String stepId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/steps/$stepId/check-in',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> advanceEveningStep({
    required String sessionId,
    required String stepId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/steps/$stepId/advance',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> skipEveningStep({
    required String sessionId,
    required String stepId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/steps/$stepId/skip',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> finishEveningSession(
    String sessionId, {
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/finish',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> fetchEveningAfterParty(
    String sessionId, {
    CancelToken? cancelToken,
  }) {
    return _getMap(
      '/evening/sessions/$sessionId/after-party',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> saveEveningAfterPartyFeedback({
    required String sessionId,
    required int rating,
    String? reaction,
    String? comment,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/after-party/feedback',
      data: {
        'rating': rating,
        if (reaction != null && reaction.isNotEmpty) 'reaction': reaction,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> addEveningAfterPartyPhoto({
    required String sessionId,
    required String assetId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/evening/sessions/$sessionId/after-party/photos',
      data: {'assetId': assetId},
      cancelToken: cancelToken,
    );
  }

  Future<PartnerOfferCodeData> issuePartnerOfferCode({
    required String sessionId,
    required String stepId,
    required String offerId,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/evening/sessions/$sessionId/steps/$stepId/offers/$offerId/code',
      cancelToken: cancelToken,
    );
    return PartnerOfferCodeData.fromJson(json);
  }

  Future<PartnerOfferCodeData> fetchPartnerOfferCode(
    String codeId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/evening/offer-codes/$codeId',
      cancelToken: cancelToken,
    );
    return PartnerOfferCodeData.fromJson(json);
  }

  Future<EveningAiDraftData> createEveningAiDraft({
    required String prompt,
    String? city,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/evening/routes/ai-drafts',
      data: {
        'prompt': prompt,
        if (city != null && city.isNotEmpty) 'city': city,
      },
      options: Options(receiveTimeout: _eveningAiRequestTimeout),
      cancelToken: cancelToken,
    );
    return EveningAiDraftData.fromJson(json);
  }

  Future<EveningAiDraftData> fetchEveningAiDraft(
    String draftId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/evening/routes/ai-drafts/$draftId',
      cancelToken: cancelToken,
    );
    return EveningAiDraftData.fromJson(json);
  }

  Future<EveningAiDraftData> acceptEveningAiDraftStep({
    required String draftId,
    required int stepIndex,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/evening/routes/ai-drafts/$draftId/steps/$stepIndex/accept',
      cancelToken: cancelToken,
    );
    return EveningAiDraftData.fromJson(json);
  }

  Future<EveningAiDraftData> regenerateEveningAiDraft(
    String draftId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/evening/routes/ai-drafts/$draftId/regenerate',
      options: Options(receiveTimeout: _eveningAiRequestTimeout),
      cancelToken: cancelToken,
    );
    return EveningAiDraftData.fromJson(json);
  }

  Future<EveningAiDraftData> regenerateEveningAiDraftStep({
    required String draftId,
    required int stepIndex,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/evening/routes/ai-drafts/$draftId/steps/$stepIndex/regenerate',
      options: Options(receiveTimeout: _eveningAiRequestTimeout),
      cancelToken: cancelToken,
    );
    return EveningAiDraftData.fromJson(json);
  }

  Future<EveningAiDraftData> confirmEveningAiDraft(
    String draftId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/evening/routes/ai-drafts/$draftId/confirm',
      cancelToken: cancelToken,
    );
    return EveningAiDraftData.fromJson(json);
  }

  Future<AfterDarkAccessData> fetchAfterDarkAccess({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/after-dark/access', cancelToken: cancelToken);
    return AfterDarkAccessData.fromJson(json);
  }

  Future<AfterDarkAccessData> unlockAfterDark({
    required String plan,
    required bool ageConfirmed,
    required bool codeAccepted,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/after-dark/unlock',
      data: {
        'plan': plan,
        'ageConfirmed': ageConfirmed,
        'codeAccepted': codeAccepted,
      },
      cancelToken: cancelToken,
    );
    return AfterDarkAccessData.fromJson(json);
  }

  Future<BackendPage<BackendCardItem>> fetchAfterDarkEvents({
    int limit = 20,
    String? cursor,
    String? query,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/after-dark/events',
      query: {'limit': limit, 'cursor': cursor, 'q': query},
      cancelToken: cancelToken,
    );
  }

  Future<BackendCardItem> fetchPublicUser(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap('/people/$userId', cancelToken: cancelToken);
    return BackendCardItem.fromJson(json);
  }

  Future<ProfileSocialData> fetchProfileSocial(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    final json =
        await _getMap('/people/$userId/social', cancelToken: cancelToken);
    return ProfileSocialData.fromJson(json);
  }

  Future<Map<String, Object?>> createDirectChat(
    String userId, {
    CancelToken? cancelToken,
  }) {
    return _postMap('/people/$userId/direct-chat', cancelToken: cancelToken);
  }

  Future<Map<String, Object?>> setProfileReaction({
    required String userId,
    required String kind,
    required bool active,
    CancelToken? cancelToken,
  }) {
    final path = '/people/$userId/reactions/$kind';
    return active
        ? _putMap(path, cancelToken: cancelToken)
        : _deleteMap(path, cancelToken: cancelToken);
  }

  Future<ProfileSocialData> setProfileFollow({
    required String userId,
    required bool active,
    CancelToken? cancelToken,
  }) async {
    final path = '/people/$userId/follow';
    final json = active
        ? await _putMap(path, cancelToken: cancelToken)
        : await _deleteMap(path, cancelToken: cancelToken);
    return ProfileSocialData.fromJson(json);
  }

  Future<ProfileSocialData> setProfileFollowNotifications({
    required String userId,
    required bool enabled,
    CancelToken? cancelToken,
  }) async {
    final json = await _patchMap(
      '/people/$userId/follow/notifications',
      data: {'enabled': enabled},
      cancelToken: cancelToken,
    );
    return ProfileSocialData.fromJson(json);
  }

  Future<HostDashboardData> fetchHostDashboard({
    int eventsLimit = 20,
    int requestsLimit = 20,
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/host/dashboard',
      query: {
        'eventsLimit': eventsLimit,
        'requestsLimit': requestsLimit,
      },
      cancelToken: cancelToken,
    );
    return HostDashboardData.fromJson(json);
  }

  Future<HostJoinRequestData> approveHostRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/host/requests/$requestId/approve',
      cancelToken: cancelToken,
    );
    return HostJoinRequestData.fromJson(json);
  }

  Future<HostJoinRequestData> rejectHostRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/host/requests/$requestId/reject',
      cancelToken: cancelToken,
    );
    return HostJoinRequestData.fromJson(json);
  }

  Future<BackendPage<BackendCardItem>> fetchMapEvents({
    String? city,
    String? date,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
    double? southWestLatitude,
    double? southWestLongitude,
    double? northEastLatitude,
    double? northEastLongitude,
    int limit = 80,
    CancelToken? cancelToken,
  }) async {
    final eventsPage = await _fetchCardPage(
      '/events',
      query: buildMapEventsQueryParameters(
        city: city,
        date: date,
        centerLatitude:
            centerLatitude == null ? null : _roundViewport(centerLatitude),
        centerLongitude:
            centerLongitude == null ? null : _roundViewport(centerLongitude),
        radiusKm: radiusKm == null ? null : _roundDistance(radiusKm),
        southWestLatitude: southWestLatitude == null
            ? null
            : _roundViewport(southWestLatitude),
        southWestLongitude: southWestLongitude == null
            ? null
            : _roundViewport(southWestLongitude),
        northEastLatitude: northEastLatitude == null
            ? null
            : _roundViewport(northEastLatitude),
        northEastLongitude: northEastLongitude == null
            ? null
            : _roundViewport(northEastLongitude),
        limit: limit,
      ),
      cancelToken: cancelToken,
    );
    final mapEvents = eventsPage.items;
    final viewport = _RadarMapViewport(
      centerLatitude:
          centerLatitude == null ? null : _roundViewport(centerLatitude),
      centerLongitude:
          centerLongitude == null ? null : _roundViewport(centerLongitude),
      radiusKm: radiusKm == null ? null : _roundDistance(radiusKm),
      southWestLatitude:
          southWestLatitude == null ? null : _roundViewport(southWestLatitude),
      southWestLongitude: southWestLongitude == null
          ? null
          : _roundViewport(southWestLongitude),
      northEastLatitude:
          northEastLatitude == null ? null : _roundViewport(northEastLatitude),
      northEastLongitude: northEastLongitude == null
          ? null
          : _roundViewport(northEastLongitude),
    );
    final visibleMapEvents = _filterRadarItemsForViewport(
      mapEvents.where(_hasRadarMapPoint),
      viewport,
    );
    return BackendPage(
      items: visibleMapEvents,
      raw: {
        'items':
            visibleMapEvents.map((item) => item.raw).toList(growable: false),
      },
    );
  }

  Future<BackendCardItem> fetchAfterDarkEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/after-dark/events/$eventId',
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendCardItem> joinAfterDarkEvent(
    String eventId, {
    bool acceptedRules = true,
    String note = '',
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/after-dark/events/$eventId/join',
      data: {
        'acceptedRules': acceptedRules,
        if (note.isNotEmpty) 'note': note,
      },
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<BackendPage<BackendCardItem>> search(
    String query, {
    String? city,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/search',
      query: {
        'q': query,
        'city': city,
        'meetupsLimit': 8,
        'routesLimit': 6,
        'afficheLimit': 6,
      },
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchDatingDiscover({
    int limit = 10,
    String? cursor,
    String? gender,
    int? ageMin,
    int? ageMax,
    int? radiusKm,
    List<String> interests = const [],
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? newThisWeekOnly,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/dating/discover',
      query: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        'ageMin': ageMin,
        'ageMax': ageMax,
        'radiusKm': radiusKm,
        if (interests.isNotEmpty) 'interests': interests,
        if (verifiedOnly != null) 'verifiedOnly': verifiedOnly,
        if (onlineOnly != null) 'onlineOnly': onlineOnly,
        if (newThisWeekOnly != null) 'newThisWeekOnly': newThisWeekOnly,
      },
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchDatingLikes({
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/dating/likes',
      query: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
      cancelToken: cancelToken,
    );
  }

  Future<DatingLimitsData> fetchDatingLimits({CancelToken? cancelToken}) async {
    final json = await _getMap('/dating/limits', cancelToken: cancelToken);
    return DatingLimitsData.fromJson(json);
  }

  Future<DatingActionResult> recordDatingAction({
    required String targetUserId,
    required String action,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/dating/actions',
      data: {'targetUserId': targetUserId, 'action': action},
      cancelToken: cancelToken,
    );
    return DatingActionResult.fromJson(json);
  }

  Future<DatingRewindResult> rewindDatingPass({
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap('/dating/rewind', cancelToken: cancelToken);
    return DatingRewindResult.fromJson(json);
  }

  Future<BackendPage<BackendCardItem>> fetchPerks({
    String? city,
    String? category,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final items = await _getList(
      '/places/promos',
      query: {'city': city, 'category': category, 'limit': limit},
      cancelToken: cancelToken,
    );
    return BackendPage(
      items: items.map(BackendCardItem.fromJson).toList(growable: false),
      raw: {'items': items},
    );
  }

  Future<BackendPage<BackendCardItem>> searchPlaces({
    required String query,
    String? city,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    if (query.trim().length < 2) {
      return const BackendPage(items: []);
    }
    final items = await _getList(
      '/places/search',
      query: {'q': query, 'city': city, 'limit': limit},
      cancelToken: cancelToken,
    );
    return BackendPage(
      items: items.map(BackendCardItem.fromJson).toList(growable: false),
      raw: {'items': items},
    );
  }

  Future<BackendPage<BackendCardItem>> fetchHistory({
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/profile/me/frendly-history',
      cancelToken: cancelToken,
    );
  }

  Future<FrendlySeasonData> fetchFrendlySeason({
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(
      '/profile/me/frendly-season',
      cancelToken: cancelToken,
    );
    return FrendlySeasonData.fromJson(json);
  }

  Future<Map<String, Object?>> claimFrendlySeasonReward(
    String rewardKey, {
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/profile/me/frendly-season/rewards/$rewardKey/claim',
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchTrustedContacts({
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Object?>(
      '/safety/trusted-contacts',
      cancelToken: cancelToken,
    );
    return BackendPage(
      items: _asList(response.data)
          .map(BackendCardItem.fromJson)
          .toList(growable: false),
    );
  }

  Future<BackendCardItem> createTrustedContact({
    required String name,
    required String value,
    String channel = 'phone',
    String mode = 'sos_only',
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/safety/trusted-contacts',
      data: {
        'name': name,
        'channel': channel,
        'value': value,
        'mode': mode,
      },
      cancelToken: cancelToken,
    );
    return BackendCardItem.fromJson(json);
  }

  Future<void> deleteTrustedContact(
    String contactId, {
    CancelToken? cancelToken,
  }) async {
    await _dio.delete<Object?>(
      '/safety/trusted-contacts/$contactId',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> createSos({
    String? eventId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/safety/sos',
      data: {if (eventId != null && eventId.isNotEmpty) 'eventId': eventId},
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchMatches({
    int limit = 10,
    String? cursor,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/matches',
      query: {'limit': limit, 'cursor': cursor},
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> createReport({
    String? targetUserId,
    String? targetEventId,
    String targetType = 'user',
    required String reason,
    String details = '',
    bool blockRequested = false,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/reports',
      data: {
        if (targetType != 'user') 'targetType': targetType,
        if (targetUserId != null && targetUserId.isNotEmpty)
          'targetUserId': targetUserId,
        if (targetEventId != null && targetEventId.isNotEmpty)
          'targetEventId': targetEventId,
        'reason': reason,
        'details': details,
        'blockRequested': blockRequested,
      },
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<SafetyReportData>> fetchReports({
    CancelToken? cancelToken,
  }) async {
    final json = await _getList('/reports/me', cancelToken: cancelToken);
    return BackendPage(
      items: json.map(SafetyReportData.fromJson).toList(growable: false),
      raw: {'items': json},
    );
  }

  Future<BackendPage<BlockedUserData>> fetchBlocks({
    CancelToken? cancelToken,
  }) async {
    final json = await _getList('/blocks', cancelToken: cancelToken);
    return BackendPage(
      items: json.map(BlockedUserData.fromJson).toList(growable: false),
      raw: {'items': json},
    );
  }

  Future<BlockedUserData> createBlock({
    required String targetUserId,
    CancelToken? cancelToken,
  }) async {
    final json = await _postMap(
      '/blocks',
      data: {'targetUserId': targetUserId},
      cancelToken: cancelToken,
    );
    return BlockedUserData.fromJson(json);
  }

  Future<void> deleteBlock({
    required String targetUserId,
    CancelToken? cancelToken,
  }) async {
    await _dio.delete<Object?>(
      '/blocks/$targetUserId',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> createShare({
    required String targetType,
    required String targetId,
    CancelToken? cancelToken,
  }) {
    return _postMap(
      '/shares',
      data: {'targetType': targetType, 'targetId': targetId},
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchEventStories(
    String eventId, {
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/events/$eventId/stories',
      query: {'limit': limit, 'cursor': cursor},
      cancelToken: cancelToken,
    );
  }

  Future<BackendPage<BackendCardItem>> fetchMemoryPeople({
    CancelToken? cancelToken,
  }) {
    return _fetchCardPage(
      '/profile/me/frendly-people',
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, Object?>> fetchSignedMediaUrl(String path) {
    return _getMap(path);
  }

  Future<BackendPage<BackendCardItem>> _fetchCardPage(
    String path, {
    Map<String, Object?> query = const {},
    CancelToken? cancelToken,
  }) async {
    final json = await _getMap(path, query: query, cancelToken: cancelToken);
    return BackendPage(
      items: _items(json).map(BackendCardItem.fromJson).toList(growable: false),
      nextCursor: _stringOrNull(json['nextCursor']),
      raw: json,
    );
  }

  BackendPage<BackendChatSummary> _chatPage(Map<String, Object?> json) {
    return BackendPage(
      items:
          _items(json).map(BackendChatSummary.fromJson).toList(growable: false),
      nextCursor: _stringOrNull(json['nextCursor']),
      raw: json,
    );
  }

  Future<Map<String, Object?>> _getMap(
    String path, {
    Map<String, Object?> query = const {},
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Object?>(
      path,
      queryParameters: _cleanQuery(query),
      cancelToken: cancelToken,
    );
    return _asMap(response.data);
  }

  Future<List<Map<String, Object?>>> _getList(
    String path, {
    Map<String, Object?> query = const {},
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Object?>(
      path,
      queryParameters: _cleanQuery(query),
      cancelToken: cancelToken,
    );
    return _asList(response.data);
  }

  Future<Map<String, Object?>> _postMap(
    String path, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Object?>(
      path,
      data: data,
      options: options,
      cancelToken: cancelToken,
    );
    return _asMap(response.data);
  }

  Future<Map<String, Object?>> _patchMap(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.patch<Object?>(
      path,
      data: data,
      cancelToken: cancelToken,
    );
    return _asMap(response.data);
  }

  Future<Map<String, Object?>> _putMap(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.put<Object?>(
      path,
      data: data,
      cancelToken: cancelToken,
    );
    return _asMap(response.data);
  }

  Future<Map<String, Object?>> _deleteMap(
    String path, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.delete<Object?>(
      path,
      cancelToken: cancelToken,
    );
    return _asMap(response.data);
  }

  Future<int> _putPresignedFile({
    required String uploadUrl,
    required String filePath,
    required Map<String, String> headers,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);
    final byteSize = await file.length();
    await _dio.put<Object?>(
      uploadUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          ...headers,
          Headers.contentLengthHeader: byteSize,
        },
        extra: {
          'skipAuthHeader': true,
          'skipAuthRefresh': true,
          'skipRequestDeduplication': true,
        },
      ),
      cancelToken: cancelToken,
    );
    return byteSize;
  }

  Future<int> _putPresignedPlatformFile({
    required String uploadUrl,
    required PlatformFile file,
    required Map<String, String> headers,
    CancelToken? cancelToken,
  }) async {
    final path = file.path;
    final Object data;
    final int byteSize;
    if (path != null && path.isNotEmpty) {
      final diskFile = File(path);
      byteSize = await diskFile.length();
      data = diskFile.openRead();
    } else {
      final bytes = await _readPlatformFileBytes(file);
      byteSize = bytes.length;
      data = bytes;
    }
    await _dio.put<Object?>(
      uploadUrl,
      data: data,
      options: Options(
        headers: {
          ...headers,
          Headers.contentLengthHeader: byteSize,
        },
        extra: {
          'skipAuthHeader': true,
          'skipAuthRefresh': true,
          'skipRequestDeduplication': true,
        },
      ),
      cancelToken: cancelToken,
    );
    return byteSize;
  }

  Future<MultipartFile> _platformMultipartFile(
    PlatformFile file,
    String mimeType,
  ) {
    final contentType = DioMediaType.parse(mimeType);
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return MultipartFile.fromFile(
        path,
        filename: file.name,
        contentType: contentType,
      );
    }
    return _readPlatformFileBytes(file).then(
      (bytes) => MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: contentType,
      ),
    );
  }

  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) {
      return bytes;
    }
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw StateError('Verification file bytes are missing');
    }
    return File(path).readAsBytes();
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return const {};
  }

  List<Map<String, Object?>> _asList(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map(_asMap).toList(growable: false);
    }
    if (value is Map) {
      return _items(_asMap(value));
    }
    return const [];
  }

  List<Map<String, Object?>> _items(Map<String, Object?> json) {
    final direct = json['items'];
    if (direct is List) {
      return direct.whereType<Map>().map(_asMap).toList(growable: false);
    }
    final grouped = <Map<String, Object?>>[];
    for (final key in [
      'meetups',
      'evenings',
      'routes',
      'affiche',
      'people',
      'communities',
      'plans',
    ]) {
      final value = json[key];
      if (value is List) {
        grouped.addAll(value.whereType<Map>().map(_asMap));
      }
    }
    return grouped;
  }

  List<BackendCardItem> _filterRadarItemsForViewport(
    Iterable<BackendCardItem> items,
    _RadarMapViewport viewport,
  ) {
    return items
        .where((item) => _itemVisibleInRadarViewport(item, viewport))
        .toList(growable: false);
  }

  bool _itemVisibleInRadarViewport(
    BackendCardItem item,
    _RadarMapViewport viewport,
  ) {
    final points = _pointsForRadarItem(item);
    if (points.isEmpty || viewport.isEmpty) {
      return points.isNotEmpty;
    }
    return points.any((point) {
      final latitude = point.latitude;
      final longitude = point.longitude;
      if (viewport.hasBounds &&
          !viewport.contains(latitude: latitude, longitude: longitude)) {
        return false;
      }
      if (viewport.hasRadius &&
          !_pointWithinRadius(
            latitude: latitude,
            longitude: longitude,
            centerLatitude: viewport.centerLatitude!,
            centerLongitude: viewport.centerLongitude!,
            radiusKm: viewport.radiusKm!,
          )) {
        return false;
      }
      return true;
    });
  }

  List<_RadarCoordinate> _pointsForRadarItem(BackendCardItem item) {
    final points = <_RadarCoordinate>[];
    if (_validCoordinatePair(item.latitude, item.longitude)) {
      points.add(_RadarCoordinate(item.latitude!, item.longitude!));
    }
    for (final point
        in _mapPointList(item.raw['routePoints'] ?? item.raw['steps'])) {
      final latitude = _mapPointLatitude(point);
      final longitude = _mapPointLongitude(point);
      if (_validCoordinatePair(latitude, longitude)) {
        points.add(_RadarCoordinate(latitude!, longitude!));
      }
    }
    return points;
  }

  bool _pointWithinRadius({
    required double latitude,
    required double longitude,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
  }) {
    if (radiusKm <= 0) {
      return false;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(latitude - centerLatitude);
    final dLng = _degreesToRadians(longitude - centerLongitude);
    final lat1 = _degreesToRadians(centerLatitude);
    final lat2 = _degreesToRadians(latitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c <= radiusKm;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  bool _hasRadarMapPoint(BackendCardItem item) {
    if (_validCoordinatePair(item.latitude, item.longitude)) {
      return true;
    }
    return _mapPointList(item.raw['routePoints'] ?? item.raw['steps'])
        .any((point) => _validCoordinatePair(
              _mapPointLatitude(point),
              _mapPointLongitude(point),
            ));
  }

  List<Map<String, Object?>> _mapPointList(Object? value) {
    return _asList(value)
        .where((point) => _validCoordinatePair(
              _mapPointLatitude(point),
              _mapPointLongitude(point),
            ))
        .toList(growable: false);
  }

  double? _mapPointLatitude(Map<String, Object?> point) {
    return _doubleOrNull(point['latitude'] ?? point['lat']);
  }

  double? _mapPointLongitude(Map<String, Object?> point) {
    return _doubleOrNull(point['longitude'] ?? point['lng']);
  }

  bool _validCoordinatePair(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  double? _doubleOrNull(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  Map<String, Object?> _cleanQuery(Map<String, Object?> query) {
    return Map.fromEntries(
      query.entries.where((entry) => entry.value != null && entry.value != ''),
    );
  }

  Map<String, String> _stringMap(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, value) => MapEntry('$key', value?.toString() ?? ''));
  }

  String? _stringOrNull(Object? value) {
    final result = value?.toString();
    if (result == null || result.isEmpty) {
      return null;
    }
    return result;
  }

  double _roundViewport(double value) {
    return (value * 1000).roundToDouble() / 1000;
  }

  double _roundDistance(double value) {
    return (value * 10).roundToDouble() / 10;
  }

  String _resolveMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}
