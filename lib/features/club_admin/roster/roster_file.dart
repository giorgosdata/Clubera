// Reads roster files (.xlsx / .csv) into rows of strings and builds the
// Excel template clubs fill in.

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'roster_parser.dart';

const rosterSheetName = 'Ρόστερ';
const rosterHelpSheetName = 'Οδηγίες';

/// Turns the bytes of a picked file into a table of strings.
/// Throws a [FormatException] with a Greek message when it cannot be read.
List<List<String>> readRosterFile(Uint8List bytes, String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
    return parseCsv(_decodeText(bytes));
  }
  if (lower.endsWith('.xls')) {
    throw const FormatException(
        'Το παλιό αρχείο .xls δεν υποστηρίζεται. Αποθηκεύστε το ως .xlsx ή .csv.');
  }
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Το αρχείο δεν ανοίγει ως Excel (.xlsx).');
  }
  // Prefer the template's sheet, otherwise the first sheet with data.
  Sheet? sheet = excel.tables[rosterSheetName];
  if (sheet == null || sheet.maxRows == 0) {
    for (final name in excel.tables.keys) {
      if (name == rosterHelpSheetName) continue;
      final s = excel.tables[name]!;
      if (s.maxRows > 0) {
        sheet = s;
        break;
      }
    }
  }
  if (sheet == null) {
    throw const FormatException('Το αρχείο Excel δεν έχει δεδομένα.');
  }
  return [
    for (final row in sheet.rows) [for (final c in row) cellToString(c?.value)],
  ];
}

String _decodeText(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    // Older Excel "CSV" exports use Windows-1253 (Greek); fall back to Latin-1
    // so at least the structure is readable.
    return latin1.decode(bytes);
  }
}

/// Converts any Excel cell to text. Dates become dd/mm/yyyy.
String cellToString(CellValue? v) {
  if (v == null) return '';
  if (v is DateCellValue) return _dmy(v.day, v.month, v.year);
  if (v is DateTimeCellValue) return _dmy(v.day, v.month, v.year);
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) {
    final d = v.value;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }
  if (v is BoolCellValue) return v.value ? 'ΝΑΙ' : '';
  if (v is TextCellValue) return v.value.text ?? '';
  return v.toString();
}

String _dmy(int d, int m, int y) =>
    '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/$y';

/// The Excel template: a "Ρόστερ" sheet with the header row and an
/// "Οδηγίες" sheet explaining each column.
Uint8List buildRosterTemplate() {
  final excel = Excel.createExcel();
  final defaultName = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultName, rosterSheetName);
  final sheet = excel[rosterSheetName];
  sheet.appendRow([
    for (final h in RosterColumns.templateHeaders) TextCellValue(h),
  ]);
  for (var c = 0; c < RosterColumns.templateHeaders.length; c++) {
    sheet.setColumnWidth(c, c == 0 ? 32.0 : 20.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle =
        CellStyle(bold: true);
  }

  final help = excel[rosterHelpSheetName];
  const lines = [
    ['Στήλη', 'Υποχρεωτική', 'Τι γράφετε'],
    ['Ονοματεπώνυμο', 'Ναι', 'ΕΠΩΝΥΜΟ ΟΝΟΜΑ, π.χ. ΚΩΣΤΟΠΟΥΛΟΣ ΠΑΝΑΓΙΩΤΗΣ'],
    ['Θέση', 'Ναι', 'GK / DEF / MID / FWD (ή Τερματοφύλακας / Αμυντικός / Μέσος / Επιθετικός)'],
    ['Αριθμός φανέλας', 'Όχι', '1–99, μοναδικός ανά τμήμα'],
    ['Ημερομηνία γέννησης', 'Ναι', 'ΗΗ/ΜΜ/ΕΕΕΕ. Δεν εμφανίζεται δημόσια· χρησιμοποιείται μόνο για να μη γράφεται ο ίδιος παίκτης δύο φορές.'],
    ['Τμήμα', 'Όχι', 'Α΄ Ομάδα (προεπιλογή) / Β΄ Ομάδα / Γυναικεία. Οι ακαδημίες δεν ανεβαίνουν ακόμα.'],
    ['Συγκατάθεση', 'Ναι', 'ΝΑΙ = ο παίκτης (ή ο γονέας, για ανήλικους) συμφωνεί να εμφανίζεται στο Clubera.'],
    ['', '', ''],
    ['Σημείωση', '', 'Συμπληρώστε τους παίκτες στο φύλλο «Ρόστερ», μία γραμμή ανά παίκτη, κάτω από την επικεφαλίδα. Μην αλλάζετε τα ονόματα των στηλών.'],
  ];
  for (final l in lines) {
    help.appendRow([for (final s in l) TextCellValue(s)]);
  }
  help.setColumnWidth(0, 22.0);
  help.setColumnWidth(1, 14.0);
  help.setColumnWidth(2, 90.0);

  excel.setDefaultSheet(rosterSheetName);
  final bytes = excel.encode();
  if (bytes == null) throw StateError('Could not build the template');
  return Uint8List.fromList(bytes);
}
