enum MushafType { hafs, indopak, tajIndopak16 }

extension MushafTypeInfo on MushafType {
  String get label => switch (this) {
    MushafType.hafs => 'Hafs (15-line)',
    MushafType.indopak => 'Qudratullah IndoPak (15-line)',
    MushafType.tajIndopak16 => 'Taj IndoPak (16-line)',
  };

  int get totalPages => switch (this) {
    MushafType.hafs => 604,
    MushafType.indopak => 610,
    MushafType.tajIndopak16 => 548,
  };

  int get linesPerPage => switch (this) {
    MushafType.hafs => 15,
    MushafType.indopak => 15,
    MushafType.tajIndopak16 => 16,
  };

  bool get usesIndopakFont => switch (this) {
    MushafType.hafs => false,
    MushafType.indopak => true,
    MushafType.tajIndopak16 => true,
  };

  bool get hasTajweed => this == MushafType.hafs;

  String get layoutDbAssetPath => switch (this) {
    MushafType.hafs => 'assets/data/qpc-v4-tajweed-15-lines.db',
    MushafType.indopak => 'assets/data/qudratullah-indopak-15-lines.db',
    MushafType.tajIndopak16 => 'assets/data/taj-indopak-16-lines.db',
  };

  String get layoutDbFileName => switch (this) {
    MushafType.hafs => 'qpc-v4-tajweed-15-lines.db',
    MushafType.indopak => 'qudratullah-indopak-15-lines.db',
    MushafType.tajIndopak16 => 'taj-indopak-16-lines.db',
  };
}
