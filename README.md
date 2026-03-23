# Mushaf App

A Flutter desktop/mobile Quran reader that renders the **Madinah Mushaf** using the **QPC v4** tajweed font set.

---

## About the QPC v4 Font System

### What is QPC v4?

**QPC v4** (Quran Pages Coded, version 4) is the fourth generation of the digital typesetting system developed in collaboration with the **King Fahd Complex for the Printing of the Holy Quran** (Mujamma' al-Malik Fahd), Madinah. It faithfully represents the **Hafs ʿan ʿĀṣim** recitation according to the **Madinah Mushaf** (also called the Mushaf al-Madinah al-Nabawiyyah or the King Fahd Complex Mushaf).

### Font structure

The QPC v4 system ships **604 per-page OpenType fonts** — one font per mushaf page. Each font contains only the glyphs needed for that page, making the encoding:

- **Positional** — each glyph codepoint (U+FC41 and above) encodes a specific word *at a specific position* on a specific page, not a Unicode character. The layout is exact and pixel-perfect.
- **COLR/CPAL** — every font uses the OpenType **COLR v0** colour-layering table together with a **CPAL** colour-palette table. This enables tajweed colouring: each rule (e.g. ikhfāʾ, madd, qalqala) is encoded as a separate colour layer within the glyph. Six palettes are embedded; palette 0 is the light/print palette (black base ink), palette 1 is the dark-mode palette (white ink with adjusted tajweed colours).

| Palette entry | Light colour | Purpose |
|---|---|---|
| 0 | `#000000` | Base ink (most letters) |
| 3 | `#B50000` | Qalqala |
| 4 | `#FF7B00` | Ikhfāʾ / Iqlab |
| 5 | `#CE9E00` | Iẓhār |
| 6 | `#09B000` | Madd |
| 7 | `#3F48E6` | Ghunna |
| 8 | `#2FADFF` | Idghām |
| 9 | `#F40000` | Madd lāzim |
| 10–12 | decorative | Ayah-number ornament colours |

### Local font adjustments

The app now ships two Madinah page-font sets:

- `assets/fonts/v4/` contains the locally edited page fonts used by default in the app.
- `assets/fonts/v4_original/` contains a clean downloaded copy of the original page fonts.

The edited page-font set includes a targeted spacing fix for the hizb-quarter opening glyph on affected pages. This was necessary because the original page fonts allowed the hizb-quarter marker to collide with the following word on some pages. The local edits widen the relevant page-font glyph advances so the hizb quarters no longer touch the following text during rendering.

### Companion fonts

| Font | Purpose |
|---|---|
| `QCF4_QBSML.ttf` (**QCF4Surah**) | 114 per-surah calligraphic banner glyphs, mapped at U+F100 – U+F171 |
| `uthmanic_hafs_v20.ttf` (**UthmanicHafs v20**) | Fallback display font; also provides the Bismillah glyph U+FDFD |

### Layout database

Two SQLite databases drive the layout:

| Database | Contents |
|---|---|
| `qpc-v4.db` | Word table — every word's glyph codepoint, surah/ayah/word position |
| `qpc-v4-tajweed-15-lines.db` | Page layout — 15-line slot assignments per page, line types (`ayah`, `surah_name`, `basmallah`), centering flags, first/last word IDs |

The mushaf is typeset at exactly **15 lines per page** with consistent proportions (~0.67 width-to-height ratio).

---

## What Was Built

### 1. Core Mushaf Renderer

- **`MushafPageWidget`** renders a single mushaf page inside a double-border decorative frame.
- **`_PageLines`** maps the 15 layout slots from the database to typed widgets: surah header, bismillah line, or ayah content line.
- **`_LineContent`** uses a `LayoutBuilder` to measure each word's natural width at a stable base size (25.5 px), then computes a scale factor so the line fills its available width exactly — reproducing the full-justification of the printed mushaf.
- **`_SurahNameBox`** renders the decorative surah-name banner using the per-surah QCF4Surah calligraphic glyph inside a double-border frame.
- **`_BismillahLine`** renders the Bismillah using U+FDFD from UthmanicHafs v20.

### 2. Page Proportions

Wrapping each page in `AspectRatio(0.67)` inside a `Center` widget ensures the mushaf always renders at correct proportions, regardless of window or device size. `Flexible` weights (`surahName: 55`, `basmallah: 80`, `centeredAyah: 90`, `ayah: 100`) distribute vertical space proportionally across all 15 slots.

### 3. Dark Mode via Runtime CPAL Palette Swap

Rather than applying a post-render colour matrix (which cannot properly handle multi-channel COLR glyphs), the app patches the font **bytes at runtime**:

1. The CPAL table's `colorRecordIndices[0]` and `[1]` are swapped in memory.
2. This promotes the font's built-in dark palette (white ink + dark-mode tajweed) to palette 0, which is the default renderer palette.
3. The patched bytes are loaded as a separate `FontLoader` family (`QCF4V4DarkPage{n}`).

Result: tajweed colours are rendered correctly in both light and dark modes with zero widget-level colour transforms.

### 4. Tajweed Off — Ornament Colour Preservation

When tajweed is disabled the font's COLR layer records are patched to redirect all non-ornament palette entries to `0xFFFF` (the OpenType "use foreground colour" sentinel), so:

- All text and tajweed marks render in the display `textColor` (monochrome)
- The decorative ayah-number circle colours (palette entries 10–12) are **preserved** unchanged

Four font variants are loaded per page: light, dark, flat-light, flat-dark.

### 5. Display Modes

| Mode | Background | Ink |
|---|---|---|
| Light | Warm white `#FFFBF2` | Dark brown `#1A1008` |
| Sepia | Parchment `#F1E2BC` | Dark brown `#1A1008` |
| Dark | Deep green `#1B3020` | Warm cream `#F2EAD7` |
| Black | Near-black `#0B0F0B` | Warm cream `#F2EAD7` |

### 6. Navigation

- **PageView** with `reverse: true` so right-to-left page ordering matches mushaf convention (page 1 on the right).
- **Inline page-number text box** in the bottom bar — type any page (1–604) and press Enter to jump; syncs automatically when swiping.
- **Surah list dialog** — jump to any surah by name.
- **Slider** for quick scrubbing across all 604 pages.
- **Zoom** (pinch or ±buttons) via an `InteractiveViewer`.

---

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── chapter_model.dart        # Surah metadata
│   ├── mushaf_display_mode.dart  # Light/Sepia/Dark/Black colour schemes
│   ├── page_data.dart            # PageData, LineData, LayoutLineData
│   └── word_model.dart           # Per-word glyph and position data
├── screens/
│   └── mushaf_screen.dart        # Main screen (PageView, controls, font loading)
├── services/
│   ├── chapter_service.dart      # Fetches surah list
│   ├── database_service.dart     # SQLite access (qpc-v4 + layout DBs)
│   ├── font_service.dart         # Runtime font loading & CPAL/COLR patching
│   └── quran_api_service.dart    # Page data assembly
└── widgets/
    └── mushaf_page_widget.dart   # Core page renderer
assets/
├── data/
│   ├── qpc-v4.db                 # Word glyphs (604 pages)
│   └── qpc-v4-tajweed-15-lines.db # Page layout
└── fonts/
    ├── QCF4_QBSML.ttf            # Surah banner font (114 glyphs)
    ├── uthmanic_hafs_v20.ttf     # UthmanicHafs v20 fallback
    └── v4/                       # 604 per-page QCF4 fonts (p1.ttf – p604.ttf)
```

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.7
- Linux, macOS, Windows, or Android/iOS target

### Run

```bash
flutter pub get
flutter run -d linux --release   # or -d macos / -d android / etc.
```

---

## Credits

- **King Fahd Complex for the Printing of the Holy Quran** — the Madinah Mushaf
