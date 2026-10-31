import 'package:clubera/features/club_admin/roster/roster_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.utc(2026, 10, 31);
  final header = RosterColumns.templateHeaders;

  group('parsePosition', () {
    test('english and greek', () {
      expect(parsePosition('GK'), 'GK');
      expect(parsePosition('def'), 'DEF');
      expect(parsePosition('Τερματοφύλακας'), 'GK');
      expect(parsePosition('Αμυντικός'), 'DEF');
      expect(parsePosition('μέσος'), 'MID');
      expect(parsePosition('Επιθετικός'), 'FWD');
      expect(parsePosition('xyz'), isNull);
    });
  });

  group('parseSquad', () {
    test('greek labels', () {
      expect(parseSquad('Α΄ Ομάδα'), RosterSquad.first);
      expect(parseSquad("Α' Ομάδα"), RosterSquad.first);
      expect(parseSquad(''), RosterSquad.first);
      expect(parseSquad('Β΄ Ομάδα'), RosterSquad.second);
      expect(parseSquad('Γυναικεία'), RosterSquad.women);
      expect(parseSquad('Ακαδημία'), RosterSquad.academy);
      expect(parseSquad('Κ16'), RosterSquad.academy);
      expect(parseSquad('Ανδρική'), RosterSquad.first);
      expect(parseSquad('κάτι άλλο'), isNull);
    });
  });

  group('parseBirthDate', () {
    test('formats', () {
      expect(parseBirthDate('05/03/2001'), DateTime.utc(2001, 3, 5));
      expect(parseBirthDate('5.3.2001'), DateTime.utc(2001, 3, 5));
      expect(parseBirthDate('2001-03-05'), DateTime.utc(2001, 3, 5));
      expect(parseBirthDate('36955'), DateTime.utc(2001, 3, 5)); // Excel serial
      expect(parseBirthDate('31/02/2001'), isNull);
      expect(parseBirthDate('abc'), isNull);
    });
  });

  group('normalizeName / dupKey', () {
    test('accents and spaces do not matter', () {
      expect(normalizeName(' Κωστόπουλος   Παναγιώτης '), 'ΚΩΣΤΟΠΟΥΛΟΣ ΠΑΝΑΓΙΩΤΗΣ');
      expect(
        rosterDupKey('Κωστόπουλος Παναγιώτης', DateTime.utc(2001, 3, 5)),
        rosterDupKey('ΚΩΣΤΟΠΟΥΛΟΣ  ΠΑΝΑΓΙΩΤΗΣ', DateTime.utc(2001, 3, 5)),
      );
      expect(
        rosterDupKey('Κωστόπουλος Παναγιώτης', DateTime.utc(2001, 3, 5)),
        isNot(rosterDupKey('Κωστόπουλος Παναγιώτης', DateTime.utc(2002, 3, 5))),
      );
    });
  });

  group('parseRoster', () {
    test('valid rows', () {
      final res = parseRoster([
        header,
        ['ΚΩΣΤΟΠΟΥΛΟΣ ΠΑΝΑΓΙΩΤΗΣ', 'GK', '1', '05/03/2001', 'Α΄ Ομάδα', 'ΝΑΙ'],
        ['ΠΑΠΑΔΑΚΗ ΜΑΡΙΑ', 'MID', '8', '10/10/1999', 'Γυναικεία', 'ναι'],
      ], today: today);
      expect(res.fileErrors, isEmpty);
      expect(res.validRows.length, 2);
      expect(res.rows[0].position, 'GK');
      expect(res.rows[0].number, 1);
      expect(res.rows[1].squad, RosterSquad.women);
      expect(res.rows[1].squad.collection, 'women_players');
    });

    test('missing columns', () {
      final res = parseRoster([
        ['Name', 'Position'],
        ['A B', 'GK'],
      ], today: today);
      expect(res.fileErrors, isNotEmpty);
      expect(res.rows, isEmpty);
    });

    test('row errors', () {
      final res = parseRoster([
        header,
        ['', 'GK', '1', '05/03/2001', '', 'ΝΑΙ'],
        ['ΑΛΦΑ ΒΗΤΑ', 'ζζζ', '100', '05/03/2001', '', 'ΝΑΙ'],
        ['ΓΑΜΜΑ ΔΕΛΤΑ', 'DEF', '', '01/01/2012', '', ''], // minor, no consent
        ['ΕΨΙΛΟΝ ΖΗΤΑ', 'FWD', '9', '01/01/2000', 'Ακαδημία', 'ΝΑΙ'],
      ], today: today);
      expect(res.validRows, isEmpty);
      expect(res.rows[0].errors.join(), contains('ονοματεπώνυμο'));
      expect(res.rows[1].errors.join(), contains('θέση'));
      expect(res.rows[1].errors.join(), contains('1–99'));
      expect(res.rows[2].errors.join(), contains('γονέα'));
      expect(res.rows[2].isMinorOn(today), isTrue);
      expect(res.rows[3].errors.join(), contains('ακαδημίες'));
    });

    test('duplicate player and jersey number', () {
      final res = parseRoster([
        header,
        ['ΑΛΦΑ ΒΗΤΑ', 'GK', '1', '05/03/2001', '', 'ΝΑΙ'],
        ['Άλφα Βήτα', 'GK', '2', '05/03/2001', '', 'ΝΑΙ'],
        ['ΓΑΜΜΑ ΔΕΛΤΑ', 'DEF', '1', '01/01/2000', '', 'ΝΑΙ'],
        ['ΕΨΙΛΟΝ ΖΗΤΑ', 'DEF', '1', '01/01/2000', 'Β΄ Ομάδα', 'ΝΑΙ'],
      ], today: today);
      expect(res.rows[1].errors.join(), contains('γραμμή 2'));
      expect(res.rows[2].errors.join(), contains('αριθμός 1'));
      expect(res.rows[3].isValid, isTrue); // same number, other squad
    });

    test('header aliases and leading empty rows', () {
      final res = parseRoster([
        ['', ''],
        ['Name', 'Θέση (GK/DEF/MID/FWD)', 'Jersey Number', 'DOB', 'Squad', 'Consent'],
        ['ALPHA BETA', 'FWD', '10', '2000-01-01', '', 'yes'],
      ], today: today);
      expect(res.fileErrors, isEmpty);
      expect(res.validRows.length, 1);
    });
  });

  group('parseCsv', () {
    test('comma, semicolon and quotes', () {
      expect(parseCsv('a,b\n1,"x, y"\n'), [
        ['a', 'b'],
        ['1', 'x, y'],
      ]);
      expect(parseCsv('a;b\r\n1;2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
  });
}
