import 'player.dart';

class Team {
  final String id;
  final String name;
  final String coachName;
  final String coachPhone;
  final String coachEmail;
  final int coachAge; // Captain's age
  final List<Player> players;
  final DateTime registrationDate;
  final String division; // e.g., "Youth", "Adult", "Senior"
  final String?
  createdByUserId; // ID of user who created this team (null = public team)
  final bool isPrivate; // true if team is private to creator only

  Team({
    required this.id,
    required this.name,
    required this.coachName,
    required this.coachPhone,
    required this.coachEmail,
    required this.coachAge,
    required this.players,
    required this.registrationDate,
    required this.division,
    this.createdByUserId,
    this.isPrivate = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coachName': coachName,
      'coachPhone': coachPhone,
      'coachEmail': coachEmail,
      'coachAge': coachAge,
      'players': players.map((player) => player.toJson()).toList(),
      'registrationDate': registrationDate.toIso8601String(),
      'division': division,
      'createdByUserId': createdByUserId,
      'isPrivate': isPrivate,
    };
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      coachName: json['coachName'],
      coachPhone: json['coachPhone'],
      coachEmail: json['coachEmail'],
      coachAge: json['coachAge'] ?? 25, // Default age if not provided
      players:
          (json['players'] as List)
              .map((playerJson) => Player.fromJson(playerJson))
              .toList(),
      registrationDate: DateTime.parse(json['registrationDate']),
      division: json['division'],
      createdByUserId: json['createdByUserId'],
      isPrivate: json['isPrivate'] ?? false,
    );
  }
}
