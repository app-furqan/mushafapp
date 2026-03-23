enum PageFontSource { edited, original }

extension PageFontSourceInfo on PageFontSource {
  String get label {
    return switch (this) {
      PageFontSource.edited => 'Edited pages',
      PageFontSource.original => 'Original downloaded pages',
    };
  }

  String get assetDirectory {
    return switch (this) {
      PageFontSource.edited => 'assets/fonts/v4',
      PageFontSource.original => 'assets/fonts/v4_original',
    };
  }

  String get familyKey {
    return switch (this) {
      PageFontSource.edited => 'Edited',
      PageFontSource.original => 'Original',
    };
  }
}
