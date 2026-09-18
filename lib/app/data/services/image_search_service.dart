import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Fetches a study-related cover image. Uses `package:http` so it works
/// on mobile, desktop, and web (dart:io HttpClient does not).
class ImageSearchService {
  static const _accessKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY',
      defaultValue: '_15JEKa--q5dzR2bJUbfk1iDI69HtmFheP46idJTFpM');

  static final _rng = Random();
  static final _client = http.Client();

  /// Fetch up to 20 Unsplash hits for [subjectName] and pick one at random
  /// so the same subject does not always get the same cover.
  static Future<String?> searchSubjectImage(String subjectName) async {
    try {
      final query = Uri.encodeQueryComponent('$subjectName study');
      // per_page=20 → pool of URLs; random index avoids always using [0].
      final uri = Uri.parse('https://api.unsplash.com/search/photos'
          '?query=$query&per_page=20&orientation=landscape');

      final res = await _client.get(
        uri,
        headers: {
          if (_accessKey.isNotEmpty) 'Authorization': 'Client-ID $_accessKey',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final pick = results[_rng.nextInt(results.length)];
          final urls = pick['urls'] as Map<String, dynamic>?;
          final url = urls?['regular'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
    } catch (_) {
      // Offline / CORS / rate-limit — subject still works without a cover.
    }
    return null;
  }
}
