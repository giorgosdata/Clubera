// Files picked by the user, on phones and in the browser.
//
// dart:io File does not exist in the browser, so picked files are kept as
// XFile (works everywhere) and uploaded as bytes. Previews go through
// [xFileImage]: a blob: URL on the web, the local file on phones.

import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;

export 'package:image_picker/image_picker.dart' show XFile;

/// Image provider for a picked file, for previews before upload.
ImageProvider xFileImage(XFile f) => kIsWeb ? NetworkImage(f.path) : FileImage(io.File(f.path));

/// Image widget for a picked file (replaces Image.file).
Widget xFileImageWidget(XFile f, {BoxFit? fit, double? width, double? height}) =>
    Image(image: xFileImage(f), fit: fit, width: width, height: height);
