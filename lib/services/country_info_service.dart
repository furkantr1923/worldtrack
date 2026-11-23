import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/models/models.dart';

/// Ülke özetini Türkçe Vikipedi'den alır ve cihazda önbelleğe yazar.
///
/// Gönderilen bilgi yalnızca ülkenin Wikidata kimliği / adıdır; kişisel seyahat
/// verisi hiçbir zaman gönderilmez. İnternet yoksa önbellekteki özet gösterilir.
class CountryInfoService {
  CountryInfoService(this._db, {http.Client? client}) : _client = client ?? http.Client();

  final Database _db;
  final http.Client _client;

  static const _headers = {
    'User-Agent': 'WORLDTRACK/1.0 (kisisel seyahat arsivi; github.com/furkantr1923/worldtrack)',
    'Accept': 'application/json',
  };
  static const Duration maxAge = Duration(days: 30);
  static const Duration _timeout = Duration(seconds: 12);

  Future<CountryInfo?> cached(String code) async {
    final rows = await _db.query('country_info_cache', where: 'code = ?', whereArgs: [code]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return CountryInfo(
      title: (r['title'] as String?) ?? '',
      summary: (r['summary'] as String?) ?? '',
      url: (r['url'] as String?) ?? '',
      fetchedAt: DateTime.tryParse(r['fetched_at'] as String) ?? DateTime(2000),
    );
  }

  /// Önbellek tazeyse onu, değilse çevrimiçi sürümü döndürür.
  /// Çevrimiçi istek başarısız olursa eski önbellek (varsa) döner; yoksa hata fırlatır.
  Future<CountryInfo> get(Country country, {bool forceRefresh = false}) async {
    final cache = await cached(country.code);
    if (!forceRefresh && cache != null && DateTime.now().difference(cache.fetchedAt) < maxAge) {
      return cache;
    }
    try {
      final fresh = await _fetch(country);
      await _db.insert(
        'country_info_cache',
        {
          'code': country.code,
          'title': fresh.title,
          'summary': fresh.summary,
          'url': fresh.url,
          'fetched_at': fresh.fetchedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return fresh;
    } catch (e) {
      if (cache != null) return cache;
      rethrow;
    }
  }

  Future<int> clearCache() => _db.delete('country_info_cache');

  Future<CountryInfo> _fetch(Country country) async {
    String? title;
    if (country.wikidata.isNotEmpty) {
      final uri = Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbgetentities',
        'ids': country.wikidata,
        'props': 'sitelinks',
        'sitefilter': 'trwiki',
        'format': 'json',
      });
      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final entity = (body['entities'] as Map<String, dynamic>?)?[country.wikidata] as Map<String, dynamic>?;
        final links = entity?['sitelinks'] as Map<String, dynamic>?;
        title = (links?['trwiki'] as Map<String, dynamic>?)?['title'] as String?;
      }
    }
    title ??= country.nameTr;

    final encoded = Uri.encodeComponent(title.replaceAll(' ', '_'));
    final res = await _client
        .get(Uri.parse('https://tr.wikipedia.org/api/rest_v1/page/summary/$encoded'), headers: _headers)
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw CountryInfoException('Vikipedi yanıtı: ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['type'] == 'disambiguation') {
      throw const CountryInfoException('Bu ülke için özet bulunamadı.');
    }
    final extract = (body['extract'] as String?)?.trim() ?? '';
    if (extract.isEmpty) throw const CountryInfoException('Bu ülke için özet bulunamadı.');
    final urls = body['content_urls'] as Map<String, dynamic>?;
    final page = ((urls?['desktop'] as Map<String, dynamic>?)?['page'] as String?) ??
        'https://tr.wikipedia.org/wiki/$encoded';
    return CountryInfo(
      title: (body['title'] as String?) ?? title,
      summary: extract,
      url: page,
      fetchedAt: DateTime.now(),
    );
  }
}

class CountryInfoException implements Exception {
  const CountryInfoException(this.message);
  final String message;
  @override
  String toString() => message;
}
