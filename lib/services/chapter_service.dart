import '../models/chapter_model.dart';
import 'database_service.dart';

class ChapterService {
  // Arabic names of all 114 surahs in order
  static const List<String> _arabicNames = [
    'الْفَاتِحَة', 'الْبَقَرَة', 'آلِ عِمۡرَان', 'النِّسَاء', 'الْمَائِدَة',
    'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
    'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
    'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
    'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
    'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
    'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
    'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
    'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
    'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
    'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
    'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
    'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
    'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
    'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
    'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
    'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
    'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
    'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
    'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
    'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
    'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
    'المسد', 'الإخلاص', 'الفلق', 'الناس',
  ];

  // Surahs that do NOT have bismillah before them (Al-Fatihah=1 and At-Tawbah=9)
  static const Set<int> _noBismillah = {1, 9};

  List<ChapterModel>? _cached;

  Future<List<ChapterModel>> getChapters() async {
    if (_cached != null) return _cached!;

    // Derive start pages from the layout DB
    final db = await DatabaseService.instance.layoutDb;
    final rows = await db.rawQuery('''
      SELECT surah_number, MIN(page_number) AS start_page
      FROM pages
      WHERE line_type = 'surah_name'
        AND surah_number != ''
        AND CAST(surah_number AS INTEGER) > 0
      GROUP BY surah_number
      ORDER BY CAST(surah_number AS INTEGER)
    ''');

    final startPages = <int, int>{};
    for (final row in rows) {
      final surah = row['surah_number'];
      final page = row['start_page'];
      if (surah != null && page != null) {
        final surahId = surah is int ? surah : int.tryParse('$surah') ?? 0;
        final startPage = page is int ? page : int.tryParse('$page') ?? 1;
        if (surahId > 0) startPages[surahId] = startPage;
      }
    }

    _cached = List.generate(_arabicNames.length, (i) {
      final id = i + 1;
      return ChapterModel(
        id: id,
        nameArabic: _arabicNames[i],
        bismillahPre: !_noBismillah.contains(id),
        startPage: startPages[id] ?? 1,
      );
    });

    return _cached!;
  }

  Future<Map<int, ChapterModel>> getChapterStartsByPage() async {
    final chapters = await getChapters();
    return {for (final c in chapters) c.startPage: c};
  }
}
