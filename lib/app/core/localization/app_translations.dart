import 'package:get/get.dart';

import 'translations/ar.dart';
import 'translations/bn.dart';
import 'translations/de.dart';
import 'translations/en.dart';
import 'translations/es.dart';
import 'translations/fa.dart';
import 'translations/fr.dart';
import 'translations/gu.dart';
import 'translations/hi.dart';
import 'translations/id.dart';
import 'translations/ja.dart';
import 'translations/kn.dart';
import 'translations/ko.dart';
import 'translations/ml.dart';
import 'translations/mr.dart';
import 'translations/pt.dart';
import 'translations/ru.dart';
import 'translations/ta.dart';
import 'translations/te.dart';
import 'translations/th.dart';
import 'translations/tr.dart';
import 'translations/ur.dart';
import 'translations/vi.dart';
import 'translations/zh.dart';

/// Complete app localization for 24 languages.
/// English is the fallback — any missing key in another locale falls back here.
///
/// Placeholders: {n} = number, {name} = name — replaced in code via `.tr`.
///
/// Language maps live in `translations/` (one file per locale).
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': en,
        'bn': bn,
        'hi': hi,
        'ur': ur,
        'ar': ar,
        'fa': fa,
        'es': es,
        'fr': fr,
        'de': de,
        'pt': pt,
        'ru': ru,
        'zh': zh,
        'ja': ja,
        'ko': ko,
        'tr': tr_,
        'id': id_,
        'vi': vi,
        'th': th_,
        'ta': ta,
        'te': te,
        'ml': ml,
        'kn': kn,
        'mr': mr,
        'gu': gu,
      };
}
