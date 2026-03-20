enum IndopakFontChoice { indopak, kfgqpcNastaleeq }

extension IndopakFontChoiceInfo on IndopakFontChoice {
  String get label => switch (this) {
    IndopakFontChoice.indopak => 'IndoPak',
    IndopakFontChoice.kfgqpcNastaleeq => 'KFGQPC Nastaleeq',
  };
}
