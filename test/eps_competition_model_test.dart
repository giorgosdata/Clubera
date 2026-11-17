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

  test('scorers of a club and season statistics', () {
    final c = EpsCompetition.fromMap({
      'standings': [
        {'position': 1, 'team': 'Α', 'clubId': 'a', 'played': 3, 'goalsFor': 9, 'goalsAgainst': 2},
        {'position': 2, 'team': 'Β', 'played': 3, 'goalsFor': 4, 'goalsAgainst': 1},
        {'position': 3, 'team': 'Γ', 'played': 3, 'goalsFor': 1, 'goalsAgainst': 11},
      ],
      'scorers': [
        {'name': 'ΠΑΙΚΤΗΣ 1', 'team': 'Α', 'clubId': 'a', 'goals': 5, 'firstHalf': 2, 'secondHalf': 3},
        {'name': 'ΠΑΙΚΤΗΣ 2', 'team': 'Β', 'goals': 3},
        {'name': 'ΠΑΙΚΤΗΣ 3', 'team': 'Α', 'clubId': 'a', 'goals': 2},
      ],
      'matches': [
        _m(1, 'Α', 'Γ', hs: 6, aws: 0),
        _m(1, 'Β', 'Α', hs: 1, aws: 1),
        _m(2, 'Γ', 'Β', hs: 1, aws: 3),
        _m(2, 'Α', 'Β', hs: 2, aws: 0),
        _m(3, 'Γ', 'Α'),
      ],
    }, 'x');
    expect(c.scorersOf('a').map((s) => s.name).toList(), ['ΠΑΙΚΤΗΣ 1', 'ΠΑΙΚΤΗΣ 3']);
    expect(c.scorers.first.firstHalf, 2);
    final st = c.stats;
    expect(st.played, 4);
    expect(st.totalGoals, 14);
    expect(st.homeWins, 2);
    expect(st.draws, 1);
    expect(st.awayWins, 1);
    expect(st.goalsPerMatch, 3.5);
    expect(st.bestAttack?.team, 'Α');
    expect(st.bestDefence?.team, 'Β');
    expect(st.biggestWin?.homeScore, 6);
    expect(st.homeGoals, 10);
    expect(st.awayGoals, 4);
    expect(st.threePlusGoals, 2);
    expect(st.upToTwoGoals, 2);
    expect(st.bothScored, 2);
    expect(st.cleanSheets, 2);
    expect(st.mostCleanSheetsTeam, 'Α');
    expect(st.mostCleanSheets, 2);
    expect(st.highestScoring?.homeScore, 6);
  });
}
