String cleanTomestoPromoTitle(String value) {
  var text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) {
    return text;
  }

  final prefix = RegExp(
    r'^(?:🎁\s*)?(?:акции\s+и\s+скидки|акция\s+и\s+скидка|акции|акция|скидки|скидка|промо|спецпредложение|предложение)\s*[:\-–—]\s*',
    caseSensitive: false,
    unicode: true,
  );
  for (var index = 0; index < 3; index += 1) {
    final cleaned = text.replaceFirst(prefix, '').trim();
    if (cleaned == text) {
      break;
    }
    text = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  return text.isEmpty ? value.trim() : text;
}

String tomestoVenueDisplayName({
  required String promoTitle,
  String? placeName,
  String? venueName,
}) {
  for (final candidate in [placeName, venueName]) {
    final value = _cleanLabel(candidate);
    if (value != null && !isGenericTomestoName(value)) {
      return value;
    }
  }

  final promo = cleanTomestoPromoTitle(promoTitle);
  return promo.isEmpty ? 'Промо' : promo;
}

bool isGenericTomestoName(String? value) {
  final normalized = _normalizeGenericName(value);
  return normalized == 'tomesto' ||
      normalized == 'томесто' ||
      normalized == 'томестo' ||
      normalized == 'tomestoru' ||
      normalized == 'томестоru';
}

String tomestoPromoCategoryKey({
  String? placeKind,
  String? placeCategory,
  String? promoTitle,
  String? promoDescription,
}) {
  final placeKey = _categoryKeyFromText('$placeKind $placeCategory');
  if (placeKey != 'promo') {
    return placeKey;
  }
  return _categoryKeyFromText('$promoTitle $promoDescription');
}

String? _cleanLabel(String? value) {
  final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

String _normalizeGenericName(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+', unicode: true), '');
}

String _categoryKeyFromText(String value) {
  final text = value.toLowerCase().replaceAll('ё', 'е');

  if (_hasAny(text, const [
    'bar',
    'wine',
    'pub',
    'бар',
    'вино',
    'винн',
    'алког',
    'виски',
    'коктейл',
    'паб',
  ])) {
    return 'bar';
  }
  if (_hasAny(text, const [
    'restaurant',
    'food',
    'cafe',
    'coffee',
    'рест',
    'кафе',
    'кофе',
    'еда',
    'ужин',
    'завтрак',
    'бранч',
    'пицц',
    'суши',
    'бургер',
    'стейк',
  ])) {
    return 'food';
  }
  if (_hasAny(text, const [
    'club',
    'night',
    'music',
    'karaoke',
    'клуб',
    'музык',
    'караоке',
    'джаз',
    'танц',
  ])) {
    return 'night';
  }
  if (_hasAny(text, const [
    'culture',
    'museum',
    'theatre',
    'театр',
    'музей',
    'выстав',
    'культур',
  ])) {
    return 'culture';
  }

  return 'promo';
}

bool _hasAny(String text, List<String> needles) {
  return needles.any(text.contains);
}
