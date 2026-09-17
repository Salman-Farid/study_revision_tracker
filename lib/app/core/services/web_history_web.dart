import 'package:web/web.dart' as web;

void replaceHistoryUrl(String url) {
  web.window.history.replaceState(null, '', url);
}
