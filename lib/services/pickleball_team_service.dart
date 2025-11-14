import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/pickleball_team.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class PickleballTeamService {
  final List<PickleballTeam> _teams = [];
  static const String _teamsKey = 'pickleball_teams';

  List<PickleballTeam> get teams => List.unmodifiable(_teams);

  // Get public teams (visible to everyone)
  List<PickleballTeam> getPublicTeams() {
    return _teams.where((team) => !team.isPrivate).toList();
  }

  // Get teams visible to a specific user (public teams + user's private teams + teams where user is a player or captain)
  List<PickleballTeam> getTeamsForUser(String? userId) {
    if (userId == null) {
      // If no user logged in, only show public teams
      return getPublicTeams();
    }

    // Get user from AuthService to check name/email
    final authService = AuthService();
    User? user;
    try {
      user = authService.users.firstWhere((u) => u.id == userId);
    } catch (e) {
      user = authService.currentUser;
    }
    
    if (user == null) {
      return _teams
          .where((team) => !team.isPrivate || team.createdByUserId == userId)
          .toList();
    }

    return _teams.where((team) {
      // Public teams
      if (!team.isPrivate) return true;
      
      // Teams created by user
      if (team.createdByUserId == userId) return true;
      
      if (user != null) {
        // Teams where user is captain (check email or name)
        final isCaptain = team.coachEmail.toLowerCase() == user.email.toLowerCase() ||
                         team.coachName.toLowerCase() == user.name.toLowerCase();
        if (isCaptain) return true;
        
        // Teams where user is a player (PickleballPlayer doesn't have userId)
        // Check by name match as fallback
        final isPlayer = team.players.any((p) => p.name.toLowerCase() == user!.name.toLowerCase());
        if (isPlayer) return true;
      }
      
      return false;
    }).toList();
  }

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
    print(
      'PickleballTeamService: Existing team IDs: ${_teams.map((t) => t.id).toList()}',
    );

    // Check if team with same ID already exists
    bool teamExists = _teams.any((existingTeam) => existingTeam.id == team.id);
    if (teamExists) {
      print(
        'PickleballTeamService: Team with ID ${team.id} already exists! Replacing...',
      );
      // Remove existing team with same ID
      _teams.removeWhere((existingTeam) => existingTeam.id == team.id);
    } else {
      print('PickleballTeamService: New team with unique ID, adding to list');
    }

    _teams.add(team);
    print('PickleballTeamService: Teams count after adding: ${_teams.length}');
    print(
      'PickleballTeamService: All team names: ${_teams.map((t) => t.name).toList()}',
    );
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

  Future<void> deleteTeamsByEventId(String eventId) async {
    _teams.removeWhere((team) => team.eventId == eventId);
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
