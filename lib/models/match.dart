class Match {
  final String id;
  final String day;
  final String court;
  final String time;
  final String team1;
  final String team2;
  final String team1Status; // "Checked-in" or "Not Checked-in"
  final String team2Status; // "Checked-in" or "Not Checked-in"
  final int team1Score;
  final int team2Score;

  const Match({
    required this.id,
    required this.day,
    required this.court,
    required this.time,
    required this.team1,
    required this.team2,
    required this.team1Status,
    required this.team2Status,
    required this.team1Score,
    required this.team2Score,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'court': court,
    'time': time,
    'team1': team1,
    'team2': team2,
    'team1Status': team1Status,
    'team2Status': team2Status,
    'team1Score': team1Score,
    'team2Score': team2Score,
  };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: json['id'] as String,
    day: json['day'] as String,
    court: json['court'] as String,
    time: json['time'] as String,
    team1: json['team1'] as String,
    team2: json['team2'] as String,
    team1Status: json['team1Status'] as String,
    team2Status: json['team2Status'] as String,
    team1Score: json['team1Score'] as int,
    team2Score: json['team2Score'] as int,
  );
}
