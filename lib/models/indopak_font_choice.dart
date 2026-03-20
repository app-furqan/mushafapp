enum IndopakFontChoice {
  indopak,
  kfgqpcNastaleeq,
  digitalKhattIndoPak,
  nastaleeq,
}

extension IndopakFontChoiceInfo on IndopakFontChoice {
  String get label => switch (this) {
    IndopakFontChoice.indopak => 'IndoPak',
    IndopakFontChoice.kfgqpcNastaleeq => 'KFGQPC Nastaleeq',
    IndopakFontChoice.digitalKhattIndoPak => 'DigitalKhatt IndoPak',
    IndopakFontChoice.nastaleeq => 'Nastaleeq',
  };
}
