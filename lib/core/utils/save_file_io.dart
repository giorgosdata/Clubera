import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Phones: opens the share sheet with the file (save to Files, email, …).
Future<void> saveBytesAsFile(Uint8List bytes, String fileName, String mimeType, {String? subject}) async {
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
    fileNameOverrides: [fileName],
    subject: subject,
  );
}
