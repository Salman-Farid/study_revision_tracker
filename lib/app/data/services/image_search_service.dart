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

  static Future<String?> searchSubjectImage(String subjectName) async {
    try {
      final query = Uri.encodeQueryComponent('$subjectName study');
      final uri = Uri.parse('https://api.unsplash.com/search/photos'
          '?query=$query&per_page=2&orientation=landscape');

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
          return urls?['regular'] as String?;
        }
      }
    } catch (_) {
      // Offline / CORS / rate-limit — subject still works without a cover.
    }
    return null;
  }
}
