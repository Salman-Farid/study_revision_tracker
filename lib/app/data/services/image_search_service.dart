import 'dart:convert';
import 'dart:io';
import 'dart:math';

class ImageSearchService {
  static const _accessKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY',
      defaultValue: '_15JEKa--q5dzR2bJUbfk1iDI69HtmFheP46idJTFpM');

  static final _rng = Random();

  static Future<String?> searchSubjectImage(String subjectName) async {
    try {
      final query = Uri.encodeQueryComponent('$subjectName study');
      final uri = Uri.parse('https://api.unsplash.com/search/photos'
          '?query=$query&per_page=2&orientation=landscape');

      final client = HttpClient();
      final req = await client.getUrl(uri);
      if (_accessKey.isNotEmpty) {
        req.headers.set('Authorization', 'Client-ID $_accessKey');
      }
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();

      if (res.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          // Random pick so the same subject can get a different image each time.
          final pick = results[_rng.nextInt(results.length)];
          final urls = pick['urls'] as Map<String, dynamic>?;
          return urls?['regular'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
