import 'package:big_break_mobile/app/core/config/backend_config.dart';

String? resolveBackendUrl(String? raw) {
  if (raw == null || raw.isEmpty) {
    return raw;
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  if (raw.startsWith('/')) {
    return joinBackendUrl(BackendConfig.apiBaseUrl, raw);
  }

  return raw;
}

String joinBackendUrl(String baseUrl, String path) {
  final cleanBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
  if (!path.startsWith('/')) {
    return '$cleanBase/$path';
  }
  return '$cleanBase$path';
}
