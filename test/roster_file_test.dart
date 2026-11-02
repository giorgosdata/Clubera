import 'dart:convert';
import 'dart:typed_data';

import 'package:clubera/features/club_admin/roster/roster_file.dart';
import 'package:clubera/features/club_admin/roster/roster_parser.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template round-trips: header row is read back', () {
    final bytes = buildRosterTemplate();
    final table = readRosterFile(bytes, 'template.xlsx');
    expect(table.first, RosterColumns.templateHeaders);
  });

  test('filled Excel file with a real date cell is parsed', () {
    final excel = Excel.createExcel();
    final name = excel.getDefaultSheet()!;
    final sheet = excel[name];
    sheet.appendRow([
      for (final h in RosterColumns.templateHeaders) TextCellValue(h),
    ]);
    sheet.appendRow([
      TextCellValue('ΚΩΣΤΟΠΟΥΛΟΣ ΠΑΝΑΓΙΩΤΗΣ'),
      TextCellValue('GK'),
      IntCellValue(1),
      DateCellValue(year: 2001, month: 3, day: 5),
      TextCellValue('Α΄ Ομάδα'),
      TextCellValue('ΝΑΙ'),
    ]);
    final bytes = Uint8List.fromList(excel.encode()!);
    final table = readRosterFile(bytes, 'roster.xlsx');
    expect(table[1][3], '05/03/2001');
    final res = parseRoster(table, today: DateTime.utc(2026, 10, 31));
    expect(res.fileErrors, isEmpty);
    expect(res.validRows.single.number, 1);
    expect(res.validRows.single.birthDate, DateTime.utc(2001, 3, 5));
  });

  test('CSV file', () {
    final csv = '${RosterColumns.templateHeaders.join(';')}\n'
        'ΑΛΦΑ ΒΗΤΑ;FWD;9;01/01/2000;;ΝΑΙ\n';
    final table = readRosterFile(Uint8List.fromList(utf8.encode(csv)), 'r.csv');
    final res = parseRoster(table, today: DateTime.utc(2026, 10, 31));
    expect(res.validRows.length, 1);
  });

  test('old .xls is rejected with a clear message', () {
    expect(() => readRosterFile(Uint8List(4), 'old.xls'), throwsFormatException);
  });
}
