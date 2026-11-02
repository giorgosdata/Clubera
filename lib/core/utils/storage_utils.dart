import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// Picked files are XFile / PlatformFile and are uploaded as bytes, so the
// same code works on phones and in the browser (where dart:io File does not
// exist). Videos on phones still upload from the file, to avoid loading up
// to 100 MB into memory.

class PickedPdf {
  final PlatformFile file;
  final String name;
  PickedPdf({required this.file, required this.name});
}

class StorageUtils {
  static final _picker = ImagePicker();

  static Future<XFile?> pickImage({int maxSizeKB = 2048}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return null;
    final sizeKB = (await picked.length()) / 1024;
    if (sizeKB > maxSizeKB) {
      throw Exception('Image too large (${sizeKB.toStringAsFixed(0)} KB). Max ${maxSizeKB} KB.');
    }
    return picked;
  }

  static Future<PickedPdf?> pickPdf({int maxSizeMB = 10}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return null;
    final pf = result.files.single;
    if (pf.bytes == null && pf.path == null) {
      throw Exception('Could not access file');
    }
    final sizeMB = pf.size / (1024 * 1024);
    if (sizeMB > maxSizeMB) {
      throw Exception('PDF too large (${sizeMB.toStringAsFixed(1)} MB). Max $maxSizeMB MB.');
    }
    return PickedPdf(file: pf, name: pf.name);
  }

  static Future<String> uploadImage({
    required XFile file,
    required String path,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    // Set contentType explicitly: storage.rules require image/* and Android
    // does not infer it from a file:// path, so uploads were rejected.
    final task = await ref.putData(
      await file.readAsBytes(),
      SettableMetadata(contentType: _imageContentType(path)),
    );
    return await task.ref.getDownloadURL();
  }

  static String _imageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  static Future<String> uploadPdf({
    required PlatformFile file,
    required String path,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final meta = SettableMetadata(contentType: 'application/pdf');
    final task = file.bytes != null
        ? await ref.putData(file.bytes!, meta)
        : await ref.putFile(io.File(file.path!), meta);
    return await task.ref.getDownloadURL();
  }

  static Future<String> uploadClubLogo(XFile file, String clubId) =>
      uploadImage(file: file, path: 'clubs/$clubId/logo.jpg');

  static Future<String> uploadUserPhoto(XFile file, String userId) =>
      uploadImage(file: file, path: 'users/$userId/photo.jpg');

  static Future<String> uploadPlayerPhoto(XFile file, String clubId, String playerId) =>
      uploadImage(file: file, path: 'clubs/$clubId/players/$playerId/photo.jpg');

  static Future<String> uploadSponsorPdf({
    required PlatformFile file,
    required String sponsorId,
    required String fileName,
  }) =>
      uploadPdf(file: file, path: 'sponsors/$sponsorId/$fileName');

  static Future<String> uploadPuzzleImage(XFile file, String gameId) =>
      uploadImage(file: file, path: 'games/$gameId/puzzle.jpg');

  static Future<String> uploadPrizePhoto(XFile file, String prizeId) =>
      uploadImage(file: file, path: 'prizes/$prizeId/photo.jpg');

  static Future<String> uploadGalleryPhoto(XFile file, String clubId, String fileName) =>
      uploadImage(file: file, path: 'clubs/$clubId/gallery/$fileName');

  static Future<XFile?> pickVideo({int maxSizeMB = 100}) async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (picked == null) return null;
    final sizeMB = (await picked.length()) / (1024 * 1024);
    if (sizeMB > maxSizeMB) throw Exception('Video too large (${sizeMB.toStringAsFixed(1)} MB). Max $maxSizeMB MB.');
    return picked;
  }

  static Future<String> uploadGalleryVideo(XFile file, String clubId, String fileName) async {
    final ref = FirebaseStorage.instance.ref().child('clubs/$clubId/gallery/$fileName');
    final meta = SettableMetadata(contentType: 'video/mp4');
    final task = kIsWeb
        ? await ref.putData(await file.readAsBytes(), meta)
        : await ref.putFile(io.File(file.path), meta);
    return await task.ref.getDownloadURL();
  }

  static Future<String> uploadStadiumPhoto(XFile file, String clubId, String fileName) =>
      uploadImage(file: file, path: 'clubs/$clubId/stadium_photos/$fileName');
}
