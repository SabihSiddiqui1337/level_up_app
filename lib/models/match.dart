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

  // Additional fields for scoring functionality
  final String? team1Id;
  final String? team2Id;
  final String? team1Name;
  final String? team2Name;
  final bool isCompleted;
  final DateTime? scheduledDate;

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
    this.team1Id,
    this.team2Id,
    this.team1Name,
    this.team2Name,
    this.isCompleted = false,
    this.scheduledDate,
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
    'team1Id': team1Id,
    'team2Id': team2Id,
    'team1Name': team1Name,
    'team2Name': team2Name,
    'isCompleted': isCompleted,
    'scheduledDate': scheduledDate?.toIso8601String(),
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
    team1Id: json['team1Id'] as String?,
    team2Id: json['team2Id'] as String?,
    team1Name: json['team1Name'] as String?,
    team2Name: json['team2Name'] as String?,
    isCompleted: json['isCompleted'] as bool? ?? false,
    scheduledDate:
        json['scheduledDate'] != null
            ? DateTime.parse(json['scheduledDate'] as String)
            : null,
  );
}
