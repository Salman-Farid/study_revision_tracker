import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Fetches study-related cover images from Unsplash.
/// Uses `package:http` so it works on mobile, desktop, and web.
class ImageSearchService {
  static const _accessKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY',
      defaultValue: '_15JEKa--q5dzR2bJUbfk1iDI69HtmFheP46idJTFpM');

  static final _rng = Random();
  static final _client = http.Client();

  /// Random cover for a new subject (uses the same quality pool as the picker).
  static Future<String?> searchSubjectImage(String subjectName) async {
    try {
      final pool = await fetchSubjectImagePool(subjectName);
      if (pool.isEmpty) return null;
      return pool[_rng.nextInt(pool.length)];
    } catch (_) {
      return null;
    }
  }

  /// Up to 20 strong, relevant landscape covers for [subjectName].
  ///
  /// Unsplash search params used (from official API docs):
  /// - `order_by=relevant` — best match for the query
  /// - `content_filter=high` — stricter content safety
  /// - `orientation=landscape` — card wallpapers
  /// - several education-focused queries, then rank by likes + min size
  static Future<List<String>> fetchSubjectImagePool(String subjectName) async {
    final name = subjectName.trim();
    if (name.isEmpty) return const [];

    // Narrow, study-relevant queries (not a generic dump).
    final queries = <String>[
      '$name study notes desk',
      '$name textbook education',
      '$name classroom learning',
      name,
    ];

    final seenIds = <String>{};
    final hits = <_Hit>[];

    for (final q in queries) {
      if (hits.length >= 30) break;
      final batch = await _search(q);
      for (final h in batch) {
        if (seenIds.add(h.id)) hits.add(h);
      }
    }

    // Drop tiny/low-effort images; rank popular, relevant photos higher.
    final filtered = hits
        .where((h) => h.width >= 1000 && h.height >= 600)
        .toList()
      ..sort((a, b) {
        final byLikes = b.likes.compareTo(a.likes);
        if (byLikes != 0) return byLikes;
        return b.width.compareTo(a.width);
      });

    final urls = <String>[];
    final seenUrls = <String>{};
    for (final h in filtered) {
      final cover = _coverUrl(h.raw, fallback: h.regular);
      if (cover.isEmpty || !seenUrls.add(cover)) continue;
      urls.add(cover);
      if (urls.length >= 20) break;
    }

    // If quality filter was too strict, fall back to any landscape hits.
    if (urls.isEmpty) {
      for (final h in hits) {
        final cover = _coverUrl(h.raw, fallback: h.regular);
        if (cover.isEmpty || !seenUrls.add(cover)) continue;
        urls.add(cover);
        if (urls.length >= 20) break;
      }
    }
    return urls;
  }

  /// Official search/photos — keep ixid (Unsplash hotlink rule) and force
  /// a sharp landscape crop for subject cards.
  static Future<List<_Hit>> _search(String query) async {
    try {
      final q = Uri.encodeQueryComponent(query);
      final uri = Uri.parse(
        'https://api.unsplash.com/search/photos'
        '?query=$q'
        '&per_page=20'
        '&orientation=landscape'
        '&order_by=relevant'
        '&content_filter=high',
      );
      final res = await _client.get(
        uri,
        headers: {
          'Accept-Version': 'v1',
          if (_accessKey.isNotEmpty) 'Authorization': 'Client-ID $_accessKey',
        },
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null) return const [];
      final out = <_Hit>[];
      for (final r in results) {
        final m = r as Map<String, dynamic>;
        final urls = m['urls'] as Map<String, dynamic>?;
        final raw = urls?['raw'] as String?;
        final regular = urls?['regular'] as String?;
        if ((raw == null || raw.isEmpty) &&
            (regular == null || regular.isEmpty)) {
          continue;
        }
        out.add(_Hit(
          id: m['id'] as String? ?? '${out.length}',
          raw: raw ?? '',
          regular: regular ?? '',
          width: (m['width'] as num?)?.toInt() ?? 0,
          height: (m['height'] as num?)?.toInt() ?? 0,
          likes: (m['likes'] as num?)?.toInt() ?? 0,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Build a high-quality cover URL; preserve `ixid` when present.
  static String _coverUrl(String raw, {String? fallback}) {
    var base = raw.isNotEmpty ? raw : (fallback ?? '');
    if (base.isEmpty) return '';
    // Imgix params — keep any ixid already on the URL.
    const extra =
        'auto=format&fit=crop&crop=entropy&w=1200&h=675&q=82&fm=jpg';
    if (base.contains('?')) {
      return '$base&$extra';
    }
    return '$base?$extra';
  }
}

class _Hit {
  const _Hit({
    required this.id,
    required this.raw,
    required this.regular,
    required this.width,
    required this.height,
    required this.likes,
  });
  final String id;
  final String raw;
  final String regular;
  final int width;
  final int height;
  final int likes;
}
