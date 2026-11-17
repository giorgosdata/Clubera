import 'package:clubera/models/eps_competition_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _m(int round, String home, String away,
        {int? hs, int? aws, String? hId, String? aId, String? at}) =>
    {
      'round': round,
      'homeTeam': home,
      'awayTeam': away,
      'homeClubId': hId,
      'awayClubId': aId,
      'homeScore': hs,
      'awayScore': aws,
      'status': hs == null ? 'upcoming' : 'finished',
      'scheduledAt': at,
      'hasTime': at != null,
    };

void main() {
  final comp = EpsCompetition.fromMap({
    'assocId': 'eps_achaias',
    'assocName': 'ΕΠΣ Αχαΐας',
    'name': 'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 2ος ΟΜΙΛΟΣ',
    'season': '2026-2027',
    'level': 'senior',
    'gender': 'men',
    'clubIds': ['niki'],
    'standings': [
      {'position': 1, 'team': 'ΑΡΗΣ ΠΑΤΡΩΝ', 'points': 13, 'played': 5},
      {'position': 2, 'team': 'ΝΙΚΗ ΠΡΟΑΣΤΕΙΟΥ', 'clubId': 'niki', 'points': 12, 'played': 5},
    ],
    'matches': [
      _m(1, 'ΝΙΚΗ ΠΡΟΑΣΤΕΙΟΥ', 'ΑΡΗΣ ΠΑΤΡΩΝ', hs: 1, aws: 1, hId: 'niki', at: '2026-09-27T13:00:00.000Z'),
      _m(2, 'ΠΑΤΡΑΙ ΑΠΣ', 'ΝΙΚΗ ΠΡΟΑΣΤΕΙΟΥ', hs: 0, aws: 2, aId: 'niki', at: '2026-10-04T13:00:00.000Z'),
      _m(3, 'ΝΙΚΗ ΠΡΟΑΣΤΕΙΟΥ', 'ΑΙΓΙΟΥ ΑΕ', hId: 'niki', at: '2026-11-22T13:00:00.000Z'),
      _m(3, 'ΑΡΗΣ ΠΑΤΡΩΝ', 'ΠΑΤΡΑΙ ΑΠΣ', hs: 2, aws: 0, at: '2026-11-21T13:00:00.000Z'),
      _m(4, 'ΑΙΓΙΟΥ ΑΕ', 'ΝΙΚΗ ΠΡΟΑΣΤΕΙΟΥ', aId: 'niki'),
    ],
  }, 'eps_achaias__a_erasitechniki_2os_omilos');

  test('parses standings and matches', () {
    expect(comp.standings.length, 2);
    expect(comp.matches.length, 5);
    expect(comp.matches.first.isFinished, isTrue);
    expect(comp.matches.last.scheduledAt, isNull);
    expect(comp.matches.last.hasTime, isFalse);
  });

  test('opens on the first round that is not fully played', () {
    expect(comp.rounds, [1, 2, 3, 4]);
    expect(comp.currentRound, 3);
  });

  test('round matches are sorted by date', () {
    final r3 = comp.matchesOfRound(3);
    expect(r3.first.homeTeam, 'ΑΡΗΣ ΠΑΤΡΩΝ');
  });

  test('club view: position, next match and latest results', () {
    expect(comp.standingOf('niki')?.position, 2);
    expect(comp.nextMatchOf('niki')?.round, 3);
    final last = comp.lastResultsOf('niki');
    expect(last.map((m) => m.round).toList(), [2, 1]);
  });

  test('a finished season opens on the last round', () {
    final done = EpsCompetition.fromMap({
      'matches': [_m(1, 'Α', 'Β', hs: 1, aws: 0), _m(2, 'Β', 'Α', hs: 0, aws: 0)],
    }, 'x');
    expect(done.currentRound, 2);
  });

  test('entry of the association list', () {
    final e = EpsCompetitionEntry.fromMap({
      'id': 'eps_achaias__k13_korasidon_8ch8',
      'name': 'Κ13 ΚΟΡΑΣΙΔΩΝ 8Χ8',
      'level': 'youth',
      'ageGroup': 'K13',
      'gender': 'women',
      'teams': 8,
      'rounds': 14,
    });
    expect(e.isYouth, isTrue);
    expect(e.isWomen, isTrue);
    expect(e.teams, 8);
  });
}
