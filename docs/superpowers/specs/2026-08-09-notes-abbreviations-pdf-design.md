# Per-Course Notes, Course Abbreviations & 3-Page PDF Export — Design

Date: 2026-08-09
Status: Approved (pending written-spec review)

## Overview

Three UI features for the timetable-planner app:

1. **Per-course note** — users write a short free-text note per course; it is shown in the course/session details when a session is tapped in a generated timetable, and on PDF page 3.
2. **Course abbreviation** — the timetable grid shows an auto-derived abbreviation of the course name (e.g. "Chinese Civilisation - History and Philosophy" → **CCHP**) as the primary block label, with the course code small underneath.
3. **3-page PDF export** — replaces the current single-page export with: page 1 = full visual timetable (colored, exactly one page); page 2 = day-by-day textual breakdown (one page preferred, may flow); page 3 = per-course breakdown with note, selected sessions, timings, availability (multi-page, but a single course is never split across pages).

## Feature 1 — Per-course note

### Model (`lib/models/course.dart`)
- Add `final String note` (default `''`) to `Course`.
- `toJson`: add `'note': note`.
- `fromJson`: `note: json['note'] as String? ?? ''` — existing stored data has no `note` key, so **no migration** is needed; it defaults to empty.
- `copyWith`: add `String? note`.

### Provider (`lib/providers/course_data_provider.dart`)
- Add `updateCourseNote(int groupIndex, int courseIndex, String note)` — replaces the course via `copyWith(note: note)`, `notifyListeners()`, and the existing debounced `_scheduleSave()`.

### Dashboard UI (`lib/screens/dashboard_screen.dart`)
- Add a note icon button (`Icons.note_alt_outlined`) to each course card's subtitle row (next to the lock/delete buttons).
- Tapping it opens an `AlertDialog` with a multiline `TextField` (maxLines ~5) pre-filled with the current note. Save commits via `updateCourseNote`; an empty save clears the note. Cancel discards.
- If the course has a non-empty note, the course card shows a one-line italic preview (ellipsized) under the subtitle.

### Detail sheet (`lib/widgets/session_detail_sheet.dart`)
- Below the course code/name, if `course.note` is non-empty, show a subtle quoted block (light background, rounded corners, `Icons.note_alt` + italic text) before the divider.

## Feature 2 — Course abbreviation

### Derivation rule (pure function, `lib/utils/abbreviation.dart`)
`String courseAbbreviation(String name, {String fallback = ''})`:
1. Split `name` into tokens on any non-alphanumeric character (spaces, hyphens, punctuation).
2. Drop tokens that don't start with a letter (e.g. "3D", pure punctuation).
3. Drop connector words (case-insensitive): `and, or, of, the, a, an, in, on, at, for, to, with, by, from, &`.
4. Take the uppercase first letter of each remaining token.
5. Cap the result at **6 letters**.
6. If the result is empty, return `fallback` (callers pass the course code).

Examples:
- "Chinese Civilisation - History and Philosophy" → `CCHP`
- "AI for Software Engineering" → `ASE`
- "Business Programming with Spreadsheet" → `BPS`
- "Algebra" → `A`
- Empty/ill-formed name → fallback (course code)

### Model convenience
- Add `String get abbreviation => courseAbbreviation(courseName, fallback: courseCode);` on `Course`.

### Grid (`lib/widgets/timetable_grid.dart`)
Block label changes to:
- Line 1: **abbreviation** (bold, colored, ~12px).
- Line 2: `CODE · SESSION` (small, grey).
- Line 3: time range (small, grey).

Existing ellipsis + clip behavior is preserved so short blocks don't overflow.

## Feature 3 — 3-page PDF export

### New service (`lib/services/pdf_export_service.dart`)
Extract export logic out of `lib/screens/timetable_screen.dart`:
- `Future<Uint8List> buildPdf({required GeneratedTimetable timetable, required Uint8List gridImagePng})` — pure (testable), returns PDF bytes.
- `Future<void> exportToPrint({required GeneratedTimetable timetable, required Uint8List gridImagePng})` — calls `Printing.layoutPdf(onLayout: (_) async => buildPdf(...))` (the current export mechanism).

