import 'package:flutter/material.dart';

/// Ball shown for a club. Four clubs have their own team-coloured ball;
/// every other club gets the neutral one so it does not pick up their glow.
String clubBallAsset(String clubName) {
  final n = clubName.toLowerCase();
  if (n.contains('ηρακλ')) return 'assets/images/balls/heraklis.png';
  if (n.contains('diachron')) return 'assets/images/balls/diachron.png';
  if (n.contains('προαστ')) return 'assets/images/balls/niki.png';
  if (n.contains('γρανιτ')) return 'assets/images/balls/granitis.png';
  return 'assets/images/balls/neutral.png';
}

class ClubBall extends StatelessWidget {
  final String clubName;
  final double size;
  const ClubBall(this.clubName, {super.key, this.size = 60});

  @override
  Widget build(BuildContext context) => Image.asset(
        clubBallAsset(clubName),
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: clubName,
      );
}
