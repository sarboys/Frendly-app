enum EveningMood { chill, social, date, wild }

enum EveningBudget { free, low, mid, high }

enum EveningGoal { newfriends, date, company, quiet }

enum EveningFormat { bar, show, active, culture, mixed }

enum EveningStepKind {
  bar,
  show,
  afterparty,
  followup,
  dinner,
  wellness,
  active,
}

class EveningOption {
  const EveningOption({
    required this.key,
    required this.label,
    this.emoji,
    this.blurb,
  });

  final String key;
  final String label;
  final String? emoji;
  final String? blurb;
}

class EveningRouteStep {
  const EveningRouteStep({
    required this.id,
    required this.time,
    this.endTime,
    required this.kind,
    required this.title,
    required this.venue,
    required this.address,
    required this.emoji,
    required this.distance,
    this.walkMin,
    this.perk,
    this.perkShort,
    this.ticketPrice,
    this.ticketCommission,
    this.ticketUrl,
    this.ticketSourceCode,
    this.ticketProvider,
    this.sponsored = false,
    this.premium = false,
    this.partnerId,
    this.venueId,
    this.partnerOfferId,
    this.offerTitle,
    this.offerDescription,
    this.offerTerms,
    this.offerShortLabel,
    this.description,
    this.vibeTag,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String time;
  final String? endTime;
  final EveningStepKind kind;
  final String title;
  final String venue;
  final String address;
  final String emoji;
  final String distance;
  final int? walkMin;
  final String? perk;
  final String? perkShort;
  final int? ticketPrice;
  final int? ticketCommission;
  final String? ticketUrl;
  final String? ticketSourceCode;
  final String? ticketProvider;
  final bool sponsored;
  final bool premium;
  final String? partnerId;
  final String? venueId;
  final String? partnerOfferId;
  final String? offerTitle;
  final String? offerDescription;
  final String? offerTerms;
  final String? offerShortLabel;
  final String? description;
  final String? vibeTag;
  final double lat;
  final double lng;

  bool get hasShareable => perk != null || ticketPrice != null;

  EveningRouteStep copyWith({
    String? id,
    String? time,
    String? endTime,
    bool clearEndTime = false,
    EveningStepKind? kind,
    String? title,
    String? venue,
    String? address,
    String? emoji,
    String? distance,
    int? walkMin,
    bool clearWalkMin = false,
    String? perk,
    bool clearPerk = false,
    String? perkShort,
    bool clearPerkShort = false,
    int? ticketPrice,
    bool clearTicketPrice = false,
    int? ticketCommission,
    bool clearTicketCommission = false,
    String? ticketUrl,
    bool clearTicketUrl = false,
    String? ticketSourceCode,
    bool clearTicketSourceCode = false,
    String? ticketProvider,
    bool clearTicketProvider = false,
    bool? sponsored,
    bool? premium,
    String? partnerId,
    bool clearPartnerId = false,
    String? venueId,
    bool clearVenueId = false,
    String? partnerOfferId,
    bool clearPartnerOfferId = false,
    String? offerTitle,
    bool clearOfferTitle = false,
    String? offerDescription,
    bool clearOfferDescription = false,
    String? offerTerms,
    bool clearOfferTerms = false,
    String? offerShortLabel,
    bool clearOfferShortLabel = false,
    String? description,
    bool clearDescription = false,
    String? vibeTag,
    bool clearVibeTag = false,
    double? lat,
    double? lng,
  }) {
    return EveningRouteStep(
      id: id ?? this.id,
      time: time ?? this.time,
      endTime: clearEndTime ? null : endTime ?? this.endTime,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      venue: venue ?? this.venue,
      address: address ?? this.address,
      emoji: emoji ?? this.emoji,
      distance: distance ?? this.distance,
      walkMin: clearWalkMin ? null : walkMin ?? this.walkMin,
      perk: clearPerk ? null : perk ?? this.perk,
      perkShort: clearPerkShort ? null : perkShort ?? this.perkShort,
      ticketPrice: clearTicketPrice ? null : ticketPrice ?? this.ticketPrice,
      ticketCommission: clearTicketCommission
          ? null
          : ticketCommission ?? this.ticketCommission,
      ticketUrl: clearTicketUrl ? null : ticketUrl ?? this.ticketUrl,
      ticketSourceCode: clearTicketSourceCode
          ? null
          : ticketSourceCode ?? this.ticketSourceCode,
      ticketProvider:
          clearTicketProvider ? null : ticketProvider ?? this.ticketProvider,
      sponsored: sponsored ?? this.sponsored,
      premium: premium ?? this.premium,
      partnerId: clearPartnerId ? null : partnerId ?? this.partnerId,
      venueId: clearVenueId ? null : venueId ?? this.venueId,
      partnerOfferId:
          clearPartnerOfferId ? null : partnerOfferId ?? this.partnerOfferId,
      offerTitle: clearOfferTitle ? null : offerTitle ?? this.offerTitle,
      offerDescription: clearOfferDescription
          ? null
          : offerDescription ?? this.offerDescription,
      offerTerms: clearOfferTerms ? null : offerTerms ?? this.offerTerms,
      offerShortLabel:
          clearOfferShortLabel ? null : offerShortLabel ?? this.offerShortLabel,
      description: clearDescription ? null : description ?? this.description,
      vibeTag: clearVibeTag ? null : vibeTag ?? this.vibeTag,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}

class EveningRouteData {
  const EveningRouteData({
    required this.id,
    required this.title,
    required this.vibe,
    required this.blurb,
    required this.totalPriceFrom,
    required this.totalSavings,
    required this.durationLabel,
    required this.area,
    required this.goal,
    required this.mood,
    required this.budget,
    this.premium = false,
    this.recommendedFor,
    required this.steps,
    required this.hostsCount,
  });

  final String id;
  final String title;
  final String vibe;
  final String blurb;
  final int totalPriceFrom;
  final int totalSavings;
  final String durationLabel;
  final String area;
  final EveningGoal goal;
  final EveningMood mood;
  final EveningBudget budget;
  final bool premium;
  final String? recommendedFor;
  final List<EveningRouteStep> steps;
  final int hostsCount;

  EveningRouteData copyWith({
    String? id,
    String? title,
    String? vibe,
    String? blurb,
    int? totalPriceFrom,
    int? totalSavings,
    String? durationLabel,
    String? area,
    EveningGoal? goal,
    EveningMood? mood,
    EveningBudget? budget,
    bool? premium,
    String? recommendedFor,
    bool clearRecommendedFor = false,
    List<EveningRouteStep>? steps,
    int? hostsCount,
  }) {
    return EveningRouteData(
      id: id ?? this.id,
      title: title ?? this.title,
      vibe: vibe ?? this.vibe,
      blurb: blurb ?? this.blurb,
      totalPriceFrom: totalPriceFrom ?? this.totalPriceFrom,
      totalSavings: totalSavings ?? this.totalSavings,
      durationLabel: durationLabel ?? this.durationLabel,
      area: area ?? this.area,
      goal: goal ?? this.goal,
      mood: mood ?? this.mood,
      budget: budget ?? this.budget,
      premium: premium ?? this.premium,
      recommendedFor:
          clearRecommendedFor ? null : recommendedFor ?? this.recommendedFor,
      steps: steps ?? this.steps,
      hostsCount: hostsCount ?? this.hostsCount,
    );
  }
}

class AiRouteDraft {
  const AiRouteDraft({
    required this.draftId,
    required this.route,
    required this.acceptedStepIndexes,
    required this.currentStepIndex,
    required this.canConfirm,
    required this.expiresAt,
    required this.warnings,
  });

  final String draftId;
  final EveningRouteData route;
  final Set<int> acceptedStepIndexes;
  final int? currentStepIndex;
  final bool canConfirm;
  final DateTime? expiresAt;
  final List<String> warnings;

  factory AiRouteDraft.fromJson(Map<String, dynamic> json) {
    final accepted = ((json['acceptedStepIndexes'] as List?) ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet();
    final warnings = ((json['warnings'] as List?) ?? const [])
        .map((warning) {
          if (warning is Map) {
            return warning['message'] as String? ?? warning['code'] as String?;
          }
          return warning?.toString();
        })
        .whereType<String>()
        .toList(growable: false);
    return AiRouteDraft(
      draftId: json['draftId'] as String? ?? '',
      route: eveningRouteFromJson(
        Map<String, dynamic>.from((json['route'] as Map?) ?? const {}),
      ),
      acceptedStepIndexes: accepted,
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt(),
      canConfirm: json['canConfirm'] as bool? ?? false,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      warnings: warnings,
    );
  }
}

class EveningBuilderOptions {
  const EveningBuilderOptions({
    required this.goals,
    required this.moods,
    required this.budgets,
    required this.formats,
    required this.areas,
  });

  final List<EveningOption> goals;
  final List<EveningOption> moods;
  final List<EveningOption> budgets;
  final List<EveningOption> formats;
  final List<EveningOption> areas;

  factory EveningBuilderOptions.fromJson(Map<String, dynamic> json) {
    return EveningBuilderOptions(
      goals: eveningOptionsFromJson(json['goals'], eveningGoals),
      moods: eveningOptionsFromJson(json['moods'], eveningMoods),
      budgets: eveningOptionsFromJson(json['budgets'], eveningBudgets),
      formats: eveningOptionsFromJson(json['formats'], eveningFormats),
      areas: eveningOptionsFromJson(json['areas'], eveningAreas),
    );
  }
}

const eveningRoutes = <EveningRouteData>[];

const eveningGoals = <EveningOption>[
  EveningOption(
    key: 'newfriends',
    emoji: '👋',
    label: 'Новые друзья',
    blurb: 'Маршрут с группой',
  ),
  EveningOption(
    key: 'date',
    emoji: '💞',
    label: 'Свидание',
    blurb: 'Для двоих',
  ),
  EveningOption(
    key: 'company',
    emoji: '🥂',
    label: 'С моей компанией',
    blurb: 'С друзьями',
  ),
  EveningOption(
    key: 'quiet',
    emoji: '🌙',
    label: 'Тихий вечер',
    blurb: 'Сам(а) с собой',
  ),
];

const eveningMoods = <EveningOption>[
  EveningOption(key: 'chill', emoji: '🌿', label: 'Спокойно'),
  EveningOption(key: 'social', emoji: '🫶', label: 'Общение'),
  EveningOption(key: 'date', emoji: '💞', label: 'Романтика'),
  EveningOption(key: 'wild', emoji: '🪩', label: 'Громче'),
];

const eveningBudgets = <EveningOption>[
  EveningOption(key: 'free', emoji: '🪙', label: 'Бесплатно', blurb: '0 ₽'),
  EveningOption(key: 'low', emoji: '☕', label: 'Легко', blurb: '500–1500 ₽'),
  EveningOption(key: 'mid', emoji: '🍷', label: 'Средне', blurb: '1500–3000 ₽'),
  EveningOption(key: 'high', emoji: '✨', label: 'Шире', blurb: '3000+ ₽'),
];

const eveningFormats = <EveningOption>[
  EveningOption(key: 'bar', emoji: '🍷', label: 'Бар'),
  EveningOption(key: 'show', emoji: '🎤', label: 'Шоу'),
  EveningOption(key: 'active', emoji: '🏃', label: 'Актив'),
  EveningOption(key: 'culture', emoji: '🎨', label: 'Культура'),
  EveningOption(key: 'mixed', emoji: '🧭', label: 'Смешать'),
];

const eveningAreas = <EveningOption>[
  EveningOption(key: 'center', emoji: '🏛️', label: 'Центр'),
  EveningOption(key: 'patriki', emoji: '🦢', label: 'Патриаршие'),
  EveningOption(key: 'chistye', emoji: '🌳', label: 'Чистые пруды'),
  EveningOption(key: 'gorky', emoji: '🎡', label: 'Парк Горького'),
  EveningOption(key: 'kursk', emoji: '🚉', label: 'Курская'),
  EveningOption(key: 'any', emoji: '🗺️', label: 'Не важно'),
];

List<EveningOption> eveningOptionsFromJson(
  Object? value,
  List<EveningOption> fallback,
) {
  final parsed = ((value as List?) ?? const [])
      .whereType<Map>()
      .map((item) => EveningOption(
            key: item['key'] as String? ?? '',
            emoji: item['emoji'] as String?,
            label: item['label'] as String? ?? '',
            blurb: item['blurb'] as String? ?? item['range'] as String?,
          ))
      .where((item) => item.key.isNotEmpty && item.label.isNotEmpty)
      .toList(growable: false);
  return parsed.isEmpty ? fallback : parsed;
}

String eveningKindLabel(EveningStepKind kind) {
  switch (kind) {
    case EveningStepKind.bar:
      return 'Бар';
    case EveningStepKind.show:
      return 'Шоу';
    case EveningStepKind.afterparty:
      return 'Финал';
    case EveningStepKind.followup:
      return 'Утро';
    case EveningStepKind.dinner:
      return 'Ужин';
    case EveningStepKind.wellness:
      return 'Wellness';
    case EveningStepKind.active:
      return 'Актив';
  }
}

EveningRouteData findEveningRoute(String? id) {
  for (final route in eveningRoutes) {
    if (route.id == id) {
      return route;
    }
  }
  return emptyEveningRoute(id);
}

EveningRouteData eveningRouteFromJson(
  Map<String, dynamic> json, {
  EveningRouteData? fallback,
}) {
  final base = fallback ?? emptyEveningRoute(json['id'] as String?);
  final steps = ((json['steps'] as List?) ?? const [])
      .whereType<Map>()
      .map((item) => eveningRouteStepFromJson(
            Map<String, dynamic>.from(item),
            fallback: base.steps.isEmpty ? null : base.steps.first,
          ))
      .toList(growable: false);

  return EveningRouteData(
    id: json['id'] as String? ?? base.id,
    title: json['title'] as String? ?? base.title,
    vibe: json['vibe'] as String? ?? base.vibe,
    blurb: json['blurb'] as String? ?? base.blurb,
    totalPriceFrom:
        (json['totalPriceFrom'] as num?)?.toInt() ?? base.totalPriceFrom,
    totalSavings: (json['totalSavings'] as num?)?.toInt() ?? base.totalSavings,
    durationLabel: json['durationLabel'] as String? ?? base.durationLabel,
    area: json['area'] as String? ?? base.area,
    goal: eveningGoalFromKey(json['goal'] as String?) ?? base.goal,
    mood: eveningMoodFromKey(json['mood'] as String?) ?? base.mood,
    budget: eveningBudgetFromKey(json['budget'] as String?) ?? base.budget,
    premium: json['premium'] as bool? ?? base.premium,
    recommendedFor: json['recommendedFor'] as String? ?? base.recommendedFor,
    hostsCount: (json['hostsCount'] as num?)?.toInt() ?? base.hostsCount,
    steps: steps.isEmpty ? base.steps : steps,
  );
}

EveningRouteData emptyEveningRoute([String? id]) {
  return EveningRouteData(
    id: id ?? '',
    title: '',
    vibe: '',
    blurb: '',
    totalPriceFrom: 0,
    totalSavings: 0,
    durationLabel: '',
    area: '',
    goal: EveningGoal.newfriends,
    mood: EveningMood.chill,
    budget: EveningBudget.free,
    hostsCount: 0,
    steps: const [],
  );
}

EveningRouteStep eveningRouteStepFromJson(
  Map<String, dynamic> json, {
  EveningRouteStep? fallback,
}) {
  return EveningRouteStep(
    id: json['id'] as String? ?? fallback?.id ?? '',
    time: json['time'] as String? ??
        json['timeLabel'] as String? ??
        fallback?.time ??
        '',
    endTime: json['endTime'] as String? ??
        json['endTimeLabel'] as String? ??
        fallback?.endTime,
    kind: eveningStepKindFromKey(json['kind'] as String?) ??
        fallback?.kind ??
        EveningStepKind.bar,
    title: json['title'] as String? ?? fallback?.title ?? '',
    venue: json['venue'] as String? ?? fallback?.venue ?? '',
    address: json['address'] as String? ?? fallback?.address ?? '',
    emoji: json['emoji'] as String? ?? fallback?.emoji ?? '✨',
    distance: json['distance'] as String? ??
        json['distanceLabel'] as String? ??
        fallback?.distance ??
        '',
    walkMin: (json['walkMin'] as num?)?.toInt() ?? fallback?.walkMin,
    perk: json['perk'] as String? ?? fallback?.perk,
    perkShort: json['perkShort'] as String? ?? fallback?.perkShort,
    ticketPrice:
        (json['ticketPrice'] as num?)?.toInt() ?? fallback?.ticketPrice,
    ticketCommission: (json['ticketCommission'] as num?)?.toInt() ??
        fallback?.ticketCommission,
    ticketUrl: json['ticketUrl'] as String? ?? fallback?.ticketUrl,
    ticketSourceCode:
        json['ticketSourceCode'] as String? ?? fallback?.ticketSourceCode,
    ticketProvider:
        json['ticketProvider'] as String? ?? fallback?.ticketProvider,
    sponsored: json['sponsored'] as bool? ?? fallback?.sponsored ?? false,
    premium: json['premium'] as bool? ?? fallback?.premium ?? false,
    partnerId: json['partnerId'] as String? ?? fallback?.partnerId,
    venueId: json['venueId'] as String? ?? fallback?.venueId,
    partnerOfferId:
        json['partnerOfferId'] as String? ?? fallback?.partnerOfferId,
    offerTitle: json['offerTitle'] as String? ?? fallback?.offerTitle,
    offerDescription:
        json['offerDescription'] as String? ?? fallback?.offerDescription,
    offerTerms: json['offerTerms'] as String? ?? fallback?.offerTerms,
    offerShortLabel:
        json['offerShortLabel'] as String? ?? fallback?.offerShortLabel,
    description: json['description'] as String? ?? fallback?.description,
    vibeTag: json['vibeTag'] as String? ?? fallback?.vibeTag,
    lat: (json['lat'] as num?)?.toDouble() ?? fallback?.lat ?? 0.5,
    lng: (json['lng'] as num?)?.toDouble() ?? fallback?.lng ?? 0.5,
  );
}

EveningGoal? eveningGoalFromKey(String? key) {
  switch (key) {
    case 'newfriends':
      return EveningGoal.newfriends;
    case 'date':
      return EveningGoal.date;
    case 'company':
      return EveningGoal.company;
    case 'quiet':
      return EveningGoal.quiet;
    default:
      return null;
  }
}

EveningMood? eveningMoodFromKey(String? key) {
  switch (key) {
    case 'chill':
      return EveningMood.chill;
    case 'social':
      return EveningMood.social;
    case 'date':
      return EveningMood.date;
    case 'wild':
      return EveningMood.wild;
    default:
      return null;
  }
}

EveningBudget? eveningBudgetFromKey(String? key) {
  switch (key) {
    case 'free':
      return EveningBudget.free;
    case 'low':
      return EveningBudget.low;
    case 'mid':
      return EveningBudget.mid;
    case 'high':
      return EveningBudget.high;
    default:
      return null;
  }
}

EveningFormat? eveningFormatFromKey(String? key) {
  switch (key) {
    case 'bar':
      return EveningFormat.bar;
    case 'show':
      return EveningFormat.show;
    case 'active':
      return EveningFormat.active;
    case 'culture':
      return EveningFormat.culture;
    case 'mixed':
      return EveningFormat.mixed;
    default:
      return null;
  }
}

EveningStepKind? eveningStepKindFromKey(String? key) {
  switch (key) {
    case 'bar':
      return EveningStepKind.bar;
    case 'food':
    case 'restaurant':
    case 'cafe':
      return EveningStepKind.dinner;
    case 'show':
    case 'theatre':
    case 'concert':
    case 'comedy':
    case 'cinema':
    case 'quiz':
    case 'lecture':
    case 'workshop':
    case 'culture':
    case 'market':
    case 'festival':
      return EveningStepKind.show;
    case 'walk':
    case 'outdoor':
    case 'bike':
    case 'sport':
    case 'adventure':
      return EveningStepKind.active;
    case 'afterparty':
      return EveningStepKind.afterparty;
    case 'followup':
      return EveningStepKind.followup;
    case 'dinner':
      return EveningStepKind.dinner;
    case 'wellness':
      return EveningStepKind.wellness;
    case 'active':
      return EveningStepKind.active;
    default:
      return null;
  }
}

EveningRouteData matchEveningRoute({
  EveningGoal? goal,
  EveningMood? mood,
  EveningBudget? budget,
  EveningFormat? format,
  String? area,
}) {
  for (final route in eveningRoutes) {
    if (route.goal == goal) {
      return route;
    }
  }

  for (final route in eveningRoutes) {
    if (route.mood == mood) {
      return route;
    }
  }

  for (final route in eveningRoutes) {
    if (route.budget == budget) {
      return route;
    }
  }

  return emptyEveningRoute();
}
