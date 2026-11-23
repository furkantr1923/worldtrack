/// Türkçe karakterlere duyarlı metin işlemleri.
///
/// Arama için metinler "katlanır" (fold): küçük harfe çevrilir (Türkçe I/İ
/// kuralıyla), aksanlar atılır ve ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u dönüşümü
/// yapılır. Böylece "istanbul", "İSTANBUL" ve "Istanbul" aynı sonucu verir;
/// "munih" yazan da "Münih"i bulur.
class TurkishText {
  TurkishText._();

  static const Map<String, String> _fold = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
    'â': 'a', 'î': 'i', 'û': 'u', 'á': 'a', 'à': 'a', 'ä': 'a', 'ã': 'a',
    'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a', 'é': 'e', 'è': 'e', 'ê': 'e',
    'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e', 'í': 'i', 'ì': 'i', 'ï': 'i',
    'ī': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
    'ő': 'o', 'ú': 'u', 'ù': 'u', 'ū': 'u', 'ű': 'u', 'ů': 'u', 'ñ': 'n',
    'ń': 'n', 'ň': 'n', 'ś': 's', 'š': 's', 'ș': 's', 'ž': 'z', 'ź': 'z',
    'ż': 'z', 'č': 'c', 'ć': 'c', 'ř': 'r', 'ł': 'l', 'ý': 'y', 'ÿ': 'y',
    'đ': 'd', 'ď': 'd', 'ț': 't', 'ţ': 't', 'ť': 't', 'œ': 'oe', 'æ': 'ae',
    'ß': 'ss', 'þ': 'th', 'ð': 'd',
  };

  /// Türkçe kurallarına uygun küçük harf (I→ı, İ→i).
  static String lower(String input) =>
      input.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  /// Türkçe kurallarına uygun büyük harf (i→İ, ı→I).
  static String upper(String input) =>
      input.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  /// Arama anahtarı üretir. Harf ve rakam dışındaki her şey tek boşluğa iner.
  static String fold(String input) {
    final lowered = lower(input);
    final out = StringBuffer();
    var lastWasSpace = true;
    for (final rune in lowered.runes) {
      // Birleşik aksan işaretleri (U+0300–U+036F) atılır.
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      final ch = String.fromCharCode(rune);
      final mapped = _fold[ch] ?? ch;
      final isWordChar = _isWordChar(rune) || _fold.containsKey(ch);
      if (isWordChar) {
        out.write(mapped);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        out.write(' ');
        lastWasSpace = true;
      }
    }
    return out.toString().trim();
  }

  static bool _isWordChar(int r) {
    if (r >= 0x30 && r <= 0x39) return true; // 0-9
    if (r >= 0x61 && r <= 0x7A) return true; // a-z
    if (r >= 0x41 && r <= 0x5A) return true; // A-Z
    // Latin dışı alfabeler (Kiril, Yunan, Arap, CJK…) olduğu gibi korunur.
    if (r >= 0x00C0 && r != 0x00D7 && r != 0x00F7) {
      return !(r >= 0x2000 && r <= 0x2BFF) && !(r >= 0x3000 && r <= 0x303F);
    }
    return false;
  }

  /// Aramanın bir metne uyup uymadığı (kelime başı eşleşmesi öncelikli).
  static bool matches(String foldedHaystack, String foldedNeedle) =>
      foldedNeedle.isEmpty || foldedHaystack.contains(foldedNeedle);

  static const String _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

  /// Türk alfabesine göre sıralama karşılaştırıcısı (Ç, Ğ, İ, Ö, Ş, Ü doğru yerde).
  static int compare(String a, String b) {
    final la = lower(a), lb = lower(b);
    final ra = la.runes.toList(), rb = lb.runes.toList();
    final n = ra.length < rb.length ? ra.length : rb.length;
    for (var i = 0; i < n; i++) {
      final ca = String.fromCharCode(ra[i]), cb = String.fromCharCode(rb[i]);
      if (ca == cb) continue;
      final wa = _weight(ca), wb = _weight(cb);
      if (wa != wb) return wa.compareTo(wb);
      final c = ca.compareTo(cb);
      if (c != 0) return c;
    }
    return ra.length.compareTo(rb.length);
  }

  static double _weight(String ch) {
    final i = _alphabet.indexOf(ch);
    if (i >= 0) return i.toDouble();
    final folded = _fold[ch];
    if (folded != null && folded.isNotEmpty) {
      final j = _alphabet.indexOf(folded[0]);
      if (j >= 0) return j + 0.5;
    }
    if (ch == 'q') return _alphabet.indexOf('p') + 0.5;
    if (ch == 'w') return _alphabet.indexOf('v') + 0.5;
    if (ch == 'x') return _alphabet.indexOf('v') + 0.7;
    final code = ch.codeUnitAt(0);
    if (code < 0x41) return -100.0 + code; // boşluk, rakam ve noktalama önde
    return 1000.0 + code;
  }
}
