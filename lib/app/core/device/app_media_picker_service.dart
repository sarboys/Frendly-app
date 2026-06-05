import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final appMediaPickerServiceProvider = Provider<AppMediaPickerService>(
  (ref) => NativeAppMediaPickerService(),
);

abstract class AppMediaPickerService {
  Future<PlatformFile?> pickFromCamera();
  Future<PlatformFile?> pickImage();
}

class NativeAppMediaPickerService implements AppMediaPickerService {
  NativeAppMediaPickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  bool get _supportsNativePicker =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<PlatformFile?> pickFromCamera() async {
    if (!_supportsNativePicker) {
      return _pickImageFile();
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null) {
        return null;
      }
      return _fromXFile(file);
    } catch (_) {
      return _pickImageFile();
    }
  }

  @override
  Future<PlatformFile?> pickImage() async {
    if (!_supportsNativePicker) {
      return _pickImageFile();
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null) {
        return null;
      }
      return _fromXFile(file);
    } catch (_) {
      return _pickImageFile();
    }
  }

  Future<PlatformFile?> _pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.single;
  }

  Future<PlatformFile> _fromXFile(XFile file) async {
    final size = await file.length();
    final segments = file.path.split(RegExp(r'[\\/]'));
    final fallbackName = segments.isEmpty ? 'image.jpg' : segments.last;
    return PlatformFile(
      name: file.name.isEmpty ? fallbackName : file.name,
      path: file.path,
      size: size,
    );
  }
}
