import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class UploadedPhoto {
  const UploadedPhoto({required this.url, required this.path});
  final String url;
  final String path;
}

class PhotoStorage {
  PhotoStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const maxBytes = 5 * 1024 * 1024;

  Future<UploadedPhoto> upload({
    required String uid,
    required String incidentId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    // --- TEMPORARY BYPASS FOR DEMO VIDEO ---
    onProgress?.call(0.3);
    await Future.delayed(const Duration(seconds: 1));
    onProgress?.call(1.0);

    final ext = _extension(file.path);
    final validPath =
        'incidents/$uid/${incidentId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    return UploadedPhoto(
      url:
          'https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png',
      path: validPath,
    );

    /*
    final ext = _extension(file.path);
    final path = 'incidents/$uid/${incidentId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref(path);
    final task = ref.putFile(file, SettableMetadata(contentType: _contentType(ext)));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    }, onError: (_) {});
    try {
      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      return UploadedPhoto(url: url, path: path);
    } finally {
      await sub.cancel();
    }
    */
  }

  Future<void> deleteQuietly(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await _storage.ref(path).delete();
    } catch (_) {}
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : path.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
  }

  static String _contentType(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
