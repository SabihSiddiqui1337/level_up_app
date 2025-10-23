import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/pickleball_team.dart';

class PickleballTeamService {
  final List<PickleballTeam> _teams = [];
  static const String _teamsKey = 'pickleball_teams';

  List<PickleballTeam> get teams => List.unmodifiable(_teams);

  Future<void> loadTeams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final teamsJson = prefs.getString(_teamsKey);

      if (teamsJson != null) {
        final List<dynamic> teamsList = json.decode(teamsJson);
        _teams.clear();
        _teams.addAll(
          teamsList.map((teamJson) => PickleballTeam.fromJson(teamJson)),
        );
      }
    } catch (e) {
      print('Error loading pickleball teams: $e');
    }
  }

  Future<void> _saveTeams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final teamsJson = json.encode(
        _teams.map((team) => team.toJson()).toList(),
      );
      await prefs.setString(_teamsKey, teamsJson);
    } catch (e) {
      print('Error saving pickleball teams: $e');
    }
  }

  Future<void> addTeam(PickleballTeam team) async {
    print('PickleballTeamService: Adding team ${team.name} with ID ${team.id}');
    print(
      'PickleballTeamService: Current teams count before adding: ${_teams.length}',
    );

    // Check if team with same ID already exists
    bool teamExists = _teams.any((existingTeam) => existingTeam.id == team.id);
    if (teamExists) {
      print(
        'PickleballTeamService: Team with ID ${team.id} already exists! Replacing...',
      );
      // Remove existing team with same ID
      _teams.removeWhere((existingTeam) => existingTeam.id == team.id);
    }

    _teams.add(team);
    print('PickleballTeamService: Teams count after adding: ${_teams.length}');
    await _saveTeams();
  }

  Future<void> updateTeam(PickleballTeam updatedTeam) async {
    final index = _teams.indexWhere((team) => team.id == updatedTeam.id);
    if (index != -1) {
      _teams[index] = updatedTeam;
      await _saveTeams();
    }
  }

  Future<void> deleteTeam(String teamId) async {
    _teams.removeWhere((team) => team.id == teamId);
    await _saveTeams();
  }

  PickleballTeam? getTeamById(String id) {
    try {
      return _teams.firstWhere((team) => team.id == id);
    } catch (e) {
      return null;
    }
  }
}
