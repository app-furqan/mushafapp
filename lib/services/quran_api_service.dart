import '../models/page_data.dart';
import 'database_service.dart';

class QuranApiService {
  final _cache = <int, PageData>{};
  final _inflight = <int, Future<PageData>>{};

  Future<PageData> getPage(int pageNumber) async {
    if (_cache.containsKey(pageNumber)) return _cache[pageNumber]!;
    if (_inflight.containsKey(pageNumber)) return _inflight[pageNumber]!;

    final future = DatabaseService.instance.getPage(pageNumber);
    _inflight[pageNumber] = future;
    try {
      final result = await future;
      _cache[pageNumber] = result;
      return result;
    } finally {
      _inflight.remove(pageNumber);
    }
  }

  void invalidate(int pageNumber) => _cache.remove(pageNumber);
}
