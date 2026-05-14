class AppCacheKey {
  const AppCacheKey._();

  static String build({
    required String path,
    Map<String, Object?> query = const {},
  }) {
    final parts = <String>[];
    final keys = query.keys.where((key) => query[key] != null).toList()..sort();

    for (final key in keys) {
      final value = query[key];
      if (value == null) {
        continue;
      }
      if (value is Iterable && value is! String) {
        for (final item in value) {
          if (item != null) {
            parts.add('${_encode(key)}=${_encode(item)}');
          }
        }
        continue;
      }
      parts.add('${_encode(key)}=${_encode(value)}');
    }

    if (parts.isEmpty) {
      return path;
    }
    return '$path?${parts.join('&')}';
  }

  static String _encode(Object value) => Uri.encodeQueryComponent('$value');
}

class AppCacheUserScope {
  const AppCacheUserScope._(this.storageId);

  static const public = AppCacheUserScope._('public');
  static const guest = AppCacheUserScope._('guest');

  final String storageId;

  static AppCacheUserScope user(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      return guest;
    }
    return AppCacheUserScope._('user:$trimmed');
  }

  static AppCacheUserScope fromUserId(String? userId) {
    if (userId == null) {
      return guest;
    }
    return user(userId);
  }
}
