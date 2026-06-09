import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PickedPdf {
  final File file;
  final String name;
  PickedPdf({required this.file, required this.name});
}

class StorageUtils {
  static final _picker = ImagePicker();

  static Future<File?> pickImage({int maxSizeKB = 2048}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return null;
    final file = File(picked.path);
    final sizeKB = (await file.length()) / 1024;
    if (sizeKB > maxSizeKB) {
      throw Exception('Image too large (${sizeKB.toStringAsFixed(0)} KB). Max ${maxSizeKB} KB.');
    }
    return file;
  }

  static Future<PickedPdf?> pickPdf({int maxSizeMB = 10}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final pf = result.files.single;
    if (pf.path == null) {
      throw Exception('Could not access file path');
    }
    final file = File(pf.path!);
    final sizeMB = (await file.length()) / (1024 * 1024);
    if (sizeMB > maxSizeMB) {
      throw Exception('PDF too large (${sizeMB.toStringAsFixed(1)} MB). Max $maxSizeMB MB.');
    }
    return PickedPdf(file: file, name: pf.name);
  }

  static Future<String> uploadImage({
    required File file,
    required String path,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  static Future<String> uploadPdf({
    required File file,
    required String path,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return await task.ref.getDownloadURL();
  }

  static Future<String> uploadClubLogo(File file, String clubId) =>
      uploadImage(file: file, path: 'clubs/$clubId/logo.jpg');

  static Future<String> uploadUserPhoto(File file, String userId) =>
      uploadImage(file: file, path: 'users/$userId/photo.jpg');

  static Future<String> uploadSponsorPdf({
    required File file,
    required String sponsorId,
    required String fileName,
  }) =>
      uploadPdf(file: file, path: 'sponsors/$sponsorId/$fileName');
}
