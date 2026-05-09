import 'package:big_break_mobile/shared/models/backend_url.dart';

class MediaVariantData {
  const MediaVariantData({
    required this.url,
    this.downloadUrl,
    this.mimeType,
    this.byteSize,
    this.cacheKey,
    this.expiresAt,
  });

  final String? url;
  final String? downloadUrl;
  final String? mimeType;
  final int? byteSize;
  final String? cacheKey;
  final DateTime? expiresAt;

  factory MediaVariantData.fromJson(Map<String, dynamic> json) {
    return MediaVariantData(
      url: resolveBackendUrl(json['url'] as String?),
      downloadUrl: resolveBackendUrl(json['downloadUrl'] as String?),
      mimeType: json['mimeType'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt(),
      cacheKey: json['cacheKey'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }
}

Map<String, MediaVariantData> parseMediaVariants(Object? raw) {
  if (raw is! Map) {
    return const {};
  }

  final variants = <String, MediaVariantData>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is String && value is Map) {
      variants[key] = MediaVariantData.fromJson(
        Map<String, dynamic>.from(value),
      );
    }
  }
  return Map.unmodifiable(variants);
}
