import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef AppChatMediaBaseDirectory = Future<Directory> Function();

class AppChatMediaFileStore {
  AppChatMediaFileStore({
    AppChatMediaBaseDirectory? baseDirectory,
  }) : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  final AppChatMediaBaseDirectory _baseDirectory;

  Future<String> copyForPendingUpload({
    required String sourcePath,
    required String uploadId,
    required String fileName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
          'Pending chat media source is missing', sourcePath);
    }
    final base = await _baseDirectory();
    final directory = Directory('${base.path}/pending_chat_media');
    await directory.create(recursive: true);
    final safeUploadId = _safeSegment(uploadId, fallback: 'upload');
    final safeFileName = _safeSegment(fileName, fallback: 'attachment.bin');
    final target = File('${directory.path}/$safeUploadId-$safeFileName');
    if (source.path == target.path) {
      return target.path;
    }
    await source.copy(target.path);
    return target.path;
  }

  String _safeSegment(String value, {required String fallback}) {
    final fileOnly = value.replaceAll('\\', '/').split('/').last.trim();
    final safe = fileOnly.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final compact = safe.replaceAll(RegExp(r'_+'), '_');
    final trimmed = compact.replaceAll(RegExp(r'^[_\.-]+|[_\.-]+$'), '');
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
