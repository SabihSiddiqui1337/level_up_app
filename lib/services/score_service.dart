import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ScoreService {
  static final ScoreService _instance = ScoreService._internal();
  factory ScoreService() => _instance;
  ScoreService._internal();

  static const String _preliminaryScoresKey = 'preliminary_scores';
  static const String _playoffScoresKey = 'playoff_scores';
  static const String _quarterFinalsScoresKey = 'quarter_finals_scores';
  static const String _semiFinalsScoresKey = 'semi_finals_scores';
  static const String _finalsScoresKey = 'finals_scores';
  static const String _playoffsStartedKey = 'playoffs_started';

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

        return scores;
      }
    } catch (e) {
      print('Error loading playoff scores: $e');
    }

    return {};
  }

  // Save Quarter Finals scores
  Future<void> saveQuarterFinalsScores(
    Map<String, Map<String, int>> scores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      await prefs.setString(_quarterFinalsScoresKey, scoresJson);
      print('Saved quarter finals scores: $scores');
    } catch (e) {
      print('Error saving quarter finals scores: $e');
    }
  }

  // Load Quarter Finals scores
  Future<Map<String, Map<String, int>>> loadQuarterFinalsScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_quarterFinalsScoresKey);

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

        return scores;
      }
    } catch (e) {
      print('Error loading quarter finals scores: $e');
    }

    return {};
  }

  // Save Semi Finals scores
  Future<void> saveSemiFinalsScores(
    Map<String, Map<String, int>> scores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      await prefs.setString(_semiFinalsScoresKey, scoresJson);
      print('Saved semi finals scores: $scores');
    } catch (e) {
      print('Error saving semi finals scores: $e');
    }
  }

  // Load Semi Finals scores
  Future<Map<String, Map<String, int>>> loadSemiFinalsScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_semiFinalsScoresKey);

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

        return scores;
      }
    } catch (e) {
      print('Error loading semi finals scores: $e');
    }

    return {};
  }

  // Save Finals scores
  Future<void> saveFinalsScores(Map<String, Map<String, int>> scores) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      await prefs.setString(_finalsScoresKey, scoresJson);
      print('Saved finals scores: $scores');
    } catch (e) {
      print('Error saving finals scores: $e');
    }
  }

  // Load Finals scores
  Future<Map<String, Map<String, int>>> loadFinalsScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_finalsScoresKey);

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

        return scores;
      }
    } catch (e) {
      print('Error loading finals scores: $e');
    }

    return {};
  }

  // Clear all scores (useful for testing or reset)
  Future<void> clearAllScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preliminaryScoresKey);
      await prefs.remove(_playoffScoresKey);
      await prefs.remove(_quarterFinalsScoresKey);
      await prefs.remove(_semiFinalsScoresKey);
      await prefs.remove(_finalsScoresKey);
      await prefs.remove(_playoffsStartedKey);
      print('Cleared all scores');
    } catch (e) {
      print('Error clearing scores: $e');
    }
  }

  // Save playoff state
  Future<void> savePlayoffsStarted(bool playoffsStarted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_playoffsStartedKey, playoffsStarted);
      print('Saved playoffs started state: $playoffsStarted');
    } catch (e) {
      print('Error saving playoffs started state: $e');
    }
  }

  // Load playoff state
  Future<bool> loadPlayoffsStarted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playoffsStarted = prefs.getBool(_playoffsStartedKey) ?? false;
      return playoffsStarted;
    } catch (e) {
      print('Error loading playoffs started state: $e');
      return false;
    }
  }
}
