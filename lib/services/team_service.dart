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
    return List.from(_teams); // Changed from List.unmodifiable to List.from
  }

  // Get public teams (visible to everyone)
  List<Team> getPublicTeams() {
    return _teams.where((team) => !team.isPrivate).toList();
  }

  // Get teams visible to a specific user (public teams + user's private teams)
  List<Team> getTeamsForUser(String? userId) {
    if (userId == null) {
      // If no user logged in, only show public teams
      return getPublicTeams();
    }

    return _teams
        .where((team) => !team.isPrivate || team.createdByUserId == userId)
        .toList();
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
    } catch (e) {
      print('Error saving teams: $e');
    }
  }

  Future<void> addTeam(Team team) async {
    _teams.add(team);
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
    _teams.removeWhere((team) => team.id == teamId);
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
          coachAge: 28,
          players: [],
          registrationDate: DateTime.now().subtract(const Duration(days: 5)),
          division: 'Adult 18+',
        ),
      ]);
    }
  }
}
