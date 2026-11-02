// Parses and validates a club roster (rows from an Excel/CSV file).
//
// Pure Dart (no Flutter, no Firebase) so it can be unit-tested.
// Spec: "Clubera — Ανέβασμα ρόστερ από τους συλλόγους".

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Which part of the club a player belongs to.
enum RosterSquad { first, second, women, academy }

extension RosterSquadX on RosterSquad {
  String get label {
    switch (this) {
      case RosterSquad.first:
        return 'Α΄ Ομάδα';
      case RosterSquad.second:
        return 'Β΄ Ομάδα';
      case RosterSquad.women:
        return 'Γυναικεία';
      case RosterSquad.academy:
        return 'Ακαδημία';
    }
  }

  /// Value stored in the player document (`squad` field).
  String get code {
    switch (this) {
      case RosterSquad.first:
        return 'A';
      case RosterSquad.second:
        return 'B';
      case RosterSquad.women:
        return 'W';
      case RosterSquad.academy:
        return 'ACADEMY';
    }
  }

  /// Firestore subcollection of `clubs/{clubId}` the player goes into.
  String get collection =>
      this == RosterSquad.women ? 'women_players' : 'players';
}

/// The columns of the template, in order. The first name of each list is the
/// header written in the template; the others are accepted aliases.
class RosterColumns {
  static const name = ['Ονοματεπώνυμο', 'Ονοματεπωνυμο', 'Όνομα', 'Ονομα', 'Name', 'Player Name', 'Full name'];
  static const position = ['Θέση', 'Θεση', 'Position', 'Pos'];
  static const number = ['Αριθμός φανέλας', 'Αριθμος φανελας', 'Αριθμός', 'Αριθμος', 'Νούμερο', 'Number', 'Jersey Number', 'Jersey', 'No'];
  static const birthDate = ['Ημερομηνία γέννησης', 'Ημερομηνια γεννησης', 'Ημ. γέννησης', 'Γέννηση', 'Birth date', 'Date of birth', 'DOB', 'Birthday'];
  static const squad = ['Τμήμα', 'Τμημα', 'Ομάδα', 'Ομαδα', 'Squad', 'Team'];
  static const consent = ['Συγκατάθεση', 'Συγκαταθεση', 'Consent'];

  static List<String> get templateHeaders => [
        name.first,
        position.first,
        number.first,
        birthDate.first,
        squad.first,
        consent.first,
      ];
}

/// One row of the file after validation.
class RosterRow {
  final int line; // 1-based line number in the file (header = line 1)
  final String name;
  final String? position; // GK / DEF / MID / FWD
  final int? number;
  final DateTime? birthDate;
  final RosterSquad squad;
  final bool consent;
  final List<String> errors;
  final List<String> warnings;

  const RosterRow({
    required this.line,
    required this.name,
    required this.position,
    required this.number,
    required this.birthDate,
    required this.squad,
    required this.consent,
    required this.errors,
    required this.warnings,
  });

  bool get isValid => errors.isEmpty;

  int? ageOn(DateTime today) {
    final b = birthDate;
    if (b == null) return null;
    var age = today.year - b.year;
    if (today.month < b.month || (today.month == b.month && today.day < b.day)) {
      age--;
    }
    return age;
  }

  bool isMinorOn(DateTime today) {
    final a = ageOn(today);
    return a != null && a < 18;
  }

  /// Stable, privacy-preserving key for duplicate detection: a hash of the
  /// normalized name and birth date. The birth date itself is never stored.
  String get dupKey => rosterDupKey(name, birthDate);
}

class RosterParseResult {
  final List<RosterRow> rows;

  /// Problems with the file as a whole (e.g. missing columns). When this is
  /// not empty, [rows] is empty.
  final List<String> fileErrors;

  const RosterParseResult({required this.rows, required this.fileErrors});

  List<RosterRow> get validRows => rows.where((r) => r.isValid).toList();
  List<RosterRow> get invalidRows => rows.where((r) => !r.isValid).toList();
}

