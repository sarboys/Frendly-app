class EventFilters {
  const EventFilters({
    this.lifestyle = 'any',
    this.price = 'any',
    this.gender = 'any',
    this.access = 'any',
    this.date = 'any',
  });

  final String lifestyle;
  final String price;
  final String gender;
  final String access;
  final String date;

  static const defaults = EventFilters();

  int get activeCount {
    var count = 0;
    if (lifestyle != 'any') count += 1;
    if (price != 'any') count += 1;
    if (gender != 'any') count += 1;
    if (access != 'any') count += 1;
    if (date != 'any') count += 1;
    return count;
  }

  bool get hasActiveFilters => activeCount > 0;

  EventFilters copyWith({
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? date,
  }) {
    return EventFilters(
      lifestyle: lifestyle ?? this.lifestyle,
      price: price ?? this.price,
      gender: gender ?? this.gender,
      access: access ?? this.access,
      date: date ?? this.date,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EventFilters &&
        other.lifestyle == lifestyle &&
        other.price == price &&
        other.gender == gender &&
        other.access == access &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(lifestyle, price, gender, access, date);
}
