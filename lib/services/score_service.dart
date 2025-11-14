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
  static const String _gameStartedKey = 'game_started';

  // Save preliminary settings for a specific division
  Future<void> savePreliminarySettingsForDivision(
    String division,
    int gamesPerTeam,
    int winningScore,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'preliminary_settings_$division';
      final settings = {
        'gamesPerTeam': gamesPerTeam,
        'winningScore': winningScore,
      };
      final settingsJson = json.encode(settings);
      await prefs.setString(key, settingsJson);
      print(
        'Saved preliminary settings for division $division: gamesPerTeam=$gamesPerTeam, winningScore=$winningScore',
      );
    } catch (e) {
      print('Error saving preliminary settings for division $division: $e');
    }
  }

  // Load preliminary settings for a specific division
  Future<Map<String, int>> loadPreliminarySettingsForDivision(
    String division,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'preliminary_settings_$division';
      final settingsJson = prefs.getString(key);

      if (settingsJson != null) {
        final Map<String, dynamic> decoded = json.decode(settingsJson);
        final settings = {
          'gamesPerTeam': (decoded['gamesPerTeam'] ?? 1) as int,
          'winningScore': (decoded['winningScore'] ?? 11) as int,
        };
        print('Loaded preliminary settings for division $division: $settings');
        return settings;
      }
    } catch (e) {
      print('Error loading preliminary settings for division $division: $e');
    }
    return {'gamesPerTeam': 1, 'winningScore': 11}; // Default values
  }

  // Save selected division for a sport
  Future<void> saveSelectedDivision(String sportName, String division) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'selected_division_$sportName';
      await prefs.setString(key, division);
      print('Saved selected division for $sportName: $division');
    } catch (e) {
      print('Error saving selected division for $sportName: $e');
    }
  }

  // Load selected division for a sport
  Future<String?> loadSelectedDivision(String sportName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'selected_division_$sportName';
      final division = prefs.getString(key);
      print('Loaded selected division for $sportName: $division');
      return division;
    } catch (e) {
      print('Error loading selected division for $sportName: $e');
      return null;
    }
  }

  // Save preliminary scores for a specific division
  Future<void> savePreliminaryScoresForDivision(
    String division,
    Map<String, Map<String, int>> scores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final divisionKey = 'preliminary_scores_$division';
      final scoresJson = json.encode(scores);
      await prefs.setString(divisionKey, scoresJson);
      print('Saved preliminary scores for division $division: $scores');
    } catch (e) {
      print('Error saving preliminary scores for division $division: $e');
    }
  }

  // Load preliminary scores for a specific division
  Future<Map<String, Map<String, int>>> loadPreliminaryScoresForDivision(
    String division,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final divisionKey = 'preliminary_scores_$division';
      final scoresJson = prefs.getString(divisionKey);

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

        print('Loaded preliminary scores for division $division: $scores');
        return scores;
      }
    } catch (e) {
      print('Error loading preliminary scores for division $division: $e');
    }
    return {};
  }

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

  // Save Quarter Finals scores for a specific division
  Future<void> saveQuarterFinalsScoresForDivision(
    String division,
    Map<String, Map<String, int>> scores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      final key = 'quarter_finals_scores_$division';
      await prefs.setString(key, scoresJson);
      print('Saved quarter finals scores for division $division: $scores');
    } catch (e) {
      print('Error saving quarter finals scores for division $division: $e');
    }
  }

  // Load Quarter Finals scores for a specific division
  Future<Map<String, Map<String, int>>> loadQuarterFinalsScoresForDivision(
    String division,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'quarter_finals_scores_$division';
      final scoresJson = prefs.getString(key);

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

        print('Loaded quarter finals scores for division $division: $scores');
        return scores;
      }
    } catch (e) {
      print('Error loading quarter finals scores for division $division: $e');
    }

    return {};
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

  // Save Semi Finals scores for a specific division
  Future<void> saveSemiFinalsScoresForDivision(
    String division,
    Map<String, Map<String, int>> scores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      final key = 'semi_finals_scores_$division';
      await prefs.setString(key, scoresJson);
      print('Saved semi finals scores for division $division: $scores');
    } catch (e) {
      print('Error saving semi finals scores for division $division: $e');
    }
  }

  // Load Semi Finals scores for a specific division
  Future<Map<String, Map<String, int>>> loadSemiFinalsScoresForDivision(
    String division,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'semi_finals_scores_$division';
      final scoresJson = prefs.getString(key);

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

        print('Loaded semi finals scores for division $division: $scores');
        return scores;
      }
    } catch (e) {
      print('Error loading semi finals scores for division $division: $e');
    }

    return {};
  }

  // Save Finals scores for a specific division
  Future<void> saveFinalsScoresForDivision(
    String division,
    Map<String, Map<String, int>> scores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = json.encode(scores);
      final key = 'finals_scores_$division';
      await prefs.setString(key, scoresJson);
      print('Saved finals scores for division $division: $scores');
    } catch (e) {
      print('Error saving finals scores for division $division: $e');
    }
  }

  // Load Finals scores for a specific division
  Future<Map<String, Map<String, int>>> loadFinalsScoresForDivision(
    String division,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'finals_scores_$division';
      final scoresJson = prefs.getString(key);

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

        print('Loaded finals scores for division $division: $scores');
        return scores;
      }
    } catch (e) {
      print('Error loading finals scores for division $division: $e');
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

  // Save playoff state for a specific division
  Future<void> savePlayoffsStartedForDivision(
    String division,
    bool playoffsStarted,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_playoffsStartedKey}_$division';
      await prefs.setBool(key, playoffsStarted);
      print(
        'Saved playoffs started state for division $division: $playoffsStarted',
      );
    } catch (e) {
      print('Error saving playoffs started state for division $division: $e');
    }
  }

  // Load playoff state for a specific division
  Future<bool> loadPlayoffsStartedForDivision(String division) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_playoffsStartedKey}_$division';
      final playoffsStarted = prefs.getBool(key) ?? false;
      return playoffsStarted;
    } catch (e) {
      print('Error loading playoffs started state for division $division: $e');
      return false;
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

  // Save game started state for a specific event (by event ID)
  Future<void> saveGameStartedForEvent(String eventId, bool gameStarted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_gameStartedKey}_$eventId';
      await prefs.setBool(key, gameStarted);
      print('Saved game started state for event $eventId: $gameStarted');
    } catch (e) {
      print('Error saving game started state for event $eventId: $e');
    }
  }

  // Load game started state for a specific event (by event ID)
  Future<bool> loadGameStartedForEvent(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_gameStartedKey}_$eventId';
      final gameStarted = prefs.getBool(key) ?? false;
      return gameStarted;
    } catch (e) {
      print('Error loading game started state for event $eventId: $e');
      return false;
    }
  }

  // Save navigation state for an event (sportName + tournamentTitle)
  Future<void> saveNavigationState(
    String sportName,
    String tournamentTitle,
    int bottomNavIndex,
    int tabIndex,
    int playoffTabIndex,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nav_state_${sportName}_$tournamentTitle';
      final navState = {
        'bottomNavIndex': bottomNavIndex,
        'tabIndex': tabIndex,
        'playoffTabIndex': playoffTabIndex,
      };
      final navStateJson = json.encode(navState);
      await prefs.setString(key, navStateJson);
      print('Saved navigation state for $sportName/$tournamentTitle: bottomNavIndex=$bottomNavIndex, tabIndex=$tabIndex, playoffTabIndex=$playoffTabIndex');
    } catch (e) {
      print('Error saving navigation state for $sportName/$tournamentTitle: $e');
    }
  }

  // Load navigation state for an event (sportName + tournamentTitle)
  Future<Map<String, int>?> loadNavigationState(
    String sportName,
    String tournamentTitle,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'nav_state_${sportName}_$tournamentTitle';
      final navStateJson = prefs.getString(key);

      if (navStateJson != null) {
        final Map<String, dynamic> decoded = json.decode(navStateJson);
        final navState = {
          'bottomNavIndex': decoded['bottomNavIndex'] as int? ?? 0,
          'tabIndex': decoded['tabIndex'] as int? ?? 0,
          'playoffTabIndex': decoded['playoffTabIndex'] as int? ?? 0,
        };
        print('Loaded navigation state for $sportName/$tournamentTitle: $navState');
        return navState;
      }
    } catch (e) {
      print('Error loading navigation state for $sportName/$tournamentTitle: $e');
    }
    return null;
  }

  // Save expansion state for Home tab sections
  Future<void> saveHomeExpansionState(
    bool upcomingExpanded,
    bool pastExpanded,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('home_upcoming_expanded', upcomingExpanded);
      await prefs.setBool('home_past_expanded', pastExpanded);
      print('Saved Home expansion state: upcoming=$upcomingExpanded, past=$pastExpanded');
    } catch (e) {
      print('Error saving Home expansion state: $e');
    }
  }

  // Load expansion state for Home tab sections
  Future<Map<String, bool>> loadHomeExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final upcomingExpanded = prefs.getBool('home_upcoming_expanded') ?? true;
      final pastExpanded = prefs.getBool('home_past_expanded') ?? true;
      print('Loaded Home expansion state: upcoming=$upcomingExpanded, past=$pastExpanded');
      return {
        'upcomingExpanded': upcomingExpanded,
        'pastExpanded': pastExpanded,
      };
    } catch (e) {
      print('Error loading Home expansion state: $e');
      return {
        'upcomingExpanded': true,
        'pastExpanded': true,
      };
    }
  }

  // Save expansion state for Schedule tab sections
  Future<void> saveScheduleExpansionState(
    bool scheduleExpanded,
    bool resultsExpanded,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('schedule_schedule_expanded', scheduleExpanded);
      await prefs.setBool('schedule_results_expanded', resultsExpanded);
      print('Saved Schedule expansion state: schedule=$scheduleExpanded, results=$resultsExpanded');
    } catch (e) {
      print('Error saving Schedule expansion state: $e');
    }
  }

  // Load expansion state for Schedule tab sections
  Future<Map<String, bool>> loadScheduleExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduleExpanded = prefs.getBool('schedule_schedule_expanded') ?? true;
      final resultsExpanded = prefs.getBool('schedule_results_expanded') ?? true;
      print('Loaded Schedule expansion state: schedule=$scheduleExpanded, results=$resultsExpanded');
      return {
        'scheduleExpanded': scheduleExpanded,
        'resultsExpanded': resultsExpanded,
      };
    } catch (e) {
      print('Error loading Schedule expansion state: $e');
      return {
        'scheduleExpanded': true,
        'resultsExpanded': true,
      };
    }
  }
}
