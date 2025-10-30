import 'pickleball_player.dart';

class PickleballTeam {
  final String id;
  final String name;
  final String coachName;
  final String coachPhone;
  final String coachEmail;
  final List<PickleballPlayer> players;
  final DateTime registrationDate;
  final String division;
  final String?
  createdByUserId; // ID of user who created this team (null = public team)
  final bool isPrivate; // true if team is private to creator only
  final String eventId;

  PickleballTeam({
    required this.id,
    required this.name,
    required this.coachName,
    required this.coachPhone,
    required this.coachEmail,
    required this.players,
    required this.registrationDate,
    required this.division,
    this.createdByUserId,
    this.isPrivate = false,
    required this.eventId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coachName': coachName,
      'coachPhone': coachPhone,
      'coachEmail': coachEmail,
      'players': players.map((player) => player.toJson()).toList(),
      'registrationDate': registrationDate.toIso8601String(),
      'division': division,
      'createdByUserId': createdByUserId,
      'isPrivate': isPrivate,
      'eventId': eventId,
    };
  }

  factory PickleballTeam.fromJson(Map<String, dynamic> json) {
    return PickleballTeam(
      id: json['id'],
      name: json['name'],
      coachName: json['coachName'],
      coachPhone: json['coachPhone'],
      coachEmail: json['coachEmail'],
      players: (json['players'] as List)
          .map((playerJson) => PickleballPlayer.fromJson(playerJson))
          .toList(),
      registrationDate: DateTime.parse(json['registrationDate']),
      division: json['division'],
      createdByUserId: json['createdByUserId'],
      isPrivate: json['isPrivate'] ?? false,
      eventId: json['eventId'] ?? '',
    );
  }
}