### Page 1 — visual capture (exactly one page)
- `TimetableGrid` gains an optional `final GlobalKey? captureKey;`.
- The inner content (header row + body row, i.e. the Column inside both `SingleChildScrollView`s) is wrapped in `RepaintBoundary(key: captureKey)`. Because the boundary sits inside the scroll views, it lays out at **full intrinsic size** — the captured image is the *entire* grid, not the clipped viewport.
- In `timetable_screen._exportToPdf`: resolve the boundary via `captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary`, `await boundary.toImage(pixelRatio: 2.0)`, encode as PNG bytes, pass to the service. If the boundary can't be resolved, abort with a SnackBar (no partial export).
- Page format: custom page sized to the grid image's aspect ratio — `width = 1122pt` (A3-landscape width), `height = min(width / aspect, 1500pt)`. The image is embedded with `pw.BoxFit.contain` so it **always fits on a single page** with minimal letterboxing, at the largest size that fits.

### Page 2 — day-by-day textual breakdown (one page preferred, may flow)
- The existing grouping logic (from the current `_exportToPdf`): group sessions by day, sort by start time, list `HH:MM - HH:MM: ABBR - CODE - SESSION(TYPE) - CRN - NAME`.
- Rendered with `pw.MultiPage` (auto page-breaks) — fits one page for typical data, flows naturally if longer.

### Page 3 — course breakdown (multi-page, keep-together per course)
- For each `SelectedCourse` in the timetable: a header (abbreviation + code + full name) and, if present, the **note**; then each selected session as a row: session type, session code, CRN, day, time, availability, plus a locked badge where applicable.
- Rendered with `pw.MultiPage` using manual keep-together pagination:
  - Maintain a running "used height" for the current page.
  - Before adding each course block, estimate its height (prefer the pdf package's `widget.size`; fall back to a conservative content-based estimate: header + note + per-session row heights).
  - If the block doesn't fit the remaining page height, insert `pw.PageBreak()` and reset used height to 0.
  - Erring toward an early break is the safe direction: worst case a page bottom has unused space, but a course's details are never cut across pages.
  - Only exception: a single course taller than one full page (not realistic for this data) would split — the keep-together constraint is best-effort there.

## Pagination summary (explicit)

| Page | Content | Pagination rule |
|------|---------|-----------------|
| 1 | Visual timetable (colored) | Exactly one page |
| 2 | Day-by-day list | One page preferred; more allowed |
| 3 | Course breakdown | Multi-page; a single course never split across pages |

## Testing

- **Unit — abbreviation** (`test/unit/utils/abbreviation_test.dart`): CCHP example, connector skipping, digit-token skipping, cap at 6, single word, empty-name → fallback.
- **Unit — serialization**: add a `Course` note round-trip case to `test/unit/models/serialization_test.dart` — `toJson`/`fromJson` preserves `note`; missing `note` key → `''`.
- **Widget — detail sheet** (`test/widget/session_detail_sheet_test.dart`): note shown when set, hidden when empty.
- **Widget — grid label**: extend `test/widget/timetable_grid_test.dart` — block shows the abbreviation and the code.
- **Widget — dashboard note dialog**: open dialog, save text, assert provider value updated (and empty save clears).
- **Smoke — PDF** (`test/unit/services/pdf_export_service_test.dart`): `buildPdf` with a stub 1×1 PNG returns non-empty bytes beginning with `%PDF`; page-3 keep-together is verified manually in the running app.

## Files touched

- `lib/models/course.dart` — `note` field + serialization + `abbreviation` getter.
- `lib/utils/abbreviation.dart` — **new**, pure abbreviation function.
- `lib/providers/course_data_provider.dart` — `updateCourseNote`.
- `lib/screens/dashboard_screen.dart` — note dialog + card preview.
- `lib/widgets/session_detail_sheet.dart` — note display.
- `lib/widgets/timetable_grid.dart` — `captureKey` + `RepaintBoundary`, abbreviation label.
- `lib/services/pdf_export_service.dart` — **new**, 3-page builder.
- `lib/screens/timetable_screen.dart` — capture grid image, delegate to service.
- Tests (above).

## Out of scope

- No wizard note field (dashboard-only, per decision).
- No user-editable abbreviation override (auto-derived, per decision).
- No PDF export from other screens.
- No data migration script (defaults handle it).
