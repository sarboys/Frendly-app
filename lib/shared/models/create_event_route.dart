class CreateEventRoutePayload {
  const CreateEventRoutePayload({
    required this.title,
    required this.steps,
    this.durationLabel,
  });

  final String title;
  final String? durationLabel;
  final List<CreateEventRouteStepPayload> steps;

  Map<String, dynamic> toJson() {
    return {
      'type': 'custom',
      'title': title,
      if (durationLabel != null && durationLabel!.trim().isNotEmpty)
        'durationLabel': durationLabel,
      'steps': steps.map((step) => step.toJson()).toList(growable: false),
    };
  }
}

class CreateEventRouteStepPayload {
  const CreateEventRouteStepPayload({
    required this.time,
    required this.emoji,
    required this.title,
    required this.place,
  });

  final String time;
  final String emoji;
  final String title;
  final String place;

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'emoji': emoji,
      'title': title,
      'place': place,
    };
  }
}
