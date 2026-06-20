import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerModel {
  final String id;
  final String name;
  final String position; // 'GK' | 'DEF' | 'MID' | 'FWD'
  final int? number;
  final String? photoUrl;
  final int? age;
  final String? nationality;
  final bool isActive;
  // Career stats (aggregated by Cloud Functions from match events)
  final int goals;
  final int yellowCards;
  final int redCards;
  final int appearances;
  // Injury tracking
  final bool isInjured;
  final String? injuryNote;
  final DateTime? expectedReturn;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.position,
    this.number,
    this.photoUrl,
    this.age,
    this.nationality,
    this.isActive = true,
    this.goals = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.appearances = 0,
    this.isInjured = false,
    this.injuryNote,
    this.expectedReturn,
  });

  String get positionLabel {
    switch (position) {
      case 'GK': return 'Goalkeeper';
      case 'DEF': return 'Defender';
      case 'MID': return 'Midfielder';
      case 'FWD': return 'Forward';
      default: return position;
    }
  }

  factory PlayerModel.fromMap(Map<String, dynamic> m, String id) => PlayerModel(
    id: id,
    name: m['name'] ?? '',
    position: m['position'] ?? 'MID',
    number: m['number'],
    photoUrl: m['photoUrl'],
    age: m['age'],
    nationality: m['nationality'],
    isActive: m['isActive'] ?? true,
    goals: (m['goals'] as num?)?.toInt() ?? 0,
    yellowCards: (m['yellowCards'] as num?)?.toInt() ?? 0,
    redCards: (m['redCards'] as num?)?.toInt() ?? 0,
    appearances: (m['appearances'] as num?)?.toInt() ?? 0,
    isInjured: m['isInjured'] ?? false,
    injuryNote: m['injuryNote'] as String?,
    expectedReturn: m['expectedReturn'] is Timestamp
        ? (m['expectedReturn'] as Timestamp).toDate()
        : null,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'position': position,
    'number': number,
    'photoUrl': photoUrl,
    'age': age,
    'nationality': nationality,
    'isActive': isActive,
    'goals': goals,
    'yellowCards': yellowCards,
    'redCards': redCards,
    'appearances': appearances,
    'isInjured': isInjured,
    'injuryNote': injuryNote,
    'expectedReturn': expectedReturn != null ? Timestamp.fromDate(expectedReturn!) : null,
  };

  PlayerModel copyWith({
    String? id,
    String? name,
    String? position,
    int? number,
    String? photoUrl,
    int? age,
    String? nationality,
    bool? isActive,
    int? goals,
    int? yellowCards,
    int? redCards,
    int? appearances,
    bool? isInjured,
    Object? injuryNote = _sentinel,
    Object? expectedReturn = _sentinel,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      number: number ?? this.number,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      nationality: nationality ?? this.nationality,
      isActive: isActive ?? this.isActive,
      goals: goals ?? this.goals,
      yellowCards: yellowCards ?? this.yellowCards,
      redCards: redCards ?? this.redCards,
      appearances: appearances ?? this.appearances,
      isInjured: isInjured ?? this.isInjured,
      injuryNote: identical(injuryNote, _sentinel)
          ? this.injuryNote
          : injuryNote as String?,
      expectedReturn: identical(expectedReturn, _sentinel)
          ? this.expectedReturn
          : expectedReturn as DateTime?,
    );
  }
}

const Object _sentinel = Object();
