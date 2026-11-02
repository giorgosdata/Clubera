// Removes a one-time parameter (like ?invite=…) from the browser's address
// bar, so a reload or a bookmark does not repeat it. No-op on phones.
export 'clean_url_io.dart' if (dart.library.js_interop) 'clean_url_web.dart';
