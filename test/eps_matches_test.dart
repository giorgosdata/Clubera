import 'package:clubera/features/eps/ui/eps_matches.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day document id uses the calendar date', () {
    expect(epsDayId('eps_achaias', DateTime(2026, 11, 2)), 'eps_achaias__2026-11-02');
  });

  test('day matches become coupon matches', () {
    final list = epsDayMatchesFrom({
      'matches': [
        {
          'id': 'eps_achaias_1042',
          'round': 9,
          'homeTeam': 'ΑΝΑΓΕΝΝΗΣΗ ΠΑΤΡΩΝ',
          'awayTeam': 'ΘΥΕΛΛΑ ΠΑΤΡΩΝ',
          'awayClubId': 'thyella',
          'status': 'upcoming',
          'scheduledAt': '2026-11-22T16:30:00.000Z',
          'hasTime': true,
          'venue': 'ΔΗΜΟΤΙΚΟ ΓΗΠΕΔΟ ΖΑΡΟΥΧΛΕΙΚΩΝ',
          'competitionId': 'eps_achaias__a_erasitechniki_1os_omilos',
          'competitionName': 'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ',
          'level': 'senior',
        },
        {'homeTeam': 'χωρίς id', 'awayTeam': 'x'},
      ],
    });
    expect(list.length, 1);
    final m = list.first;
    expect(m.isSenior, isTrue);
    final mm = m.toMatchModel();
    expect(mm.id, 'eps_achaias_1042');
    expect(mm.homeClubId, '');
    expect(mm.awayClubId, 'thyella');
    expect(mm.isUpcoming, isTrue);
    expect(mm.league, 'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ');
    expect(mm.scheduledAt.toUtc(), DateTime.utc(2026, 11, 22, 16, 30));
  });
}
