// ignore_for_file: avoid_print

import '../models/team.dart';

class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  final List<Team> _teams = [];

  List<Team> get teams {
    print(
      'TeamService.teams getter called, returning ${_teams.length} teams',
    ); // Debug print
    for (var team in _teams) {
      print(
        'TeamService team: ${team.name} has ${team.players.length} players',
      ); // Debug print
    }
    return List.from(_teams); // Changed from List.unmodifiable to List.from
  }

  void addTeam(Team team) {
    print(
      'Adding team: ${team.name} with ${team.players.length} players',
    ); // Debug print
    print(
      'Team players before adding: ${team.players.map((p) => p.name).toList()}',
    ); // Debug print
    _teams.add(team);
    print('Total teams now: ${_teams.length}'); // Debug print
    print(
      'Team after adding: ${_teams.last.name} with ${_teams.last.players.length} players',
    ); // Debug print
    print(
      'Team players after adding: ${_teams.last.players.map((p) => p.name).toList()}',
    ); // Debug print
  }

  void updateTeam(Team updatedTeam) {
    final index = _teams.indexWhere((team) => team.id == updatedTeam.id);
    if (index != -1) {
      _teams[index] = updatedTeam;
    }
  }

  void deleteTeam(String teamId) {
    print('Deleting team with ID: $teamId'); // Debug print
    print('Teams before deletion: ${_teams.length}'); // Debug print
    _teams.removeWhere((team) => team.id == teamId);
    print('Teams after deletion: ${_teams.length}'); // Debug print
  }

  void loadDemoData() {
    if (_teams.isEmpty) {
      _teams.addAll([
        Team(
          id: '1',
          name: 'Thunder Hawks',
          coachName: 'John Coach',
          coachPhone: '987-654-3210',
          coachEmail: 'coach@levelup.com',
          players: [],
          registrationDate: DateTime.now().subtract(const Duration(days: 5)),
          division: 'Adult (18-35)',
        ),
      ]);
    }
  }
}
