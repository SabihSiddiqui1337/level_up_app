import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ScoreService {
  static final ScoreService _instance = ScoreService._internal();
  factory ScoreService() => _instance;
  ScoreService._internal();

  static const String _preliminaryScoresKey = 'preliminary_scores';
  static const String _playoffScoresKey = 'playoff_scores';

  // Save preliminary scores to SharedPreferences
  Future<void> savePreliminaryScores(
    Map<String, Map<String, int>> scores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      await prefs.setString(_preliminaryScoresKey, scoresJson);
      print('Saved preliminary scores: $scores');
    } catch (e) {
      print('Error saving preliminary scores: $e');
    }
  }

  // Load preliminary scores from SharedPreferences
  Future<Map<String, Map<String, int>>> loadPreliminaryScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_preliminaryScoresKey);

      if (scoresJson != null) {
        final Map<String, dynamic> decoded = json.decode(scoresJson);
        final Map<String, Map<String, int>> scores = {};

        decoded.forEach((matchId, teamScores) {
          if (teamScores is Map<String, dynamic>) {
            final Map<String, int> convertedScores = {};
            teamScores.forEach((teamId, score) {
              convertedScores[teamId] = score is int ? score : 0;
            });
            scores[matchId] = convertedScores;
          }
        });

        print('Loaded preliminary scores: $scores');
        return scores;
      }
    } catch (e) {
      print('Error loading preliminary scores: $e');
    }

    return {};
  }

  // Save playoff scores to SharedPreferences
  Future<void> savePlayoffScores(Map<String, Map<String, int>> scores) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      await prefs.setString(_playoffScoresKey, scoresJson);
      print('Saved playoff scores: $scores');
    } catch (e) {
      print('Error saving playoff scores: $e');
    }
  }

  // Load playoff scores from SharedPreferences
  Future<Map<String, Map<String, int>>> loadPlayoffScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_playoffScoresKey);

      if (scoresJson != null) {
        final Map<String, dynamic> decoded = json.decode(scoresJson);
        final Map<String, Map<String, int>> scores = {};

        decoded.forEach((matchId, teamScores) {
          if (teamScores is Map<String, dynamic>) {
            final Map<String, int> convertedScores = {};
            teamScores.forEach((teamId, score) {
              convertedScores[teamId] = score is int ? score : 0;
            });
            scores[matchId] = convertedScores;
          }
        });

        print('Loaded playoff scores: $scores');
        return scores;
      }
    } catch (e) {
      print('Error loading playoff scores: $e');
    }

    return {};
  }

  // Clear all scores (useful for testing or reset)
  Future<void> clearAllScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preliminaryScoresKey);
      await prefs.remove(_playoffScoresKey);
      print('Cleared all scores');
    } catch (e) {
      print('Error clearing scores: $e');
    }
  }
}
