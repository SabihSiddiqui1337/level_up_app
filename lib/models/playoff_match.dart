class PlayoffMatch {
  final String id;
  final String time;
  final String court;
  final String? team1;
  final String? team2;
  final int team1Score;
  final int team2Score;
  final String round; // "Semi-Finals" or "Finals"

  const PlayoffMatch({
    required this.id,
    required this.time,
    required this.court,
    this.team1,
    this.team2,
    required this.team1Score,
    required this.team2Score,
    required this.round,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'court': court,
    'team1': team1,
    'team2': team2,
    'team1Score': team1Score,
    'team2Score': team2Score,
    'round': round,
  };

  factory PlayoffMatch.fromJson(Map<String, dynamic> json) => PlayoffMatch(
    id: json['id'] as String,
    time: json['time'] as String,
    court: json['court'] as String,
    team1: json['team1'] as String?,
    team2: json['team2'] as String?,
    team1Score: json['team1Score'] as int,
    team2Score: json['team2Score'] as int,
    round: json['round'] as String,
  );
}
