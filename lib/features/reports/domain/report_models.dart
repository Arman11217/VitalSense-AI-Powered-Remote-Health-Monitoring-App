import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../vitals/domain/vital_reading.dart';

/// Result of a generated report (CSV/PDF blob + filename + mime type).
class ReportArtifact {
  ReportArtifact({
    required this.bytes,
    required this.filename,
    required this.mime,
    required this.kind,
  });
  final Uint8List bytes;
  final String filename;
  final String mime;
  final ReportKind kind;
}

enum ReportKind { csv, pdf }

/// Build a CSV blob from a list of readings.
Uint8List buildCsv(List<VitalReading> readings) {
  final buf = StringBuffer()
    ..writeln('timestamp,heart_rate_bpm,spo2_percent,temperature_c')
    ..writeln('ISO8601,integer,0-100,float');
  for (final r in readings) {
    buf.writeln(
        '${r.timestamp.toIso8601String()},${r.heartRateBpm},${r.spo2Percent},${r.temperatureC}');
  }
  return Uint8List.fromList(buf.toString().codeUnits);
}

/// Build a single-page PDF report from a list of readings.
Future<Uint8List> buildPdf(List<VitalReading> readings) async {
  final doc = pw.Document(
    title: 'VitalSense Health Report',
    author: 'VitalSense AI',
  );
  final fmt = DateFormat('MMM d, y · HH:mm:ss');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => <pw.Widget>[
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text('VitalSense Health Report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Generated ${fmt.format(DateTime.now())}'),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Total readings: ${readings.length}',
            style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: <String>['Time', 'HR (bpm)', 'SpO₂ (%)', 'Temp (°C)'],
          data: <List<String>>[
            for (final r in readings)
              <String>[
                fmt.format(r.timestamp),
                r.heartRateBpm.toString(),
                r.spo2Percent.toString(),
                r.temperatureC.toStringAsFixed(1),
              ],
          ],
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        ),
        pw.SizedBox(height: 16),
        pw.Footer(
          title: pw.Text(
            'This report is generated automatically by the VitalSense app '
            'and is not a substitute for professional medical advice.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}