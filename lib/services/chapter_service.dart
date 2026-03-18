import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chapter_model.dart';

class ChapterService {
  static const _chaptersUrl =
      'https://api.qurancdn.com/api/qdc/chapters?language=en';

  Future<List<ChapterModel>> getChapters() async {
    final response = await http.get(Uri.parse(_chaptersUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load chapters: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return (data['chapters'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => ChapterModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<int, ChapterModel>> getChapterStartsByPage() async {
    final chapters = await getChapters();
    final byPage = <int, ChapterModel>{};
    for (final chapter in chapters) {
      byPage[chapter.startPage] = chapter;
    }
    return byPage;
  }
}
