import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatSegment { all, meetup, dating, personal, clubs }

final chatSegmentProvider =
    StateProvider<ChatSegment>((ref) => ChatSegment.all);
