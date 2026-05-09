import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/event.dart';

class GroupedSearchResults {
  const GroupedSearchResults({
    required this.meetups,
    required this.routes,
    required this.affiche,
  });

  final List<Event> meetups;
  final List<EveningRouteTemplateSummary> routes;
  final List<AfficheEvent> affiche;

  bool get isEmpty => meetups.isEmpty && routes.isEmpty && affiche.isEmpty;

  factory GroupedSearchResults.fromJson(Map<String, dynamic> json) {
    return GroupedSearchResults(
      meetups: ((json['meetups'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Event.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      routes: ((json['routes'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => EveningRouteTemplateSummary.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      affiche: ((json['affiche'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => AfficheEvent.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}
