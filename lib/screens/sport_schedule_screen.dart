// ignore_for_file: use_super_parameters

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/simple_app_bar.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../services/score_service.dart';
import '../keys/schedule_screen/schedule_screen_keys.dart';
import 'main_navigation_screen.dart';
import 'match_scoring_screen.dart';

class SportScheduleScreen extends StatefulWidget {
  final String sportName;
  final String tournamentTitle;
  final VoidCallback? onHomePressed;

  const SportScheduleScreen({
    super.key,
    required this.sportName,
    required this.tournamentTitle,
    this.onHomePressed,
  });

  @override
  State<SportScheduleScreen> createState() => _SportScheduleScreenState();
}

class _SportScheduleScreenState extends State<SportScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _playoffTabController;
  final AuthService _authService = AuthService();
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();
  final ScoreService _scoreService = ScoreService();

  // Division selection state
  String? _selectedDivision;
  List<String> _availableDivisions = [];

  // Cache for stable match generation
  final Map<String, List<Match>> _matchesCache = {};

  // Cache for standings to prevent stack overflow
  List<Standing>? _cachedStandings;
  String? _lastStandingsCacheKey;

  // Scoring state
  Match? _selectedMatch;
  DateTime? _lastSelectionTime;
  final Map<String, Map<String, int>> _matchScores =
      {}; // matchId -> {team1Id: score, team2Id: score}

  // Playoffs state
  // Playoff state per division
  Map<String, bool> _playoffsStartedByDivision = {};
  final Map<String, Map<String, int>> _playoffScores = {};
  bool _justRestartedPlayoffs = false;

  // Match format per tab: '1game' or 'bestof3'
  Map<String, String> _matchFormats =
      {}; // Key: 'QF', 'SF', 'Finals', Value: '1game' or 'bestof3'

  // Check if playoffs have started for a specific division
  bool _playoffsStartedForDivision(String division) {
    return _playoffsStartedByDivision[division] ?? false;
  }

  // Check if playoffs have started for the current division
  bool get _playoffsStarted =>
      _playoffsStartedForDivision(_selectedDivision ?? '');

  // Bottom navigation state for playoffs
  int _bottomNavIndex = 0;

  // Store reshuffled matches directly
  List<Match>? _reshuffledMatches;

  // Helper method to get preliminary matches directly without getter recursion
  List<Match> _getPreliminaryMatchesDirect({bool shouldShuffle = false}) {
    final teams = _teams;
    if (teams.isEmpty) return [];

    // Create a cache key based on teams and division
    // Sort team IDs to ensure consistent cache key regardless of team loading order
    final sortedTeamIds = teams.map((t) => t.id).toList()..sort();
    String cacheKey =
        '${widget.sportName}_${_selectedDivision ?? 'all'}_${sortedTeamIds.join('_')}_shuffle_$shouldShuffle';

    // For shuffle operations, add timestamp to ensure unique cache key
    if (shouldShuffle) {
      cacheKey += '_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Return cached matches if available (but not for reshuffle operations)
    if (_matchesCache.containsKey(cacheKey) && !shouldShuffle) {
      return _matchesCache[cacheKey]!;
    }

    // Generate matches from registered teams
    List<Match> matches = [];
    int matchId = 1;
    int courtNumber = 1;
    int timeSlot = 10; // Start at 10 AM

    // Group teams by division
    Map<String, List<dynamic>> teamsByDivision = {};
    for (var team in teams) {
      String division = team.division;
      if (!teamsByDivision.containsKey(division)) {
        teamsByDivision[division] = [];
      }
      teamsByDivision[division]!.add(team);
    }

    // Generate matches for each division separately
    for (String division in teamsByDivision.keys) {
      final divisionTeams = teamsByDivision[division]!;
      if (divisionTeams.length < 2) continue;

      // Create a copy of teams for this division to avoid modifying the original
      List<dynamic> availableTeams = List.from(divisionTeams);
      Map<String, int> gamesPlayed = {};
      Set<String> usedMatches = {};

      // Initialize games played counter
      for (var team in availableTeams) {
        gamesPlayed[team.id] = 0;
      }

      // Shuffle teams once at the beginning if requested
      if (shouldShuffle) {
        availableTeams.shuffle();

        // Also shuffle the gamesPlayed map keys to randomize the order
        final shuffledGamesPlayed = <String, int>{};
        final teamIds = gamesPlayed.keys.toList()..shuffle();
        for (final teamId in teamIds) {
          shuffledGamesPlayed[teamId] = gamesPlayed[teamId]!;
        }
        gamesPlayed.clear();
        gamesPlayed.addAll(shuffledGamesPlayed);
      }

      // Generate matches ensuring each team plays exactly 3 games
      int maxAttempts = 1000; // Prevent infinite loops
      int attempts = 0;

      while (availableTeams.length >= 2 && attempts < maxAttempts) {
        attempts++;

        // Find two teams that haven't played each other and haven't played 3 games
        bool matchFound = false;

        // If shuffling, randomize the search order
        List<int> indices = List.generate(
          availableTeams.length,
          (index) => index,
        );
        if (shouldShuffle) {
          indices.shuffle();
        }

        for (int i = 0; i < indices.length - 1; i++) {
          for (int j = i + 1; j < indices.length; j++) {
            final team1 = availableTeams[indices[i]];
            final team2 = availableTeams[indices[j]];

            // Create match key for uniqueness check
            final matchKey = '${team1.id}_${team2.id}';
            final reverseMatchKey = '${team2.id}_${team1.id}';

            // Check if teams haven't played each other and haven't reached game limit
            if (!usedMatches.contains(matchKey) &&
                !usedMatches.contains(reverseMatchKey) &&
                gamesPlayed[team1.id]! < 3 &&
                gamesPlayed[team2.id]! < 3) {
              // Create match
              matches.add(
                Match(
                  id: matchId.toString(),
                  day: 'Day 1',
                  court: 'Court $courtNumber',
                  time: '$timeSlot:00',
                  team1: team1.name,
                  team2: team2.name,
                  team1Status: 'Not Checked-in',
                  team2Status: 'Not Checked-in',
                  team1Score: 0,
                  team2Score: 0,
                  team1Id: team1.id,
                  team2Id: team2.id,
                  team1Name: team1.name,
                  team2Name: team2.name,
                  isCompleted: false,
                  scheduledDate: DateTime.now().add(Duration(days: 1)),
                ),
              );

              // Mark this match as used
              usedMatches.add(matchKey);
              usedMatches.add(reverseMatchKey);

              // Update games played
              gamesPlayed[team1.id] = gamesPlayed[team1.id]! + 1;
              gamesPlayed[team2.id] = gamesPlayed[team2.id]! + 1;

              matchId++;
              courtNumber++;
              if (courtNumber > 4) {
                courtNumber = 1;
                timeSlot++;
              }

              matchFound = true;
              break;
            }
          }
          if (matchFound) break;
        }

        // If no match found, break to avoid infinite loop
        if (!matchFound) {
          // Check if all teams have played 3 games
          bool allTeamsPlayed3Games = true;
          for (var entry in gamesPlayed.entries) {
            if (entry.value < 3) {
              allTeamsPlayed3Games = false;
              break;
            }
          }
          if (allTeamsPlayed3Games) break;

          // If we can't find a match and not all teams have played 3 games,
          // remove teams that have already played 3 games to avoid infinite loop
          availableTeams.removeWhere((team) => gamesPlayed[team.id]! >= 3);
        }
      }

      // Log if we hit the max attempts limit
      if (attempts >= maxAttempts) {
        print(
          'WARNING: Match generation hit max attempts limit ($maxAttempts) for division $division',
        );
      }

      // Validation: Ensure no team plays more than 3 games
      for (var entry in gamesPlayed.entries) {
        if (entry.value > 3) {
          print(
            'ERROR: Team ${entry.key} played ${entry.value} games (should be max 3)',
          );
        }
        print('DEBUG: Team ${entry.key} played ${entry.value} games');
      }
    }

    // Cache the matches for stability
    _matchesCache[cacheKey] = matches;

    // Save to persistent storage (asynchronous)
    _saveMatchesToStorage(cacheKey, matches);

    return matches;
  }

  // Get teams based on sport type and selected division
  List<dynamic> get _teams {
    List<dynamic> allTeams = [];
    final currentUserId = _authService.currentUser?.id;

    if (widget.sportName.toLowerCase().contains('basketball')) {
      // Use filtered teams based on user privacy
      allTeams = _teamService.getTeamsForUser(currentUserId);
    } else if (widget.sportName.toLowerCase().contains('pickleball')) {
      // Use filtered teams based on user privacy
      allTeams = _pickleballTeamService.getTeamsForUser(currentUserId);
    }

    // Filter by selected division if one is selected
    List<dynamic> filteredTeams;
    if (_selectedDivision != null) {
      filteredTeams =
          allTeams.where((team) => team.division == _selectedDivision).toList();
    } else {
      filteredTeams = allTeams;
    }

    // Sort teams by ID to ensure consistent order
    filteredTeams.sort((a, b) => a.id.compareTo(b.id));

    return filteredTeams;
  }

  // Update available divisions
  void _updateDivisions() {
    List<dynamic> allTeams = [];
    if (widget.sportName.toLowerCase().contains('basketball')) {
      allTeams = _teamService.teams;
    } else if (widget.sportName.toLowerCase().contains('pickleball')) {
      allTeams = _pickleballTeamService.teams;
    }

    Set<String> divisions =
        allTeams.map((team) => team.division as String).toSet();
    _availableDivisions = divisions.toList()..sort();

    // If no division is selected or selected division is not available, select first one
    if (_selectedDivision == null ||
        !_availableDivisions.contains(_selectedDivision)) {
      _selectedDivision =
          _availableDivisions.isNotEmpty ? _availableDivisions.first : null;
    }
  }

  void _selectMatch(Match match) {
    // Don't allow selection of matches without opponents
    if (match.team2 == 'TBA') {
      return;
    }

    // Debounce rapid selections (prevent multiple calls within 500ms)
    final now = DateTime.now();
    if (_lastSelectionTime != null &&
        now.difference(_lastSelectionTime!).inMilliseconds < 500) {
      print('DEBUG: Ignoring rapid selection of match ${match.id}');
      return;
    }
    _lastSelectionTime = now;

    setState(() {
      // If clicking the same match that's already selected, unselect it
      if (_selectedMatch?.id == match.id) {
        print(
          'DEBUG: Deselecting match ${match.id} (${match.team1} vs ${match.team2})',
        );
        _selectedMatch = null;
      } else {
        print(
          'DEBUG: Selecting match ${match.id} (${match.team1} vs ${match.team2})',
        );
        _selectedMatch = match;
      }
    });
  }

  // Save matches to persistent storage
  Future<void> _saveMatchesToStorage(
    String cacheKey,
    List<Match> matches,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final matchesJson = matches.map((match) => match.toJson()).toList();
      await prefs.setString('matches_$cacheKey', json.encode(matchesJson));
    } catch (e) {
      print('Error saving matches to storage: $e');
    }
  }

  // Completely reset all playoff data
  Future<void> _resetAllPlayoffData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear only playoff-related keys (keep preliminary scores)
      await prefs.remove('playoff_scores');
      await prefs.remove('quarter_finals_scores');
      await prefs.remove('semi_finals_scores');
      await prefs.remove('finals_scores');
      await prefs.remove('playoffs_started');

      // Clear only playoff-specific keys, NOT preliminary scores
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.contains('playoff') ||
            key.contains('quarter') ||
            key.contains('semi') ||
            key.contains('final')) {
          await prefs.remove(key);
        }
        // DO NOT remove keys that contain 'score' as that would clear preliminary scores
      }
    } catch (e) {
      print('Error resetting playoff data: $e');
    }
  }

  // Get current tab name (QF, SF, or Finals)
  String _getCurrentTabName() {
    if (_tabController.index == 1) {
      // Playoffs tab
      final playoffSubTabIndex = _playoffTabController.index;
      if (playoffSubTabIndex == 0) return 'QF'; // Quarter Finals
      if (playoffSubTabIndex == 1) return 'SF'; // Semi Finals
      if (playoffSubTabIndex == 2) return 'Finals';
    }
    return 'QF'; // Default
  }

  // Show dialog to select match format
  Future<String?> _showMatchFormatDialog() {
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Match Total Games'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('1 Game'),
                  leading: Radio<String>(
                    value: '1game',
                    groupValue:
                        _matchFormats[_getCurrentTabName()] ?? 'bestof3',
                    onChanged: (value) {
                      Navigator.pop(context, value);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Best of 3'),
                  leading: Radio<String>(
                    value: 'bestof3',
                    groupValue:
                        _matchFormats[_getCurrentTabName()] ?? 'bestof3',
                    onChanged: (value) {
                      Navigator.pop(context, value);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _startScoring() {
    // Check if user has scoring permissions
    if (!_authService.canScore) {
      _showScoringPermissionDialog();
      return;
    }

    // Prevent cross-tab scoring
    if (_selectedMatch == null || !_isSelectedMatchInCurrentTab()) {
      return;
    }

    if (_selectedMatch != null) {
      // Determine if this is a playoff match
      final isPlayoffMatch = _playoffs.contains(_selectedMatch!);
      final isSemiFinalsMatch = _selectedMatch!.day == 'Semi Finals';

      // For QF matches, always ask for match format
      if (isPlayoffMatch && _selectedMatch!.day == 'Quarter Finals') {
        final currentTab = _getCurrentTabName();

        // Always show dialog for QF matches
        _showMatchFormatDialog().then((format) {
          if (format != null) {
            setState(() {
              _matchFormats[currentTab] = format;
            });
            // Call _startScoring again after format is set
            _startScoring();
          }
        });
        return;
      }

      // Check if playoffs have started and this is a playoff match
      if (_playoffsStarted && isPlayoffMatch) {
        // Show dialog explaining that scores cannot be edited once playoffs have started
        _showPlayoffScoreEditRestrictionDialog();
        return;
      }

      // Get the match format for this tab
      final currentTab = _getCurrentTabName();
      final matchFormat = _matchFormats[currentTab] ?? 'bestof3';

      // For QF matches, always use the SemiFinals scoring screen which adapts to format
      // For SF and Finals, always use SemiFinals scoring screen
      if (isSemiFinalsMatch ||
          _selectedMatch!.day == 'Finals' ||
          _selectedMatch!.day == 'Quarter Finals') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SemiFinalsScoringScreen(
                  match: _selectedMatch!,
                  initialScores: _playoffScores[_selectedMatch!.id],
                  matchFormat:
                      _selectedMatch!.day == 'Quarter Finals'
                          ? matchFormat
                          : 'bestof3',
                  onScoresUpdated: (scores) async {
                    setState(() {
                      _playoffScores[_selectedMatch!
                          .id] = Map<String, int>.from(scores);
                      // Clear selection after saving scores
                      _selectedMatch = null;
                      // Clear standings cache to force recalculation
                      _cachedStandings = null;
                      _lastStandingsCacheKey = null;
                    });

                    // Save scores to persistent storage
                    try {
                      await _scoreService.savePlayoffScores(_playoffScores);

                      // Also save to specific playoff round storage
                      if (_selectedMatch!.day == 'Semi Finals') {
                        await _scoreService.saveSemiFinalsScores(
                          _playoffScores,
                        );
                      } else if (_selectedMatch!.day == 'Finals') {
                        await _scoreService.saveFinalsScores(_playoffScores);
                      }
                    } catch (e) {
                      print('Error saving scores to storage: $e');
                    }
                  },
                ),
          ),
        );
        return;
      }

      // Navigate to regular scoring screen for other matches
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MatchScoringScreen(
                match: _selectedMatch!,
                initialScores:
                    isPlayoffMatch
                        ? _playoffScores[_selectedMatch!.id]
                        : _matchScores[_selectedMatch!.id],
                onScoresUpdated: (scores) async {
                  setState(() {
                    if (isPlayoffMatch) {
                      _playoffScores[_selectedMatch!.id] = scores;
                    } else {
                      _matchScores[_selectedMatch!.id] = scores;
                    }
                    // Clear selection after saving scores
                    _selectedMatch = null;
                    // Clear standings cache to force recalculation
                    _cachedStandings = null;
                    _lastStandingsCacheKey = null;
                  });

                  // Save scores to persistent storage
                  try {
                    if (isPlayoffMatch) {
                      await _scoreService.savePlayoffScores(_playoffScores);

                      // Also save to specific playoff round storage for QF
                      if (_selectedMatch!.day == 'Quarter Finals') {
                        await _scoreService.saveQuarterFinalsScores(
                          _playoffScores,
                        );
                      }
                    } else {
                      await _scoreService.savePreliminaryScores(_matchScores);
                    }
                  } catch (e) {
                    print('Error saving scores to storage: $e');
                  }
                },
              ),
        ),
      );
    }
  }

  int _getTeamScore(String matchId, String? teamId) {
    if (teamId == null) return 0; // Handle "TBA" case

    // Check if this is a playoff match ID (very high numbers)
    final matchIdNum = int.tryParse(matchId) ?? 0;
    final isPlayoffMatch =
        matchIdNum >= 1000000; // Playoff matches start at 1 million

    if (isPlayoffMatch) {
      // For playoff matches, check playoff scores first
      final playoffScores = _playoffScores[matchId];
      if (playoffScores != null) {
        final score = playoffScores[teamId] ?? 0;
        if (score > 0) {
          print(
            'DEBUG: _getTeamScore - Found playoff score for match $matchId, team $teamId: $score',
          );
        }
        return score;
      }

      // If no playoff score found, check preliminary scores as fallback
      final preliminaryScores = _matchScores[matchId];
      if (preliminaryScores != null) {
        final score = preliminaryScores[teamId] ?? 0;
        if (score > 0) {
          print(
            'DEBUG: _getTeamScore - Found preliminary score for playoff match $matchId, team $teamId: $score (fallback)',
          );
        }
        return score;
      }
    } else {
      // For preliminary matches, check preliminary scores first
      final preliminaryScores = _matchScores[matchId];
      if (preliminaryScores != null) {
        final score = preliminaryScores[teamId] ?? 0;
        if (score > 0) {
          print(
            'DEBUG: _getTeamScore - Found preliminary score for match $matchId, team $teamId: $score',
          );
        }
        return score;
      }
    }

    return 0;
  }

  String? _getWinningTeamId(String matchId) {
    // Check if this is a playoff match ID (very high numbers)
    final matchIdNum = int.tryParse(matchId) ?? 0;
    final isPlayoffMatch =
        matchIdNum >= 1000000; // Playoff matches start at 1 million

    if (isPlayoffMatch) {
      // For playoff matches, check playoff scores first
      final playoffScores = _playoffScores[matchId];
      if (playoffScores != null && playoffScores.length >= 2) {
        final teamIds = playoffScores.keys.toList();
        if (teamIds.length >= 2) {
          final team1Score = playoffScores[teamIds[0]] ?? 0;
          final team2Score = playoffScores[teamIds[1]] ?? 0;

          if (team1Score > team2Score) return teamIds[0];
          if (team2Score > team1Score) return teamIds[1];
          return null; // Tie
        }
      }

      // If no playoff score found, check preliminary scores as fallback
      final preliminaryScores = _matchScores[matchId];
      if (preliminaryScores != null && preliminaryScores.length >= 2) {
        final teamIds = preliminaryScores.keys.toList();
        if (teamIds.length >= 2) {
          final team1Score = preliminaryScores[teamIds[0]] ?? 0;
          final team2Score = preliminaryScores[teamIds[1]] ?? 0;

          if (team1Score > team2Score) return teamIds[0];
          if (team2Score > team1Score) return teamIds[1];
          return null; // Tie
        }
      }
    } else {
      // For preliminary matches, check preliminary scores first
      final preliminaryScores = _matchScores[matchId];
      if (preliminaryScores != null && preliminaryScores.length >= 2) {
        final teamIds = preliminaryScores.keys.toList();
        if (teamIds.length >= 2) {
          final team1Score = preliminaryScores[teamIds[0]] ?? 0;
          final team2Score = preliminaryScores[teamIds[1]] ?? 0;

          if (team1Score > team2Score) return teamIds[0];
          if (team2Score > team1Score) return teamIds[1];
          return null; // Tie
        }
      }
    }

    return null;
  }

  // Check if any Quarter Finals scores have been entered
  bool get _hasQuarterFinalsScores {
    final quarterFinals = _getQuarterFinals();
    for (var match in quarterFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        final team1Score = _getTeamScore(match.id, match.team1Id!);
        final team2Score = _getTeamScore(match.id, match.team2Id!);
        if (team1Score > 0 || team2Score > 0) {
          return true; // Found at least one QF score
        }
      }
    }
    return false;
  }

  // Check if any Finals scores have been entered
  bool get _hasFinalsScores {
    final finals = _getFinals();
    for (var match in finals) {
      if (match.team1Id != null && match.team2Id != null) {
        // Check if any individual game scores exist for this match
        for (int game = 1; game <= 3; game++) {
          final team1GameScore = _getGameScore(match.id, match.team1Id!, game);
          final team2GameScore = _getGameScore(match.id, match.team2Id!, game);
          if (team1GameScore != null && team1GameScore > 0) {
            return true; // Found at least one Finals game score
          }
          if (team2GameScore != null && team2GameScore > 0) {
            return true; // Found at least one Finals game score
          }
        }
      }
    }
    return false;
  }

  // Check if any Semi Finals scores have been entered
  bool get _hasSemiFinalsScores {
    final semiFinals = _getSemiFinals();
    for (var match in semiFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        // Check if any individual game scores exist for this match
        for (int game = 1; game <= 3; game++) {
          final team1GameScore = _getGameScore(match.id, match.team1Id!, game);
          final team2GameScore = _getGameScore(match.id, match.team2Id!, game);
          if (team1GameScore != null && team1GameScore > 0) {
            return true; // Found at least one SF game score
          }
          if (team2GameScore != null && team2GameScore > 0) {
            return true; // Found at least one SF game score
          }
        }
      }
    }
    return false;
  }

  // Check if all Quarter Finals scores are set
  bool get _allQuarterFinalsScoresSet {
    final quarterFinals = _getQuarterFinals();
    if (quarterFinals.isEmpty) return false;

    for (var match in quarterFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        final team1Score = _getTeamScore(match.id, match.team1Id!);
        final team2Score = _getTeamScore(match.id, match.team2Id!);
        if (team1Score == 0 && team2Score == 0) {
          return false; // Found a match without scores
        }
      }
    }
    return true; // All matches have scores
  }

  // Get Finals winner
  String? _getFinalsWinner() {
    final finals = _getFinals();
    if (finals.isEmpty) return null;

    final match = finals.first;
    if (match.team1Id == null || match.team2Id == null) return null;

    final team1GamesWon = _getGamesWon(match.id, match.team1Id!);
    final team2GamesWon = _getGamesWon(match.id, match.team2Id!);

    if (team1GamesWon >= 2) {
      return match.team1;
    } else if (team2GamesWon >= 2) {
      return match.team2;
    }

    return null; // No winner yet
  }

  // Check if all Semi Finals scores are set
  bool get _allSemiFinalsScoresSet {
    final semiFinals = _getSemiFinals();
    if (semiFinals.isEmpty) return false;

    // Check if we have actual teams (not TBA placeholders)
    bool hasActualTeams = false;
    for (var match in semiFinals) {
      if (match.team1Id != null &&
          match.team2Id != null &&
          match.team1 != 'TBA' &&
          match.team2 != 'TBA') {
        hasActualTeams = true;

        // For Semi Finals, check if the best-of-3 match is completed
        final team1GamesWon = _getGamesWon(match.id, match.team1Id!);
        final team2GamesWon = _getGamesWon(match.id, match.team2Id!);

        // Match is complete when one team wins 2 games
        if (team1GamesWon < 2 && team2GamesWon < 2) {
          return false; // Found an incomplete match
        }
      }
    }

    // If no actual teams yet (still TBA placeholders), return false
    return hasActualTeams;
  }

  // Check if all preliminary games are completed
  bool get _allPreliminaryGamesCompleted {
    for (var match in _preliminaryMatches) {
      if (match.team2 == 'TBA') {
        continue; // Skip waiting matches
      }
      final scores = _matchScores[match.id];
      if (scores == null || scores.length < 2) return false;
      final team1Score = scores[match.team1Id] ?? 0;
      final team2Score = scores[match.team2Id] ?? 0;
      if (team1Score == 0 && team2Score == 0) return false; // No scores entered
    }
    return true;
  }

  // Start playoffs
  void _startPlayoffs() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Start Playoffs'),
          content: const Text(
            'Are you sure you want to start the playoffs? This will begin the elimination rounds based on current standings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Save all current scores before starting playoffs (but not if we just restarted)
                if (!_justRestartedPlayoffs) {
                  print('DEBUG: Starting Playoffs - About to save scores...');
                  await _saveScores();
                } else {
                  print(
                    'DEBUG: Starting Playoffs - Skipping save scores (just restarted)',
                  );
                }

                // Debug: Check QF scores before starting playoffs
                final qfScores = await _scoreService.loadQuarterFinalsScores();
                print(
                  'DEBUG: Starting Playoffs - QF scores in storage: $qfScores',
                );

                print(
                  'DEBUG: Starting Playoffs - _justRestartedPlayoffs: $_justRestartedPlayoffs',
                );
                print(
                  'DEBUG: Starting Playoffs - Current _playoffScores: $_playoffScores',
                );

                setState(() {
                  _playoffsStartedByDivision[_selectedDivision ?? ''] = true;
                  _justRestartedPlayoffs =
                      false; // Reset the flag when starting playoffs
                  // Clear cache when starting playoffs
                });
                // Switch to Playoffs bottom navigation
                setState(() {
                  _bottomNavIndex = 1;
                });
                // Save playoff state for current division
                await _scoreService.savePlayoffsStartedForDivision(
                  _selectedDivision ?? '',
                  true,
                );
              },
              child: const Text('Start Playoffs'),
            ),
          ],
        );
      },
    );
  }

  // Restart playoffs
  void _restartPlayoffs() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restart Playoffs'),
          content: const Text(
            'This will clear all Quarter Finals, Semi Finals, and Finals scores. Your preliminary round scores will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Clear only playoff scores from storage (keep preliminary scores)
                print(
                  'DEBUG: Step 1 - Clearing playoff scores from storage...',
                );
                // Clear playoff state for current division only
                await _scoreService.savePlayoffsStartedForDivision(
                  _selectedDivision ?? '',
                  false,
                );
                await _scoreService.saveQuarterFinalsScores({});
                await _scoreService.saveSemiFinalsScores({});
                await _scoreService.saveFinalsScores({});
                await _scoreService.savePlayoffScores({});
                // DO NOT clear preliminary scores - keep them!

                print('DEBUG: Step 2 - Calling _resetAllPlayoffData...');
                // Clear only playoff-related data from storage
                await _resetAllPlayoffData();

                print(
                  'DEBUG: Step 3 - Verifying scores are cleared from storage...',
                );
                // Verify scores are cleared from storage
                final verifyQF = await _scoreService.loadQuarterFinalsScores();
                final verifySF = await _scoreService.loadSemiFinalsScores();
                final verifyF = await _scoreService.loadFinalsScores();
                final verifyP = await _scoreService.loadPlayoffScores();
                print(
                  'DEBUG: Restart Playoffs - QF scores in storage: $verifyQF',
                );
                print(
                  'DEBUG: Restart Playoffs - SF scores in storage: $verifySF',
                );
                print(
                  'DEBUG: Restart Playoffs - Finals scores in storage: $verifyF',
                );
                print(
                  'DEBUG: Restart Playoffs - Playoff scores in storage: $verifyP',
                );

                print('DEBUG: Restart Playoffs - Clearing all playoff scores');

                // Clear preliminary scores that have high IDs (conflicting with playoff matches)
                final highIdMatches =
                    _matchScores.keys.where((id) {
                      final idNum = int.tryParse(id) ?? 0;
                      return idNum >=
                          1000000; // Clear matches with IDs >= 1 million
                    }).toList();

                for (final matchId in highIdMatches) {
                  _matchScores.remove(matchId);
                  print(
                    'DEBUG: Removed preliminary score for high-ID match: $matchId',
                  );
                }

                // Save the updated preliminary scores to storage
                await _scoreService.savePreliminaryScores(_matchScores);

                setState(() {
                  _playoffsStartedByDivision[_selectedDivision ?? ''] = false;
                  _playoffScores
                      .clear(); // Clear only playoff scores from memory
                  _selectedMatch = null; // Clear selected match
                  _justRestartedPlayoffs = true; // Set flag to prevent reload
                  // Clear standings cache to force recalculation
                  _cachedStandings = null;
                  _lastStandingsCacheKey = null;
                  // Clear Quarter Finals cache
                });

                // Verify that playoff scores are actually cleared
                final verifyPlayoffScores =
                    await _scoreService.loadPlayoffScores();
                print(
                  'DEBUG: After restart - Playoff scores in storage: $verifyPlayoffScores',
                );
                print(
                  'DEBUG: After restart - _playoffScores in memory: $_playoffScores',
                );

                // Navigate to QF tab (index 0) when restarting playoffs
                _playoffTabController.animateTo(0);

                // Force a rebuild to ensure UI reflects the cleared state
                if (mounted) {
                  setState(() {});
                }

                // Verify that only playoff scores are cleared
                await _scoreService.loadPlayoffScores();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(225, 243, 51, 33),
                foregroundColor: Colors.white,
              ),
              child: const Text('Restart Playoffs'),
            ),
          ],
        );
      },
    );
  }

  // Get teams from service instead of hardcoded data
  List<Match> get _preliminaryMatches {
    // If we have reshuffled matches, use them
    if (_reshuffledMatches != null) {
      return _reshuffledMatches!;
    }

    // Otherwise use the direct method to avoid duplication
    // Always use non-shuffled version for normal display
    return _getPreliminaryMatchesDirect(shouldShuffle: false);
  }

  // Get standings from registered teams
  List<Standing> get _standings {
    final teams = _teams;
    if (teams.isEmpty) return [];

    // Create cache key based on teams and match scores
    final teamsKey = teams.map((t) => t.id).join('_');
    final scoresKey = _matchScores.keys.join('_');
    final cacheKey = '${teamsKey}_$scoresKey';

    // Return cached standings if available and still valid
    if (_cachedStandings != null && _lastStandingsCacheKey == cacheKey) {
      return _cachedStandings!;
    }

    // Calculate actual stats based on match scores
    Map<String, Map<String, int>> teamStats = {};

    // Initialize team stats
    for (var team in teams) {
      teamStats[team.id] = {
        'games': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'points': 0,
        'pointDifference': 0,
      };
    }

    // Get preliminary matches without calling the getter to avoid recursion
    final preliminaryMatches = _getPreliminaryMatchesDirect();

    // First, count only games that have been played (have scores entered)
    for (var match in preliminaryMatches) {
      // Only process preliminary match scores (IDs 1-999)
      final matchIdInt = int.tryParse(match.id);
      if (matchIdInt == null || matchIdInt >= 1000) {
        continue;
      }

      // Skip "TBA" matches
      if (match.team2 == 'TBA') continue;

      // Only count matches that have actual scores entered
      if (match.team1Id != null && match.team2Id != null) {
        final scores = _matchScores[match.id];
        if (scores != null && scores.length >= 2) {
          final team1Score = scores[match.team1Id!] ?? 0;
          final team2Score = scores[match.team2Id!] ?? 0;

          // Only count if at least one team has scored (game has been played)
          if (team1Score > 0 || team2Score > 0) {
            if (teamStats.containsKey(match.team1Id!) &&
                teamStats.containsKey(match.team2Id!)) {
              teamStats[match.team1Id!]!['games'] =
                  (teamStats[match.team1Id!]!['games']! + 1);
              teamStats[match.team2Id!]!['games'] =
                  (teamStats[match.team2Id!]!['games']! + 1);
            }
          }
        }
      }
    }

    // Then, process match results for wins/losses/draws/points
    for (var match in preliminaryMatches) {
      // Only process preliminary match scores (IDs 1-999)
      final matchIdInt = int.tryParse(match.id);
      if (matchIdInt == null || matchIdInt >= 1000) {
        continue;
      }

      final scores = _matchScores[match.id];
      if (scores != null && scores.length >= 2) {
        final teamIds = scores.keys.toList();
        if (teamIds.length >= 2) {
          final team1Id = teamIds[0];
          final team2Id = teamIds[1];
          final team1Score = scores[team1Id] ?? 0;
          final team2Score = scores[team2Id] ?? 0;

          // Only process if both teams have valid IDs and scores are meaningful
          if (team1Id.isNotEmpty &&
              team2Id.isNotEmpty &&
              (team1Score > 0 || team2Score > 0)) {
            // Make sure both teams exist in teamStats
            if (teamStats.containsKey(team1Id) &&
                teamStats.containsKey(team2Id)) {
              // Calculate point differential for both teams
              final team1Diff = team1Score - team2Score;
              final team2Diff = team2Score - team1Score;

              teamStats[team1Id]!['pointDifference'] =
                  (teamStats[team1Id]!['pointDifference']! + team1Diff);
              teamStats[team2Id]!['pointDifference'] =
                  (teamStats[team2Id]!['pointDifference']! + team2Diff);

              // Determine winner
              if (team1Score > team2Score) {
                teamStats[team1Id]!['wins'] =
                    (teamStats[team1Id]!['wins']! + 1);
                teamStats[team1Id]!['points'] =
                    (teamStats[team1Id]!['points']! + 1);
                teamStats[team2Id]!['losses'] =
                    (teamStats[team2Id]!['losses']! + 1);
              } else if (team2Score > team1Score) {
                teamStats[team2Id]!['wins'] =
                    (teamStats[team2Id]!['wins']! + 1);
                teamStats[team2Id]!['points'] =
                    (teamStats[team2Id]!['points']! + 1);
                teamStats[team1Id]!['losses'] =
                    (teamStats[team1Id]!['losses']! + 1);
              } else if (team1Score == team2Score && team1Score > 0) {
                // Draw (only if both teams scored)
                teamStats[team1Id]!['draws'] =
                    (teamStats[team1Id]!['draws']! + 1);
                teamStats[team2Id]!['draws'] =
                    (teamStats[team2Id]!['draws']! + 1);
              }
            }
          }
        }
      }
    }

    // Generate standings from calculated stats
    List<Standing> standings = [];
    for (int i = 0; i < teams.length; i++) {
      final teamId = teams[i].id;
      final stats = teamStats[teamId]!;

      // Calculate team stats

      standings.add(
        Standing(
          rank: i + 1,
          teamName: teams[i].name,
          games: stats['games']!,
          wins: stats['wins']!,
          draws: stats['draws']!,
          losses: stats['losses']!,
          technicalFouls: 0,
          pointDifference: stats['pointDifference']!,
          points: stats['points']!,
        ),
      );
    }

    // Sort by points (descending), then by point differential (descending), then by wins (descending)
    standings.sort((a, b) {
      // First priority: Points (higher is better)
      if (b.points != a.points) return b.points.compareTo(a.points);

      // Second priority: Point differential (higher is better)
      if (b.pointDifference != a.pointDifference) {
        return b.pointDifference.compareTo(a.pointDifference);
      }

      // Third priority: Wins (higher is better)
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);

      // Fourth priority: Losses (lower is better)
      return a.losses.compareTo(b.losses);
    });

    // Update ranks after sorting
    for (int i = 0; i < standings.length; i++) {
      standings[i] = Standing(
        rank: i + 1,
        teamName: standings[i].teamName,
        games: standings[i].games,
        wins: standings[i].wins,
        draws: standings[i].draws,
        losses: standings[i].losses,
        technicalFouls: standings[i].technicalFouls,
        pointDifference: standings[i].pointDifference,
        points: standings[i].points,
      );
    }

    // Cache the results
    _cachedStandings = standings;
    _lastStandingsCacheKey = cacheKey;

    return standings;
  }

  // Get playoffs matches
  List<Match> get _playoffs {
    if (!_playoffsStarted) return [];

    final standings = _standings;
    if (standings.length < 2) return []; // Need at least 2 teams for playoffs

    List<Match> playoffMatches = [];
    // Use consistent ID generation to prevent card selection jumping
    int matchId = 1000000; // Start with a very high base ID to avoid conflicts
    int courtNumber = 1;
    int timeSlot = 14; // Start at 2 PM for playoffs

    // Calculate how many teams qualify (half of total teams, minimum 2)
    int qualifyingTeams = (standings.length / 2).ceil();
    if (qualifyingTeams < 2) qualifyingTeams = 2;
    if (qualifyingTeams > standings.length) qualifyingTeams = standings.length;

    // QUARTER FINALS - Create initial playoff matches with proper seeding
    for (int i = 0; i < qualifyingTeams / 2; i++) {
      final team1Index = i;
      final team2Index = qualifyingTeams - 1 - i;

      if (team2Index > team1Index) {
        // Find teams by their standings
        final team1 = _teams.firstWhere(
          (t) => t.name == standings[team1Index].teamName,
        );
        final team2 = _teams.firstWhere(
          (t) => t.name == standings[team2Index].teamName,
        );

        playoffMatches.add(
          Match(
            id: '${matchId++}',
            day: 'Quarter Finals',
            court: 'Court $courtNumber',
            time: '$timeSlot:00 PM',
            team1: team1.name,
            team2: team2.name,
            team1Status: 'Ready',
            team2Status: 'Ready',
            team1Score: 0,
            team2Score: 0,
            team1Id: team1.id,
            team2Id: team2.id,
            team1Name: team1.name,
            team2Name: team2.name,
          ),
        );

        // Alternate courts and time slots
        courtNumber = (courtNumber % 3) + 1;
        if (courtNumber == 1) timeSlot += 1;
      }
    }

    // SEMI FINALS - Always create 2 semi-final matches
    final quarterFinalsWinners = _getQuarterFinalsWinners();

    // Always create exactly 2 semi-final matches with proper seeding
    for (int i = 0; i < 2; i++) {
      if (quarterFinalsWinners.length >= 4) {
        // We have all 4 quarter-final winners, create proper seeding matchups
        // SF1: Winner of QF1 vs Winner of QF4 (1st seed vs 4th seed)
        // SF2: Winner of QF2 vs Winner of QF3 (2nd seed vs 3rd seed)
        final team1Index =
            i == 0
                ? 0
                : 1; // First SF gets QF1 winner, Second SF gets QF2 winner
        final team2Index =
            i == 0
                ? 3
                : 2; // First SF gets QF4 winner, Second SF gets QF3 winner

        if (team1Index < quarterFinalsWinners.length &&
            team2Index < quarterFinalsWinners.length) {
          final team1 = quarterFinalsWinners[team1Index];
          final team2 = quarterFinalsWinners[team2Index];

          playoffMatches.add(
            Match(
              id: '${matchId++}',
              day: 'Semi Finals',
              court: 'Court ${(i % 3) + 1}',
              time: '${timeSlot + i}:00 PM',
              team1: team1.name,
              team2: team2.name,
              team1Status: 'Ready',
              team2Status: 'Ready',
              team1Score: 0,
              team2Score: 0,
              team1Id: team1.id,
              team2Id: team2.id,
              team1Name: team1.name,
              team2Name: team2.name,
            ),
          );
        } else {
          // Create TBA match if we don't have enough winners yet
          playoffMatches.add(
            Match(
              id: '${matchId++}',
              day: 'Semi Finals',
              court: 'Court ${(i % 3) + 1}',
              time: '${timeSlot + i}:00 PM',
              team1: 'TBA',
              team2: 'TBA',
              team1Status: 'TBA',
              team2Status: 'TBA',
              team1Score: 0,
              team2Score: 0,
            ),
          );
        }
      } else {
        // Create TBA match if we don't have enough winners yet
        playoffMatches.add(
          Match(
            id: '${matchId++}',
            day: 'Semi Finals',
            court: 'Court ${(i % 3) + 1}',
            time: '${timeSlot + i}:00 PM',
            team1: 'TBA',
            team2: 'TBA',
            team1Status: 'TBA',
            team2Status: 'TBA',
            team1Score: 0,
            team2Score: 0,
          ),
        );
      }
    }

    // FINALS - Create final match based on semi-final results
    final semiFinalsWinners = _getSemiFinalsWinners();
    if (semiFinalsWinners.length >= 2) {
      final team1 = semiFinalsWinners[0];
      final team2 = semiFinalsWinners[1];

      playoffMatches.add(
        Match(
          id: '${matchId++}',
          day: 'Finals',
          court: 'Court 1',
          time: '${timeSlot + 2}:00 PM',
          team1: team1.name,
          team2: team2.name,
          team1Status: 'Ready',
          team2Status: 'Ready',
          team1Score: 0,
          team2Score: 0,
          team1Id: team1.id,
          team2Id: team2.id,
          team1Name: team1.name,
          team2Name: team2.name,
        ),
      );
    } else {
      // Create waiting match for finals
      playoffMatches.add(
        Match(
          id: '${matchId++}',
          day: 'Finals',
          court: 'Court 1',
          time: '${timeSlot + 2}:00 PM',
          team1: 'TBA',
          team2: 'TBA',
          team1Status: 'TBA',
          team2Status: 'TBA',
          team1Score: 0,
          team2Score: 0,
        ),
      );
    }

    return playoffMatches;
  }

  // Get winners of quarter finals
  List<dynamic> _getQuarterFinalsWinners() {
    final quarterFinals = _getQuarterFinalsDirect();
    List<dynamic> winners = [];

    for (var match in quarterFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        // Use _getTeamScore method to get scores consistently
        final team1Score = _getTeamScore(match.id, match.team1Id!);
        final team2Score = _getTeamScore(match.id, match.team2Id!);

        if (team1Score > 0 || team2Score > 0) {
          if (team1Score > team2Score) {
            // Team 1 won
            final team = _teams.firstWhere((t) => t.id == match.team1Id);
            winners.add(team);
          } else if (team2Score > team1Score) {
            // Team 2 won
            final team = _teams.firstWhere((t) => t.id == match.team2Id);
            winners.add(team);
          }
        }
      }
    }

    // Sort winners by their original seeding (rank in standings)
    final standings = _standings;
    winners.sort((a, b) {
      final aRank = standings.indexWhere((s) => s.teamName == a.name);
      final bRank = standings.indexWhere((s) => s.teamName == b.name);
      return aRank.compareTo(bRank);
    });

    return winners;
  }

  // Get winners of semi finals
  List<dynamic> _getSemiFinalsWinners() {
    final semiFinals = _getSemiFinalsDirect();
    List<dynamic> winners = [];

    for (var match in semiFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        // Use _getGamesWon for best-of-3 scoring (SF and Finals)
        final team1GamesWon = _getGamesWon(match.id, match.team1Id);
        final team2GamesWon = _getGamesWon(match.id, match.team2Id);

        if (team1GamesWon >= 2 || team2GamesWon >= 2) {
          if (team1GamesWon >= 2) {
            // Team 1 won
            final team = _teams.firstWhere((t) => t.id == match.team1Id);
            winners.add(team);
          } else if (team2GamesWon >= 2) {
            // Team 2 won
            final team = _teams.firstWhere((t) => t.id == match.team2Id);
            winners.add(team);
          }
        }
      }
    }

    // Sort winners by their original seeding (rank in standings)
    final standings = _standings;
    winners.sort((a, b) {
      final aRank = standings.indexWhere((s) => s.teamName == a.name);
      final bRank = standings.indexWhere((s) => s.teamName == b.name);
      return aRank.compareTo(bRank);
    });

    return winners;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _playoffTabController = TabController(length: 3, vsync: this);

    // Add listeners to clear selected match when switching tabs
    _tabController.addListener(() async {
      if (_tabController.indexIsChanging) {
        // Save scores before switching tabs
        await _saveScores();
        // Refresh standings to show latest data
        _refreshStandings();
        setState(() {
          _selectedMatch = null;
        });
      }
    });

    _playoffTabController.addListener(() async {
      if (_playoffTabController.indexIsChanging) {
        // Save scores before switching playoff tabs
        await _saveScores();
        // Refresh standings to show latest data
        _refreshStandings();
        setState(() {
          _selectedMatch = null;
        });
      }
    });

    _loadTeams();
    _loadScores();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload if we don't have scores loaded yet AND we haven't already loaded teams
    // This prevents clearing the matches cache unnecessarily
    if (_matchScores.isEmpty && _teams.isEmpty) {
      _loadTeams();
      _loadScores();
    }
  }

  Future<void> _loadTeams() async {
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();
    if (mounted) {
      setState(() {
        // Only clear the matches cache if teams have actually changed
        // This prevents unnecessary regeneration when navigating back and forth
        final currentTeamIds = _teams.map((t) => t.id).toList()..sort();
        final cacheKeys = _matchesCache.keys.toList();
        bool teamsChanged = false;

        for (String key in cacheKeys) {
          if (!key.contains(currentTeamIds.join('_'))) {
            teamsChanged = true;
            break;
          }
        }

        if (teamsChanged) {
          _matchesCache.clear();
        }

        // Clear standings cache to force recalculation
        _cachedStandings = null;
        _lastStandingsCacheKey = null;
        _updateDivisions();
      });
    }
  }

  Future<void> _loadScores() async {
    try {
      // Don't reload scores if we just restarted playoffs
      if (_justRestartedPlayoffs) {
        // Reset the flag after skipping the reload
        _justRestartedPlayoffs = false;
        return;
      }

      final preliminaryScores = await _scoreService.loadPreliminaryScores();
      final playoffScores = await _scoreService.loadPlayoffScores();
      final playoffsStarted = await _scoreService
          .loadPlayoffsStartedForDivision(_selectedDivision ?? '');

      print('DEBUG: _loadScores - playoffsStarted: $playoffsStarted');
      print('DEBUG: _loadScores - playoffScores from storage: $playoffScores');

      // Only update state if widget is still mounted
      if (mounted) {
        setState(() {
          // Don't clear existing scores, just update them
          _matchScores.clear();
          _matchScores.addAll(preliminaryScores);

          // Only load playoff scores if playoffs have actually started
          // This prevents loading old scores when starting playoffs fresh
          if (playoffsStarted) {
            print('DEBUG: _loadScores - Playoffs started, loading scores');
            // Only load scores if we don't have any scores already
            // This prevents reloading old scores after restart
            if (_playoffScores.isEmpty) {
              print(
                'DEBUG: _loadScores - _playoffScores is empty, loading from storage',
              );
              _playoffScores.clear();
              _playoffScores.addAll(playoffScores);
              print(
                'DEBUG: _loadScores - Loaded playoff scores: $_playoffScores',
              );
            } else {
              print(
                'DEBUG: _loadScores - _playoffScores not empty, skipping load',
              );
            }
          } else {
            print('DEBUG: _loadScores - Playoffs not started, clearing scores');
            // Clear playoff scores if playoffs haven't started
            _playoffScores.clear();
          }

          _playoffsStartedByDivision[_selectedDivision ?? ''] = playoffsStarted;
        });

        // Scores loaded successfully
      }
    } catch (e) {
      print('Error loading scores: $e');
      // Don't rethrow the error to prevent app crashes
    }
  }

  @override
  void dispose() {
    // Save scores before disposing
    _saveScores();
    _tabController.dispose();
    _playoffTabController.dispose();
    super.dispose();
  }

  // Force refresh standings to show latest data
  void _refreshStandings() {
    setState(() {
      _cachedStandings = null;
      _lastStandingsCacheKey = null;
    });
  }

  // Save scores to persistent storage
  Future<void> _saveScores() async {
    try {
      print('DEBUG: _saveScores called - _playoffScores: $_playoffScores');
      await _scoreService.savePreliminaryScores(_matchScores);
      await _scoreService.savePlayoffScores(_playoffScores);
      await _scoreService.savePlayoffsStartedForDivision(
        _selectedDivision ?? '',
        _playoffsStarted,
      );
      print('DEBUG: _saveScores completed');
    } catch (e) {
      print('Error saving scores to storage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(
        title: widget.tournamentTitle,
        onBackPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (context) => MainNavigationScreen(
                    initialIndex: 3,
                  ), // Go to Schedule tab
            ),
          );
        },
      ),
      bottomNavigationBar: _buildPlayoffsBottomNav(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[50]!, Colors.white],
          ),
        ),
        child: SafeArea(child: _buildPlayoffsContent()),
      ),
    );
  }

  // Build Semi Finals scoreboard like the image
  Widget _buildSemiFinalsScoreboard(Match match, int matchNumber) {
    // Handle null team IDs safely
    final team1Id = match.team1Id ?? '';
    final team2Id = match.team2Id ?? '';

    final team1GamesWon = _getGamesWon(match.id, team1Id);
    final team2GamesWon = _getGamesWon(match.id, team2Id);
    final winner =
        team1GamesWon >= 2
            ? match.team1Id
            : (team2GamesWon >= 2 ? match.team2Id : null);

    final isSelected = _selectedMatch?.id == match.id;

    // Get actual seeding numbers for the teams
    final team1Seeding = _getTeamSeeding(match.team1Id);
    final team2Seeding = _getTeamSeeding(match.team2Id);

    // Check if SF is locked (when Finals has started)
    final isSemiFinalsLocked =
        _hasFinalsScores && _authService.canScore && match.day == 'Semi Finals';

    return GestureDetector(
      onTap:
          (_authService.canScore && !isSemiFinalsLocked)
              ? () => _selectMatch(match)
              : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber[600]! : Colors.grey[600]!,
            width: isSelected ? 4 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'SEEDING',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'TEAM',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'GAME 1',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8), // Gap between game columns
                      Expanded(
                        child: Text(
                          'GAME 2',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8), // Gap between game columns
                      Expanded(
                        child: Text(
                          'GAME 3',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'WINNER',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Team 1 row
                  _buildTeamScoreRow(
                    match.team1,
                    team1GamesWon,
                    match.team1Id,
                    winner == match.team1Id,
                    match,
                    team1Seeding,
                  ),

                  const SizedBox(height: 8),

                  // Team 2 row
                  _buildTeamScoreRow(
                    match.team2,
                    team2GamesWon,
                    match.team2Id,
                    winner == match.team2Id,
                    match,
                    team2Seeding,
                  ),
                ],
              ),
            ),

            // Selection checkmark
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber[600]!.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build team score row
  Widget _buildTeamScoreRow(
    String teamName,
    int gamesWon,
    String? teamId,
    bool isWinner,
    Match match,
    int teamNumber,
  ) {
    final isTBA = teamName == 'TBA';
    // Handle null team IDs safely
    final game1Score =
        teamId != null ? _getGameScore(match.id, teamId, 1) : null;
    final game2Score =
        teamId != null ? _getGameScore(match.id, teamId, 2) : null;
    final game3Score =
        teamId != null ? _getGameScore(match.id, teamId, 3) : null;

    return Row(
      children: [
        // Seeding number
        Expanded(
          flex: 2,
          child: Text(
            isTBA ? '-' : '#$teamNumber',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Team name
        Expanded(
          flex: 2,
          child: Text(
            teamName,
            style: TextStyle(
              color: isTBA ? Colors.grey[400] : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Game 1
        Expanded(
          child: _buildGameScoreCell(match.id, teamId ?? '', 1, game1Score),
        ),

        // Gap between game columns
        const SizedBox(width: 8),

        // Game 2
        Expanded(
          child: _buildGameScoreCell(match.id, teamId ?? '', 2, game2Score),
        ),

        // Gap between game columns
        const SizedBox(width: 8),

        // Game 3
        Expanded(
          child: _buildGameScoreCell(match.id, teamId ?? '', 3, game3Score),
        ),

        // Winner trophy - only show if team won 2+ games
        Expanded(
          child: Center(
            child:
                isWinner && gamesWon >= 2
                    ? Icon(
                      Icons.emoji_events,
                      color: Colors.yellow[600],
                      size: 24,
                    )
                    : const SizedBox(width: 24, height: 24),
          ),
        ),
      ],
    );
  }

  // Build individual game score cell
  Widget _buildGameScoreCell(
    String matchId,
    String teamId,
    int gameNumber,
    int? score,
  ) {
    // Check if this team won this specific game
    final isWinner = _didTeamWinGame(matchId, teamId, gameNumber);

    // For game 3, check if the match was decided in 2 games (Game 3 didn't happen)
    final bool game3DidntHappen =
        gameNumber == 3 && _isGame3NotNeeded(matchId, teamId);

    // Determine what to display
    String displayText;
    if (game3DidntHappen) {
      // Game 3 wasn't needed - always show "-" regardless of stored score
      displayText = '-';
    } else if (score != null && score > 0) {
      displayText = '$score';
    } else {
      // Score is 0 or null
      displayText = '0';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 28,
      decoration: BoxDecoration(
        color: isWinner ? Colors.green[600] : Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isWinner ? Colors.green[400]! : Colors.grey[600]!,
          width: isWinner ? 2 : 1,
        ),
        boxShadow:
            isWinner
                ? [
                  BoxShadow(
                    color: Colors.green[400]!.withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
                : null,
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color:
                isWinner
                    ? Colors.white
                    : (score != null ? Colors.white : Colors.grey[400]),
            fontSize: 12,
            fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Check if Game 3 was not needed (match decided in 2 games)
  bool _isGame3NotNeeded(String matchId, String teamId) {
    if (teamId.isEmpty) return false;

    // Get the opponent ID
    final match = _getSemiFinals().firstWhere(
      (m) => m.id == matchId,
      orElse:
          () => _getFinals().firstWhere(
            (m) => m.id == matchId,
            orElse:
                () => Match(
                  id: matchId,
                  day: '',
                  court: '',
                  time: '',
                  team1: '',
                  team2: '',
                  team1Status: '',
                  team2Status: '',
                  team1Score: 0,
                  team2Score: 0,
                  team1Id: null,
                  team2Id: null,
                  team1Name: null,
                  team2Name: null,
                ),
          ),
    );

    // Get opponent ID
    String? opponentId;
    if (match.team1Id == teamId) {
      opponentId = match.team2Id;
    } else {
      opponentId = match.team1Id;
    }

    if (opponentId == null || opponentId.isEmpty) return false;

    // Check if either team won 2 games (match decided)
    final teamGamesWon = _getGamesWon(matchId, teamId);
    final opponentGamesWon = _getGamesWon(matchId, opponentId);

    // Game 3 is not needed if someone won 2 games
    return teamGamesWon >= 2 || opponentGamesWon >= 2;
  }

  // Check if a team won a specific game
  bool _didTeamWinGame(String matchId, String teamId, int gameNumber) {
    // Return false if teamId is empty (TBA placeholders)
    if (teamId.isEmpty) return false;

    // Get the match to find the opponent
    // Try QF, SF, then Finals
    Match match = _getQuarterFinals().firstWhere(
      (m) => m.id == matchId,
      orElse:
          () => Match(
            id: '',
            day: '',
            court: '',
            time: '',
            team1: '',
            team2: '',
            team1Status: '',
            team2Status: '',
            team1Score: 0,
            team2Score: 0,
            team1Id: null,
            team2Id: null,
            team1Name: null,
            team2Name: null,
            isCompleted: false,
            scheduledDate: null,
          ),
    );

    // If not found in QF, try SF
    if (match.id == '') {
      match = _getSemiFinals().firstWhere(
        (m) => m.id == matchId,
        orElse:
            () => Match(
              id: '',
              day: '',
              court: '',
              time: '',
              team1: '',
              team2: '',
              team1Status: '',
              team2Status: '',
              team1Score: 0,
              team2Score: 0,
              team1Id: null,
              team2Id: null,
              team1Name: null,
              team2Name: null,
              isCompleted: false,
              scheduledDate: null,
            ),
      );
    }

    // If not found in SF, try Finals
    if (match.id == '') {
      match = _getFinals().firstWhere(
        (m) => m.id == matchId,
        orElse:
            () => Match(
              id: '',
              day: '',
              court: '',
              time: '',
              team1: '',
              team2: '',
              team1Status: '',
              team2Status: '',
              team1Score: 0,
              team2Score: 0,
              team1Id: null,
              team2Id: null,
              team1Name: null,
              team2Name: null,
              isCompleted: false,
              scheduledDate: null,
            ),
      );
    }

    final opponentId = match.team1Id == teamId ? match.team2Id : match.team1Id;
    if (opponentId == null || opponentId.isEmpty) return false;

    final teamScore = _getGameScore(matchId, teamId, gameNumber) ?? 0;
    final opponentScore = _getGameScore(matchId, opponentId, gameNumber) ?? 0;

    // Check if this is a completed game (has a valid winner)
    // For QF with best of 1, check if score reaches 11+ and wins by 2
    // For QF/SF/Finals with best of 3, check if score reaches 15+ and wins by 2
    final minScore =
        (match.day == 'Quarter Finals' && _matchFormats['QF'] == '1game')
            ? 11
            : 15;

    // Team wins if they reach minScore and win by 2
    return teamScore >= minScore && teamScore >= opponentScore + 2;
  }

  // Get individual game score
  int? _getGameScore(String matchId, String teamId, int gameNumber) {
    // Get the game-specific score from storage
    final gameKey = '${teamId}_game$gameNumber';
    final playoffScores = _playoffScores[matchId];

    if (playoffScores != null && playoffScores.containsKey(gameKey)) {
      return playoffScores[gameKey];
    }
    return null;
  }

  // Get total games won for a team in a best-of-3 match
  int _getGamesWon(String matchId, String? teamId) {
    if (teamId == null) return 0;

    int gamesWon = 0;
    for (int i = 1; i <= 3; i++) {
      final gameScore = _getGameScore(matchId, teamId, i);
      if (gameScore != null && gameScore > 0) {
        // Check if this team won this game by comparing with opponent
        // Try SF first, then Finals
        Match match = _getSemiFinals().firstWhere(
          (m) => m.id == matchId,
          orElse:
              () => Match(
                id: '',
                day: '',
                court: '',
                time: '',
                team1: '',
                team2: '',
                team1Status: '',
                team2Status: '',
                team1Score: 0,
                team2Score: 0,
                team1Id: null,
                team2Id: null,
                team1Name: null,
                team2Name: null,
                isCompleted: false,
                scheduledDate: null,
              ),
        );

        // If not found in SF, try Finals
        if (match.id == '') {
          match = _getFinals().firstWhere(
            (m) => m.id == matchId,
            orElse:
                () => Match(
                  id: '',
                  day: '',
                  court: '',
                  time: '',
                  team1: '',
                  team2: '',
                  team1Status: '',
                  team2Status: '',
                  team1Score: 0,
                  team2Score: 0,
                  team1Id: null,
                  team2Id: null,
                  team1Name: null,
                  team2Name: null,
                  isCompleted: false,
                  scheduledDate: null,
                ),
          );
        }

        final opponentId =
            match.team1Id == teamId ? match.team2Id : match.team1Id;
        if (opponentId != null) {
          final opponentScore = _getGameScore(matchId, opponentId, i);
          if (gameScore > (opponentScore ?? 0)) {
            gamesWon++;
          }
        }
      }
    }
    return gamesWon;
  }

  // Get team seeding number based on standings position
  int _getTeamSeeding(String? teamId) {
    if (teamId == null) return 0;

    try {
      // Find the team in the teams list
      final team = _teams.firstWhere((t) => t.id == teamId);

      // Find the team in the standings by name
      final standings = _standings;
      for (int i = 0; i < standings.length; i++) {
        if (standings[i].teamName == team.name) {
          return i + 1; // Return 1-based seeding
        }
      }
    } catch (e) {
      // Team not found, return 0
    }
    return 0; // Default if team not found
  }

  // Build Quarter Finals specific card with conditional Game 2 and 3 display
  Widget _buildQuarterFinalsScoreboard(Match match, int matchNumber) {
    final isSelected = _selectedMatch?.id == match.id;
    final team1Seeding = _getTeamSeeding(match.team1Id);
    final team2Seeding = _getTeamSeeding(match.team2Id);

    // Check if scores exist to determine format, otherwise default to '1game'
    final hasGame3Scores =
        _getGameScore(match.id, match.team1Id ?? '', 3) != null ||
        _getGameScore(match.id, match.team2Id ?? '', 3) != null;
    final showBestOf3 = _matchFormats['QF'] == 'bestof3' || hasGame3Scores;

    return GestureDetector(
      onTap: _authService.canScore ? () => _selectMatch(match) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber[600]! : Colors.grey[600]!,
            width: isSelected ? 4 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'SEEDING',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'TEAM',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'GAME 1',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (showBestOf3) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GAME 2',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GAME 3',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          'WINNER',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Team 1 row
                  _buildQuarterFinalsTeamScoreRow(
                    match.team1,
                    match.team1Id,
                    match,
                    team1Seeding,
                    showBestOf3,
                  ),
                  const SizedBox(height: 8),
                  // Team 2 row
                  _buildQuarterFinalsTeamScoreRow(
                    match.team2,
                    match.team2Id,
                    match,
                    team2Seeding,
                    showBestOf3,
                  ),
                ],
              ),
            ),
            // Selection checkmark
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber[600]!.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build team score row for Quarter Finals with conditional Game 2/3
  Widget _buildQuarterFinalsTeamScoreRow(
    String teamName,
    String? teamId,
    Match match,
    int teamNumber,
    bool showBestOf3,
  ) {
    final isTBA = teamName == 'TBA';
    final game1Score =
        teamId != null ? _getGameScore(match.id, teamId, 1) : null;
    final game2Score =
        teamId != null ? _getGameScore(match.id, teamId, 2) : null;
    final game3Score =
        teamId != null ? _getGameScore(match.id, teamId, 3) : null;

    // Determine winner for single game format
    String? winnerId;
    if (teamId != null && game1Score != null && !showBestOf3) {
      final opponentId =
          match.team1Id == teamId ? match.team2Id : match.team1Id;
      if (opponentId != null) {
        final opponentScore = _getGameScore(match.id, opponentId, 1);
        if (game1Score > (opponentScore ?? 0)) {
          winnerId = teamId;
        }
      }
    }

    // Determine winner for best of 3
    final isWinner =
        showBestOf3
            ? _getGamesWon(match.id, teamId) >= 2
            : (winnerId == teamId);

    return Row(
      children: [
        // Seeding number
        Expanded(
          flex: 2,
          child: Text(
            isTBA ? '-' : '#$teamNumber',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Team name
        Expanded(
          flex: 2,
          child: Text(
            teamName,
            style: TextStyle(
              color: isTBA ? Colors.grey[400] : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Game 1
        Expanded(
          child: _buildGameScoreCell(match.id, teamId ?? '', 1, game1Score),
        ),
        if (showBestOf3) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _buildGameScoreCell(match.id, teamId ?? '', 2, game2Score),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildGameScoreCell(match.id, teamId ?? '', 3, game3Score),
          ),
        ],
        // Winner trophy
        Expanded(
          child: Center(
            child:
                isWinner
                    ? Icon(
                      Icons.emoji_events,
                      color: Colors.yellow[600],
                      size: 24,
                    )
                    : const SizedBox(width: 24, height: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Match match) {
    final team1Score = _getTeamScore(match.id, match.team1Id ?? '');
    final team2Score = _getTeamScore(match.id, match.team2Id ?? '');
    final winningTeamId = _getWinningTeamId(match.id);
    final isSelected = _selectedMatch?.id == match.id;

    // Debug logging to track selection
    if (isSelected) {
      print(
        'DEBUG: Card ${match.id} (${match.team1} vs ${match.team2}) is VISUALLY SELECTED',
      );
      print('DEBUG: _selectedMatch ID: ${_selectedMatch?.id}');
    }

    // Debug logging for all cards to see the mismatch
    if (_selectedMatch != null &&
        match.team1 == _selectedMatch!.team1 &&
        match.team2 == _selectedMatch!.team2) {
      print(
        'DEBUG: Found match with same teams: ${match.id} (${match.team1} vs ${match.team2}) - Selected: ${_selectedMatch!.id}',
      );
    }
    final hasOpponent = match.team2 != 'TBA';

    // Check if this is a preliminary match that should be locked
    final isPreliminaryMatch =
        match.day == 'Day 1' || match.day == 'Preliminary';
    final isLocked = _playoffsStarted && isPreliminaryMatch;

    // Check if Semi Finals are locked due to Finals starting
    final isSemiFinalsLocked =
        _hasFinalsScores && _authService.canScore && match.day == 'Semi Finals';

    // Check if Quarter Finals are locked due to Semi Finals starting
    final isQuarterFinalsLocked =
        _hasSemiFinalsScores &&
        _authService.canScore &&
        match.day == 'Quarter Finals';

    return GestureDetector(
      onTap:
          (hasOpponent &&
                  !isLocked &&
                  !isSemiFinalsLocked &&
                  !isQuarterFinalsLocked &&
                  _authService.canScore)
              ? () => _selectMatch(match)
              : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected ? Border.all(color: Colors.yellow, width: 4) : null,
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? Colors.yellow.withOpacity(0.8)
                      : Colors.black.withOpacity(0.1),
              blurRadius: isSelected ? 20 : 4,
              offset: const Offset(0, 4),
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? Colors.yellow.withOpacity(0.2) : null,
            gradient:
                isSelected
                    ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.yellow.withOpacity(0.3),
                        Colors.orange.withOpacity(0.2),
                      ],
                    )
                    : null,
          ),
          child: Stack(
            children: [
              _buildNormalMatchCard(
                match,
                team1Score,
                team2Score,
                winningTeamId,
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
              if (!hasOpponent)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalMatchCard(
    Match match,
    int team1Score,
    int team2Score,
    String? winningTeamId,
  ) {
    final hasScores = team1Score > 0 || team2Score > 0;
    final team1Won = winningTeamId == match.team1Id;
    final team2Won = winningTeamId == match.team2Id;

    // Check if this is a playoff match
    final isPlayoffMatch =
        match.day == 'Quarter Finals' ||
        match.day == 'Semi Finals' ||
        match.day == 'Finals';

    // Get seeding information for playoff matches
    String getTeamDisplayName(String teamName, String? teamId) {
      if (!isPlayoffMatch) return teamName;

      // Handle "TBA" case
      if (teamName == 'TBA') {
        return 'TBA';
      }

      // Find the team's seeding in standings
      final standings = _standings;
      final teamStanding = standings.firstWhere(
        (standing) => standing.teamName == teamName,
        orElse:
            () => Standing(
              rank: 0,
              teamName: teamName,
              games: 0,
              wins: 0,
              losses: 0,
              draws: 0,
              technicalFouls: 0,
              points: 0,
              pointDifference: 0,
            ),
      );

      return '#${teamStanding.rank} $teamName';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date and Match Type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${match.day} - ${match.time}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Match',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Teams and Scores
          Row(
            children: [
              // Team 1 (Left side)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      getTeamDisplayName(match.team1, match.team1Id),
                      style: TextStyle(
                        color:
                            match.team1 == 'TBA'
                                ? Colors.grey[600]
                                : (team1Won ? Colors.blue : Colors.grey[400]),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$team1Score',
                      style: TextStyle(
                        color:
                            match.team1 == 'TBA'
                                ? Colors.grey[600]
                                : (team1Won ? Colors.blue : Colors.grey[400]),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (team1Won && hasScores) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Winner',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // VS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:
                    isPlayoffMatch
                        ? const Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            const Text(
                              'VS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
              ),

              // Team 2 (Right side)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      getTeamDisplayName(match.team2, match.team2Id),
                      style: TextStyle(
                        color:
                            match.team2 == 'TBA'
                                ? Colors.grey[600]
                                : (team2Won ? Colors.red : Colors.grey[400]),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$team2Score',
                      style: TextStyle(
                        color:
                            match.team2 == 'TBA'
                                ? Colors.grey[600]
                                : (team2Won ? Colors.red : Colors.grey[400]),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (team2Won && hasScores) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Winner',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsTab() {
    return Column(
      children: [
        // Standings Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                _standings.isEmpty
                    ? _buildEmptyStandingsState()
                    : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Header Row
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildTableHeader(
                                  ScheduleScreenKeys.teamHeader,
                                  3,
                                ),
                                _buildTableHeader(
                                  ScheduleScreenKeys.winsHeader,
                                  1,
                                ),
                                _buildTableHeader(
                                  ScheduleScreenKeys.lossesHeader,
                                  1,
                                ),
                                _buildTableHeader(
                                  ScheduleScreenKeys.pointDifferenceHeader,
                                  1,
                                ),
                                _buildTableHeader(
                                  ScheduleScreenKeys.pointsHeader,
                                  1,
                                ),
                              ],
                            ),
                          ),

                          // Data Rows
                          Expanded(
                            child: ListView.builder(
                              itemCount: _standings.length,
                              itemBuilder: (context, index) {
                                return _buildStandingRow(_standings[index]);
                              },
                            ),
                          ),

                          // Legend for playoff qualification
                          if (_playoffsStarted)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '* Qualified for Playoffs',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
          ),
        ),

        // Start Playoffs Button (only show when all games are completed and playoffs haven't started)
        if (_allPreliminaryGamesCompleted &&
            !_playoffsStarted &&
            _standings.length >= 2 &&
            _authService.canScore)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _startPlayoffs,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Playoffs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

        // Start/Restart Playoffs Buttons
        if (_authService.canScore)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child:
                _playoffsStarted
                    // Show both buttons when playoffs have started
                    ? Row(
                      children: [
                        // Restart Playoffs button (left side)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _hasQuarterFinalsScores
                                    ? null
                                    : _restartPlayoffs,
                            icon: Icon(
                              _hasQuarterFinalsScores
                                  ? Icons.lock
                                  : Icons.refresh,
                            ),
                            label: const Text('Restart Playoffs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _hasQuarterFinalsScores
                                      ? Colors.grey[400]
                                      : const Color.fromARGB(225, 243, 51, 33),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Start Playoffs button (right side)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to Playoffs tab
                              setState(() {
                                _bottomNavIndex = 1;
                              });
                            },
                            icon: const Icon(Icons.sports_esports),
                            label: const Text('Start Playoffs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                    // Show only Start Playoffs button when playoffs haven't started
                    : _allPreliminaryGamesCompleted && _standings.length >= 2
                    ? ElevatedButton.icon(
                      onPressed: _startPlayoffs,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Playoffs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildTableHeader(String text, int flex) {
    // For stats columns (W, L, D, PTS), use fixed width
    if (flex == 1) {
      return SizedBox(
        width: 30,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // For team name column, use Expanded
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStandingRow(Standing standing) {
    // Calculate how many teams qualify for playoffs
    int qualifyingTeams = (_standings.length / 2).ceil();
    if (qualifyingTeams < 2) qualifyingTeams = 2;
    if (qualifyingTeams > _standings.length) {
      qualifyingTeams = _standings.length;
    }

    // Check if this team qualifies for playoffs
    bool isQualifying = _playoffsStarted && standing.rank <= qualifyingTeams;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isQualifying ? Colors.green.withOpacity(0.2) : null,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${standing.rank}',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Team Logo (placeholder)
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sports, color: Colors.grey[800], size: 14),
          ),
          const SizedBox(width: 8),

          // Team Name
          Expanded(
            flex: 3,
            child: Text(
              standing.teamName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

          // Stats - only W, L, D, PTS with consistent width
          SizedBox(
            width: 30,
            child: Text(
              '${standing.wins}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${standing.losses}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${standing.pointDifference >= 0 ? '+' : ''}${standing.pointDifference}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${standing.points}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Check if there are no scores entered
  bool _hasNoScores() {
    for (var match in _preliminaryMatches) {
      if (match.team2 == 'TBA') continue;
      final scores = _matchScores[match.id];
      if (scores != null && scores.length >= 2) {
        final team1Score = scores[match.team1Id] ?? 0;
        final team2Score = scores[match.team2Id] ?? 0;
        if (team1Score > 0 || team2Score > 0) {
          return false; // Found a score > 0
        }
      }
    }
    return true; // No scores found
  }

  // Check if the selected match has scores
  bool _hasScoresForSelectedMatch() {
    if (_selectedMatch == null) return false;

    // Check for SF/Finals (best-of-3)
    if (_selectedMatch!.day == 'Semi Finals' ||
        _selectedMatch!.day == 'Finals') {
      final playoffScores = _playoffScores[_selectedMatch!.id];
      if (playoffScores != null && playoffScores.isNotEmpty) {
        // Check if any game scores exist (game1, game2, or game3)
        final team1Id = _selectedMatch!.team1Id ?? '';
        final team2Id = _selectedMatch!.team2Id ?? '';

        for (int game = 1; game <= 3; game++) {
          final team1GameScore = playoffScores['${team1Id}_game$game'];
          final team2GameScore = playoffScores['${team2Id}_game$game'];
          if ((team1GameScore != null && team1GameScore > 0) ||
              (team2GameScore != null && team2GameScore > 0)) {
            return true;
          }
        }
      }
      return false;
    }

    // Check for regular matches (single game)
    final scores = _matchScores[_selectedMatch!.id];
    if (scores != null && scores.length >= 2) {
      final team1Score = scores[_selectedMatch!.team1Id] ?? 0;
      final team2Score = scores[_selectedMatch!.team2Id] ?? 0;
      return team1Score > 0 || team2Score > 0;
    }
    return false;
  }

  // Debug method to check button state (removed excessive logging)
  void _debugButtonState() {
    // Removed debug logging to prevent console spam
  }

  // Check if the selected match belongs to the current tab
  bool _isSelectedMatchInCurrentTab() {
    if (_selectedMatch == null) {
      print('DEBUG: _isSelectedMatchInCurrentTab - No selected match');
      return false;
    }

    print(
      'DEBUG: _isSelectedMatchInCurrentTab - Selected match: ${_selectedMatch!.id} (${_selectedMatch!.team1} vs ${_selectedMatch!.team2})',
    );
    print(
      'DEBUG: _isSelectedMatchInCurrentTab - Main tab index: ${_tabController.index}',
    );

    // Check if we're in the preliminary tab and the match is a preliminary match
    if (_tabController.index == 0) {
      // Preliminary tab
      final isInPreliminary = _preliminaryMatches.any(
        (match) => match.id == _selectedMatch!.id,
      );
      print(
        'DEBUG: _isSelectedMatchInCurrentTab - Preliminary tab, isInPreliminary: $isInPreliminary',
      );
      return isInPreliminary;
    }

    // Check if we're in the playoffs tab and the match is a playoff match
    if (_tabController.index == 1) {
      // Playoffs tab - need to check which specific playoff sub-tab we're in
      final playoffSubTabIndex = _playoffTabController.index;

      if (playoffSubTabIndex == 0) {
        // Quarter Finals tab
        final quarterFinals = _getQuarterFinals();
        final isInQuarterFinals = quarterFinals.any(
          (match) => match.id == _selectedMatch!.id,
        );
        print(
          'DEBUG: _isSelectedMatchInCurrentTab - Quarter Finals tab, isInQuarterFinals: $isInQuarterFinals',
        );
        print(
          'DEBUG: _isSelectedMatchInCurrentTab - Quarter Finals matches: ${quarterFinals.map((m) => '${m.id} (${m.team1} vs ${m.team2})').join(', ')}',
        );
        return isInQuarterFinals;
      } else if (playoffSubTabIndex == 1) {
        // Semi Finals tab
        final semiFinals = _getSemiFinalsDirect();
        final isInSemiFinals = semiFinals.any(
          (match) => match.id == _selectedMatch!.id,
        );
        return isInSemiFinals;
      } else if (playoffSubTabIndex == 2) {
        // Finals tab
        final finals = _getFinalsDirect();
        final isInFinals = finals.any(
          (match) => match.id == _selectedMatch!.id,
        );
        return isInFinals;
      }
    }

    return false;
  }

  // Reshuffle teams method
  void _reshuffleTeams() async {
    print('DEBUG: _reshuffleTeams called - clearing _selectedMatch');
    // Clear everything completely
    _matchesCache.clear();
    _matchScores.clear();
    _selectedMatch = null;
    _cachedStandings = null;
    _lastStandingsCacheKey = null;
    _reshuffledMatches = null; // Clear reshuffled matches

    // Clear scores from storage
    await _scoreService.clearAllScores();

    // Generate completely new matches
    final teams = _teams;
    if (teams.isNotEmpty) {
      // Shuffle teams directly
      final shuffledTeams = List.from(teams);
      shuffledTeams.shuffle();

      // Generate matches with shuffled teams
      final newMatches = _generateMatchesForTeams(shuffledTeams);

      // Store the new matches in state
      _reshuffledMatches = newMatches;
    }

    // Single UI update with new matches
    if (mounted) {
      setState(() {
        // UI updated with new matches
      });
    }
  }

  // Generate matches for a specific set of teams
  List<Match> _generateMatchesForTeams(List<dynamic> teams) {
    List<Match> matches = [];
    int matchId = 1;
    int courtNumber = 1;
    int timeSlot = 10; // Start at 10 AM

    // Group teams by division
    Map<String, List<dynamic>> teamsByDivision = {};
    for (var team in teams) {
      final division = team.division ?? 'Open';
      if (!teamsByDivision.containsKey(division)) {
        teamsByDivision[division] = [];
      }
      teamsByDivision[division]!.add(team);
    }

    // Generate matches for each division separately
    for (String division in teamsByDivision.keys) {
      final divisionTeams = teamsByDivision[division]!;
      if (divisionTeams.length < 2) continue;

      // Create a copy of teams for this division
      List<dynamic> availableTeams = List.from(divisionTeams);
      Map<String, int> gamesPlayed = {};
      Set<String> usedMatches = {};

      // Initialize games played counter
      for (var team in availableTeams) {
        gamesPlayed[team.id] = 0;
      }

      // Generate matches ensuring each team plays exactly 3 games
      int maxAttempts = 1000;
      int attempts = 0;

      while (availableTeams.length >= 2 && attempts < maxAttempts) {
        attempts++;

        // Find two teams that haven't played each other and haven't played 3 games
        bool matchFound = false;
        for (int i = 0; i < availableTeams.length - 1; i++) {
          for (int j = i + 1; j < availableTeams.length; j++) {
            final team1 = availableTeams[i];
            final team2 = availableTeams[j];

            // Create match key for uniqueness check
            final matchKey = '${team1.id}_${team2.id}';
            final reverseMatchKey = '${team2.id}_${team1.id}';

            // Check if teams haven't played each other and haven't reached game limit
            if (!usedMatches.contains(matchKey) &&
                !usedMatches.contains(reverseMatchKey) &&
                gamesPlayed[team1.id]! < 3 &&
                gamesPlayed[team2.id]! < 3) {
              // Create match
              matches.add(
                Match(
                  id: matchId.toString(),
                  day: 'Day 1',
                  time: '$timeSlot:00 AM',
                  court: 'Court $courtNumber',
                  team1: team1.name,
                  team1Id: team1.id,
                  team2: team2.name,
                  team2Id: team2.id,
                  team1Status: 'pending',
                  team2Status: 'pending',
                  team1Score: 0,
                  team2Score: 0,
                ),
              );

              // Mark teams as having played each other
              usedMatches.add(matchKey);
              usedMatches.add(reverseMatchKey);

              // Update games played counter
              gamesPlayed[team1.id] = gamesPlayed[team1.id]! + 1;
              gamesPlayed[team2.id] = gamesPlayed[team2.id]! + 1;

              // Remove teams that have played 3 games
              availableTeams.removeWhere((team) => gamesPlayed[team.id]! >= 3);

              matchId++;
              courtNumber++;
              if (courtNumber > 4) {
                courtNumber = 1;
                timeSlot += 2; // 2-hour intervals
              }

              matchFound = true;
              break;
            }
          }
          if (matchFound) break;
        }

        if (!matchFound) {
          // Remove teams that have played their maximum games
          availableTeams.removeWhere((team) => gamesPlayed[team.id]! >= 3);
        }
      }

      if (attempts >= maxAttempts) {
        print('WARNING: Max attempts reached for division $division');
      }
    }

    return matches;
  }

  // Show dialog when trying to reshuffle with scores
  void _showReshuffleScoresDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Scores Required'),
          content: const Text(
            'Please manually reset all scores to 0 before reshuffling teams.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show dialog explaining playoff score edit restriction
  void _showPlayoffScoreEditRestrictionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Playoffs in Progress'),
          content: const Text(
            'To edit playoff scores, you\'ll need to restart the playoffs first. This will reset the entire playoff bracket and allow you to make changes.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartPlayoffs();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(225, 243, 51, 33),
                foregroundColor: Colors.white,
              ),
              child: const Text('Restart Playoffs'),
            ),
          ],
        );
      },
    );
  }

  // Show dialog explaining that user doesn't have scoring permissions
  void _showScoringPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access Restricted'),
          content: const Text(
            'Only authorized administrators can access scoring features. Please contact an administrator if you need scoring access.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show dialog when trying to start next round without completing scores
  void _showCompleteScoresDialog(String roundName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Complete $roundName Scores'),
          content: Text(
            'Please enter all $roundName scores before starting the next round.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Build playoffs bottom navigation
  Widget _buildPlayoffsBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: (index) async {
        // Save scores before switching tabs
        await _saveScores();
        setState(() {
          _bottomNavIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF2196F3),
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.sports_score), label: 'Games'),
        BottomNavigationBarItem(icon: Icon(Icons.sports), label: 'Playoffs'),
      ],
    );
  }

  // Build playoffs content based on bottom nav index
  Widget _buildPlayoffsContent() {
    if (_bottomNavIndex == 0) {
      // Show the regular schedule content
      return Column(
        children: [
          // Division Dropdown
          if (_availableDivisions.isNotEmpty) ...[
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 230),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedDivision,
                  decoration: InputDecoration(
                    hintText:
                        widget.sportName.toLowerCase().contains('pickleball')
                            ? 'Select DUPR Rating'
                            : 'Select Division',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    prefixIcon: Icon(
                      widget.sportName.toLowerCase().contains('pickleball')
                          ? Icons.sports_tennis
                          : Icons.sports_basketball,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                  ),
                  isExpanded: false,
                  items:
                      _availableDivisions.map((String division) {
                        return DropdownMenuItem<String>(
                          value: division,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedDivision == division) ...[
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF2196F3),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  division,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: (String? newValue) async {
                    setState(() {
                      _selectedDivision = newValue;
                    });
                    // Load playoff state for the new division
                    await _loadScores();
                  },
                ),
              ),
            ),
          ],

          // Spacing between dropdown and tab bar
          const SizedBox(height: 16),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Tab Bar
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: EdgeInsets.zero,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      isScrollable: false,
                      tabs: const [
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Preliminary',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Standings',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPreliminaryRoundsTab(), _buildStandingsTab()],
            ),
          ),
        ],
      );
    } else {
      // Show playoffs content
      return _buildPlayoffsTab();
    }
  }

  // Build preliminary rounds tab
  Widget _buildPreliminaryRoundsTab() {
    if (_preliminaryMatches.isEmpty) {
      return _buildEmptyMatchesState();
    }

    return Column(
      children: [
        // Matches List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _preliminaryMatches.length,
            itemBuilder: (context, index) {
              return _buildMatchCard(_preliminaryMatches[index]);
            },
          ),
        ),
        // Fixed buttons at bottom
        if (_preliminaryMatches.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children:
                  _authService.canScore
                      ? [
                        // Reshuffle Teams button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _hasNoScores()
                                    ? _reshuffleTeams
                                    : _showReshuffleScoresDialog,
                            icon: const Icon(Icons.shuffle, size: 18),
                            label: const Text('Reshuffle Teams'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _hasNoScores()
                                      ? const Color(0xFF2196F3)
                                      : Colors.grey[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Start Scoring button
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              _debugButtonState(); // Debug button state
                              return ElevatedButton.icon(
                                onPressed:
                                    (_selectedMatch != null &&
                                            _isSelectedMatchInCurrentTab())
                                        ? _startScoring
                                        : null,
                                icon: const Icon(Icons.sports_score, size: 18),
                                label: Text(
                                  _playoffsStarted
                                      ? 'Playoffs Started'
                                      : _selectedMatch != null &&
                                          _isSelectedMatchInCurrentTab()
                                      ? (_hasScoresForSelectedMatch()
                                          ? 'Edit Scoring'
                                          : 'Start Scoring')
                                      : 'Select a Match',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      (_selectedMatch != null &&
                                              _isSelectedMatchInCurrentTab())
                                          ? const Color(0xFF2196F3)
                                          : Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ]
                      : [], // Hide buttons for regular users
            ),
          ),
      ],
    );
  }

  Widget _buildPlayoffsTab() {
    // Always show playoffs tab, but with different content based on playoff status

    return Column(
      children: [
        // Playoff Bracket Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${widget.tournamentTitle} Playoffs',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Playoff Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _playoffTabController,
            indicator: BoxDecoration(
              color: const Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: EdgeInsets.zero,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            isScrollable: false,
            tabs: const [
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Quarter Finals',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Semi Finals',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Finals',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Playoff Tab Content
        Expanded(
          child: TabBarView(
            controller: _playoffTabController,
            children: [
              _buildQuarterFinalsTab(),
              _buildSemiFinalsTab(),
              _buildFinalsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // Build Quarter Finals tab
  Widget _buildQuarterFinalsTab() {
    final quarterFinals = _getQuarterFinals();

    return Column(
      children: [
        // Quarter Finals matches
        Expanded(
          child:
              quarterFinals.isEmpty
                  ? _buildEmptyPlayoffsState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: quarterFinals.length,
                    itemBuilder: (context, index) {
                      // Always use QF specific scoreboard that adapts to format
                      return _buildQuarterFinalsScoreboard(
                        quarterFinals[index],
                        index + 1,
                      );
                    },
                  ),
        ),

        // Start Scoring Button for Quarter Finals
        if (quarterFinals.isNotEmpty && _authService.canScore)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      _debugButtonState(); // Debug button state
                      return ElevatedButton.icon(
                        onPressed:
                            (!_authService.canScore)
                                ? null
                                : (_selectedMatch != null &&
                                    _isSelectedMatchInCurrentTab())
                                ? _startScoring
                                : null,
                        label: Text(
                          !_authService.canScore
                              ? 'Access Restricted'
                              : _hasSemiFinalsScores
                              ? 'Semi Finals Started'
                              : _selectedMatch != null &&
                                  _isSelectedMatchInCurrentTab()
                              ? (_hasScoresForSelectedMatch()
                                  ? 'Edit Scoring'
                                  : 'Start Scoring')
                              : 'Select a Match',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              !_authService.canScore
                                  ? Colors.red[400]
                                  : (_selectedMatch != null &&
                                      _isSelectedMatchInCurrentTab())
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Start SF Button (disabled until all QF scores are set)
                if (_authService.canScore)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: ElevatedButton.icon(
                        onPressed:
                            _allQuarterFinalsScoresSet
                                ? () {
                                  // Navigate to Semi Finals tab (index 1)
                                  _playoffTabController.animateTo(1);
                                }
                                : () {
                                  _showCompleteScoresDialog('Quarter Finals');
                                },
                        icon: Icon(
                          _allQuarterFinalsScoresSet
                              ? Icons.arrow_forward
                              : Icons.lock,
                        ),
                        label: Text(
                          _allQuarterFinalsScoresSet
                              ? 'Start Semi Finals'
                              : 'Start Semi Finals',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _allQuarterFinalsScoresSet
                                  ? Colors.green
                                  : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Build Semi Finals tab
  Widget _buildSemiFinalsTab() {
    final semiFinals = _getSemiFinals();

    return Column(
      children: [
        // Semi Finals matches
        Expanded(
          child:
              semiFinals.isEmpty
                  ? _buildEmptyPlayoffsState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: semiFinals.length,
                    itemBuilder: (context, index) {
                      return _buildSemiFinalsScoreboard(
                        semiFinals[index],
                        index + 1,
                      );
                    },
                  ),
        ),

        // Start Scoring Button for Semi Finals
        if (semiFinals.isNotEmpty && _authService.canScore)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      _debugButtonState(); // Debug button state
                      return ElevatedButton.icon(
                        onPressed:
                            (!_authService.canScore || _hasFinalsScores)
                                ? null
                                : (_selectedMatch != null &&
                                    _isSelectedMatchInCurrentTab())
                                ? _startScoring
                                : null,
                        label: Text(
                          !_authService.canScore
                              ? 'Access Restricted'
                              : _hasFinalsScores
                              ? 'Finals Started'
                              : _selectedMatch != null &&
                                  _isSelectedMatchInCurrentTab()
                              ? (_hasScoresForSelectedMatch()
                                  ? 'Edit Scoring'
                                  : 'Start Scoring')
                              : 'Select a Match',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              !_authService.canScore
                                  ? Colors.red[400]
                                  : _hasFinalsScores
                                  ? Colors.grey[400]
                                  : (_selectedMatch != null &&
                                      _isSelectedMatchInCurrentTab())
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Start Finals Button (disabled until all SF scores are set)
                if (_authService.canScore)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: ElevatedButton.icon(
                        onPressed:
                            _allSemiFinalsScoresSet
                                ? () {
                                  // Navigate to Finals tab (index 2)
                                  _playoffTabController.animateTo(2);
                                }
                                : () {
                                  _showCompleteScoresDialog('Semi Finals');
                                },
                        icon: Icon(
                          _allSemiFinalsScoresSet
                              ? Icons.arrow_forward
                              : Icons.lock,
                        ),
                        label: Text(
                          _allSemiFinalsScoresSet
                              ? 'Start Finals'
                              : 'Start Finals',
                          textAlign: TextAlign.center,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _allSemiFinalsScoresSet
                                  ? Colors.green
                                  : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Build Finals tab
  Widget _buildFinalsTab() {
    final finals = _getFinals();

    return Column(
      children: [
        // Finals matches
        Expanded(
          child:
              finals.isEmpty
                  ? _buildEmptyPlayoffsState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: finals.length,
                    itemBuilder: (context, index) {
                      return _buildSemiFinalsScoreboard(
                        finals[index],
                        index + 1,
                      );
                    },
                  ),
        ),

        // Winner Announcement (only show if there's a winner)
        if (_getFinalsWinner() != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1A2E), // Deep purple
                  const Color(0xFF16213E), // Dark blue-purple
                  const Color(0xFF0F3460), // Ocean blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.5),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    size: 56,
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '🏆 CHAMPION 🏆',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Colors.amberAccent.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getFinalsWinner()!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.tournamentTitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Start Scoring Button for Finals
        if (finals.isNotEmpty && _authService.canScore)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      _debugButtonState(); // Debug button state
                      return ElevatedButton.icon(
                        onPressed:
                            (!_authService.canScore)
                                ? null
                                : (_selectedMatch != null &&
                                    _isSelectedMatchInCurrentTab())
                                ? _startScoring
                                : null,
                        icon: const Icon(Icons.sports_score),
                        label: Text(
                          !_authService.canScore
                              ? 'Access Restricted'
                              : _selectedMatch != null &&
                                  _isSelectedMatchInCurrentTab()
                              ? (_hasScoresForSelectedMatch()
                                  ? 'Edit Scoring'
                                  : 'Start Scoring')
                              : _getFinalsWinner() != null
                              ? 'Finals Complete'
                              : 'Select a Match',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              !_authService.canScore
                                  ? Colors.red[400]
                                  : (_selectedMatch != null &&
                                      _isSelectedMatchInCurrentTab())
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Get Quarter Finals matches directly without calling _playoffs getter
  List<Match> _getQuarterFinalsDirect() {
    final standings = _standings;
    if (standings.length < 2) return [];

    List<Match> quarterFinals = [];
    // Use consistent ID generation based on team names to prevent card selection jumping
    // Use very high ID range to avoid conflicts with preliminary matches
    int matchId = 2000000; // Start with a very high base ID to avoid conflicts
    int courtNumber = 1;
    int timeSlot = 14;

    // Calculate how many teams qualify (half of total teams, minimum 2)
    int qualifyingTeams = (standings.length / 2).ceil();
    if (qualifyingTeams < 2) qualifyingTeams = 2;
    if (qualifyingTeams > standings.length) qualifyingTeams = standings.length;

    // Create quarter-final matches with proper seeding
    for (int i = 0; i < qualifyingTeams / 2; i++) {
      final team1Index = i;
      final team2Index = qualifyingTeams - 1 - i;

      if (team2Index > team1Index) {
        // Find teams by their standings
        final team1 = _teams.firstWhere(
          (t) => t.name == standings[team1Index].teamName,
        );
        final team2 = _teams.firstWhere(
          (t) => t.name == standings[team2Index].teamName,
        );

        quarterFinals.add(
          Match(
            id: matchId.toString(),
            day: 'Quarter Finals',
            court: 'Court $courtNumber',
            time: '$timeSlot:00',
            team1: team1.name,
            team2: team2.name,
            team1Status: 'Not Checked-in',
            team2Status: 'Not Checked-in',
            team1Score: 0,
            team2Score: 0,
            team1Id: team1.id,
            team2Id: team2.id,
            team1Name: team1.name,
            team2Name: team2.name,
            isCompleted: false,
            scheduledDate: DateTime.now().add(Duration(days: 1)),
          ),
        );

        matchId++;
        courtNumber++;
        if (courtNumber > 4) {
          courtNumber = 1;
          timeSlot++;
        }
      }
    }

    return quarterFinals;
  }

  // Get Quarter Finals matches (legacy method for compatibility)
  List<Match> _getQuarterFinals() {
    if (!_playoffsStarted) {
      return _getQuarterFinalsPlaceholders();
    }

    // Always generate fresh matches to allow winners to advance
    final matches = _getQuarterFinalsDirect();
    print(
      'DEBUG: _getQuarterFinals generating fresh ${matches.length} matches:',
    );
    for (var match in matches) {
      print('DEBUG: Match ${match.id}: ${match.team1} vs ${match.team2}');
    }
    return matches;
  }

  // Get Quarter Finals placeholder matches when playoffs haven't started
  List<Match> _getQuarterFinalsPlaceholders() {
    final standings = _standings;
    if (standings.length < 2) return [];

    List<Match> placeholders = [];
    // Use consistent ID generation to prevent card selection jumping
    // Use very high ID range to avoid conflicts with preliminary matches
    int matchId = 3000000; // Start with a very high base ID to avoid conflicts
    int courtNumber = 1;
    int timeSlot = 14;

    // Calculate how many teams would qualify (half of total teams, minimum 2)
    int qualifyingTeams = (standings.length / 2).ceil();
    if (qualifyingTeams < 2) qualifyingTeams = 2;
    if (qualifyingTeams > standings.length) qualifyingTeams = standings.length;

    // Create placeholder quarter-final matches
    for (int i = 0; i < qualifyingTeams / 2; i++) {
      final team1Index = i;
      final team2Index = qualifyingTeams - 1 - i;

      if (team2Index > team1Index) {
        placeholders.add(
          Match(
            id: matchId.toString(),
            day: 'Quarter Finals',
            court: 'Court $courtNumber',
            time: '$timeSlot:00',
            team1: 'TBA',
            team2: 'TBA',
            team1Status: 'Not Checked-in',
            team2Status: 'Not Checked-in',
            team1Score: 0,
            team2Score: 0,
            team1Id: null,
            team2Id: null,
            team1Name: 'TBA',
            team2Name: 'TBA',
            isCompleted: false,
            scheduledDate: DateTime.now().add(Duration(days: 1)),
          ),
        );

        matchId++;
        courtNumber++;
        if (courtNumber > 4) {
          courtNumber = 1;
          timeSlot++;
        }
      }
    }

    return placeholders;
  }

  // Get Semi Finals matches directly without calling _playoffs getter
  List<Match> _getSemiFinalsDirect() {
    final quarterFinalsWinners = _getQuarterFinalsWinners();

    List<Match> semiFinals = [];
    // Use consistent ID generation to prevent card selection jumping
    int matchId = 4000000; // Start with a very high base ID for semi-finals
    int courtNumber = 1;
    int timeSlot = 16;

    // Always create exactly 2 semi-final matches
    for (int i = 0; i < 2; i++) {
      if (quarterFinalsWinners.length >= 4) {
        // We have all 4 quarter-final winners, create proper seeding matchups
        // SF1: Winner of QF1 vs Winner of QF4 (1st seed vs 4th seed)
        // SF2: Winner of QF2 vs Winner of QF3 (2nd seed vs 3rd seed)
        final team1Index =
            i == 0
                ? 0
                : 1; // First SF gets QF1 winner, Second SF gets QF2 winner
        final team2Index =
            i == 0
                ? 3
                : 2; // First SF gets QF4 winner, Second SF gets QF3 winner

        if (team1Index < quarterFinalsWinners.length &&
            team2Index < quarterFinalsWinners.length) {
          final team1 = quarterFinalsWinners[team1Index];
          final team2 = quarterFinalsWinners[team2Index];

          semiFinals.add(
            Match(
              id: matchId.toString(),
              day: 'Semi Finals',
              court: 'Court $courtNumber',
              time: '$timeSlot:00',
              team1: team1.name,
              team2: team2.name,
              team1Status: 'Not Checked-in',
              team2Status: 'Not Checked-in',
              team1Score: 0,
              team2Score: 0,
              team1Id: team1.id,
              team2Id: team2.id,
              team1Name: team1.name,
              team2Name: team2.name,
              isCompleted: false,
              scheduledDate: DateTime.now().add(Duration(days: 2)),
            ),
          );
        } else {
          // Create TBA match if we don't have enough winners yet
          semiFinals.add(
            Match(
              id: matchId.toString(),
              day: 'Semi Finals',
              court: 'Court $courtNumber',
              time: '$timeSlot:00',
              team1: 'TBA',
              team2: 'TBA',
              team1Status: 'Not Checked-in',
              team2Status: 'Not Checked-in',
              team1Score: 0,
              team2Score: 0,
              team1Id: null,
              team2Id: null,
              team1Name: 'TBA',
              team2Name: 'TBA',
              isCompleted: false,
              scheduledDate: DateTime.now().add(Duration(days: 2)),
            ),
          );
        }
      } else {
        // Create TBA match if we don't have enough winners yet
        semiFinals.add(
          Match(
            id: matchId.toString(),
            day: 'Semi Finals',
            court: 'Court $courtNumber',
            time: '$timeSlot:00',
            team1: 'TBA',
            team2: 'TBA',
            team1Status: 'Not Checked-in',
            team2Status: 'Not Checked-in',
            team1Score: 0,
            team2Score: 0,
            team1Id: null,
            team2Id: null,
            team1Name: 'TBA',
            team2Name: 'TBA',
            isCompleted: false,
            scheduledDate: DateTime.now().add(Duration(days: 2)),
          ),
        );
      }

      matchId++;
      courtNumber++;
      if (courtNumber > 4) {
        courtNumber = 1;
        timeSlot++;
      }
    }

    return semiFinals;
  }

  // Get Semi Finals matches (legacy method for compatibility)
  List<Match> _getSemiFinals() {
    // Always show bracket structure, but populate with actual teams when available
    final directMatches = _getSemiFinalsDirect();
    if (directMatches.isEmpty) {
      return _getSemiFinalsPlaceholders();
    }

    // Create bracket structure with actual teams where available, TBA where not
    List<Match> bracketMatches = [];
    final placeholders = _getSemiFinalsPlaceholders();

    for (int i = 0; i < placeholders.length; i++) {
      if (i < directMatches.length) {
        // Use actual match if available
        bracketMatches.add(directMatches[i]);
      } else {
        // Use placeholder for missing matches
        bracketMatches.add(placeholders[i]);
      }
    }

    return bracketMatches;
  }

  // Get Semi Finals placeholder matches when playoffs haven't started
  List<Match> _getSemiFinalsPlaceholders() {
    List<Match> placeholders = [];
    // Use consistent ID generation to prevent card selection jumping
    int matchId = 4000000; // Start with a very high base ID for semi-finals
    int courtNumber = 1;
    int timeSlot = 16;

    // Create 2 placeholder semi-final matches with "TBA" (4 teams from QF -> 2 SF matches)
    for (int i = 0; i < 2; i++) {
      placeholders.add(
        Match(
          id: matchId.toString(),
          day: 'Semi Finals',
          court: 'Court $courtNumber',
          time: '$timeSlot:00',
          team1: 'TBA',
          team2: 'TBA',
          team1Status: 'Not Checked-in',
          team2Status: 'Not Checked-in',
          team1Score: 0,
          team2Score: 0,
          team1Id: null,
          team2Id: null,
          team1Name: 'TBA',
          team2Name: 'TBA',
          isCompleted: false,
          scheduledDate: DateTime.now().add(Duration(days: 2)),
        ),
      );

      matchId++;
      courtNumber++;
      if (courtNumber > 4) {
        courtNumber = 1;
        timeSlot++;
      }
    }

    return placeholders;
  }

  // Get Finals matches directly without calling _playoffs getter
  List<Match> _getFinalsDirect() {
    final semiFinalsWinners = _getSemiFinalsWinners();

    List<Match> finals = [];
    // Use consistent ID generation to prevent card selection jumping
    int matchId = 5000000; // Start with a very high base ID for finals
    int courtNumber = 1;
    int timeSlot = 18;

    if (semiFinalsWinners.length >= 2) {
      // Create final match with actual teams
      final team1 = semiFinalsWinners[0];
      final team2 = semiFinalsWinners[1];

      finals.add(
        Match(
          id: matchId.toString(),
          day: 'Finals',
          court: 'Court $courtNumber',
          time: '$timeSlot:00',
          team1: team1.name,
          team2: team2.name,
          team1Status: 'Not Checked-in',
          team2Status: 'Not Checked-in',
          team1Score: 0,
          team2Score: 0,
          team1Id: team1.id,
          team2Id: team2.id,
          team1Name: team1.name,
          team2Name: team2.name,
          isCompleted: false,
          scheduledDate: DateTime.now().add(Duration(days: 3)),
        ),
      );
    } else {
      // Create placeholder match when no semi finals winners yet
      finals.add(
        Match(
          id: matchId.toString(),
          day: 'Finals',
          court: 'Court $courtNumber',
          time: '$timeSlot:00',
          team1: 'TBA',
          team2: 'TBA',
          team1Status: 'Not Checked-in',
          team2Status: 'Not Checked-in',
          team1Score: 0,
          team2Score: 0,
          team1Id: null,
          team2Id: null,
          team1Name: 'TBA',
          team2Name: 'TBA',
          isCompleted: false,
          scheduledDate: DateTime.now().add(Duration(days: 3)),
        ),
      );
    }

    return finals;
  }

  // Get Finals matches (legacy method for compatibility)
  List<Match> _getFinals() {
    // Always show bracket structure, but populate with actual teams when available
    final directMatches = _getFinalsDirect();
    if (directMatches.isEmpty) {
      return _getFinalsPlaceholders();
    }

    // Create bracket structure with actual teams where available, TBA where not
    List<Match> bracketMatches = [];
    final placeholders = _getFinalsPlaceholders();

    for (int i = 0; i < placeholders.length; i++) {
      if (i < directMatches.length) {
        // Use actual match if available
        bracketMatches.add(directMatches[i]);
      } else {
        // Use placeholder for missing matches
        bracketMatches.add(placeholders[i]);
      }
    }

    return bracketMatches;
  }

  // Get Finals placeholder matches when playoffs haven't started
  List<Match> _getFinalsPlaceholders() {
    List<Match> placeholders = [];
    // Use consistent ID generation to prevent card selection jumping
    int matchId = 5000000; // Start with a very high base ID for finals
    int courtNumber = 1;
    int timeSlot = 18;

    // Create placeholder final match with "TBA"
    placeholders.add(
      Match(
        id: matchId.toString(),
        day: 'Finals',
        court: 'Court $courtNumber',
        time: '$timeSlot:00',
        team1: 'TBA',
        team2: 'TBA',
        team1Status: 'Not Checked-in',
        team2Status: 'Not Checked-in',
        team1Score: 0,
        team2Score: 0,
        team1Id: null,
        team2Id: null,
        team1Name: 'TBA',
        team2Name: 'TBA',
        isCompleted: false,
        scheduledDate: DateTime.now().add(Duration(days: 3)),
      ),
    );

    return placeholders;
  }

  Widget _buildEmptyPlayoffsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _playoffsStarted ? Colors.orange[50] : Colors.blue[50],
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      _playoffsStarted
                          ? Colors.orange[200]!
                          : Colors.blue[200]!,
                  width: 2,
                ),
              ),
              child: Icon(
                _playoffsStarted ? Icons.sports : Icons.schedule,
                size: 48,
                color: _playoffsStarted ? Colors.orange[600] : Colors.blue[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _playoffsStarted
                  ? 'No Playoff Matches Yet'
                  : 'Playoffs Not Started',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _playoffsStarted
                    ? 'Complete all preliminary rounds to generate playoff matches automatically'
                    : 'Complete all preliminary rounds and click "Start Playoffs" to begin the elimination rounds',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (!_playoffsStarted) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Playoffs will be generated automatically',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMatchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_basketball, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No Matches Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register teams to see preliminary rounds',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStandingsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No Standings Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register teams to see standings',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Semi Finals Scoring Screen for Best of 3 Games
class SemiFinalsScoringScreen extends StatefulWidget {
  final Match match;
  final Map<String, dynamic>? initialScores;
  final String matchFormat; // '1game' or 'bestof3'
  final Function(Map<String, dynamic>) onScoresUpdated;

  const SemiFinalsScoringScreen({
    Key? key,
    required this.match,
    this.initialScores,
    required this.matchFormat,
    required this.onScoresUpdated,
  }) : super(key: key);

  @override
  State<SemiFinalsScoringScreen> createState() =>
      _SemiFinalsScoringScreenState();
}

class _SemiFinalsScoringScreenState extends State<SemiFinalsScoringScreen> {
  late Map<String, dynamic> _scores;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scores = Map<String, dynamic>.from(widget.initialScores ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.match.day} - ${widget.matchFormat == '1game' ? '1 Game' : 'Best of 3'}',
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackButton,
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveScores,
              child: Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                    children: [
                      // Games Section
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Game 1 (always shown)
                              _buildGameCard(1),
                              const SizedBox(height: 16),

                              // Game 2 (only show for best of 3)
                              if (widget.matchFormat == 'bestof3') ...[
                                _buildGameCard(2),
                                const SizedBox(height: 16),
                              ],

                              // Game 3 (only show for best of 3)
                              if (widget.matchFormat == 'bestof3') ...[
                                _buildGameCard(3),
                                const SizedBox(height: 24),
                              ],

                              // Winner Display
                              _buildWinnerDisplay(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildGameCard(int gameNumber) {
    final team1Key = '${widget.match.team1Id}_game$gameNumber';
    final team2Key = '${widget.match.team2Id}_game$gameNumber';

    final team1Score = _scores[team1Key] ?? 0;
    final team2Score = _scores[team2Key] ?? 0;

    // For Game 1 and 2, always return the StatefulBuilder
    // For Game 3, calculate disabled state inside StatefulBuilder

    return StatefulBuilder(
      builder: (context, setBuilderState) {
        // Check if there were scores before - to detect when Game 3 goes from enabled to disabled
        bool hadGame3Scores = false;
        if (gameNumber == 3 &&
            widget.match.team1Id != null &&
            widget.match.team2Id != null) {
          final team1Key = '${widget.match.team1Id}_game3';
          final team2Key = '${widget.match.team2Id}_game3';
          hadGame3Scores =
              (_scores[team1Key] ?? 0) > 0 || (_scores[team2Key] ?? 0) > 0;
        }

        // Recalculate Game 3 disabled state inside StatefulBuilder
        bool currentIsGame3Disabled = false;
        if (gameNumber == 3) {
          if (widget.match.team1Id == null || widget.match.team2Id == null) {
            currentIsGame3Disabled = true;
          } else {
            final team1Key = '${widget.match.team1Id}_game';
            final team2Key = '${widget.match.team2Id}_game';

            final game1Team1 = _scores['${team1Key}1'] ?? 0;
            final game1Team2 = _scores['${team2Key}1'] ?? 0;
            final game2Team1 = _scores['${team1Key}2'] ?? 0;
            final game2Team2 = _scores['${team2Key}2'] ?? 0;

            // Get the minimum score required based on match format
            final minScore = widget.matchFormat == '1game' ? 11 : 15;

            bool game1Complete =
                (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) ||
                (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2);
            bool game2Complete =
                (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2) ||
                (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2);

            if (game1Complete && game2Complete) {
              int team1GamesWon = 0;
              int team2GamesWon = 0;

              if (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2)
                team1GamesWon++;
              else if (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2)
                team2GamesWon++;

              if (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2)
                team1GamesWon++;
              else if (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2)
                team2GamesWon++;

              currentIsGame3Disabled = team1GamesWon == 2 || team2GamesWon == 2;
            } else {
              currentIsGame3Disabled = true;
            }

            // Only clear Game 3 scores if it has scores and just became disabled
            if (currentIsGame3Disabled &&
                hadGame3Scores &&
                widget.match.team1Id != null &&
                widget.match.team2Id != null) {
              _scores[team1Key + '3'] = 0;
              _scores[team2Key + '3'] = 0;
              // Trigger rebuild to show cleared scores
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setBuilderState(() {});
              });
            }
          }
        }

        // Use current state for display
        final displayIsDisabled = currentIsGame3Disabled;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: displayIsDisabled ? Colors.grey[100] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Game $gameNumber${displayIsDisabled ? ' (TBD)' : ''}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      displayIsDisabled ? Colors.grey[600] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  // Team 1
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.match.team1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed:
                                  displayIsDisabled || team1Score <= 0
                                      ? null
                                      : () => _updateScore(
                                        team1Key,
                                        team1Score - 1,
                                      ),
                              icon: Icon(Icons.remove_circle_outline),
                              color:
                                  displayIsDisabled || team1Score <= 0
                                      ? Colors.grey[400]
                                      : Colors.red[400],
                            ),
                            Container(
                              width: 60,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Text(
                                  '$team1Score',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  displayIsDisabled || team1Score >= 20
                                      ? null
                                      : () => _updateScore(
                                        team1Key,
                                        team1Score + 1,
                                      ),
                              icon: Icon(Icons.add_circle_outline),
                              color:
                                  displayIsDisabled || team1Score >= 20
                                      ? Colors.grey[400]
                                      : Colors.green[400],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // VS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),

                  // Team 2
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.match.team2,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed:
                                  displayIsDisabled || team2Score <= 0
                                      ? null
                                      : () => _updateScore(
                                        team2Key,
                                        team2Score - 1,
                                      ),
                              icon: Icon(Icons.remove_circle_outline),
                              color:
                                  displayIsDisabled || team2Score <= 0
                                      ? Colors.grey[400]
                                      : Colors.red[400],
                            ),
                            Container(
                              width: 60,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Text(
                                  '$team2Score',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  displayIsDisabled || team2Score >= 20
                                      ? null
                                      : () => _updateScore(
                                        team2Key,
                                        team2Score + 1,
                                      ),
                              icon: Icon(Icons.add_circle_outline),
                              color:
                                  displayIsDisabled || team2Score >= 20
                                      ? Colors.grey[400]
                                      : Colors.green[400],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWinnerDisplay() {
    // Return empty if team IDs are null (TBA placeholders)
    if (widget.match.team1Id == null || widget.match.team2Id == null) {
      return const SizedBox.shrink();
    }

    final team1GamesWon = _getGamesWon(widget.match.team1Id!);
    final team2GamesWon = _getGamesWon(widget.match.team2Id!);

    String? winner;
    if (team1GamesWon >= 2) {
      winner = widget.match.team1;
    } else if (team2GamesWon >= 2) {
      winner = widget.match.team2;
    }

    if (winner == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, color: Colors.yellow[600], size: 24),
          const SizedBox(width: 8),
          Text(
            'Winner: $winner',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  int _getGamesWon(String teamId) {
    int gamesWon = 0;
    final minScore = widget.matchFormat == '1game' ? 11 : 15;

    for (int i = 1; i <= 3; i++) {
      final teamKey = '${teamId}_game$i';
      final opponentKey =
          teamId == widget.match.team1Id
              ? '${widget.match.team2Id}_game$i'
              : '${widget.match.team1Id}_game$i';

      final teamScore = _scores[teamKey] ?? 0;
      final opponentScore = _scores[opponentKey] ?? 0;

      // Win by 2 rule: must reach at least minScore and win by at least 2 points
      // Also handle extended play (11-11, 15-15, 16-16, etc.)
      if (teamScore >= minScore && teamScore >= opponentScore + 2) {
        gamesWon++;
      }
    }
    return gamesWon;
  }

  void _handleBackButton() {
    // Check if any game has incomplete scores (started but not finished)
    bool hasIncompleteScore = false;

    // Get the minimum score required based on match format
    final minScore = widget.matchFormat == '1game' ? 11 : 15;

    for (int i = 1; i <= 3; i++) {
      final team1Key = '${widget.match.team1Id}_game$i';
      final team2Key = '${widget.match.team2Id}_game$i';

      final team1Score = _scores[team1Key] ?? 0;
      final team2Score = _scores[team2Key] ?? 0;

      if (team1Score > 0 || team2Score > 0) {
        // Check if this game has a winner
        bool hasWinner = false;

        if (team1Score >= minScore && team1Score >= team2Score + 2) {
          hasWinner = true;
        } else if (team2Score >= minScore && team2Score >= team1Score + 2) {
          hasWinner = true;
        }

        if (!hasWinner) {
          hasIncompleteScore = true;
          break;
        }
      }
    }

    if (hasIncompleteScore) {
      // Check if there were previously saved scores
      final hasPreviousScores =
          widget.initialScores != null && widget.initialScores!.isNotEmpty;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Incomplete Score'),
            content: Text(
              hasPreviousScores
                  ? 'The changes will not be saved if you continue. Are you sure you want to go back?'
                  : 'The score will be reset if you continue. Are you sure you want to go back?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _updateScore(String key, int newScore) {
    // Get the base winning score based on match format
    final baseWinScore = widget.matchFormat == '1game' ? 11 : 15;
    // If both teams reach the winning score, they need to win by 2
    // So one team can go above to win (e.g., 12-11, 16-15, 17-15, etc.)
    // Set max at base+9 to allow extended play (20 for SF/Finals, 20 for QF best of 3)
    final maxScore = baseWinScore + 9; // Allows for extended play
    _scores[key] = newScore.clamp(0, maxScore);

    // Prevent adding more if already at max
    if (newScore > maxScore) {
      return;
    }

    // Trigger rebuild of the StatefulBuilder
    setState(() {});
  }

  Future<void> _saveScores() async {
    // Check if all scores are 0-0 (allowing reset)
    bool allScoresAreZero = true;
    for (int i = 1; i <= 3; i++) {
      final team1Key = '${widget.match.team1Id}_game$i';
      final team2Key = '${widget.match.team2Id}_game$i';
      final team1Score = _scores[team1Key] ?? 0;
      final team2Score = _scores[team2Key] ?? 0;
      if (team1Score > 0 || team2Score > 0) {
        allScoresAreZero = false;
        break;
      }
    }

    // If all scores are 0, allow saving (reset scenario)
    if (allScoresAreZero) {
      setState(() {
        _isLoading = true;
      });
      try {
        await widget.onScoresUpdated(_scores);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving scores: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    // Get minimum score based on match format
    final minScore = widget.matchFormat == '1game' ? 11 : 15;

    // Validate that each game with scores has a winner
    bool allGamesValid = true;
    for (int i = 1; i <= 3; i++) {
      final team1Key = '${widget.match.team1Id}_game$i';
      final team2Key = '${widget.match.team2Id}_game$i';

      final team1Score = _scores[team1Key] ?? 0;
      final team2Score = _scores[team2Key] ?? 0;

      // If any scores are entered, there must be a winner
      if (team1Score > 0 || team2Score > 0) {
        bool hasWinner = false;

        // Check if team 1 won (at least minScore and win by 2)
        if (team1Score >= minScore && team1Score >= team2Score + 2) {
          hasWinner = true;
        }
        // Check if team 2 won (at least minScore and win by 2)
        else if (team2Score >= minScore && team2Score >= team1Score + 2) {
          hasWinner = true;
        }

        if (!hasWinner) {
          allGamesValid = false;
          break;
        }
      }
    }

    // If not all games are valid, show error
    if (!allGamesValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot save: Each game must have a winner ($minScore points, win by 2)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onScoresUpdated(_scores);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving scores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
