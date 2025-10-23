// ignore_for_file: avoid_print

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/team.dart';

class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  final List<Team> _teams = [];
  static const String _teamsKey = 'saved_teams';

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

  // Load teams from SharedPreferences
  Future<void> loadTeams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final teamsJson = prefs.getString(_teamsKey);

      if (teamsJson != null) {
        final List<dynamic> teamsList = json.decode(teamsJson);
        _teams.clear();
        _teams.addAll(
          teamsList.map((teamJson) => Team.fromJson(teamJson)).toList(),
        );
        print('Loaded ${_teams.length} teams from storage');
      }
    } catch (e) {
      print('Error loading teams: $e');
    }
  }

  // Save teams to SharedPreferences
  Future<void> _saveTeams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final teamsJson = json.encode(
        _teams.map((team) => team.toJson()).toList(),
      );
      await prefs.setString(_teamsKey, teamsJson);
      print('Saved ${_teams.length} teams to storage');
    } catch (e) {
      print('Error saving teams: $e');
    }
  }

  Future<void> addTeam(Team team) async {
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

    // Save to storage
    await _saveTeams();
  }

  Future<void> updateTeam(Team updatedTeam) async {
    final index = _teams.indexWhere((team) => team.id == updatedTeam.id);
    if (index != -1) {
      _teams[index] = updatedTeam;
      // Save to storage
      await _saveTeams();
    }
  }

  Future<void> deleteTeam(String teamId) async {
    print('Deleting team with ID: $teamId'); // Debug print
    print('Teams before deletion: ${_teams.length}'); // Debug print
    _teams.removeWhere((team) => team.id == teamId);
    print('Teams after deletion: ${_teams.length}'); // Debug print

    // Save to storage
    await _saveTeams();
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
