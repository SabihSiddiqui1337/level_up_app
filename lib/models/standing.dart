class Standing {
  final int rank;
  final String teamName;
  final int games;
  final int wins;
  final int draws;
  final int losses;
  final int technicalFouls;
  final int pointDifference;
  final int points;

  const Standing({
    required this.rank,
    required this.teamName,
    required this.games,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.technicalFouls,
    required this.pointDifference,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'teamName': teamName,
    'games': games,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'technicalFouls': technicalFouls,
    'pointDifference': pointDifference,
    'points': points,
  };

  factory Standing.fromJson(Map<String, dynamic> json) => Standing(
    rank: json['rank'] as int,
    teamName: json['teamName'] as String,
    games: json['games'] as int,
    wins: json['wins'] as int,
    draws: json['draws'] as int,
    losses: json['losses'] as int,
    technicalFouls: json['technicalFouls'] as int,
    pointDifference: json['pointDifference'] as int,
    points: json['points'] as int,
  );
}
