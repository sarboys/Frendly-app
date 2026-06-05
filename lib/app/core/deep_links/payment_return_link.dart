String? paymentReturnRouteForUri(Uri uri) {
  final parts = _paymentPathParts(uri);
  if (!_isSupportedPaymentUri(uri)) {
    return null;
  }

  final result = _paymentResult(parts, uri.queryParameters);
  if (result != 'success' && result != 'fail') {
    return null;
  }
  if (!_looksLikePaymentReturn(parts, uri.queryParameters)) {
    return null;
  }

  final passthroughQuery = Map<String, String>.of(uri.queryParameters)
    ..remove('paymentResult');
  final query = <String, String>{
    'paymentResult': result!,
    ...passthroughQuery,
  };
  return Uri(path: '/wallet', queryParameters: query).toString();
}

List<String> _paymentPathParts(Uri uri) {
  if (uri.host.isEmpty || uri.scheme == 'https' || uri.scheme == 'http') {
    return uri.pathSegments;
  }
  return [uri.host, ...uri.pathSegments];
}

bool _isSupportedPaymentUri(Uri uri) {
  return switch (uri.scheme) {
    '' || 'frendly' || 'dateasy' => true,
    'https' || 'http' => _isFrendlyHost(uri.host),
    _ => false,
  };
}

bool _isFrendlyHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'frendly.tech' ||
      normalized == 'www.frendly.tech' ||
      normalized == 'api.frendly.tech';
}

String? _paymentResult(List<String> parts, Map<String, String> query) {
  if (parts.length >= 2 && parts.first == 'payment') {
    return _normalizeResult(parts[1]);
  }
  if (parts.length == 1 &&
      (parts.first == 'success' || parts.first == 'fail')) {
    return parts.first;
  }
  return _normalizeResult(
    query['paymentResult'] ?? query['result'] ?? query['status'],
  );
}

String? _normalizeResult(String? raw) {
  final value = raw?.trim().toLowerCase();
  return switch (value) {
    'success' || 'succeeded' || 'confirmed' => 'success',
    'fail' || 'failed' || 'failure' || 'error' => 'fail',
    _ => null,
  };
}

bool _looksLikePaymentReturn(List<String> parts, Map<String, String> query) {
  if (parts.isNotEmpty && parts.first == 'payment') {
    return true;
  }
  final hasPaymentMarker = query.containsKey('orderId') ||
      query.containsKey('paymentId') ||
      query['productKind'] == 'tokens';
  return parts.length == 1 &&
      (parts.first == 'success' || parts.first == 'fail') &&
      hasPaymentMarker;
}
