import '../models/mushaf_type.dart';
import '../models/page_data.dart';
import 'database_service.dart';

class QuranApiService {
  final _cache = <(int, MushafType), PageData>{};
  final _inflight = <(int, MushafType), Future<PageData>>{};

  Future<PageData> getPage(
    int pageNumber, [
    MushafType mushafType = MushafType.hafs,
  ]) async {
    final key = (pageNumber, mushafType);
    if (_cache.containsKey(key)) return _cache[key]!;
    if (_inflight.containsKey(key)) return _inflight[key]!;

    final future = DatabaseService.instance.getPage(pageNumber, mushafType);
    _inflight[key] = future;
    try {
      final result = await future;
      _cache[key] = result;
      return result;
    } finally {
      _inflight.remove(key);
    }
  }
}
