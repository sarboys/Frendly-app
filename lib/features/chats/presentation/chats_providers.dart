import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatSegment { all, meetup, dating, personal }

final chatSegmentProvider =
    StateProvider<ChatSegment>((ref) => ChatSegment.all);
