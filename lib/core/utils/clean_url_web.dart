import 'package:web/web.dart' as web;

void removeQueryParameter(String name) {
  final uri = Uri.base;
  if (!uri.queryParameters.containsKey(name)) return;
  final params = Map<String, String>.from(uri.queryParameters)..remove(name);
  final clean = uri.replace(queryParameters: params.isEmpty ? null : params);
  final text = clean.toString().replaceFirst(RegExp(r'\?$'), '');
  web.window.history.replaceState(null, '', text);
}
