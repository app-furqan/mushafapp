import 'package:flutter/material.dart';

enum MushafDisplayMode { light, sepia, dark, black }

extension MushafDisplayModeStyles on MushafDisplayMode {
  String get label {
    switch (this) {
      case MushafDisplayMode.light:
        return 'Light';
      case MushafDisplayMode.sepia:
        return 'Sepia';
      case MushafDisplayMode.dark:
        return 'Dark';
      case MushafDisplayMode.black:
        return 'Black';
    }
  }

  Color get scaffoldColor {
    switch (this) {
      case MushafDisplayMode.light:
        return const Color(0xFFF3EAD7);
      case MushafDisplayMode.sepia:
        return const Color(0xFFE6D4AF);
      case MushafDisplayMode.dark:
        return const Color(0xFF142617);
      case MushafDisplayMode.black:
        return const Color(0xFF050705);
    }
  }

  Color get pageColor {
    switch (this) {
      case MushafDisplayMode.light:
        return const Color(0xFFFFFBF2);
      case MushafDisplayMode.sepia:
        return const Color(0xFFF1E2BC);
      case MushafDisplayMode.dark:
        return const Color(0xFF1B3020);
      case MushafDisplayMode.black:
        return const Color(0xFF0B0F0B);
    }
  }

  Color get borderColor {
    switch (this) {
      case MushafDisplayMode.light:
        return const Color(0xFF8B6914);
      case MushafDisplayMode.sepia:
        return const Color(0xFF6F5120);
      case MushafDisplayMode.dark:
        return const Color(0xFF6E9B72);
      case MushafDisplayMode.black:
        return const Color(0xFF8FB48C);
    }
  }

  Color get textColor {
    switch (this) {
      case MushafDisplayMode.light:
      case MushafDisplayMode.sepia:
        return const Color(0xFF1A1008);
      case MushafDisplayMode.dark:
      case MushafDisplayMode.black:
        return const Color(0xFFF2EAD7);
    }
  }

  Color get overlayBarColor {
    switch (this) {
      case MushafDisplayMode.light:
        return Colors.white.withValues(alpha: 0.9);
      case MushafDisplayMode.sepia:
        return const Color(0xFFE8D9B6).withValues(alpha: 0.92);
      case MushafDisplayMode.dark:
        return const Color(0xFF102015).withValues(alpha: 0.88);
      case MushafDisplayMode.black:
        return Colors.black.withValues(alpha: 0.9);
    }
  }

  Brightness get brightness {
    switch (this) {
      case MushafDisplayMode.light:
      case MushafDisplayMode.sepia:
        return Brightness.light;
      case MushafDisplayMode.dark:
      case MushafDisplayMode.black:
        return Brightness.dark;
    }
  }
}