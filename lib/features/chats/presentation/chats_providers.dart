import 'package:big_break_mobile/features/communities/domain/community.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatSegment { all, meetup, dating, personal, clubs }

final chatSegmentProvider =
    StateProvider<ChatSegment>((ref) => ChatSegment.all);

final communityChatsLocalStateProvider =
    StateProvider<List<Community>?>((ref) => null);
