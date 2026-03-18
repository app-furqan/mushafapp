import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/word_model.dart';
import '../models/page_data.dart';

class QuranApiService {
  static const _baseUrl = 'https://api.qurancdn.com/api/qdc';

  // In-memory cache for API responses
  final _cache = <int, PageData>{};
  // Track in-flight requests to avoid duplicate fetches
  final _inflight = <int, Future<PageData>>{};

  Future<PageData> getPage(int pageNumber) async {
    if (_cache.containsKey(pageNumber)) return _cache[pageNumber]!;
    if (_inflight.containsKey(pageNumber)) return _inflight[pageNumber]!;

    final future = _fetchPage(pageNumber);
    _inflight[pageNumber] = future;
    try {
      final result = await future;
      _cache[pageNumber] = result;
      return result;
    } finally {
      _inflight.remove(pageNumber);
    }
  }

  Future<PageData> _fetchPage(int pageNumber) async {
    final uri = Uri.parse(
      '$_baseUrl/verses/by_page/$pageNumber'
      '?words=true&word_fields=text_qpc_hafs,code_v2',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode} for page $pageNumber');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    final verses = data['verses'] as List<dynamic>;

    final words = <WordModel>[];
    for (final verse in verses) {
      for (final word in (verse['words'] as List<dynamic>)) {
        words.add(WordModel.fromJson(word as Map<String, dynamic>));
      }
    }
    return PageData.fromWords(pageNumber, words);
  }

  void invalidate(int pageNumber) => _cache.remove(pageNumber);
}
