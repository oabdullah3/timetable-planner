import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';

/// Builds the 2-page timetable PDF:
///
/// 1. Page 1 — the exact visual capture of the timetable grid (colored), kept
///    to EXACTLY one page: the image is box-fit-contained into the page so it
///    is never clipped, whatever paper is used.
/// 2. Page 2 — a per-course breakdown (note, selected sessions, timings,
///    availability). Multi-page, but a single course's block is never split
///    across pages: each block is wrapped in [pw.Inseparable] (canSpan: false),
///    so MultiPage moves a block that would not fit to the next page whole.
class PdfExportService {
  // 40pt margins on every side of the text page.
  static const pw.EdgeInsets _textMargin = pw.EdgeInsets.all(40);

  Future<Uint8List> buildPdf({
    required GeneratedTimetable timetable,
    required Uint8List gridImagePng,
    PdfPageFormat? pageFormat,
  }) async {
    final pdf = pw.Document();
    // The whole document uses ONE paper format (from the print dialog when
    // exporting; A3 landscape as a sensible default otherwise) so every page
    // fits the same physical paper.
    final visualFormat = pageFormat ?? PdfPageFormat.a3.landscape;
    final textFormat = pageFormat ?? PdfPageFormat.a4;

    // ---------- Page 1: exact visual capture (one page) ----------
    pdf.addPage(pw.Page(
      // BoxFit.contain guarantees the image is never clipped: it always fits on
      // this single page, letterboxed if its aspect differs from the paper.
      pageFormat: visualFormat,
      build: (_) => pw.Center(
        child: pw.Image(pw.MemoryImage(gridImagePng), fit: pw.BoxFit.contain),
      ),
    ));

    // ---------- Page 2: per-course breakdown (keep-together) ----------
    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: textFormat, margin: _textMargin),
      // Each block is Inseparable (canSpan: false), so MultiPage never splits a
      // single course across pages — it starts a new page when the block does
      // not fully fit on the current one, exactly as requested.
      build: (_) => [for (final sc in timetable.courses) pw.Inseparable(child: _courseBlock(sc))],
    ));

    return pdf.save();
  }

  /// Sends the PDF to the platform print/share dialog.
  ///
  /// Requests A3 landscape up front (best fit for the timetable grid); if the
  /// user picks a different paper or orientation in the print dialog, that
  /// format is passed through to [buildPdf] so page 1 (the visual timetable)
  /// always fits exactly one page of the chosen paper.
  Future<void> exportToPrint({
    required GeneratedTimetable timetable,
    required Uint8List gridImagePng,
  }) async {
    await Printing.layoutPdf(
      format: PdfPageFormat.a3.landscape,
      onLayout: (format) async => buildPdf(
        timetable: timetable,
        gridImagePng: gridImagePng,
        pageFormat: format,
      ),
    );
  }

  // ------------------------------------------------------------------------
  // Course block helpers
  // ------------------------------------------------------------------------

  pw.Widget _courseBlock(SelectedCourse sc) {
    final course = sc.course;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${course.abbreviation} (${course.courseCode}) - ${course.courseName}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          if (course.note.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
              child: pw.Text(
                'Note: ${course.note.trim()}',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FixedColumnWidth(50),
              3: const pw.FixedColumnWidth(80),
              4: const pw.FixedColumnWidth(110),
              5: const pw.FixedColumnWidth(50),
            },
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Type', bold: true),
                  _cell('Code', bold: true),
                  _cell('CRN', bold: true),
                  _cell('Day', bold: true),
                  _cell('Time', bold: true),
                  _cell('Avail', bold: true),
                ],
              ),
              for (final s in sc.sessions)
                pw.TableRow(
                  children: [
                    _cell(_sessionType(course, s)),
                    _cell(s.sessionCode),
                    _cell(s.crn.toString()),
                    _cell(s.sessionDay),
                    _cell('${s.sessionStartTime}-${s.sessionEndTime}'),
                    _cell(s.sessionAvailability.toString()),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // Shared helpers
  // ------------------------------------------------------------------------

  String _sessionType(Course course, Session session) {
    for (final sg in course.sessionGroups) {
      if (sg.sessionOptions.contains(session)) return sg.sessionType;
    }
    return '';
  }
}