/// Normalizes a name for comparison: upper case, Greek accents removed,
/// single spaces.
String normalizeName(String s) {
  const accents = {
    'Ά': 'Α', 'Έ': 'Ε', 'Ή': 'Η', 'Ί': 'Ι', 'Ϊ': 'Ι', 'Ό': 'Ο', 'Ύ': 'Υ',
    'Ϋ': 'Υ', 'Ώ': 'Ω', 'ΐ': 'Ι', 'ΰ': 'Υ',
  };
  final up = s.trim().toUpperCase();
  final b = StringBuffer();
  for (final ch in up.split('')) {
    b.write(accents[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

String rosterDupKey(String name, DateTime? birthDate) {
  final d = birthDate == null
      ? ''
      : '${birthDate.year.toString().padLeft(4, '0')}-'
          '${birthDate.month.toString().padLeft(2, '0')}-'
          '${birthDate.day.toString().padLeft(2, '0')}';
  return sha256.convert(utf8.encode('${normalizeName(name)}|$d')).toString().substring(0, 32);
}

String? parsePosition(String raw) {
  final v = normalizeName(raw).replaceAll('.', '');
  if (v.isEmpty) return null;
  const map = {
    'GK': 'GK', 'G': 'GK', 'GOALKEEPER': 'GK', 'KEEPER': 'GK',
    'ΤΕΡ': 'GK', 'ΤΕΡΜΑΤΟΦΥΛΑΚΑΣ': 'GK', 'ΤΦ': 'GK', 'ΓΚΟΛΚΙΠΕΡ': 'GK',
    'DEF': 'DEF', 'D': 'DEF', 'DF': 'DEF', 'DEFENDER': 'DEF', 'CB': 'DEF', 'LB': 'DEF', 'RB': 'DEF',
    'ΑΜΥ': 'DEF', 'ΑΜΥΝΤΙΚΟΣ': 'DEF', 'ΑΜΥΝΑ': 'DEF', 'ΚΕΝΤΡΙΚΟΣ ΑΜΥΝΤΙΚΟΣ': 'DEF', 'ΜΠΑΚ': 'DEF',
    'MID': 'MID', 'M': 'MID', 'MF': 'MID', 'MIDFIELDER': 'MID', 'CM': 'MID', 'DM': 'MID', 'AM': 'MID',
    'ΜΕΣ': 'MID', 'ΜΕΣΟΣ': 'MID', 'ΜΕΣΟΣ ΓΡΑΜΜΗΣ': 'MID', 'ΧΑΦ': 'MID',
    'FWD': 'FWD', 'F': 'FWD', 'FW': 'FWD', 'FORWARD': 'FWD', 'ST': 'FWD', 'STRIKER': 'FWD', 'W': 'FWD',
    'ΕΠΙ': 'FWD', 'ΕΠΙΘΕΤΙΚΟΣ': 'FWD', 'ΕΠΙΘΕΣΗ': 'FWD', 'ΦΟΡ': 'FWD', 'ΦΟΡΒΕΡ': 'FWD', 'ΕΞΤΡΕΜ': 'FWD',
  };
  return map[v];
}

RosterSquad? parseSquad(String raw) {
  final v = normalizeName(raw).replaceAll(RegExp(r"[΄'`’.]"), '');
  if (v.isEmpty) return RosterSquad.first;
  // Note: \b only knows ASCII letters, so use (?=\s|$) for Greek.
  if (RegExp(r'^(Α|A|1|ΠΡΩΤΗ|ΑΝΔΡΙΚΗ|ΑΝΔΡΕΣ|FIRST|MEN)(?=\s|$)').hasMatch(v) &&
      !v.contains('ΑΚΑΔ')) {
    return RosterSquad.first;
  }
  if (RegExp(r'^(Β|B|2|ΔΕΥΤΕΡΗ|SECOND|RESERVES?)(?=\s|$)').hasMatch(v)) {
    return RosterSquad.second;
  }
  if (v.contains('ΓΥΝΑΙΚ') || v.contains('WOMEN') || v.contains('ΚΟΡΙΤΣ')) {
    return RosterSquad.women;
  }
  if (v.contains('ΑΚΑΔ') || v.contains('ACADEM') || v.contains('ΥΠΟΔΟΜ') ||
      RegExp(r'^[ΚK]\s?\d{1,2}$').hasMatch(v) || v.contains('U1') || v.contains('ΠΑΙΔ')) {
    return RosterSquad.academy;
  }
  return null;
}

/// Accepts dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy, yyyy-mm-dd and Excel serial
/// day numbers. Returns null when it cannot be read.
DateTime? parseBirthDate(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  final serial = double.tryParse(v);
  if (serial != null && serial > 1000 && serial < 80000) {
    // Excel serial date (1900 system).
    return DateTime.utc(1899, 12, 30).add(Duration(days: serial.floor()));
  }
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(v);
  if (m != null) {
    return _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  m = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})$').firstMatch(v);
  if (m != null) {
    var y = int.parse(m[3]!);
    if (y < 100) y += (y > DateTime.now().year % 100) ? 1900 : 2000;
    return _date(y, int.parse(m[2]!), int.parse(m[1]!));
  }
  return null;
}

DateTime? _date(int y, int mo, int d) {
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final dt = DateTime.utc(y, mo, d);
  if (dt.month != mo || dt.day != d) return null; // e.g. 31/02
  return dt;
}

bool _isYes(String raw) {
  final v = normalizeName(raw);
  return const {'ΝΑΙ', 'NAI', 'YES', 'Y', 'X', '✓', '✔', 'TRUE', '1', 'ΝΑΙ ΓΟΝΕΑ'}.contains(v) ||
      v.startsWith('ΝΑΙ');
}

int? _findColumn(List<String> header, List<String> aliases) {
  final norm = header.map(normalizeName).toList();
  for (final a in aliases) {
    final i = norm.indexOf(normalizeName(a));
    if (i >= 0) return i;
  }
  // Fallback: header starts with an alias (e.g. "Θέση (GK/DEF/MID/FWD)").
  for (var i = 0; i < norm.length; i++) {
    for (final a in aliases) {
      if (norm[i].startsWith(normalizeName(a))) return i;
    }
  }
  return null;
}

/// Parses rows (first row = header) into validated roster rows.
RosterParseResult parseRoster(List<List<String>> table, {DateTime? today}) {
  final now = today ?? DateTime.now();
  // Skip leading empty rows.
  var start = 0;
  while (start < table.length && table[start].every((c) => c.trim().isEmpty)) {
    start++;
  }
  if (start >= table.length) {
    return const RosterParseResult(rows: [], fileErrors: ['Το αρχείο είναι άδειο.']);
  }
  final header = table[start];
  final cName = _findColumn(header, RosterColumns.name);
  final cPos = _findColumn(header, RosterColumns.position);
  final cNum = _findColumn(header, RosterColumns.number);
  final cBirth = _findColumn(header, RosterColumns.birthDate);
  final cSquad = _findColumn(header, RosterColumns.squad);
  final cConsent = _findColumn(header, RosterColumns.consent);

  final missing = <String>[
    if (cName == null) RosterColumns.name.first,
    if (cPos == null) RosterColumns.position.first,
    if (cBirth == null) RosterColumns.birthDate.first,
    if (cConsent == null) RosterColumns.consent.first,
  ];
  if (missing.isNotEmpty) {
    return RosterParseResult(rows: const [], fileErrors: [
      'Λείπουν στήλες: ${missing.join(', ')}. Χρησιμοποιήστε το πρότυπο Excel.',
    ]);
  }

  String cell(List<String> r, int? c) =>
      (c == null || c >= r.length) ? '' : r[c].trim();

  final rows = <RosterRow>[];
  for (var i = start + 1; i < table.length; i++) {
    final r = table[i];
    if (r.every((c) => c.trim().isEmpty)) continue;
    final errors = <String>[];
    final warnings = <String>[];

    final name = cell(r, cName).replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      errors.add('Λείπει το ονοματεπώνυμο');
    } else if (name.length < 3 || !name.contains(' ')) {
      errors.add('Χρειάζεται επώνυμο και όνομα');
    }

    final posRaw = cell(r, cPos);
    final pos = parsePosition(posRaw);
    if (posRaw.isEmpty) {
      errors.add('Λείπει η θέση');
    } else if (pos == null) {
      errors.add('Άγνωστη θέση «$posRaw» (GK / DEF / MID / FWD)');
    }

    int? number;
    final numRaw = cell(r, cNum);
    if (numRaw.isNotEmpty) {
      final d = double.tryParse(numRaw.replaceAll(',', '.'));
      if (d == null || d != d.roundToDouble() || d < 1 || d > 99) {
        errors.add('Ο αριθμός φανέλας πρέπει να είναι 1–99');
      } else {
        number = d.toInt();
      }
    }

    final birthRaw = cell(r, cBirth);
    final birth = parseBirthDate(birthRaw);
    if (birthRaw.isEmpty) {
      errors.add('Λείπει η ημερομηνία γέννησης');
    } else if (birth == null) {
      errors.add('Μη έγκυρη ημερομηνία «$birthRaw» (ΗΗ/ΜΜ/ΕΕΕΕ)');
    } else if (birth.isAfter(now) || now.year - birth.year > 70) {
      errors.add('Η ημερομηνία γέννησης δεν είναι λογική');
    }

    final squadRaw = cell(r, cSquad);
    final squad = parseSquad(squadRaw);
    if (squad == null) {
      errors.add('Άγνωστο τμήμα «$squadRaw»');
    } else if (squad == RosterSquad.academy) {
      errors.add('Οι ακαδημίες δεν ανεβαίνουν ακόμα από Excel');
    }

    final consent = _isYes(cell(r, cConsent));
    final row = RosterRow(
      line: i + 1,
      name: name,
      position: pos,
      number: number,
      birthDate: birth,
      squad: squad ?? RosterSquad.first,
      consent: consent,
      errors: errors,
      warnings: warnings,
    );
    if (!consent) {
      errors.add(row.isMinorOn(now)
          ? 'Ανήλικος: χρειάζεται «ΝΑΙ» στη συγκατάθεση του γονέα'
          : 'Χρειάζεται «ΝΑΙ» στη συγκατάθεση');
    }
    rows.add(row);
  }

  // Duplicates inside the file and jersey numbers used twice in a squad.
  final seenKeys = <String, int>{};
  final seenNumbers = <String, int>{};
  for (final row in rows) {
    if (row.name.isEmpty) continue;
    final k = row.dupKey;
    if (seenKeys.containsKey(k)) {
      row.errors.add('Ίδιος παίκτης με τη γραμμή ${seenKeys[k]}');
    } else {
      seenKeys[k] = row.line;
    }
    if (row.number != null) {
      final nk = '${row.squad.code}#${row.number}';
      if (seenNumbers.containsKey(nk)) {
        row.errors.add('Ο αριθμός ${row.number} υπάρχει ήδη στη γραμμή ${seenNumbers[nk]}');
      } else {
        seenNumbers[nk] = row.line;
      }
    }
  }

  if (rows.isEmpty) {
    return const RosterParseResult(rows: [], fileErrors: ['Το αρχείο δεν έχει παίκτες κάτω από την επικεφαλίδα.']);
  }
  return RosterParseResult(rows: rows, fileErrors: const []);
}

/// Parses CSV text (comma or semicolon separated, quotes supported).
List<List<String>> parseCsv(String text) {
  final src = text.startsWith('﻿') ? text.substring(1) : text;
  final firstLine = src.split('\n').first;
  final sep = firstLine.split(';').length > firstLine.split(',').length ? ';' : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < src.length; i++) {
    final ch = src[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < src.length && src[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == sep) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < src.length && src[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
