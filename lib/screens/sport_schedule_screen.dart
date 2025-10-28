// ignore_for_file: use_super_parameters, curly_braces_in_flow_control_structures, use_build_context_synchronously, unused_element

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/simple_app_bar.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../services/score_service.dart';
import '../keys/schedule_screen/schedule_screen_keys.dart';
import 'main_navigation_screen.dart';
import 'playoff_scoring_screen.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late TabController _playoffTabController;
  final AuthService _authService = AuthService();
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();
  final ScoreService _scoreService = ScoreService();

  // Division selection state
  String? _selectedDivision;
  String? _previousDivision; // Store previous division for cancel functionality
  List<String> _availableDivisions = [];

  // Cache for stable match generation
  final Map<String, List<Match>> _matchesCache = {};

  // Cache for standings to prevent stack overflow
  List<Standing>? _cachedStandings;
  String? _lastStandingsCacheKey;

  // Scoring state
  Match? _selectedMatch;
  int?
  _selectedGameNumber; // Track which game is selected for preliminary rounds
  DateTime? _lastSelectionTime;
  final Map<String, Map<String, int>> _matchScores =
      {}; // matchId -> {team1Id: score, team2Id: score}

  // Playoffs state
  // Playoff state per division
  final Map<String, bool> _playoffsStartedByDivision = {};
  final Map<String, Map<String, int>> _playoffScores = {};
  bool _justRestartedPlayoffs = false;

  // Match format per tab: '1game' or 'bestof3'
  final Map<String, String> _matchFormats =
      {}; // Key: 'QF', 'SF', 'Finals', Value: '1game' or 'bestof3'

  // Game winning score per tab: '11' or '15'
  final Map<String, int> _gameWinningScores =
      {}; // Key: 'QF', 'SF', 'Finals', Value: 11 or 15

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

  // Games per team in preliminary rounds - division specific
  final Map<String, int> _gamesPerTeamByDivision =
      {}; // division -> games per team
  final Map<String, int> _preliminaryGameWinningScoreByDivision =
      {}; // division -> winning score
  final Map<String, bool> _hasShownGamesPerTeamDialogByDivision =
      {}; // Track dialog per division
  bool _isFirstLoad = true; // Track if this is the first load

  // Helper methods to get division-specific settings
  int get _gamesPerTeam =>
      _gamesPerTeamByDivision[_selectedDivision ?? 'all'] ?? 1;
  int get _preliminaryGameWinningScore =>
      _preliminaryGameWinningScoreByDivision[_selectedDivision ?? 'all'] ?? 11;

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

      // Shuffle teams if requested
      if (shouldShuffle) {
        availableTeams.shuffle();
      }

      // Generate matches ensuring each team plays exactly _gamesPerTeam games with different opponents
      Map<String, List<String>> teamOpponents =
          {}; // Track opponents for each team

      // Initialize opponents tracking
      for (var team in availableTeams) {
        teamOpponents[team.id] = [];
      }

      // For 1 game per team, use a simpler pairing approach
      if (_gamesPerTeam == 1) {
        // Create a copy of teams for pairing
        List<dynamic> teamsToMatch = List.from(availableTeams);

        // Shuffle teams if requested
        if (shouldShuffle) {
          teamsToMatch.shuffle();
        }

        // Pair teams up
        while (teamsToMatch.length >= 2) {
          final team1 = teamsToMatch.removeAt(0);
          final team2 = teamsToMatch.removeAt(0);

          // Create match with division-specific ID
          final divisionMatchId = '${division}_$matchId';
          matches.add(
            Match(
              id: divisionMatchId,
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

          // Track opponents
          teamOpponents[team1.id]!.add(team2.id);
          teamOpponents[team2.id]!.add(team1.id);

          matchId++;
          courtNumber++;
          if (courtNumber > 4) {
            courtNumber = 1;
            timeSlot++;
          }
        }
      } else {
        // For multiple games per team, ensure each team plays against different opponents
        Map<String, int> teamGameCount =
            {}; // Track how many games each team has played

        // Initialize game count for each team
        for (var team in availableTeams) {
          teamGameCount[team.id] = 0;
        }

        // Create matches until all teams have played the required number of games
        bool allTeamsComplete = false;
        int maxAttempts = 1000; // Prevent infinite loops
        int attempts = 0;

        while (!allTeamsComplete && attempts < maxAttempts) {
          attempts++;
          bool matchFound = false;

          // Try to find two teams that haven't played each other and haven't reached their game limit
          for (int i = 0; i < availableTeams.length - 1 && !matchFound; i++) {
            for (int j = i + 1; j < availableTeams.length && !matchFound; j++) {
              final team1 = availableTeams[i];
              final team2 = availableTeams[j];

              // Check if both teams can still play more games and haven't played each other
              if (teamGameCount[team1.id]! < _gamesPerTeam &&
                  teamGameCount[team2.id]! < _gamesPerTeam &&
                  !teamOpponents[team1.id]!.contains(team2.id)) {
                // Create match with division-specific ID
                final divisionMatchId = '${division}_$matchId';
                matches.add(
                  Match(
                    id: divisionMatchId,
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

                // Track opponents and game count
                teamOpponents[team1.id]!.add(team2.id);
                teamOpponents[team2.id]!.add(team1.id);
                teamGameCount[team1.id] = teamGameCount[team1.id]! + 1;
                teamGameCount[team2.id] = teamGameCount[team2.id]! + 1;

                matchId++;
                courtNumber++;
                if (courtNumber > 4) {
                  courtNumber = 1;
                  timeSlot++;
                }

                matchFound = true;
              }
            }
          }

          // Check if all teams have played the required number of games
          allTeamsComplete = teamGameCount.values.every(
            (count) => count >= _gamesPerTeam,
          );

          // If no match was found and not all teams are complete, break to avoid infinite loop
          if (!matchFound && !allTeamsComplete) {
            print(
              'WARNING: Could not create more matches for division $division',
            );
            break;
          }
        }

        // Log if we hit the max attempts limit
        if (attempts >= maxAttempts) {
          print(
            'WARNING: Match generation hit max attempts limit ($maxAttempts) for division $division',
          );
        }
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
  Future<void> _updateDivisions() async {
    List<dynamic> allTeams = [];
    if (widget.sportName.toLowerCase().contains('basketball')) {
      allTeams = _teamService.teams;
    } else if (widget.sportName.toLowerCase().contains('pickleball')) {
      allTeams = _pickleballTeamService.teams;
    }

    Set<String> divisions =
        allTeams.map((team) => team.division as String).toSet();
    _availableDivisions = divisions.toList()..sort();

    // Load saved division preference
    final savedDivision = await _scoreService.loadSelectedDivision(
      widget.sportName,
    );

    // If no division is selected or selected division is not available, use saved division or first one
    if (_selectedDivision == null ||
        !_availableDivisions.contains(_selectedDivision)) {
      if (savedDivision != null &&
          _availableDivisions.contains(savedDivision)) {
        // Use saved division if it's still available
        _selectedDivision = savedDivision;
        print('DEBUG: Restored saved division: $savedDivision');
      } else {
        // Fall back to first available division
        _selectedDivision =
            _availableDivisions.isNotEmpty ? _availableDivisions.first : null;
        print('DEBUG: Using first available division: $_selectedDivision');
      }
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

      // Handle 8-team case where QF doesn't exist
      if (_teams.length == 8) {
        if (playoffSubTabIndex == 0) return 'SF'; // Semi Finals
        if (playoffSubTabIndex == 1) return 'Finals';
      } else {
        // Normal case with QF
        if (playoffSubTabIndex == 0) return 'QF'; // Quarter Finals
        if (playoffSubTabIndex == 1) return 'SF'; // Semi Finals
        if (playoffSubTabIndex == 2) return 'Finals';
      }
    }
    return 'QF'; // Default
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
      // Determine if this is a playoff match based on day property
      final isPlayoffMatch =
          _selectedMatch!.day == 'Quarter Finals' ||
          _selectedMatch!.day == 'Semi Finals' ||
          _selectedMatch!.day == 'Finals';
      final isSemiFinalsMatch = _selectedMatch!.day == 'Semi Finals';

      // For QF matches, always show game settings screen on first entry
      if (_selectedMatch!.day == 'Quarter Finals') {
        final currentTab = _getCurrentTabName();
        final existingFormat = _matchFormats[currentTab];
        final existingScore = _gameWinningScores[currentTab];

        // Check if THIS specific QF match has scores
        final thisMatchScores =
            _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)];
        final hasThisMatchScores =
            thisMatchScores != null &&
            thisMatchScores.values.any((value) => value > 0);

        // Check if ANY QF match has non-zero scores - if yes, settings were already set globally
        bool hasAnyQFScores = false;
        final quarterFinals = _getQuarterFinals();
        for (var qfMatch in quarterFinals) {
          final qfMatchScores = _playoffScores[_getPlayoffMatchKey(qfMatch.id)];
          if (qfMatchScores != null &&
              qfMatchScores.values.any((value) => value > 0)) {
            hasAnyQFScores = true;
            break;
          }
        }

        // If settings are already saved for QF (any QF match has scores) OR this specific match has scores,
        // skip the Game Settings screen
        if (existingFormat != null &&
            existingScore != null &&
            (hasAnyQFScores || hasThisMatchScores)) {
          // Navigate directly to scoring screen with saved settings
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => SemiFinalsScoringScreen(
                    match: _selectedMatch!,
                    initialScores:
                        _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)],
                    matchFormat: existingFormat,
                    gameWinningScore: existingScore,
                    canAdjustSettings:
                        !hasThisMatchScores, // Only allow adjustment if this specific match has no scores yet
                    isFirstCard:
                        !hasAnyQFScores, // This is first card only if no QF scores exist yet
                    onSettingsChange: () {
                      // Show Game Settings screen again to allow changes
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => _QuarterFinalsGameSettingsScreen(
                                initialMatchTotalGames: existingFormat,
                                initialGameWinningScore: existingScore,
                                onSettingsSelected: (
                                  matchTotalGames,
                                  gameWinningScore,
                                ) {
                                  // Update settings
                                  setState(() {
                                    _matchFormats[currentTab] = matchTotalGames;
                                    _gameWinningScores[currentTab] =
                                        gameWinningScore;
                                  });
                                  // Reset scores when settings change
                                  setState(() {
                                    _playoffScores[_getPlayoffMatchKey(
                                          _selectedMatch!.id,
                                        )] =
                                        {};
                                  });
                                  // Navigate to scoring screen with updated settings (empty scores)
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => SemiFinalsScoringScreen(
                                            match: _selectedMatch!,
                                            initialScores: {},
                                            matchFormat: matchTotalGames,
                                            gameWinningScore: gameWinningScore,
                                            canAdjustSettings:
                                                !hasThisMatchScores, // Only allow adjustment if this specific match has no scores yet
                                            isFirstCard:
                                                false, // Not first card - settings already set
                                            onScoresUpdated: (scores) async {
                                              setState(() {
                                                _playoffScores[_getPlayoffMatchKey(
                                                  _selectedMatch!.id,
                                                )] = Map<String, int>.from(
                                                  scores,
                                                );
                                                _selectedMatch = null;
                                                _cachedStandings = null;
                                                _lastStandingsCacheKey = null;
                                              });

                                              try {
                                                await _scoreService
                                                    .savePlayoffScores(
                                                      _playoffScores,
                                                    );
                                                await _scoreService
                                                    .saveQuarterFinalsScoresForDivision(
                                                      _selectedDivision ??
                                                          'all',
                                                      _getCurrentDivisionPlayoffScores(),
                                                    );
                                              } catch (e) {
                                                print(
                                                  'Error saving scores to storage: $e',
                                                );
                                              }
                                            },
                                            onSettingsChange: () async {
                                              // Navigate back
                                              Navigator.pop(context);
                                              // Re-open settings screen
                                              await Future.delayed(
                                                Duration(milliseconds: 100),
                                              );
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        context,
                                                      ) => _QuarterFinalsGameSettingsScreen(
                                                        initialMatchTotalGames:
                                                            matchTotalGames,
                                                        initialGameWinningScore:
                                                            gameWinningScore,
                                                        onSettingsSelected: (
                                                          newMatchTotalGames,
                                                          newGameWinningScore,
                                                        ) {
                                                          // Same logic as above for updating settings
                                                          setState(() {
                                                            _matchFormats[currentTab] =
                                                                newMatchTotalGames;
                                                            _gameWinningScores[currentTab] =
                                                                newGameWinningScore;
                                                          });
                                                          setState(() {
                                                            _playoffScores[_getPlayoffMatchKey(
                                                                  _selectedMatch!
                                                                      .id,
                                                                )] =
                                                                {};
                                                          });
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder:
                                                                  (
                                                                    context,
                                                                  ) => SemiFinalsScoringScreen(
                                                                    match:
                                                                        _selectedMatch!,
                                                                    initialScores:
                                                                        {},
                                                                    matchFormat:
                                                                        newMatchTotalGames,
                                                                    gameWinningScore:
                                                                        newGameWinningScore,
                                                                    canAdjustSettings:
                                                                        !hasThisMatchScores, // Only allow adjustment if this specific match has no scores yet
                                                                    isFirstCard:
                                                                        false, // Not first card
                                                                    onScoresUpdated: (
                                                                      scores,
                                                                    ) async {
                                                                      setState(() {
                                                                        _playoffScores[_getPlayoffMatchKey(
                                                                          _selectedMatch!
                                                                              .id,
                                                                        )] = Map<
                                                                          String,
                                                                          int
                                                                        >.from(
                                                                          scores,
                                                                        );
                                                                        _selectedMatch =
                                                                            null;
                                                                        _cachedStandings =
                                                                            null;
                                                                        _lastStandingsCacheKey =
                                                                            null;
                                                                      });
                                                                      try {
                                                                        await _scoreService.savePlayoffScores(
                                                                          _playoffScores,
                                                                        );
                                                                        await _scoreService.saveQuarterFinalsScoresForDivision(
                                                                          _selectedDivision ??
                                                                              'all',
                                                                          _getCurrentDivisionPlayoffScores(),
                                                                        );
                                                                      } catch (
                                                                        e
                                                                      ) {
                                                                        print(
                                                                          'Error saving scores to storage: $e',
                                                                        );
                                                                      }
                                                                    },
                                                                    onSettingsChange:
                                                                        () {},
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                  );
                                },
                              ),
                        ),
                      );
                    },
                    onScoresUpdated: (scores) async {
                      setState(() {
                        _playoffScores[_getPlayoffMatchKey(
                          _selectedMatch!.id,
                        )] = Map<String, int>.from(scores);
                        _selectedMatch = null;
                        _cachedStandings = null;
                        _lastStandingsCacheKey = null;
                      });

                      try {
                        await _scoreService.savePlayoffScores(_playoffScores);
                        await _scoreService.saveQuarterFinalsScoresForDivision(
                          _selectedDivision ?? 'all',
                          _getCurrentDivisionPlayoffScores(),
                        );
                      } catch (e) {
                        print('Error saving scores to storage: $e');
                      }
                    },
                  ),
            ),
          );
          return;
        }

        // Show Game Settings dialog if settings not already saved
        _showGameSettingsDialog(isFinals: false);
        return;
      }

      // (Old code to be removed - keeping for reference)
      /*Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => _QuarterFinalsGameSettingsScreen(
                  onSettingsSelected: (matchTotalGames, gameWinningScore) {
                    // Save settings for QF
                    setState(() {
                      _matchFormats[currentTab] = matchTotalGames;
                      _gameWinningScores[currentTab] = gameWinningScore;
                    });
                    // Navigate to scoring screen with the selected format
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SemiFinalsScoringScreen(
                              match: _selectedMatch!,
                              initialScores: _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)],
                              matchFormat: matchTotalGames,
                              gameWinningScore: gameWinningScore,
                              onScoresUpdated: (scores) async {
                                setState(() {
                                  _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)] = Map<String, int>.from(scores);
                                  _selectedMatch = null;
                                  _cachedStandings = null;
                                  _lastStandingsCacheKey = null;
                                });

                                try {
                                  await _scoreService.savePlayoffScores(
                                    _playoffScores,
                                  );
                                  await _scoreService.saveQuarterFinalsScoresForDivision(
                                    _selectedDivision ?? 'all',
                                    _getCurrentDivisionPlayoffScores(),
                                  );
                                } catch (e) {
                                  print('Error saving scores to storage: $e');
                                }
                              },
                              onSettingsChange: () {
                                // Show Game Settings screen again to allow changes
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (
                                          context,
                                        ) => _QuarterFinalsGameSettingsScreen(
                                          initialMatchTotalGames:
                                              matchTotalGames,
                                          initialGameWinningScore:
                                              gameWinningScore,
                                          onSettingsSelected: (
                                            newMatchTotalGames,
                                            newGameWinningScore,
                                          ) {
                                            // Update settings
                                            setState(() {
                                              _matchFormats[currentTab] =
                                                  newMatchTotalGames;
                                              _gameWinningScores[currentTab] =
                                                  newGameWinningScore;
                                            });
                                            // Reset scores when settings change
                                            setState(() {
                                                      _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)] = {};
                                            });
                                            // Navigate to scoring screen with updated settings (empty scores)
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => SemiFinalsScoringScreen(
                                                      match: _selectedMatch!,
                                                      initialScores: {},
                                                      matchFormat:
                                                          newMatchTotalGames,
                                                      gameWinningScore:
                                                          newGameWinningScore,
                                                      onScoresUpdated: (
                                                        scores,
                                                      ) async {
                                                        setState(() {
                          _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)] = Map<String,
                                                            int
                                                          >.from(scores);
                                                          _selectedMatch = null;
                                                          _cachedStandings =
                                                              null;
                                                          _lastStandingsCacheKey =
                                                              null;
                                                        });

                                                        try {
                                                          await _scoreService
                                                              .savePlayoffScores(
                                                                _playoffScores,
                                                              );
                                                          await _scoreService
                                                              .saveQuarterFinalsScoresForDivision(
                                                      _selectedDivision ?? 'all',
                                                      _getCurrentDivisionPlayoffScores(),
                                                              );
                                                        } catch (e) {
                                                          print(
                                                            'Error saving scores to storage: $e',
                                                          );
                                                        }
                                                      },
                                                      onSettingsChange: () {
                                                        // Just pop once - the parent's onSettingsChange will handle re-opening
                                                        Navigator.pop(context);
                                                      },
                                                      canAdjustSettings: true, // Allow adjustment before scoring starts
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                  ),
                                );
                              },
                            ),
                      ),
                    );
                  },
                ),
          ),
        );*/

      // Only restrict editing for QF matches if later rounds have started
      // SF and Finals should always be able to score once playoffs have started
      if (_playoffsStarted &&
          isPlayoffMatch &&
          _selectedMatch!.day == 'Quarter Finals') {
        // Check if SF or Finals have any scores - if yes, QF editing is restricted
        bool hasLaterRoundScores = false;
        for (var entry in _playoffScores.entries) {
          final scores = entry.value;
          if (scores.values.any((value) => value > 0)) {
            // Check if this match ID belongs to SF or Finals
            try {
              final semiFinals = _getSemiFinalsDirect();
              final finals = _getFinalsDirect();
              if (semiFinals.any((m) => m.id == entry.key) ||
                  finals.any((m) => m.id == entry.key)) {
                hasLaterRoundScores = true;
                break;
              }
            } catch (e) {
              // If we can't determine, allow editing
              print('Error checking match type: $e');
            }
          }
        }

        // If later rounds have scores, restrict QF editing
        if (hasLaterRoundScores) {
          _showPlayoffScoreEditRestrictionDialog();
          return;
        }
      }

      // Get the match format for this tab
      final currentTab = _getCurrentTabName();
      final matchFormat = _matchFormats[currentTab] ?? 'bestof3';

      // For SF and Finals, check if settings are already saved
      if ((isSemiFinalsMatch || _selectedMatch!.day == 'Finals') &&
          _selectedMatch!.day != 'Quarter Finals') {
        final existingFormat = _matchFormats[currentTab];
        final existingScore = _gameWinningScores[currentTab];

        // Check if ANY match in this round has non-zero scores
        bool hasAnyRoundScores = false;
        final roundMatches =
            _selectedMatch!.day == 'Semi Finals'
                ? _getSemiFinalsDirect()
                : _getFinalsDirect();
        for (var match in roundMatches) {
          final matchScores = _playoffScores[_getPlayoffMatchKey(match.id)];
          if (matchScores != null &&
              matchScores.values.any((value) => value > 0)) {
            hasAnyRoundScores = true;
            break;
          }
        }

        // Check if THIS specific match has scores
        final thisMatchScores =
            _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)];
        final hasThisMatchScores =
            thisMatchScores != null &&
            thisMatchScores.values.any((value) => value > 0);

        // If settings are already saved for this round OR this specific match has scores, skip the Game Settings screen
        if ((existingFormat != null &&
                existingScore != null &&
                hasAnyRoundScores) ||
            hasThisMatchScores) {
          // Navigate directly to scoring screen with saved settings
          // Use defaults if settings are missing but scores exist
          final formatToUse = existingFormat ?? 'bestof3';
          final scoreToUse = existingScore ?? 15;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => SemiFinalsScoringScreen(
                    match: _selectedMatch!,
                    initialScores:
                        _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)],
                    matchFormat: formatToUse,
                    gameWinningScore: scoreToUse,
                    canAdjustSettings: false, // Disable after first scoring
                    isFirstCard:
                        !hasAnyRoundScores, // First card only if no scores exist yet
                    onScoresUpdated: (scores) async {
                      // Store the match day before clearing _selectedMatch
                      final matchDay = _selectedMatch!.day;

                      setState(() {
                        _playoffScores[_getPlayoffMatchKey(
                          _selectedMatch!.id,
                        )] = Map<String, int>.from(scores);
                        _selectedMatch = null;
                        _cachedStandings = null;
                        _lastStandingsCacheKey = null;
                      });

                      try {
                        await _scoreService.savePlayoffScores(_playoffScores);
                        if (matchDay == 'Quarter Finals') {
                          await _scoreService
                              .saveQuarterFinalsScoresForDivision(
                                _selectedDivision ?? 'all',
                                _getCurrentDivisionPlayoffScores(),
                              );
                        } else if (matchDay == 'Semi Finals') {
                          await _scoreService.saveSemiFinalsScoresForDivision(
                            _selectedDivision ?? 'all',
                            _getCurrentDivisionPlayoffScores(),
                          );
                        } else if (matchDay == 'Finals') {
                          await _scoreService.saveFinalsScoresForDivision(
                            _selectedDivision ?? 'all',
                            _getCurrentDivisionPlayoffScores(),
                          );
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

        // Show Game Settings dialog if settings not already saved
        _showGameSettingsDialog(isFinals: _selectedMatch!.day == 'Finals');
        return;
      }

      // For QF matches, always use the SemiFinals scoring screen which adapts to format
      if (_selectedMatch!.day == 'Quarter Finals') {
        // Check if THIS specific QF match has scores
        final thisMatchScores =
            _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)];
        final hasThisMatchScores =
            thisMatchScores != null &&
            thisMatchScores.values.any((value) => value > 0);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SemiFinalsScoringScreen(
                  match: _selectedMatch!,
                  initialScores:
                      _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)],
                  matchFormat: matchFormat,
                  gameWinningScore: _gameWinningScores[currentTab] ?? 11,
                  canAdjustSettings:
                      _selectedMatch!.day == 'Quarter Finals' &&
                      !hasThisMatchScores,
                  onSettingsChange:
                      _selectedMatch!.day == 'Quarter Finals' &&
                              !hasThisMatchScores
                          ? () {}
                          : null,
                  onScoresUpdated: (scores) async {
                    // Check if this is Finals and if there's a winner
                    if (_selectedMatch!.day == 'Finals') {
                      // Calculate winner
                      final team1GamesWon = _getGamesWonFromScores(
                        scores,
                        _selectedMatch!.team1Id!,
                      );
                      final team2GamesWon = _getGamesWonFromScores(
                        scores,
                        _selectedMatch!.team2Id!,
                      );
                      String? winnerName;
                      if (team1GamesWon >= 2) {
                        winnerName = _selectedMatch!.team1;
                      } else if (team2GamesWon >= 2) {
                        winnerName = _selectedMatch!.team2;
                      }

                      // If there's a winner, show confirmation dialog
                      if (winnerName != null) {
                        final shouldSave = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirm Winner'),
                              content: Text(
                                'Are you sure the winner of the tournament is $winnerName?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: const Text('Confirm'),
                                ),
                              ],
                            );
                          },
                        );

                        if (shouldSave != true) {
                          return; // User cancelled
                        }
                      }
                    }

                    // Store the match day before clearing _selectedMatch
                    final matchDay = _selectedMatch!.day;

                    setState(() {
                      _playoffScores[_getPlayoffMatchKey(
                        _selectedMatch!.id,
                      )] = Map<String, int>.from(scores);
                      // Clear selection after saving scores
                      _selectedMatch = null;
                      // Clear standings cache to force recalculation
                      _cachedStandings = null;
                      _lastStandingsCacheKey = null;
                    });

                    // Save scores to persistent storage
                    try {
                      await _scoreService.savePlayoffScores(_playoffScores);

                      // Also save to specific playoff round storage for current division
                      if (matchDay == 'Quarter Finals') {
                        await _scoreService.saveQuarterFinalsScoresForDivision(
                          _selectedDivision ?? 'all',
                          _getCurrentDivisionPlayoffScores(),
                        );
                      } else if (matchDay == 'Semi Finals') {
                        await _scoreService.saveSemiFinalsScoresForDivision(
                          _selectedDivision ?? 'all',
                          _getCurrentDivisionPlayoffScores(),
                        );
                      } else if (matchDay == 'Finals') {
                        await _scoreService.saveFinalsScoresForDivision(
                          _selectedDivision ?? 'all',
                          _getCurrentDivisionPlayoffScores(),
                        );
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

      // Navigate to semi-finals scoring screen with 1 game format for preliminary matches
      // Convert preliminary scores from team-level to game-level format
      Map<String, dynamic>? initialScoresToPass;
      if (isPlayoffMatch) {
        initialScoresToPass =
            _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)];
      } else {
        // Convert team-level scores to game-level format for preliminary matches
        final teamScores = _matchScores[_selectedMatch!.id];
        if (teamScores != null && teamScores.isNotEmpty) {
          initialScoresToPass = {};
          teamScores.forEach((teamId, score) {
            initialScoresToPass!['${teamId}_game1'] = score;
          });
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SemiFinalsScoringScreen(
                match: _selectedMatch!,
                initialScores: initialScoresToPass,
                matchFormat: '1game', // Each game is treated as 1 game
                gameWinningScore: _preliminaryGameWinningScore,
                canAdjustSettings:
                    false, // Don't allow adjusting settings for preliminaries
                selectedGameNumber:
                    _selectedGameNumber, // Pass the selected game number
                onScoresUpdated: (scores) async {
                  // Save to memory first
                  print('DEBUG: ===== SAVING SCORES =====');
                  print('DEBUG: Match ID: ${_selectedMatch!.id}');
                  print('DEBUG: Match team1Id: ${_selectedMatch!.team1Id}');
                  print('DEBUG: Match team2Id: ${_selectedMatch!.team2Id}');
                  print('DEBUG: Scores being saved: $scores');
                  print('DEBUG: Scores keys: ${scores.keys.toList()}');

                  setState(() {
                    if (isPlayoffMatch) {
                      _playoffScores[_getPlayoffMatchKey(
                        _selectedMatch!.id,
                      )] = Map<String, int>.from(scores);
                    } else {
                      _matchScores[_selectedMatch!.id] = Map<String, int>.from(
                        scores,
                      );
                    }
                    // Clear standings cache to force recalculation
                    _cachedStandings = null;
                    _lastStandingsCacheKey = null;
                  });

                  print('DEBUG: After save, checking _matchScores');
                  print(
                    'DEBUG: _matchScores keys: ${_matchScores.keys.toList()}',
                  );
                  print(
                    'DEBUG: _matchScores[${_selectedMatch!.id}]: ${_matchScores[_selectedMatch!.id]}',
                  );

                  // Save scores to persistent storage
                  try {
                    if (isPlayoffMatch) {
                      await _scoreService.savePlayoffScores(_playoffScores);

                      // Also save to specific playoff round storage for QF
                      if (_selectedMatch!.day == 'Quarter Finals') {
                        await _scoreService.saveQuarterFinalsScoresForDivision(
                          _selectedDivision ?? 'all',
                          _getCurrentDivisionPlayoffScores(),
                        );
                      }
                    } else {
                      await _scoreService.savePreliminaryScoresForDivision(
                        _selectedDivision ?? 'all',
                        _getCurrentDivisionScores(),
                      );
                    }
                  } catch (e) {
                    print('Error saving scores to storage: $e');
                  }

                  // Clear selection and cache after saving
                  if (mounted) {
                    setState(() {
                      _selectedMatch = null;
                      // Clear standings cache to force recalculation
                      _cachedStandings = null;
                      _lastStandingsCacheKey = null;
                      // Don't clear matches cache as it interferes with score persistence
                    });
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
        // Try team-level format first (teamId: score)
        var score = preliminaryScores[teamId] ?? 0;

        // If not found, try game-level format (teamId_game1: score)
        if (score == 0 && preliminaryScores.containsKey('${teamId}_game1')) {
          score = preliminaryScores['${teamId}_game1'] ?? 0;
        }

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
    print('DEBUG: _getWinningTeamId called for matchId: $matchId');
    // Check if this is a playoff match ID (very high numbers)
    final matchIdNum = int.tryParse(matchId) ?? 0;
    final isPlayoffMatch =
        matchIdNum >= 1000000; // Playoff matches start at 1 million

    print('DEBUG: isPlayoffMatch: $isPlayoffMatch');

    if (isPlayoffMatch) {
      // For playoff matches, check playoff scores first
      final playoffScores = _playoffScores[matchId];
      print(
        'DEBUG: _getWinningTeamId playoffScores for match $matchId: $playoffScores',
      );
      print('DEBUG: _playoffScores keys: ${_playoffScores.keys.toList()}');

      if (playoffScores != null && playoffScores.isNotEmpty) {
        // Look for team-level scores (wins) first
        final teamIds = <String>[];
        for (final key in playoffScores.keys) {
          if (!key.contains('_game')) {
            teamIds.add(key);
          }
        }

        print('DEBUG: _getWinningTeamId playoff teamIds: $teamIds');

        if (teamIds.length >= 2) {
          final team1Id = teamIds[0];
          final team2Id = teamIds[1];
          final team1Wins = playoffScores[team1Id] ?? 0;
          final team2Wins = playoffScores[team2Id] ?? 0;

          print(
            'DEBUG: _getWinningTeamId playoff: team1Id=$team1Id, wins=$team1Wins',
          );
          print(
            'DEBUG: _getWinningTeamId playoff: team2Id=$team2Id, wins=$team2Wins',
          );

          if (team1Wins > team2Wins) {
            print('DEBUG: _getWinningTeamId playoff - Winner is $team1Id');
            return team1Id;
          }
          if (team2Wins > team1Wins) {
            print('DEBUG: _getWinningTeamId playoff - Winner is $team2Id');
            return team2Id;
          }
          print('DEBUG: _getWinningTeamId playoff - Tie');
          return null; // Tie
        }
      } else {
        print(
          'DEBUG: _getWinningTeamId playoff - No scores found or empty map',
        );
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

      if (preliminaryScores != null && preliminaryScores.isNotEmpty) {
        // Scores from SemiFinalsScoringScreen are already in team-level format (teamId: score)
        // after being converted by _convertScoresForPreliminaries

        final teamIds = preliminaryScores.keys.toList();

        if (teamIds.length >= 2) {
          final team1Id = teamIds[0];
          final team2Id = teamIds[1];
          final team1Score = preliminaryScores[team1Id] ?? 0;
          final team2Score = preliminaryScores[team2Id] ?? 0;

          print(
            'DEBUG: _getWinningTeamId for match $matchId: team1Id=$team1Id (score=$team1Score), team2Id=$team2Id (score=$team2Score)',
          );

          if (team1Score > team2Score) {
            print('DEBUG: _getWinningTeamId - Winner is $team1Id');
            return team1Id;
          }
          if (team2Score > team1Score) {
            print('DEBUG: _getWinningTeamId - Winner is $team2Id');
            return team2Id;
          }
          print('DEBUG: _getWinningTeamId - Tie');
          return null; // Tie
        }
      }

      if (preliminaryScores == null) {
        print('DEBUG: _getWinningTeamId - No scores found for match $matchId');
      } else if (preliminaryScores.isEmpty) {
        print(
          'DEBUG: _getWinningTeamId - Scores map is empty for match $matchId',
        );
      } else if (preliminaryScores.keys.length < 2) {
        print(
          'DEBUG: _getWinningTeamId - Only ${preliminaryScores.keys.length} team(s) in scores for match $matchId',
        );
      }
    }

    return null;
  }

  // Get scores for current division only
  Map<String, Map<String, int>> _getCurrentDivisionScores() {
    final currentDivision = _selectedDivision ?? 'all';
    final divisionScores = <String, Map<String, int>>{};

    for (var entry in _matchScores.entries) {
      // Only include scores for matches that belong to the current division
      if (entry.key.startsWith('${currentDivision}_') ||
          (currentDivision == 'all' && !entry.key.contains('_'))) {
        divisionScores[entry.key] = entry.value;
      }
    }

    return divisionScores;
  }

  // Get winning team ID for a specific game in preliminary rounds
  String? _getWinningTeamIdForGame(String matchId, int gameNumber) {
    final scores = _matchScores[matchId];
    if (scores == null || scores.isEmpty) return null;

    // Look for game-specific scores using teamId_gameNumber format
    String? team1Id;
    String? team2Id;
    int? team1Score;
    int? team2Score;

    // Find team IDs from the match
    for (var entry in scores.entries) {
      if (entry.key.endsWith('_game$gameNumber')) {
        final teamId = entry.key.replaceAll('_game$gameNumber', '');
        if (team1Id == null) {
          team1Id = teamId;
          team1Score = entry.value;
        } else {
          team2Id = teamId;
          team2Score = entry.value;
        }
      }
    }

    if (team1Id != null &&
        team2Id != null &&
        team1Score != null &&
        team2Score != null) {
      if (team1Score > team2Score) {
        return team1Id;
      } else if (team2Score > team1Score) {
        return team2Id;
      }
    }

    return null;
  }

  // Get playoff scores for current division only
  Map<String, Map<String, int>> _getCurrentDivisionPlayoffScores() {
    final currentDivision = _selectedDivision ?? 'all';
    final divisionScores = <String, Map<String, int>>{};

    for (var entry in _playoffScores.entries) {
      // Only include scores for matches that belong to the current division
      if (entry.key.startsWith('${currentDivision}_') ||
          (currentDivision == 'all' && !entry.key.contains('_'))) {
        divisionScores[entry.key] = entry.value;
      }
    }

    return divisionScores;
  }

  // Helper method to create division-specific key for playoff matches
  String _getPlayoffMatchKey(String matchId) {
    final currentDivision = _selectedDivision ?? 'all';
    return '${currentDivision}_$matchId';
  }

  // Check if any Quarter Finals scores have been entered
  bool get _hasQuarterFinalsScores {
    final quarterFinals = _getQuarterFinals();
    print(
      'DEBUG: _hasQuarterFinalsScores - Checking ${quarterFinals.length} QF matches',
    );

    for (var match in quarterFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        // Check for game-specific scores (since QF can have multiple games)
        final game1Team1Score = _getGameScore(match.id, match.team1Id!, 1);
        final game1Team2Score = _getGameScore(match.id, match.team2Id!, 1);
        final game2Team1Score = _getGameScore(match.id, match.team1Id!, 2);
        final game2Team2Score = _getGameScore(match.id, match.team2Id!, 2);
        final game3Team1Score = _getGameScore(match.id, match.team1Id!, 3);
        final game3Team2Score = _getGameScore(match.id, match.team2Id!, 3);

        print(
          'DEBUG: _hasQuarterFinalsScores - Match ${match.id}: game1Team1=$game1Team1Score, game1Team2=$game1Team2Score, game2Team1=$game2Team1Score, game2Team2=$game2Team2Score, game3Team1=$game3Team1Score, game3Team2=$game3Team2Score',
        );

        if (game1Team1Score != null && game1Team1Score > 0 ||
            game1Team2Score != null && game1Team2Score > 0 ||
            game2Team1Score != null && game2Team1Score > 0 ||
            game2Team2Score != null && game2Team2Score > 0 ||
            game3Team1Score != null && game3Team1Score > 0 ||
            game3Team2Score != null && game3Team2Score > 0) {
          print(
            'DEBUG: _hasQuarterFinalsScores - Found QF scores for match ${match.id}, returning true',
          );
          return true; // Found at least one QF score
        }
      }
    }
    print(
      'DEBUG: _hasQuarterFinalsScores - No QF scores found, returning false',
    );
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
    print(
      'DEBUG: _allQuarterFinalsScoresSet - quarterFinals.length: ${quarterFinals.length}',
    );
    if (quarterFinals.isEmpty) return false;

    for (var match in quarterFinals) {
      print(
        'DEBUG: Checking match ${match.id}: ${match.team1} vs ${match.team2}',
      );
      if (match.team1Id != null && match.team2Id != null) {
        // Get the format for QF
        final format = _matchFormats['QF'] ?? '1game';
        bool hasWinner = false;

        if (format == '1game') {
          // For 1 game format, check game 1 score
          final team1Game1Score =
              _getGameScore(match.id, match.team1Id!, 1) ?? 0;
          final team2Game1Score =
              _getGameScore(match.id, match.team2Id!, 1) ?? 0;

          // Check if a team has won (reached winning score and wins by 2)
          final winningScore = _gameWinningScores['QF'] ?? 11;
          print(
            'DEBUG: 1game format - team1Game1Score: $team1Game1Score, team2Game1Score: $team2Game1Score, winningScore: $winningScore',
          );
          if (team1Game1Score >= winningScore &&
              team1Game1Score >= team2Game1Score + 2) {
            hasWinner = true;
            print('DEBUG: Team 1 won');
          } else if (team2Game1Score >= winningScore &&
              team2Game1Score >= team1Game1Score + 2) {
            hasWinner = true;
            print('DEBUG: Team 2 won');
          }
        } else {
          // For best of 3 format, check if one team has won 2 games
          final team1GamesWon = _getGamesWon(match.id, match.team1Id!);
          final team2GamesWon = _getGamesWon(match.id, match.team2Id!);
          print(
            'DEBUG: bestof3 format - team1GamesWon: $team1GamesWon, team2GamesWon: $team2GamesWon',
          );

          if (team1GamesWon >= 2 || team2GamesWon >= 2) {
            hasWinner = true;
            print('DEBUG: Match has winner');
          }
        }

        if (!hasWinner) {
          print('DEBUG: Match ${match.id} has no winner yet');
          return false; // Found a match without a winner
        }
      }
    }
    print('DEBUG: All Quarter Finals matches have winners');
    return true; // All matches have winners
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
    // Check if there are fewer than 8 teams
    if (_teams.length < 8) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Insufficient Teams'),
            content: Text(
              'Not enough teams registered. Need 8 teams to start games. Currently have ${_teams.length} teams.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Check if there are exactly 8 teams
    if (_teams.length == 8) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('8 Teams Required'),
            content: const Text(
              '8 teams are required to start the games. Please ensure you have exactly 8 teams registered for this sport.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Go to Playoffs'),
          content: const Text(
            'Are you sure you want to go to the playoffs? This will begin the elimination rounds based on current standings.',
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
              child: const Text('Go to Playoffs'),
            ),
          ],
        );
      },
    );
  }

  // Show Game Settings Dialog
  void _showGameSettingsDialog({bool isFinals = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedFormat = '1game';
        int selectedScore = 11;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Game Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Match Format
                  Text(
                    'Match Total Games:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => setDialogState(
                                () => selectedFormat = '1game',
                              ),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedFormat == '1game'
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '1 Game',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => setDialogState(
                                () => selectedFormat = 'bestof3',
                              ),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedFormat == 'bestof3'
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Best of 3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Game Winning Score
                  Text(
                    'Game Winning Score:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedScore = 11),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedScore == 11
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '11 Points',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedScore = 15),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedScore == 15
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '15 Points',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Info tooltip - hide for Finals
                  if (!isFinals) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'These settings apply to all games in this round.',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final currentTab = _getCurrentTabName();
                    setState(() {
                      _matchFormats[currentTab] = selectedFormat;
                      _gameWinningScores[currentTab] = selectedScore;
                    });
                    Navigator.of(context).pop();
                    // Navigate to scoring screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SemiFinalsScoringScreen(
                              match: _selectedMatch!,
                              initialScores:
                                  _playoffScores[_getPlayoffMatchKey(
                                    _selectedMatch!.id,
                                  )],
                              matchFormat: selectedFormat,
                              gameWinningScore: selectedScore,
                              isFirstCard:
                                  true, // First time showing settings dialog
                              onScoresUpdated: (scores) async {
                                setState(() {
                                  _playoffScores[_getPlayoffMatchKey(
                                    _selectedMatch!.id,
                                  )] = Map<String, int>.from(scores);
                                  _selectedMatch = null;
                                  _cachedStandings = null;
                                  _lastStandingsCacheKey = null;
                                });
                                try {
                                  await _scoreService.savePlayoffScores(
                                    _playoffScores,
                                  );
                                  // Save to appropriate round storage
                                  if (_selectedMatch!.day == 'Quarter Finals') {
                                    await _scoreService
                                        .saveQuarterFinalsScoresForDivision(
                                          _selectedDivision ?? 'all',
                                          _getCurrentDivisionPlayoffScores(),
                                        );
                                  } else if (_selectedMatch!.day ==
                                      'Semi Finals') {
                                    await _scoreService
                                        .saveSemiFinalsScoresForDivision(
                                          _selectedDivision ?? 'all',
                                          _getCurrentDivisionPlayoffScores(),
                                        );
                                  } else if (_selectedMatch!.day == 'Finals') {
                                    await _scoreService
                                        .saveFinalsScoresForDivision(
                                          _selectedDivision ?? 'all',
                                          _getCurrentDivisionPlayoffScores(),
                                        );
                                  }
                                } catch (e) {
                                  print('Error saving scores to storage: $e');
                                }
                              },
                              onSettingsChange: () {
                                // Show settings dialog with current values
                                Navigator.pop(context);
                                Future.delayed(Duration(milliseconds: 100), () {
                                  _showGameSettingsDialogWithValues(
                                    selectedFormat,
                                    selectedScore,
                                  );
                                });
                              },
                              canAdjustSettings:
                                  false, // Disable after first QF scoring
                              onBackPressed: () {
                                // Reset settings when back is pressed to allow re-entry
                                final currentTab = _getCurrentTabName();
                                _matchFormats.remove(currentTab);
                                _gameWinningScores.remove(currentTab);
                                _playoffScores[_getPlayoffMatchKey(
                                      _selectedMatch!.id,
                                    )] =
                                    {};
                              },
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Start Scoring'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGamesPerTeamDialog({
    bool isFirstLoad = false,
    int currentTabIndex = 0,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // Don't allow dismissing by tapping outside
      builder: (BuildContext context) {
        int selectedGames = _gamesPerTeam;
        int selectedScore = _preliminaryGameWinningScore;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Preliminary Rounds Settings'),
              contentPadding: EdgeInsets.fromLTRB(20, 16, 20, 16),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'How many games should each team play?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () => setDialogState(() => selectedGames = 1),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    selectedGames == 1
                                        ? Color(0xFF2196F3)
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '1 Game',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () => setDialogState(() => selectedGames = 2),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    selectedGames == 2
                                        ? Color(0xFF2196F3)
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '2 Games',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () => setDialogState(() => selectedGames = 3),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    selectedGames == 3
                                        ? Color(0xFF2196F3)
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '3 Games',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Game Winning Score:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () => setDialogState(() => selectedScore = 11),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    selectedScore == 11
                                        ? Color(0xFF2196F3)
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '11 Points',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () => setDialogState(() => selectedScore = 15),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    selectedScore == 15
                                        ? Color(0xFF2196F3)
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '15 Points',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (isFirstLoad) {
                      // On first load, navigate back to Schedule screen
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  MainNavigationScreen(initialIndex: 3),
                        ),
                      );
                    } else {
                      // Just close the dialog without changing anything
                      // Don't revert division or clear cache to prevent teams from moving
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Check if settings have changed from their current values
                    final gamesChanged = selectedGames != _gamesPerTeam;
                    final scoreChanged =
                        selectedScore != _preliminaryGameWinningScore;

                    // Only show reset dialog if settings are actually being changed
                    // and this is not the first time setting them up
                    if ((gamesChanged || scoreChanged) && !isFirstLoad) {
                      // Show confirmation dialog for resetting scores
                      Navigator.of(context).pop(); // Close settings dialog
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Reset All Games?'),
                            content: Text(
                              'Changing the settings will reset all game scores, even if games have started. This action cannot be undone. Do you want to continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  // Clear all scores for current division
                                  final currentDivision =
                                      _selectedDivision ?? 'all';
                                  _matchScores.removeWhere(
                                    (key, value) =>
                                        key.startsWith('${currentDivision}_') ||
                                        (currentDivision == 'all' &&
                                            !key.contains('_')),
                                  );

                                  // Update settings for current division
                                  setState(() {
                                    _gamesPerTeamByDivision[_selectedDivision ??
                                            'all'] =
                                        selectedGames;
                                    _preliminaryGameWinningScoreByDivision[_selectedDivision ??
                                            'all'] =
                                        selectedScore;
                                    _matchesCache.clear();
                                    _reshuffledMatches = null;
                                  });

                                  // Save the settings for current division
                                  await _scoreService
                                      .savePreliminarySettingsForDivision(
                                        _selectedDivision ?? 'all',
                                        selectedGames,
                                        selectedScore,
                                      );

                                  // Save the cleared scores
                                  _scoreService
                                      .savePreliminaryScoresForDivision(
                                        currentDivision,
                                        _getCurrentDivisionScores(),
                                      );

                                  Navigator.of(
                                    context,
                                  ).pop(); // Close confirmation dialog
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Reset All Scores'),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      // First time setup or no changes - just update settings for current division
                      setState(() {
                        _gamesPerTeamByDivision[_selectedDivision ?? 'all'] =
                            selectedGames;
                        _preliminaryGameWinningScoreByDivision[_selectedDivision ??
                                'all'] =
                            selectedScore;
                        _matchesCache.clear();
                        _reshuffledMatches = null;
                      });

                      // Save the settings for current division
                      await _scoreService.savePreliminarySettingsForDivision(
                        _selectedDivision ?? 'all',
                        selectedGames,
                        selectedScore,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('Confirm', style: TextStyle(fontSize: 14)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show Game Settings Dialog with initial values (for editing)
  void _showGameSettingsDialogWithValues(
    String currentFormat,
    int currentScore,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedFormat = currentFormat;
        int selectedScore = currentScore;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Adjust Match Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Match Format
                  Text(
                    'Match Total Games:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => setDialogState(
                                () => selectedFormat = '1game',
                              ),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedFormat == '1game'
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '1 Game',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => setDialogState(
                                () => selectedFormat = 'bestof3',
                              ),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedFormat == 'bestof3'
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Best of 3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Game Winning Score
                  Text(
                    'Game Winning Score:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedScore = 11),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedScore == 11
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '11 Points',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedScore = 15),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  selectedScore == 15
                                      ? Color(0xFF2196F3)
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '15 Points',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Info tooltip
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Changing settings will reset all scores.',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final currentTab = _getCurrentTabName();
                    setState(() {
                      _matchFormats[currentTab] = selectedFormat;
                      _gameWinningScores[currentTab] = selectedScore;
                      // Reset scores
                      _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)] =
                          {};
                    });
                    Navigator.of(context).pop();
                    // Navigate to scoring screen with empty scores
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SemiFinalsScoringScreen(
                              match: _selectedMatch!,
                              initialScores: {},
                              matchFormat: selectedFormat,
                              gameWinningScore: selectedScore,
                              onScoresUpdated: (scores) async {
                                setState(() {
                                  _playoffScores[_getPlayoffMatchKey(
                                    _selectedMatch!.id,
                                  )] = Map<String, int>.from(scores);
                                  _selectedMatch = null;
                                  _cachedStandings = null;
                                  _lastStandingsCacheKey = null;
                                });
                                try {
                                  await _scoreService.savePlayoffScores(
                                    _playoffScores,
                                  );
                                  await _scoreService
                                      .saveQuarterFinalsScoresForDivision(
                                        _selectedDivision ?? 'all',
                                        _getCurrentDivisionPlayoffScores(),
                                      );
                                } catch (e) {
                                  print('Error saving scores to storage: $e');
                                }
                              },
                              onSettingsChange: () {
                                // Show settings dialog again with current values
                                Navigator.pop(context);
                                Future.delayed(Duration(milliseconds: 100), () {
                                  _showGameSettingsDialogWithValues(
                                    selectedFormat,
                                    selectedScore,
                                  );
                                });
                              },
                              canAdjustSettings:
                                  false, // Disable since this specific QF match already has scores
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Update Settings'),
                ),
              ],
            );
          },
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
                await _scoreService.savePreliminaryScoresForDivision(
                  _selectedDivision ?? 'all',
                  _getCurrentDivisionScores(),
                );

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

    // Filter teams by current division
    final currentDivision = _selectedDivision ?? 'all';
    final filteredTeams =
        teams.where((team) {
          if (currentDivision == 'all') return true;
          // For basketball teams, check division
          if (team is Team) {
            return team.division == currentDivision;
          }
          // For pickleball teams, check DUPR rating
          if (team is PickleballTeam) {
            return team.division == currentDivision;
          }
          return false;
        }).toList();

    if (filteredTeams.isEmpty) return [];

    // Create cache key based on teams, match scores, and current division
    final teamsKey = filteredTeams.map((t) => t.id).join('_');
    // Only include scores for the current division in the cache key
    final divisionScores = _getCurrentDivisionScores();
    final scoresKey = divisionScores.keys.join('_');
    final cacheKey = '${teamsKey}_${currentDivision}_$scoresKey';

    // Return cached standings if available and still valid
    if (_cachedStandings != null && _lastStandingsCacheKey == cacheKey) {
      return _cachedStandings!;
    }

    // Calculate actual stats based on match scores
    Map<String, Map<String, int>> teamStats = {};

    // Initialize team stats
    for (var team in filteredTeams) {
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
      // Only process matches for the current division
      if (!match.id.startsWith('${currentDivision}_') &&
          !(currentDivision == 'all' && !match.id.contains('_'))) {
        continue;
      }

      // Skip "TBA" matches
      if (match.team2 == 'TBA') continue;

      // Only count matches that have actual scores entered
      if (match.team1Id != null && match.team2Id != null) {
        final scores = _matchScores[match.id];
        if (scores != null && scores.isNotEmpty) {
          // Extract team-level scores from game-level format
          final teamLevelScores = <String, int>{};
          scores.forEach((key, value) {
            // Handle both team-level format (teamId: score) and game-level format (teamId_game1: score)
            if (key.endsWith('_game1')) {
              final teamId = key.replaceAll('_game1', '');
              teamLevelScores[teamId] = value;
            } else {
              teamLevelScores[key] = value;
            }
          });

          final team1Score = teamLevelScores[match.team1Id!] ?? 0;
          final team2Score = teamLevelScores[match.team2Id!] ?? 0;

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
      // Only process matches for the current division
      if (!match.id.startsWith('${currentDivision}_') &&
          !(currentDivision == 'all' && !match.id.contains('_'))) {
        continue;
      }

      final scores = _matchScores[match.id];
      if (scores != null && scores.isNotEmpty) {
        // Extract team-level scores from game-level format (teamId_game1 -> teamId)
        final teamLevelScores = <String, int>{};
        scores.forEach((key, value) {
          // Handle both team-level format (teamId: score) and game-level format (teamId_game1: score)
          if (key.endsWith('_game1')) {
            final teamId = key.replaceAll('_game1', '');
            teamLevelScores[teamId] = value;
          } else {
            // Direct team-level format
            teamLevelScores[key] = value;
          }
        });

        // Get unique team IDs
        final teamIds = teamLevelScores.keys.toList();
        if (teamIds.length >= 2) {
          final team1Id = teamIds[0];
          final team2Id = teamIds[1];
          final team1Score = teamLevelScores[team1Id] ?? 0;
          final team2Score = teamLevelScores[team2Id] ?? 0;

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
    for (int i = 0; i < filteredTeams.length; i++) {
      final teamId = filteredTeams[i].id;
      final stats = teamStats[teamId]!;

      // Calculate team stats

      standings.add(
        Standing(
          rank: i + 1,
          teamName: filteredTeams[i].name,
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

    // Debug: Print standings order
    print('DEBUG Standings order:');
    for (int i = 0; i < standings.length; i++) {
      print('  ${i + 1}. ${standings[i].teamName}');
    }

    // Cache the results
    _cachedStandings = standings;
    _lastStandingsCacheKey = cacheKey;

    return standings;
  }

  // Get winners of quarter finals
  List<dynamic> _getQuarterFinalsWinners() {
    final quarterFinals = _getQuarterFinalsDirect();
    List<dynamic> winners = [];

    for (var match in quarterFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        // Get the format for QF
        final format = _matchFormats['QF'] ?? '1game';
        bool hasWinner = false;
        String? winnerTeamId;

        if (format == '1game') {
          // For 1 game format, check game 1 score
          final team1Game1Score =
              _getGameScore(match.id, match.team1Id!, 1) ?? 0;
          final team2Game1Score =
              _getGameScore(match.id, match.team2Id!, 1) ?? 0;

          // Check if a team has won (reached winning score and wins by 2)
          final winningScore = _gameWinningScores['QF'] ?? 11;
          if (team1Game1Score >= winningScore &&
              team1Game1Score >= team2Game1Score + 2) {
            hasWinner = true;
            winnerTeamId = match.team1Id;
          } else if (team2Game1Score >= winningScore &&
              team2Game1Score >= team1Game1Score + 2) {
            hasWinner = true;
            winnerTeamId = match.team2Id;
          }
        } else {
          // For best of 3 format, use _getGamesWon
          final team1GamesWon = _getGamesWon(match.id, match.team1Id!);
          final team2GamesWon = _getGamesWon(match.id, match.team2Id!);

          if (team1GamesWon >= 2) {
            hasWinner = true;
            winnerTeamId = match.team1Id;
          } else if (team2GamesWon >= 2) {
            hasWinner = true;
            winnerTeamId = match.team2Id;
          }
        }

        if (hasWinner && winnerTeamId != null) {
          final team = _teams.firstWhere((t) => t.id == winnerTeamId);
          winners.add(team);
          print('DEBUG: QF Winner: ${team.name}');
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

    print(
      'DEBUG: QF Winners (${winners.length}): ${winners.map((w) => w.name).join(", ")}',
    );
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
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _playoffTabController = TabController(length: 3, vsync: this);

    // Reset bottom navigation to Games tab when entering the screen
    _bottomNavIndex = 0;

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

    _loadTeams().then((_) {
      _loadScores();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset bottom navigation to Games tab when screen is rebuilt
    // This ensures playoffs nav is hidden until user explicitly presses "Go to Playoffs"
    if (_bottomNavIndex == 1) {
      setState(() {
        _bottomNavIndex = 0;
      });
    }
    // Don't reload teams and scores here as it can cause data loss
    // The initState method already handles initial loading
    // This prevents clearing scores when navigating back and forth
  }

  Future<void> _loadTeams() async {
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();
    if (mounted) {
      // Check if there are fewer than 8 teams and show dialog
      if (_teams.length < 8) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            barrierDismissible: true, // Allow dismissing by tapping outside
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Insufficient Teams'),
                content: Text(
                  'Not enough teams registered. Need 8 teams to start games. Currently have ${_teams.length} teams.\n\nPlease go back and register more teams.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      // Use pushReplacement to go back to previous screen
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => MainNavigationScreen(),
                        ),
                      );
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              );
            },
          );
        });
        return; // Exit early to prevent further processing
      }

      setState(() {
        // Only clear the matches cache if teams have actually changed
        // This prevents unnecessary regeneration when navigating back and forth
        final currentTeamIds = _teams.map((t) => t.id).toList()..sort();
        final cacheKeys = _matchesCache.keys.toList();
        bool teamsChanged = false;

        // Show games per team dialog on first load if not shown yet and no scores exist
        // After scores are loaded, check if any scores exist
        // If scores exist, don't show dialog; if no scores, show dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Wait for scores to be loaded, then check
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted && _teams.isNotEmpty) {
              final currentDivision = _selectedDivision ?? 'all';
              final hasShownForDivision =
                  _hasShownGamesPerTeamDialogByDivision[currentDivision] ??
                  false;

              if (!hasShownForDivision) {
                // Check if there are no scores for this division - only show dialog if no scores exist
                final hasNoScores = _hasNoScoresForCurrentDivision();
                if (hasNoScores) {
                  _hasShownGamesPerTeamDialogByDivision[currentDivision] = true;
                  _showGamesPerTeamDialog(
                    isFirstLoad: _isFirstLoad,
                    currentTabIndex: _tabController.index,
                  );
                } else {
                  // Scores exist, mark as shown to prevent showing dialog
                  _hasShownGamesPerTeamDialogByDivision[currentDivision] = true;
                }
              }
              // Mark that we've completed the first load
              _isFirstLoad = false;
            }
          });
        });

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
      });

      // Update divisions after setState
      await _updateDivisions();
    }
  }

  Future<void> _loadScores() async {
    try {
      print(
        'DEBUG: _loadScores - Starting load, _selectedDivision: ${_selectedDivision ?? 'all'}',
      );

      // Don't reload scores if we just restarted playoffs
      if (_justRestartedPlayoffs) {
        // Reset the flag after skipping the reload
        _justRestartedPlayoffs = false;
        return;
      }

      // Always load scores when entering the screen to ensure we have the latest data
      print('DEBUG: _loadScores - Loading scores from storage');

      final preliminaryScores = await _scoreService
          .loadPreliminaryScoresForDivision(_selectedDivision ?? 'all');
      final playoffScores = await _scoreService.loadPlayoffScores();
      final quarterFinalsScores = await _scoreService
          .loadQuarterFinalsScoresForDivision(_selectedDivision ?? 'all');
      final semiFinalsScores = await _scoreService
          .loadSemiFinalsScoresForDivision(_selectedDivision ?? 'all');
      final finalsScores = await _scoreService.loadFinalsScoresForDivision(
        _selectedDivision ?? 'all',
      );
      final playoffsStarted = await _scoreService
          .loadPlayoffsStartedForDivision(_selectedDivision ?? '');

      // Load preliminary settings for current division
      final preliminarySettings = await _scoreService
          .loadPreliminarySettingsForDivision(_selectedDivision ?? 'all');

      print(
        'DEBUG: _loadScores - Current division: ${_selectedDivision ?? 'all'}',
      );
      print(
        'DEBUG: _loadScores - preliminaryScores from storage: $preliminaryScores',
      );
      print('DEBUG: _loadScores - playoffsStarted: $playoffsStarted');
      print('DEBUG: _loadScores - playoffScores from storage: $playoffScores');
      print(
        'DEBUG: _loadScores - Current _matchScores before loading: $_matchScores',
      );

      // Only update state if widget is still mounted
      if (mounted) {
        setState(() {
          // Load scores for the current division without clearing other divisions
          // Only load if we don't already have scores for this match
          for (var entry in preliminaryScores.entries) {
            if (!_matchScores.containsKey(entry.key)) {
              _matchScores[entry.key] = entry.value;
              print(
                'DEBUG: _loadScores - Loaded score for ${entry.key}: ${entry.value}',
              );
            } else {
              print(
                'DEBUG: _loadScores - Skipping ${entry.key}, already exists: ${_matchScores[entry.key]}',
              );
            }
          }
          print(
            'DEBUG: _loadScores - After loading preliminary scores: $_matchScores',
          );

          // Only load playoff scores if playoffs have actually started
          // This prevents loading old scores when starting playoffs fresh
          if (playoffsStarted) {
            print('DEBUG: _loadScores - Playoffs started, loading scores');
            print(
              'DEBUG: _loadScores - Current _playoffScores before loading: $_playoffScores',
            );
            print(
              'DEBUG: _loadScores - QF scores from storage: $quarterFinalsScores',
            );
            print(
              'DEBUG: _loadScores - SF scores from storage: $semiFinalsScores',
            );
            print(
              'DEBUG: _loadScores - Finals scores from storage: $finalsScores',
            );

            // Load division-specific playoff scores without clearing existing ones
            // Only load if we don't already have scores for this match
            for (var entry in quarterFinalsScores.entries) {
              if (!_playoffScores.containsKey(entry.key)) {
                _playoffScores[entry.key] = entry.value;
                print(
                  'DEBUG: _loadScores - Loaded QF score for ${entry.key}: ${entry.value}',
                );
              } else {
                print(
                  'DEBUG: _loadScores - Skipping QF score ${entry.key}, already exists: ${_playoffScores[entry.key]}',
                );
              }
            }

            for (var entry in semiFinalsScores.entries) {
              if (!_playoffScores.containsKey(entry.key)) {
                _playoffScores[entry.key] = entry.value;
                print(
                  'DEBUG: _loadScores - Loaded SF score for ${entry.key}: ${entry.value}',
                );
              } else {
                print(
                  'DEBUG: _loadScores - Skipping SF score ${entry.key}, already exists: ${_playoffScores[entry.key]}',
                );
              }
            }

            for (var entry in finalsScores.entries) {
              if (!_playoffScores.containsKey(entry.key)) {
                _playoffScores[entry.key] = entry.value;
                print(
                  'DEBUG: _loadScores - Loaded Finals score for ${entry.key}: ${entry.value}',
                );
              } else {
                print(
                  'DEBUG: _loadScores - Skipping Finals score ${entry.key}, already exists: ${_playoffScores[entry.key]}',
                );
              }
            }

            print(
              'DEBUG: _loadScores - After loading playoff scores: $_playoffScores',
            );
          } else {
            print('DEBUG: _loadScores - Playoffs not started, clearing scores');
            // Clear playoff scores if playoffs haven't started
            _playoffScores.clear();
          }

          _playoffsStartedByDivision[_selectedDivision ?? ''] = playoffsStarted;

          // Load preliminary settings for current division
          _gamesPerTeamByDivision[_selectedDivision ?? 'all'] =
              preliminarySettings['gamesPerTeam'] ?? 1;
          _preliminaryGameWinningScoreByDivision[_selectedDivision ?? 'all'] =
              preliminarySettings['winningScore'] ?? 11;

          // Set initial tab based on playoff status
          // If playoffs have started, default to Standings tab (index 1)
          // Otherwise, stay on Preliminary Rounds tab (index 0)
          if (playoffsStarted && _tabController.index == 0) {
            // Only change tab if we're currently on Preliminary Rounds tab
            // This prevents disrupting user's current tab selection
            _tabController.animateTo(1);
          }
        });

        // Scores loaded successfully
        print('DEBUG: _loadScores - Scores loaded successfully');
      }
    } catch (e) {
      print('Error loading scores: $e');
      // Don't rethrow the error to prevent app crashes
    }
  }

  @override
  void dispose() {
    // Save scores before disposing - use a different approach
    print('DEBUG: dispose() called - saving scores before disposal');
    _saveScoresBeforeDispose();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _playoffTabController.dispose();
    super.dispose();
  }

  // Save scores before dispose using a different approach
  void _saveScoresBeforeDispose() {
    // Use a microtask to ensure the save happens before the widget is disposed
    Future.microtask(() async {
      try {
        print(
          'DEBUG: _saveScoresBeforeDispose called - Current division: ${_selectedDivision ?? 'all'}',
        );
        print('DEBUG: _saveScoresBeforeDispose - _matchScores: $_matchScores');
        print(
          'DEBUG: _saveScoresBeforeDispose - _playoffScores: $_playoffScores',
        );

        final currentDivisionScores = _getCurrentDivisionScores();
        print(
          'DEBUG: _saveScoresBeforeDispose - currentDivisionScores: $currentDivisionScores',
        );

        await _scoreService.savePreliminaryScoresForDivision(
          _selectedDivision ?? 'all',
          currentDivisionScores,
        );
        await _scoreService.savePlayoffScores(_playoffScores);

        // Save division-specific playoff scores
        final currentDivisionPlayoffScores = _getCurrentDivisionPlayoffScores();
        await _scoreService.saveQuarterFinalsScoresForDivision(
          _selectedDivision ?? 'all',
          currentDivisionPlayoffScores,
        );
        await _scoreService.saveSemiFinalsScoresForDivision(
          _selectedDivision ?? 'all',
          currentDivisionPlayoffScores,
        );
        await _scoreService.saveFinalsScoresForDivision(
          _selectedDivision ?? 'all',
          currentDivisionPlayoffScores,
        );

        await _scoreService.savePlayoffsStartedForDivision(
          _selectedDivision ?? '',
          _playoffsStarted,
        );
        print('DEBUG: _saveScoresBeforeDispose completed successfully');
      } catch (e) {
        print('Error saving scores before dispose: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Save scores when app goes to background or becomes inactive
      _saveScores().catchError((e) {
        print('Error saving scores on app lifecycle change: $e');
      });
    } else if (state == AppLifecycleState.resumed) {
      // Reset bottom navigation to Games tab when app resumes
      // This ensures playoffs nav is hidden until user explicitly presses "Go to Playoffs"
      if (_bottomNavIndex == 1) {
        setState(() {
          _bottomNavIndex = 0;
        });
      }
    }
  }

  // Force refresh standings to show latest data
  void _refreshStandings() {
    setState(() {
      _cachedStandings = null;
      _lastStandingsCacheKey = null;
    });
  }

  // Calculate dropdown width based on division name length
  double _getDropdownWidth() {
    if (_selectedDivision == null) {
      return 200; // Default width when no selection
    }

    final divisionName = _selectedDivision!;
    final baseWidth = 120.0; // Minimum width
    final charWidth = 8.0; // Approximate width per character
    final padding = 40.0; // Padding for icon and dropdown arrow

    final calculatedWidth =
        baseWidth + (divisionName.length * charWidth) + padding;

    // Set reasonable limits
    return calculatedWidth.clamp(120.0, 300.0);
  }

  // Save scores to persistent storage
  Future<void> _saveScores() async {
    try {
      print(
        'DEBUG: _saveScores called - Current division: ${_selectedDivision ?? 'all'}',
      );
      print('DEBUG: _saveScores - _matchScores: $_matchScores');
      print('DEBUG: _saveScores - _playoffScores: $_playoffScores');

      final currentDivisionScores = _getCurrentDivisionScores();
      print(
        'DEBUG: _saveScores - currentDivisionScores: $currentDivisionScores',
      );

      await _scoreService.savePreliminaryScoresForDivision(
        _selectedDivision ?? 'all',
        currentDivisionScores,
      );
      await _scoreService.savePlayoffScores(_playoffScores);

      // Save division-specific playoff scores
      final currentDivisionPlayoffScores = _getCurrentDivisionPlayoffScores();
      await _scoreService.saveQuarterFinalsScoresForDivision(
        _selectedDivision ?? 'all',
        currentDivisionPlayoffScores,
      );
      await _scoreService.saveSemiFinalsScoresForDivision(
        _selectedDivision ?? 'all',
        currentDivisionPlayoffScores,
      );
      await _scoreService.saveFinalsScoresForDivision(
        _selectedDivision ?? 'all',
        currentDivisionPlayoffScores,
      );

      await _scoreService.savePlayoffsStartedForDivision(
        _selectedDivision ?? '',
        _playoffsStarted,
      );
      print('DEBUG: _saveScores completed successfully');
    } catch (e) {
      print('Error saving scores to storage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(
        title: widget.tournamentTitle,
        onBackPressed: () async {
          // Save scores before navigating away
          await _saveScores();
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
      bottomNavigationBar:
          _bottomNavIndex == 1 ? _buildPlayoffsBottomNav() : null,
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

        // Winner icon - only show if team won 2+ games
        Expanded(
          child: Center(
            child:
                isWinner && gamesWon >= 2
                    ? Icon(
                      match.day == 'Semi Finals'
                          ? Icons.check_circle
                          : Icons.emoji_events,
                      size: match.day == 'Semi Finals' ? 20 : 24,
                      color:
                          match.day == 'Semi Finals'
                              ? const Color.fromARGB(176, 255, 255, 255)
                              : Colors.yellow[600],
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
      // Game 3 wasn't needed - show "-"
      displayText = '-';
    } else if (score != null) {
      // Show the actual score (even if 0)
      displayText = '$score';
    } else {
      // No score entered yet - show 0
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

    // Get the opponent ID - try QF first, then SF, then Finals
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
      );
    }

    // If still not found, try Finals
    if (match.id == matchId && match.day == '') {
      match = _getFinals().firstWhere(
        (m) => m.id == matchId,
        orElse: () => match,
      );
    }

    // Get opponent ID
    String? opponentId;
    if (match.team1Id == teamId) {
      opponentId = match.team2Id;
    } else {
      opponentId = match.team1Id;
    }

    if (opponentId == null || opponentId.isEmpty) return false;

    // Check if Game 3 scores exist - if they do, Game 3 was played
    final team3Score = _getGameScore(matchId, teamId, 3);
    final opponent3Score = _getGameScore(matchId, opponentId, 3);

    // If any Game 3 score exists, Game 3 was played
    if (team3Score != null || opponent3Score != null) {
      return false; // Game 3 was played
    }

    // Check if either team won 2 games (match decided)
    final teamGamesWon = _getGamesWon(matchId, teamId);
    final opponentGamesWon = _getGamesWon(matchId, opponentId);

    // Game 3 is not needed if someone won 2 games AND Game 3 wasn't played
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
    // Use the actual winning score from settings
    final minScore =
        match.day == 'Quarter Finals'
            ? (_gameWinningScores['QF'] ?? 11)
            : (match.day == 'Semi Finals' ? 15 : 15);

    // Team wins if they reach minScore and win by 2
    return teamScore >= minScore && teamScore >= opponentScore + 2;
  }

  // Get individual game score
  int? _getGameScore(String matchId, String teamId, int gameNumber) {
    // Get the game-specific score from storage
    final gameKey = '${teamId}_game$gameNumber';

    // Check playoff scores first using division-specific key
    final playoffMatchKey = _getPlayoffMatchKey(matchId);
    final playoffScores = _playoffScores[playoffMatchKey];
    if (playoffScores != null && playoffScores.containsKey(gameKey)) {
      return playoffScores[gameKey];
    }

    // Check preliminary scores (these already use division-specific keys)
    final preliminaryScores = _matchScores[matchId];
    if (preliminaryScores != null && preliminaryScores.containsKey(gameKey)) {
      return preliminaryScores[gameKey];
    }

    return null;
  }

  // Get total games won for a team in a best-of-3 match
  int _getGamesWonForMatch(Match match, String teamId) {
    int gamesWon = 0;
    final minScore =
        match.day == 'Quarter Finals'
            ? (_gameWinningScores['QF'] ?? 11)
            : (match.day == 'Semi Finals' ? 15 : 15);

    for (int i = 1; i <= 3; i++) {
      final gameScore = _getGameScore(match.id, teamId, i);
      if (gameScore != null) {
        final opponentId =
            match.team1Id == teamId ? match.team2Id : match.team1Id;
        if (opponentId != null) {
          final opponentScore = _getGameScore(match.id, opponentId, i);
          // Check if this team won (reached minScore and won by 2)
          if (gameScore >= minScore && gameScore >= (opponentScore ?? 0) + 2) {
            gamesWon++;
          }
        }
      }
    }
    return gamesWon;
  }

  // Get games won from a scores map (for Finals confirmation)
  int _getGamesWonFromScores(Map<String, dynamic> scores, String teamId) {
    int gamesWon = 0;
    final minScore = 15; // Finals always use 15 points

    for (int i = 1; i <= 3; i++) {
      final teamKey = '${teamId}_game$i';
      final teamScore = scores[teamKey] ?? 0;

      // Find opponent score
      int? opponentScore;
      for (var key in scores.keys) {
        if (key.startsWith('${teamId}_game') || key == teamKey) continue;
        if (key.endsWith('_game$i')) {
          opponentScore = scores[key] ?? 0;
          break;
        }
      }

      if (teamScore >= minScore && teamScore >= (opponentScore ?? 0) + 2) {
        gamesWon++;
      }
    }
    return gamesWon;
  }

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
          // Get the correct winning score for this match
          final minScore = _gameWinningScores['QF'] ?? 11;
          // Check if this team won (reached minScore and won by 2)
          if (gameScore >= minScore && gameScore >= (opponentScore ?? 0) + 2) {
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

    // Check if scores exist to determine format, otherwise use stored format
    final hasGame3Scores =
        _getGameScore(match.id, match.team1Id ?? '', 3) != null ||
        _getGameScore(match.id, match.team2Id ?? '', 3) != null;
    final storedFormat = _matchFormats['QF'] ?? '1game';
    final showBestOf3 = storedFormat == 'bestof3' || hasGame3Scores;

    // Check if SF has started - if yes, disable QF editing
    bool hasSFStarted = false;
    final semiFinals = _getSemiFinalsDirect();
    for (var sfMatch in semiFinals) {
      final matchScores = _playoffScores[_getPlayoffMatchKey(sfMatch.id)];
      if (matchScores != null && matchScores.values.any((value) => value > 0)) {
        hasSFStarted = true;
        break;
      }
    }

    return GestureDetector(
      onTap:
          (_authService.canScore && !hasSFStarted)
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
        final minScore = _gameWinningScores['QF'] ?? 11;
        // Check if this team won (reached minScore and won by 2)
        if (game1Score >= minScore && game1Score >= (opponentScore ?? 0) + 2) {
          winnerId = teamId;
        }
      }
    }

    // Determine winner for best of 3
    int gamesWon = 0;
    if (showBestOf3 && teamId != null) {
      gamesWon = _getGamesWonForMatch(match, teamId);
    }
    final isWinner = showBestOf3 ? gamesWon >= 2 : (winnerId == teamId);

    // Check if there are any scores entered for this match
    final hasScores = game1Score != null && game1Score > 0;

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
        // Winner trophy - only show if there are scores AND they won
        Expanded(
          child: Center(
            child:
                (isWinner && hasScores)
                    ? Icon(
                      Icons.check_circle,
                      color: const Color.fromARGB(176, 255, 255, 255),
                      size: 20,
                    )
                    : const SizedBox(width: 24, height: 24),
          ),
        ),
      ],
    );
  }

  // Build preliminary match card (single match against one opponent)
  Widget _buildPreliminaryMatchCard(Match match) {
    final team1Score = _getGameScore(match.id, match.team1Id ?? '', 1) ?? 0;
    final team2Score = _getGameScore(match.id, match.team2Id ?? '', 1) ?? 0;
    final winningTeamId = _getWinningTeamIdForGame(match.id, 1);
    final isSelected = _selectedMatch?.id == match.id;

    final hasOpponent = match.team2 != 'TBA';

    // Check if this is a preliminary match that should be locked
    final isPreliminaryMatch =
        match.day == 'Day 1' || match.day == 'Preliminary';
    final isLocked = _playoffsStarted && isPreliminaryMatch;

    return GestureDetector(
      onTap: () {
        if (!isLocked && hasOpponent && _authService.canScore) {
          setState(() {
            _selectedMatch = match;
            _selectedGameNumber = 1; // Always game 1 for preliminary matches
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.blue[50] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teams and scores
              Row(
                children: [
                  // Team 1
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.team1,
                          style: TextStyle(
                            fontSize: winningTeamId == match.team1Id ? 18 : 14,
                            fontWeight:
                                winningTeamId == match.team1Id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                winningTeamId == match.team1Id
                                    ? Colors.green[700]
                                    : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Score: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$team1Score',
                              style: TextStyle(
                                fontSize:
                                    winningTeamId == match.team1Id ? 18 : 14,
                                color: Colors.grey[600],
                                fontWeight:
                                    winningTeamId == match.team1Id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
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
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          match.team2,
                          style: TextStyle(
                            fontSize: winningTeamId == match.team2Id ? 18 : 14,
                            fontWeight:
                                winningTeamId == match.team2Id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                winningTeamId == match.team2Id
                                    ? Colors.green[700]
                                    : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Score: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$team2Score',
                              style: TextStyle(
                                fontSize:
                                    winningTeamId == match.team2Id ? 18 : 14,
                                color: Colors.grey[600],
                                fontWeight:
                                    winningTeamId == match.team2Id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Winner display
              if (winningTeamId != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        'Winner: ${winningTeamId == match.team1Id ? match.team1 : match.team2}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Build individual game card for preliminary rounds
  Widget _buildPreliminaryGameCard(Match match, int gameNumber) {
    final team1Score =
        _getGameScore(match.id, match.team1Id ?? '', gameNumber) ?? 0;
    final team2Score =
        _getGameScore(match.id, match.team2Id ?? '', gameNumber) ?? 0;
    final winningTeamId = _getWinningTeamIdForGame(match.id, gameNumber);
    final isSelected =
        _selectedMatch?.id == match.id && _selectedGameNumber == gameNumber;

    final hasOpponent = match.team2 != 'TBA';

    // Check if this is a preliminary match that should be locked
    final isPreliminaryMatch =
        match.day == 'Day 1' || match.day == 'Preliminary';
    final isLocked = _playoffsStarted && isPreliminaryMatch;

    return GestureDetector(
      onTap: () {
        if (!isLocked && hasOpponent && _authService.canScore) {
          setState(() {
            _selectedMatch = match;
            _selectedGameNumber = gameNumber;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.blue[50] : Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Teams and scores
              Row(
                children: [
                  // Team 1
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.team1,
                          style: TextStyle(
                            fontSize: winningTeamId == match.team1Id ? 18 : 14,
                            fontWeight:
                                winningTeamId == match.team1Id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                winningTeamId == match.team1Id
                                    ? Colors.green[700]
                                    : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Score: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$team1Score',
                              style: TextStyle(
                                fontSize:
                                    winningTeamId == match.team1Id ? 18 : 14,
                                color: Colors.grey[600],
                                fontWeight:
                                    winningTeamId == match.team1Id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (winningTeamId == match.team1Id) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.yellow[600],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Winner',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
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
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  // Team 2
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          match.team2,
                          style: TextStyle(
                            fontSize: winningTeamId == match.team2Id ? 18 : 14,
                            fontWeight:
                                winningTeamId == match.team2Id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                winningTeamId == match.team2Id
                                    ? Colors.green[700]
                                    : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Score: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$team2Score',
                              style: TextStyle(
                                fontSize:
                                    winningTeamId == match.team2Id ? 18 : 14,
                                color: Colors.grey[600],
                                fontWeight:
                                    winningTeamId == match.team2Id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (winningTeamId == match.team2Id) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.yellow[600],
                                size: 16,
                              ),
                              Text(
                                'Winner',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Lock overlay
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock,
                        color: Colors.grey[600],
                        size: 24,
                      ),
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

    // Debug logging
    print(
      'DEBUG: _buildNormalMatchCard: team1Won=$team1Won, team2Won=$team2Won, hasScores=$hasScores',
    );

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
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

        // Start/Restart Playoffs Buttons (only when playoffs have started)
        if (_authService.canScore && _playoffsStarted)
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
                // Restart Playoffs button (left side)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _hasQuarterFinalsScores ? null : _restartPlayoffs,
                    icon: Icon(
                      _hasQuarterFinalsScores ? Icons.lock : Icons.refresh,
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

                        // If Finals are completed, navigate directly to Finals tab
                        if (_hasFinalsScores) {
                          // For 8-team case, Finals is at index 1
                          // For normal case, Finals is at index 2
                          if (_teams.length == 8) {
                            _playoffTabController.animateTo(
                              1,
                            ); // Finals tab in 8-team case
                          } else {
                            _playoffTabController.animateTo(
                              2,
                            ); // Finals tab in normal case
                          }
                        }
                      });
                    },
                    icon: const Icon(Icons.sports_esports),
                    label: const Text('Go to Playoffs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
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
                color: Color.fromARGB(212, 30, 255, 0),
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

  // Check if there are no scores entered across ALL divisions
  bool _hasNoScores() {
    // Check scores across all divisions, not just current division
    for (var entry in _matchScores.entries) {
      final scores = entry.value;
      if (scores.isNotEmpty) {
        // Check if any score is greater than 0
        for (var scoreEntry in scores.entries) {
          if (scoreEntry.value > 0) {
            return false; // Found a score > 0 in any division
          }
        }
      }
    }
    return true; // No scores found in any division
  }

  // Check if there are no scores entered for the current division
  bool _hasNoScoresForCurrentDivision() {
    final currentDivision = _selectedDivision ?? 'all';
    final preliminaryMatches = _getPreliminaryMatchesDirect();

    for (var match in preliminaryMatches) {
      // Only check matches for the current division
      if (!match.id.startsWith('${currentDivision}_') &&
          !(currentDivision == 'all' && !match.id.contains('_'))) {
        continue;
      }

      if (match.team2 == 'TBA') continue;
      final scores = _matchScores[match.id];
      if (scores != null && scores.isNotEmpty) {
        // Check both team-level and game-level formats
        final team1Id = match.team1Id ?? '';
        final team2Id = match.team2Id ?? '';

        // Check team-level format
        final team1Score = scores[team1Id] ?? 0;
        final team2Score = scores[team2Id] ?? 0;

        // Check game-level format (teamId_game1)
        final team1Game1Score = scores['${team1Id}_game1'] ?? 0;
        final team2Game1Score = scores['${team2Id}_game1'] ?? 0;

        if (team1Score > 0 ||
            team2Score > 0 ||
            team1Game1Score > 0 ||
            team2Game1Score > 0) {
          return false; // Found a score > 0
        }
      }
    }
    return true; // No scores found
  }

  // Check if the selected match has scores
  bool _hasScoresForSelectedMatch() {
    if (_selectedMatch == null) return false;

    // Check for QF/SF/Finals (best-of-3 or 1-game)
    if (_selectedMatch!.day == 'Quarter Finals' ||
        _selectedMatch!.day == 'Semi Finals' ||
        _selectedMatch!.day == 'Finals') {
      final playoffScores =
          _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)];
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
      // Check both team-level format (teamId: score) and game-level format (teamId_game1: score)
      final team1Score = scores[_selectedMatch!.team1Id] ?? 0;
      final team2Score = scores[_selectedMatch!.team2Id] ?? 0;

      // Also check for game-level format keys
      final team1Game1Score = scores['${_selectedMatch!.team1Id}_game1'] ?? 0;
      final team2Game1Score = scores['${_selectedMatch!.team2Id}_game1'] ?? 0;

      return team1Score > 0 ||
          team2Score > 0 ||
          team1Game1Score > 0 ||
          team2Game1Score > 0;
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

      // Handle 8-team case where QF doesn't exist
      if (_teams.length == 8) {
        if (playoffSubTabIndex == 0) {
          // Semi Finals tab (first tab in 8-team case)
          final semiFinals = _getSemiFinalsDirect();
          final isInSemiFinals = semiFinals.any(
            (match) => match.id == _selectedMatch!.id,
          );
          return isInSemiFinals;
        } else if (playoffSubTabIndex == 1) {
          // Finals tab (second tab in 8-team case)
          final finals = _getFinalsDirect();
          final isInFinals = finals.any(
            (match) => match.id == _selectedMatch!.id,
          );
          return isInFinals;
        }
      } else {
        // Normal case with QF
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
    }

    return false;
  }

  // Reshuffle teams method
  void _reshuffleTeams() async {
    print('DEBUG: _reshuffleTeams called - clearing _selectedMatch');

    // Get current teams (already filtered by division)
    final teams = _teams;
    if (teams.isEmpty) return;

    // Clear only the cache entries for the current division
    final currentDivision = _selectedDivision ?? 'all';
    final keysToRemove =
        _matchesCache.keys
            .where((key) => key.contains('_${currentDivision}_'))
            .toList();

    for (final key in keysToRemove) {
      _matchesCache.remove(key);
    }

    // Clear scores for current division only
    _matchScores.clear();
    _selectedMatch = null;
    _cachedStandings = null;
    _lastStandingsCacheKey = null;
    _reshuffledMatches = null; // Clear reshuffled matches

    // Clear scores from storage for current division
    await _scoreService.clearAllScores();

    // Generate completely new matches for current division only
    // Shuffle teams directly
    final shuffledTeams = List.from(teams);
    shuffledTeams.shuffle();

    // Generate matches with shuffled teams
    final newMatches = _generateMatchesForTeams(shuffledTeams);

    // Store the new matches in state
    _reshuffledMatches = newMatches;

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

      // Generate matches ensuring each team plays exactly _gamesPerTeam games
      int maxAttempts = 1000;
      int attempts = 0;

      while (availableTeams.length >= 2 && attempts < maxAttempts) {
        attempts++;

        // Find two teams that haven't played each other and haven't played _gamesPerTeam games
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
                gamesPlayed[team1.id]! < _gamesPerTeam &&
                gamesPlayed[team2.id]! < _gamesPerTeam) {
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

              // Remove teams that have played _gamesPerTeam games
              availableTeams.removeWhere(
                (team) => gamesPlayed[team.id]! >= _gamesPerTeam,
              );

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
          availableTeams.removeWhere(
            (team) => gamesPlayed[team.id]! >= _gamesPerTeam,
          );
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
          // Division Dropdown and Settings Button
          if (_availableDivisions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Stack(
                children: [
                  // Centered dropdown
                  Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: _getDropdownWidth(),
                        minWidth: 120,
                      ),
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
                          hintText: 'Select Division',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.sports_basketball,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                        ),
                        isExpanded: true,
                        items:
                            _availableDivisions.map((String division) {
                              return DropdownMenuItem<String>(
                                value: division,
                                child: Row(
                                  children: [
                                    if (_selectedDivision == division) ...[
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF2196F3),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        division,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (String? newValue) async {
                          // Store previous division before changing
                          _previousDivision = _selectedDivision;

                          setState(() {
                            _selectedDivision = newValue;
                            // Clear selected card when switching divisions
                            _selectedMatch = null;
                            // Clear reshuffled matches when switching divisions
                            _reshuffledMatches = null;
                            // Clear standings cache when switching divisions
                            _cachedStandings = null;
                            _lastStandingsCacheKey = null;
                            // Don't reset dialog flag - it should be global across divisions
                            // Reset first load flag when switching divisions
                            _isFirstLoad = false;
                          });

                          // Save the selected division
                          if (newValue != null) {
                            await _scoreService.saveSelectedDivision(
                              widget.sportName,
                              newValue,
                            );
                          }

                          // Load playoff state for the new division first
                          await _loadScores();

                          // If user is on Playoffs tab and new division hasn't started playoffs,
                          // redirect them back to Games tab
                          if (_bottomNavIndex == 1) {
                            final newDivisionPlayoffsStarted =
                                _playoffsStartedByDivision[newValue ?? ''] ??
                                false;
                            if (!newDivisionPlayoffsStarted) {
                              setState(() {
                                _bottomNavIndex = 0; // Switch back to Games tab
                              });
                            }
                          }

                          // Check if we should show the preliminary settings dialog
                          // Only show if division actually changed, we have teams, and dialog hasn't been shown for this division
                          if (_previousDivision != newValue &&
                              _teams.isNotEmpty) {
                            final currentDivision = newValue ?? 'all';
                            final hasShownForDivision =
                                _hasShownGamesPerTeamDialogByDivision[currentDivision] ??
                                false;

                            if (!hasShownForDivision) {
                              // Check if there are no scores for this division
                              final hasNoScores =
                                  _hasNoScoresForCurrentDivision();
                              if (hasNoScores) {
                                _hasShownGamesPerTeamDialogByDivision[currentDivision] =
                                    true;
                                _showGamesPerTeamDialog(
                                  isFirstLoad: false,
                                  currentTabIndex: _tabController.index,
                                );
                              } else {
                                // Scores exist, mark as shown to prevent showing dialog
                                _hasShownGamesPerTeamDialogByDivision[currentDivision] =
                                    true;
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ),

                  // Settings Button positioned at the end
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: Icon(
                        Icons.settings,
                        color:
                            (_playoffsStartedByDivision[_selectedDivision ??
                                        ''] ??
                                    false)
                                ? Colors.grey[400]
                                : const Color(0xFF2196F3),
                      ),
                      iconSize: 18,
                      onPressed:
                          (_playoffsStartedByDivision[_selectedDivision ??
                                      ''] ??
                                  false)
                              ? null // Disable when playoffs started
                              : () {
                                _showGamesPerTeamDialog(
                                  isFirstLoad: false,
                                  currentTabIndex: _tabController.index,
                                );
                              },
                    ),
                  ),
                ],
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
              children: [
                _buildPreliminaryRoundsTab(),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildStandingsTab(),
                ),
              ],
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
              final match = _preliminaryMatches[index];
              return _buildPreliminaryMatchCard(match);
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
                            icon: Icon(
                              _hasNoScores() ? Icons.shuffle : Icons.lock,
                              size: 18,
                            ),
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
                          child: ElevatedButton.icon(
                            onPressed:
                                (_selectedMatch != null &&
                                        _isSelectedMatchInCurrentTab() &&
                                        !_playoffsStarted)
                                    ? _startScoring
                                    : null,
                            icon: Icon(
                              (_selectedMatch != null &&
                                      _isSelectedMatchInCurrentTab() &&
                                      !_playoffsStarted)
                                  ? Icons.sports_score
                                  : Icons.lock,
                              size: 18,
                            ),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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
        // Division Dropdown and Settings Button for Playoffs
        if (_availableDivisions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Stack(
              children: [
                // Centered dropdown
                Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: _getDropdownWidth(),
                      minWidth: 120,
                    ),
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
                        hintText: 'Select Division',
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.sports_basketball,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                      ),
                      isExpanded: true,
                      items:
                          _availableDivisions.map((String division) {
                            return DropdownMenuItem<String>(
                              value: division,
                              child: Row(
                                children: [
                                  if (_selectedDivision == division) ...[
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF2196F3),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      division,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) async {
                        // Store previous division before changing
                        _previousDivision = _selectedDivision;

                        setState(() {
                          _selectedDivision = newValue;
                          // Clear selected card when switching divisions
                          _selectedMatch = null;
                          // Clear reshuffled matches when switching divisions
                          _reshuffledMatches = null;
                          // Clear standings cache when switching divisions
                          _cachedStandings = null;
                          _lastStandingsCacheKey = null;
                          // Don't reset dialog flag - it should be global across divisions
                          // Reset first load flag when switching divisions
                          _isFirstLoad = false;
                        });

                        // Save the selected division
                        if (newValue != null) {
                          await _scoreService.saveSelectedDivision(
                            widget.sportName,
                            newValue,
                          );
                        }

                        // Load playoff state for the new division first
                        await _loadScores();

                        // If user is on Playoffs tab and new division hasn't started playoffs,
                        // redirect them back to Games tab
                        if (_bottomNavIndex == 1) {
                          final newDivisionPlayoffsStarted =
                              _playoffsStartedByDivision[newValue ?? ''] ??
                              false;
                          if (!newDivisionPlayoffsStarted) {
                            setState(() {
                              _bottomNavIndex = 0; // Switch back to Games tab
                            });
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 16),
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
            tabs:
                _teams.length == 8
                    ? const [
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
                    ]
                    : const [
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
            children:
                _teams.length == 8
                    ? [_buildSemiFinalsTab(), _buildFinalsTab()]
                    : [
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
                              : _selectedMatch != null &&
                                  _isSelectedMatchInCurrentTab()
                              ? (_hasScoresForSelectedMatch()
                                  ? 'Edit Scoring'
                                  : 'Start Scoring')
                              : _hasQuarterFinalsScores
                              ? 'Quarter Finals Started'
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
                      child: Builder(
                        builder: (context) {
                          // Debug print to check button state
                          print(
                            'DEBUG: _playoffsStarted = $_playoffsStarted, _allQuarterFinalsScoresSet = $_allQuarterFinalsScoresSet',
                          );

                          return ElevatedButton.icon(
                            onPressed:
                                _playoffsStarted && _allQuarterFinalsScoresSet
                                    ? () {
                                      // Navigate to Semi Finals tab (index 1)
                                      _playoffTabController.animateTo(1);
                                    }
                                    : () {
                                      _showCompleteScoresDialog(
                                        'Quarter Finals',
                                      );
                                    },
                            icon: Icon(
                              _playoffsStarted && _allQuarterFinalsScoresSet
                                  ? Icons.arrow_forward
                                  : Icons.lock,
                            ),
                            label: Text(
                              _playoffsStarted && _allQuarterFinalsScoresSet
                                  ? 'Go to Semi Finals'
                                  : 'Complete all Games',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _playoffsStarted && _allQuarterFinalsScoresSet
                                      ? Colors.green
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
                              ? 'Go to Finals'
                              : 'Complete all Games',
                          textAlign: TextAlign.center,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _allSemiFinalsScoresSet
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

    // Calculate how many teams qualify - for QF, always use 8 teams (4 matches)
    int qualifyingTeams = standings.length >= 8 ? 8 : standings.length;

    print(
      'DEBUG QF Seeding: qualifyingTeams=$qualifyingTeams, standings.length=${standings.length}',
    );

    // Create quarter-final matches with proper seeding
    // QF1: #1 vs #8, QF2: #2 vs #7, QF3: #3 vs #6, QF4: #4 vs #5
    final numMatches = (qualifyingTeams / 2).ceil();
    for (int i = 0; i < numMatches; i++) {
      final team1Index = i;
      final team2Index = qualifyingTeams - 1 - i;

      print(
        'DEBUG QF Match ${i + 1}: i=$i, team1Index=$team1Index (Rank ${team1Index + 1}: ${standings[team1Index].teamName}), team2Index=$team2Index (Rank ${team2Index + 1}: ${standings[team2Index].teamName})',
      );

      if (team2Index > team1Index &&
          team2Index >= 0 &&
          team1Index < standings.length &&
          team2Index < standings.length) {
        // Get team names from standings
        final team1Name = standings[team1Index].teamName;
        final team2Name = standings[team2Index].teamName;

        // Find teams by name
        final team1 = _teams.firstWhere((t) => t.name == team1Name);
        final team2 = _teams.firstWhere((t) => t.name == team2Name);

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

    // Create placeholder quarter-final matches with proper seeding
    // QF1: #1 vs #8, QF2: #2 vs #7, QF3: #3 vs #6, QF4: #4 vs #5
    for (int i = 0; i < (qualifyingTeams / 2).ceil(); i++) {
      final team1Index = i;
      final team2Index = qualifyingTeams - 1 - i;

      if (team2Index > team1Index &&
          team2Index >= 0 &&
          team1Index < standings.length &&
          team2Index < standings.length) {
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
    List<dynamic> semiFinalsTeams;

    // For 8-team case, get top 4 teams directly from standings
    if (_teams.length == 8) {
      final standings = _standings;
      semiFinalsTeams =
          standings.take(4).map((standing) {
            return _teams.firstWhere((team) => team.name == standing.teamName);
          }).toList();
    } else {
      // Normal case: get QF winners
      semiFinalsTeams = _getQuarterFinalsWinners();
    }

    List<Match> semiFinals = [];
    // Use consistent ID generation to prevent card selection jumping
    int matchId = 4000000; // Start with a very high base ID for semi-finals
    int courtNumber = 1;
    int timeSlot = 16;

    // Always create exactly 2 semi-final matches
    for (int i = 0; i < 2; i++) {
      if (semiFinalsTeams.length >= 4) {
        // We have all 4 teams, create proper seeding matchups
        // SF1: 1st seed vs 4th seed
        // SF2: 2nd seed vs 3rd seed
        final team1Index =
            i == 0 ? 0 : 1; // First SF gets 1st seed, Second SF gets 2nd seed
        final team2Index =
            i == 0 ? 3 : 2; // First SF gets 4th seed, Second SF gets 3rd seed

        if (team1Index < semiFinalsTeams.length &&
            team2Index < semiFinalsTeams.length) {
          final team1 = semiFinalsTeams[team1Index];
          final team2 = semiFinalsTeams[team2Index];

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
                    : 'Complete all preliminary rounds and click "Go to Playoffs" to begin the elimination rounds',
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

// Game Settings Screen for Quarter Finals
class _QuarterFinalsGameSettingsScreen extends StatefulWidget {
  final Function(String matchTotalGames, int gameWinningScore)
  onSettingsSelected;
  final String? initialMatchTotalGames;
  final int? initialGameWinningScore;

  const _QuarterFinalsGameSettingsScreen({
    required this.onSettingsSelected,
    this.initialMatchTotalGames,
    this.initialGameWinningScore,
  });

  @override
  State<_QuarterFinalsGameSettingsScreen> createState() =>
      _QuarterFinalsGameSettingsScreenState();
}

class _QuarterFinalsGameSettingsScreenState
    extends State<_QuarterFinalsGameSettingsScreen> {
  late String _selectedMatchTotalGames; // '1game' or 'bestof3'
  late int _selectedGameWinningScore; // 11 or 15

  @override
  void initState() {
    super.initState();
    _selectedMatchTotalGames = widget.initialMatchTotalGames ?? '1game';
    _selectedGameWinningScore = widget.initialGameWinningScore ?? 11;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Settings'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Match Total Games setting
            const Text(
              'Match Total Games:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMatchTotalGames = '1game';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedMatchTotalGames == '1game'
                                ? const Color(0xFF2196F3)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '1 Game',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMatchTotalGames = 'bestof3';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedMatchTotalGames == 'bestof3'
                                ? const Color(0xFF2196F3)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Best of 3',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Game Winning Score setting
            const Text(
              'Game Winning Score:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGameWinningScore = 11;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedGameWinningScore == 11
                                ? const Color(0xFF2196F3)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '11 Points',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGameWinningScore = 15;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedGameWinningScore == 15
                                ? const Color(0xFF2196F3)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '15 Points',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Info tooltip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These settings apply to all games in this round. You can adjust them later from the scoring screen if needed.',
                      style: TextStyle(color: Colors.blue[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Start Scoring button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close settings screen
                  widget.onSettingsSelected(
                    _selectedMatchTotalGames,
                    _selectedGameWinningScore,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Start Scoring',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SemiFinalsScoringScreen has been extracted to playoff_scoring_screen.dart
// Using typedef to maintain backward compatibility
typedef SemiFinalsScoringScreen = PlayoffScoringScreen;
