// ignore_for_file: use_super_parameters, curly_braces_in_flow_control_structures, use_build_context_synchronously, unused_element

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:level_up_app/models/event.dart';
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
import '../services/event_service.dart';
import '../utils/role_utils.dart';
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
  final EventService _eventService = EventService();

  // Division selection state
  String? _selectedDivision;
  String? _previousDivision; // Store previous division for cancel functionality
  List<String> _availableDivisions = [];

  // Cache for stable match generation
  final Map<String, List<Match>> _matchesCache = {};

  // Cache for standings to prevent stack overflow
  List<Standing>? _cachedStandings;
  String? _lastStandingsCacheKey;
  int _standingsUpdateCounter = 0; // Counter to force UI rebuild when standings change

  // Timer for polling score updates
  Timer? _scoreUpdateTimer;
  Map<String, Map<String, int>> _lastKnownScores = {}; // Track last known scores for comparison

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
  // Cache stable playoff matches per division to keep IDs consistent across rebuilds
  final Map<String, List<Match>> _playoffMatchesByDivision = {};
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
    final division = _selectedDivision ?? 'all';
    String cacheKey =
        '${widget.sportName}_${division}_${sortedTeamIds.join('_')}_shuffle_$shouldShuffle';

    // Check for custom schedule first (only if not shuffling)
    if (!shouldShuffle) {
      final customCacheKey = '${widget.sportName}_${division}_${sortedTeamIds.join('_')}_custom';
      if (_matchesCache.containsKey(customCacheKey)) {
        return _matchesCache[customCacheKey]!;
      }
    }

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

  // Get event for this tournament
  Event? _currentEvent;
  
  Future<void> _loadCurrentEvent() async {
    await _eventService.initialize();
    _currentEvent = _eventService.findEventBySportAndTitle(
      widget.sportName,
      widget.tournamentTitle,
    );
    if (mounted) {
      setState(() {});
    }
  }

  // Get teams based on sport type and event division
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

    // Filter by event division if available, otherwise by eventId
    List<dynamic> filteredTeams;
    if (_currentEvent?.division != null) {
      // Filter by event division
      filteredTeams = allTeams.where((team) {
        return team.division == _currentEvent!.division && team.eventId == _currentEvent!.id;
      }).toList();
    } else if (_currentEvent != null) {
      // Filter by eventId only
      filteredTeams = allTeams.where((team) => team.eventId == _currentEvent!.id).toList();
    } else {
      // Fallback: filter by selected division if no event (for backward compatibility)
      if (_selectedDivision != null) {
        filteredTeams = allTeams.where((team) => team.division == _selectedDivision).toList();
      } else {
        filteredTeams = allTeams;
      }
    }

    // Sort teams by ID to ensure consistent order
    filteredTeams.sort((a, b) => a.id.compareTo(b.id));

    return filteredTeams;
  }

  // Get filtered available divisions based on finals completion status
  List<String> get _filteredAvailableDivisions {
    if (_availableDivisions.isEmpty) return [];
    
    // Check which divisions have finals completed
    final completedDivisions = _availableDivisions.where((division) {
      return _finalsCompletedByDivision[division] ?? false;
    }).toList();
    
    final incompleteDivisions = _availableDivisions.where((division) {
      return !(_finalsCompletedByDivision[division] ?? false);
    }).toList();
    
    // If all divisions are completed, show all
    if (incompleteDivisions.isEmpty) {
      return _availableDivisions;
    }
    
    // If only some divisions are completed, show only completed ones
    if (completedDivisions.isNotEmpty) {
      return completedDivisions..sort();
    }
    
    // If none are completed, show all
    return _availableDivisions;
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

    // Get filtered divisions to validate selection
    final filteredDivisions = _filteredAvailableDivisions;
    
    // If no division is selected or selected division is not in filtered list, use saved division or first one
    if (_selectedDivision == null ||
        !filteredDivisions.contains(_selectedDivision)) {
      if (savedDivision != null &&
          filteredDivisions.contains(savedDivision)) {
        // Use saved division if it's still available in filtered list
        _selectedDivision = savedDivision;
        print('DEBUG: Restored saved division: $savedDivision');
      } else {
        // Fall back to first available division from filtered list
        _selectedDivision =
            filteredDivisions.isNotEmpty ? filteredDivisions.first : null;
        print('DEBUG: Using first available division from filtered list: $_selectedDivision');
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
    print('DEBUG: _startScoring called - _selectedMatch: ${_selectedMatch?.id}, day: ${_selectedMatch?.day}');
    
    // Check if user has scoring permissions
    if (!_authService.canScore) {
      print('DEBUG: _startScoring - User does not have scoring permissions');
      _showScoringPermissionDialog();
      return;
    }

    // Prevent cross-tab scoring
    if (_selectedMatch == null) {
      print('DEBUG: _startScoring - No match selected');
      return;
    }
    
    final isInCurrentTab = _isSelectedMatchInCurrentTab();
    print('DEBUG: _startScoring - isInCurrentTab: $isInCurrentTab');
    if (!isInCurrentTab) {
      print('DEBUG: _startScoring - Match is not in current tab, returning');
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
                    onScoresUpdated: (scores) async {
                    // Clear standings cache BEFORE updating scores
                    _cachedStandings = null;
                    _lastStandingsCacheKey = null;
                    
                    // Save scores and clear selection
                    setState(() {
                      _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)] = Map<String, int>.from(scores);
                      _selectedMatch = null;
                      // Increment counter to force UI rebuild of standings
                      _standingsUpdateCounter++;
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
                                  // Store match before clearing selection
                                  final currentMatch = _selectedMatch!;
                                  // Update settings and clear selection to force scoreboard rebuild
                                  setState(() {
                                    _matchFormats[currentTab] = matchTotalGames;
                                    _gameWinningScores[currentTab] =
                                        gameWinningScore;
                                    _selectedMatch =
                                        null; // Clear to force UI rebuild
                                  });
                                  // Save the updated settings
                                  _saveMatchFormats();
                                  _saveScores();
                                  // Reset scores when settings change
                                  setState(() {
                                    _playoffScores[_getPlayoffMatchKey(
                                          currentMatch.id,
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
                                            match: currentMatch,
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
                                                // Save to appropriate round storage
                                                final matchDay = _selectedMatch!.day;
                                                if (matchDay == 'Quarter Finals') {
                                                  await _scoreService
                                                      .saveQuarterFinalsScoresForDivision(
                                                        _selectedDivision ??
                                                            'all',
                                                        _getCurrentDivisionPlayoffScores(),
                                                      );
                                                } else if (matchDay == 'Semi Finals') {
                                                  await _scoreService
                                                      .saveSemiFinalsScoresForDivision(
                                                        _selectedDivision ??
                                                            'all',
                                                        _getCurrentDivisionPlayoffScores(),
                                                      );
                                                } else if (matchDay == 'Finals') {
                                                  await _scoreService
                                                      .saveFinalsScoresForDivision(
                                                        _selectedDivision ??
                                                            'all',
                                                        _getCurrentDivisionPlayoffScores(),
                                                      );
                                                }
                                              } catch (e) {
                                                print(
                                                  'Error saving scores to storage: $e',
                                                );
                                              }
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
          return;
        }
        // If settings are NOT saved yet, open QF Game Settings first
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _QuarterFinalsGameSettingsScreen(
              initialMatchTotalGames: existingFormat ?? '1game',
              initialGameWinningScore: existingScore ?? 11,
              onSettingsSelected: (matchTotalGames, gameWinningScore) {
                final currentMatch = _selectedMatch!;
                setState(() {
                  _matchFormats[currentTab] = matchTotalGames;
                  _gameWinningScores[currentTab] = gameWinningScore;
                });
                _saveMatchFormats();

                // After selecting settings, go to scoring for this match
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SemiFinalsScoringScreen(
                      match: currentMatch,
                      initialScores: _playoffScores[_getPlayoffMatchKey(currentMatch.id)] ?? {},
                      matchFormat: matchTotalGames,
                      gameWinningScore: gameWinningScore,
                      canAdjustSettings: true,
                      isFirstCard: true,
                      onScoresUpdated: (scores) async {
                        setState(() {
                          _playoffScores[_getPlayoffMatchKey(currentMatch.id)] = Map<String, int>.from(scores);
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
                          print('Error saving QF scores to storage: $e');
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
        return;
      }

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

        // If settings are NOT saved yet, use defaults and navigate directly to scoring screen
        // SF and Finals use bestof3 format with 15 points by default
        final defaultFormat = 'bestof3';
        final defaultScore = 15;
        
        print('DEBUG: _startScoring - SF/Finals: No settings saved, using defaults (format: $defaultFormat, score: $defaultScore)');
        
        // Save default settings for this round
        setState(() {
          _matchFormats[currentTab] = defaultFormat;
          _gameWinningScores[currentTab] = defaultScore;
        });
        _saveMatchFormats();

        print('DEBUG: _startScoring - Navigating to SemiFinalsScoringScreen for match: ${_selectedMatch!.id}');
        // Navigate directly to scoring screen with default settings
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SemiFinalsScoringScreen(
                  match: _selectedMatch!,
                  initialScores:
                      _playoffScores[_getPlayoffMatchKey(_selectedMatch!.id)] ?? {},
                  matchFormat: defaultFormat,
                  gameWinningScore: defaultScore,
                  canAdjustSettings: false, // Don't allow settings adjustment for SF/Finals
                  isFirstCard: true, // This is the first card since no scores exist yet
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
                          barrierDismissible: false,
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

                    // Clear standings cache BEFORE updating scores
                    _cachedStandings = null;
                    _lastStandingsCacheKey = null;
                    
                    setState(() {
                      _playoffScores[_getPlayoffMatchKey(
                        _selectedMatch!.id,
                      )] = Map<String, int>.from(scores);
                      // Clear selection after saving scores
                      _selectedMatch = null;
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
                    
                    // Force standings recalculation if this affects preliminary standings
                    if (mounted && !isPlayoffMatch) {
                      final _ = _standings;
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

                  // Clear standings cache BEFORE updating scores to ensure recalculation
                  _cachedStandings = null;
                  _lastStandingsCacheKey = null;
                  
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
                    // Increment counter to force UI rebuild of standings
                    _standingsUpdateCounter++;
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

                      // Also save to specific playoff round storage
                      if (_selectedMatch!.day == 'Quarter Finals') {
                        await _scoreService.saveQuarterFinalsScoresForDivision(
                          _selectedDivision ?? 'all',
                          _getCurrentDivisionPlayoffScores(),
                        );
                      } else if (_selectedMatch!.day == 'Semi Finals') {
                        await _scoreService.saveSemiFinalsScoresForDivision(
                          _selectedDivision ?? 'all',
                          _getCurrentDivisionPlayoffScores(),
                        );
                      } else if (_selectedMatch!.day == 'Finals') {
                        await _scoreService.saveFinalsScoresForDivision(
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

                  // Clear selection after saving
                  // Standings cache was already cleared before updating scores, and counter was incremented
                  if (mounted) {
                    setState(() {
                      _selectedMatch = null;
                      // Don't clear matches cache as it interferes with score persistence
                      // Counter was already incremented above to force UI rebuild
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

  // Check if all Quarter Finals scores are 0-0 (no scores entered or all zero)
  bool get _areAllQuarterFinalsScoresZero {
    final quarterFinals = _getQuarterFinals();
    if (quarterFinals.isEmpty) return true; // No QF matches means all are "zero"

    for (var match in quarterFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        // Check all possible game scores (1, 2, 3)
        for (int game = 1; game <= 3; game++) {
          final team1Score = _getGameScore(match.id, match.team1Id!, game);
          final team2Score = _getGameScore(match.id, match.team2Id!, game);
          
          // If any score exists and is greater than 0, return false
          if ((team1Score != null && team1Score > 0) ||
              (team2Score != null && team2Score > 0)) {
            return false; // Found a non-zero score
          }
        }
      }
    }
    return true; // All scores are 0 or null
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

    final finalsFormat = _matchFormats['Finals'] ?? '1game';
    if (finalsFormat == 'bestof3') {
      // Best of 3: need 2 game wins
      final team1GamesWon = _getGamesWon(match.id, match.team1Id!);
      final team2GamesWon = _getGamesWon(match.id, match.team2Id!);
      if (team1GamesWon >= 2) {
        return match.team1;
      } else if (team2GamesWon >= 2) {
        return match.team2;
      }
    } else {
      // Single game: winner decided by game 1 reaching winning score with 2-point lead
      final winScore = _gameWinningScores['Finals'] ?? 15;
      final t1 = _getGameScore(match.id, match.team1Id!, 1) ?? 0;
      final t2 = _getGameScore(match.id, match.team2Id!, 1) ?? 0;
      if (t1 >= winScore && t1 >= t2 + 2) {
        return match.team1;
      } else if (t2 >= winScore && t2 >= t1 + 2) {
        return match.team2;
      }
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
        // Determine format for SF: 'bestof3' or '1game'
        final sfFormat = _matchFormats['SF'] ?? '1game';
        if (sfFormat == 'bestof3') {
          // Best of 3: a team must have 2 wins
          final team1GamesWon = _getGamesWon(match.id, match.team1Id!);
          final team2GamesWon = _getGamesWon(match.id, match.team2Id!);
          if (team1GamesWon < 2 && team2GamesWon < 2) {
            return false; // Incomplete best-of-3
          }
        } else {
          // Single game: check Game 1 meets winning conditions
          final team1Game1 = _getGameScore(match.id, match.team1Id!, 1) ?? 0;
          final team2Game1 = _getGameScore(match.id, match.team2Id!, 1) ?? 0;
          final winningScore = _gameWinningScores['SF'] ?? 15;
          final team1Wins = team1Game1 >= winningScore && team1Game1 >= team2Game1 + 2;
          final team2Wins = team2Game1 >= winningScore && team2Game1 >= team1Game1 + 2;
          if (!team1Wins && !team2Wins) {
            return false; // Incomplete 1-game match
          }
        }
      }
    }

    // If no actual teams yet (still TBA placeholders), return false
    return hasActualTeams;
  }

  // Check if all preliminary games are completed (have winners)
  bool get _allPreliminaryGamesCompleted {
    final preliminaryMatches = _preliminaryMatches;
    final minScore = _preliminaryGameWinningScore;
    
    for (var match in preliminaryMatches) {
      if (match.team2 == 'TBA') {
        continue; // Skip waiting matches
      }
      
      final team1Id = match.team1Id ?? '';
      final team2Id = match.team2Id ?? '';
      
      // Check game-level format scores
      final team1Score = _getGameScore(match.id, team1Id, 1) ?? 0;
      final team2Score = _getGameScore(match.id, team2Id, 1) ?? 0;
      
      // Check if match has a winner (reached minScore and won by 2)
      final hasWinner = (team1Score >= minScore && team1Score >= team2Score + 2) ||
          (team2Score >= minScore && team2Score >= team1Score + 2);
      
      if (!hasWinner) {
        // No winner yet - match is not completed
        return false;
      }
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

    // If there are 8 teams, playoffs will skip Quarter Finals and go directly to Semi Finals
    // If there are more than 8 teams, playoffs will proceed normally with Quarter Finals
    showDialog(
      context: context,
      barrierDismissible: false,
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
                  // Save navigation state
                  _saveNavigationState();
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
  void _showGamesPerTeamDialog({
    bool isFirstLoad = false,
    int currentTabIndex = 0,
  }) {
    // Only allow scoring users (management, owner, scoring) to see settings dialog
    if (!_authService.canScore) {
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false, // Don't allow dismissing by tapping outside
      builder: (BuildContext context) {
        int selectedGames = _gamesPerTeam;
        int selectedScore = _preliminaryGameWinningScore;
        final sportName = widget.sportName.toLowerCase();
        final isBasketball = sportName.contains('basketball');
        final isVolleyball = sportName.contains('volleyball');
        
        // Create controller for "First to:" input (Basketball/Volleyball)
        final scoreController = TextEditingController(
          text: (isBasketball || isVolleyball) && selectedScore > 0 ? selectedScore.toString() : '',
        );
        bool scoreError = false;

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
                    // Check sport type to determine scoring input method
                    Builder(
                      builder: (context) {
                        final sportName = widget.sportName.toLowerCase();
                        final isPickleball = sportName.contains('pickleball') || sportName.contains('pickelball');
                        final isBasketball = sportName.contains('basketball');
                        final isVolleyball = sportName.contains('volleyball');
                        
                        // For Pickleball: Show 11/15 dropdown
                        if (isPickleball) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Division:',
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
                                      onTap: () => setDialogState(() => selectedScore = 11),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selectedScore == 11
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
                                      onTap: () => setDialogState(() => selectedScore = 15),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selectedScore == 15
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
                            ],
                          );
                        }
                        
                        // For Basketball and Volleyball: Show "First to:" text input
                        if (isBasketball || isVolleyball) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'First to:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: scoreController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Enter points (e.g., 21)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  errorText: scoreError ? 'Please enter a valid number' : null,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (value) {
                                  final parsed = int.tryParse(value);
                                  if (parsed != null && parsed > 0) {
                                    setDialogState(() {
                                      selectedScore = parsed;
                                      scoreError = false;
                                    });
                                  } else if (value.isNotEmpty) {
                                    setDialogState(() {
                                      scoreError = true;
                                    });
                                  } else {
                                    setDialogState(() {
                                      selectedScore = 0;
                                      scoreError = false;
                                    });
                                  }
                                },
                              ),
                            ],
                          );
                        }
                        
                        // Default: Show 11/15 dropdown for other sports
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    onTap: () => setDialogState(() => selectedScore = 11),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: selectedScore == 11
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
                                    onTap: () => setDialogState(() => selectedScore = 15),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: selectedScore == 15
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
                          ],
                        );
                      },
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
                    // Validate "First to:" input for Basketball/Volleyball
                    if ((isBasketball || isVolleyball) && (selectedScore <= 0 || scoreError)) {
                      setDialogState(() {
                        scoreError = true;
                      });
                      return;
                    }
                    
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
                        barrierDismissible: false,
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
                        // Dispose controller after saving
                        scoreController.dispose();
                      });

                      // Save the settings for current division
                      await _scoreService.savePreliminarySettingsForDivision(
                        _selectedDivision ?? 'all',
                        selectedGames,
                        selectedScore,
                      );
                      
                      // Close the settings dialog first
                      Navigator.of(context).pop();
                      
                      // Show prompt: "Do you want to create your own schedule?"
                      _showCustomSchedulePrompt(selectedGames, selectedScore);
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
    // Include both match IDs and score values to ensure cache invalidates when scores change
    final teamsKey = filteredTeams.map((t) => t.id).join('_');
    // Only include scores for the current division in the cache key
    final divisionScores = _getCurrentDivisionScores();
    // Create a hash of all scores (keys + values) to detect any score changes
    // Sort entries to ensure consistent cache key regardless of map iteration order
    final sortedScores = divisionScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final scoresHash = sortedScores.map((e) {
      // Sort score entries within each match for consistency
      final sortedScoreEntries = e.value.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return '${e.key}:${sortedScoreEntries.map((v) => '${v.key}=${v.value}').join(',')}';
    }).join('|');
    final cacheKey = '${teamsKey}_${currentDivision}_$scoresHash';

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
          // Check if this is game-level format (teamId_game1, teamId_game2, etc.) or team-level format
          bool isGameLevelFormat = scores.keys.any((key) => key.contains('_game'));
          
          if (isGameLevelFormat) {
            // For game-level format, check if any game has been played
            bool hasAnyGamePlayed = false;
            for (int gameNum = 1; gameNum <= 3; gameNum++) {
              final team1GameKey = '${match.team1Id!}_game$gameNum';
              final team2GameKey = '${match.team2Id!}_game$gameNum';
              final team1GameScore = scores[team1GameKey] ?? 0;
              final team2GameScore = scores[team2GameKey] ?? 0;
              if (team1GameScore > 0 || team2GameScore > 0) {
                hasAnyGamePlayed = true;
                break;
              }
            }
            
            // Only count if at least one game has been played
            if (hasAnyGamePlayed) {
              if (teamStats.containsKey(match.team1Id!) &&
                  teamStats.containsKey(match.team2Id!)) {
                teamStats[match.team1Id!]!['games'] =
                    (teamStats[match.team1Id!]!['games']! + 1);
                teamStats[match.team2Id!]!['games'] =
                    (teamStats[match.team2Id!]!['games']! + 1);
              }
            }
          } else {
            // Team-level format - check if scores exist
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
        // Handle both team-level format and game-level format
        // For preliminary rounds with multiple games, process all games
        final matchTeam1Id = match.team1Id;
        final matchTeam2Id = match.team2Id;

        if (matchTeam1Id != null && matchTeam2Id != null) {
          // Check if this is game-level format (teamId_game1, teamId_game2, etc.) or team-level format
          bool isGameLevelFormat = scores.keys.any(
            (key) => key.contains('_game'),
          );

          if (isGameLevelFormat) {
            // Process each game separately for multi-game matches
            int team1Wins = 0;
            int team2Wins = 0;
            int totalTeam1Points = 0;
            int totalTeam2Points = 0;

            // Process games 1, 2, 3
            for (int gameNum = 1; gameNum <= 3; gameNum++) {
              final team1GameKey = '${matchTeam1Id}_game$gameNum';
              final team2GameKey = '${matchTeam2Id}_game$gameNum';
              final team1GameScore = scores[team1GameKey] ?? 0;
              final team2GameScore = scores[team2GameKey] ?? 0;

              // Only count if at least one team has scored in this game
              if (team1GameScore > 0 || team2GameScore > 0) {
                totalTeam1Points += team1GameScore;
                totalTeam2Points += team2GameScore;

                // Determine game winner
                if (team1GameScore > team2GameScore) {
                  team1Wins++;
                } else if (team2GameScore > team1GameScore) {
                  team2Wins++;
                }
              }
            }

            // Only process if at least one game has been played
            if (totalTeam1Points > 0 || totalTeam2Points > 0) {
              if (teamStats.containsKey(matchTeam1Id) &&
                  teamStats.containsKey(matchTeam2Id)) {
                // Calculate point differential
                final team1Diff = totalTeam1Points - totalTeam2Points;
                final team2Diff = totalTeam2Points - totalTeam1Points;

                teamStats[matchTeam1Id]!['pointDifference'] =
                    (teamStats[matchTeam1Id]!['pointDifference']! + team1Diff);
                teamStats[matchTeam2Id]!['pointDifference'] =
                    (teamStats[matchTeam2Id]!['pointDifference']! + team2Diff);

                // Determine match winner (best of 3: team with more game wins)
                if (team1Wins > team2Wins) {
                  teamStats[matchTeam1Id]!['wins'] =
                      (teamStats[matchTeam1Id]!['wins']! + 1);
                  teamStats[matchTeam1Id]!['points'] =
                      (teamStats[matchTeam1Id]!['points']! + 1);
                  teamStats[matchTeam2Id]!['losses'] =
                      (teamStats[matchTeam2Id]!['losses']! + 1);
                } else if (team2Wins > team1Wins) {
                  teamStats[matchTeam2Id]!['wins'] =
                      (teamStats[matchTeam2Id]!['wins']! + 1);
                  teamStats[matchTeam2Id]!['points'] =
                      (teamStats[matchTeam2Id]!['points']! + 1);
                  teamStats[matchTeam1Id]!['losses'] =
                      (teamStats[matchTeam1Id]!['losses']! + 1);
                } else if (team1Wins == team2Wins &&
                    (totalTeam1Points > 0 || totalTeam2Points > 0)) {
                  // Draw (equal game wins)
                  teamStats[matchTeam1Id]!['draws'] =
                      (teamStats[matchTeam1Id]!['draws']! + 1);
                  teamStats[matchTeam2Id]!['draws'] =
                      (teamStats[matchTeam2Id]!['draws']! + 1);
                }
              }
            }
          } else {
            // Team-level format (single game or old format)
            final team1Score = scores[matchTeam1Id] ?? 0;
            final team2Score = scores[matchTeam2Id] ?? 0;

            // Only process if both teams have valid IDs and scores are meaningful
            if (team1Score > 0 || team2Score > 0) {
              if (teamStats.containsKey(matchTeam1Id) &&
                  teamStats.containsKey(matchTeam2Id)) {
                // Calculate point differential
                final team1Diff = team1Score - team2Score;
                final team2Diff = team2Score - team1Score;

                teamStats[matchTeam1Id]!['pointDifference'] =
                    (teamStats[matchTeam1Id]!['pointDifference']! + team1Diff);
                teamStats[matchTeam2Id]!['pointDifference'] =
                    (teamStats[matchTeam2Id]!['pointDifference']! + team2Diff);

                // Determine winner
                if (team1Score > team2Score) {
                  teamStats[matchTeam1Id]!['wins'] =
                      (teamStats[matchTeam1Id]!['wins']! + 1);
                  teamStats[matchTeam1Id]!['points'] =
                      (teamStats[matchTeam1Id]!['points']! + 1);
                  teamStats[matchTeam2Id]!['losses'] =
                      (teamStats[matchTeam2Id]!['losses']! + 1);
                } else if (team2Score > team1Score) {
                  teamStats[matchTeam2Id]!['wins'] =
                      (teamStats[matchTeam2Id]!['wins']! + 1);
                  teamStats[matchTeam2Id]!['points'] =
                      (teamStats[matchTeam2Id]!['points']! + 1);
                  teamStats[matchTeam1Id]!['losses'] =
                      (teamStats[matchTeam1Id]!['losses']! + 1);
                } else if (team1Score == team2Score && team1Score > 0) {
                  // Draw (only if both teams scored)
                  teamStats[matchTeam1Id]!['draws'] =
                      (teamStats[matchTeam1Id]!['draws']! + 1);
                  teamStats[matchTeam2Id]!['draws'] =
                      (teamStats[matchTeam2Id]!['draws']! + 1);
                }
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
        final sfFormat = _matchFormats['SF'] ?? '1game';
        if (sfFormat == 'bestof3') {
          // Best of 3: need 2 game wins
          final team1GamesWon = _getGamesWon(match.id, match.team1Id);
          final team2GamesWon = _getGamesWon(match.id, match.team2Id);
          if (team1GamesWon >= 2) {
            winners.add(_teams.firstWhere((t) => t.id == match.team1Id));
          } else if (team2GamesWon >= 2) {
            winners.add(_teams.firstWhere((t) => t.id == match.team2Id));
          }
        } else {
          // Single game: winner decided by game 1 reaching winning score with 2-point lead
          final winScore = _gameWinningScores['SF'] ?? 15;
          final t1 = _getGameScore(match.id, match.team1Id!, 1) ?? 0;
          final t2 = _getGameScore(match.id, match.team2Id!, 1) ?? 0;
          if (t1 >= winScore && t1 >= t2 + 2) {
            winners.add(_teams.firstWhere((t) => t.id == match.team1Id));
          } else if (t2 >= winScore && t2 >= t1 + 2) {
            winners.add(_teams.firstWhere((t) => t.id == match.team2Id));
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

    // Reset state for new sport/event to prevent carryover
    _resetStateForNewEvent();

    // Load navigation state for this event
    _loadNavigationState();

    // Add listeners to clear selected match and save navigation state when switching tabs
    _tabController.addListener(() async {
      if (_tabController.indexIsChanging) {
        // Save scores before switching tabs
        await _saveScores();
        // Save navigation state
        _saveNavigationState();
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
        // Save navigation state
        _saveNavigationState();
        // Refresh standings to show latest data
        _refreshStandings();
        setState(() {
          _selectedMatch = null;
        });
      }
    });

    // Load current event first to ensure teams are filtered correctly
    _loadCurrentEvent();
    
    _loadTeams().then((_) async {
      // Ensure current event is loaded before loading scores
      if (_currentEvent == null) {
        await _loadCurrentEvent();
      }
      await _loadScores();
      // Store initial scores for comparison
      _lastKnownScores = Map<String, Map<String, int>>.from(_matchScores);
      // Start polling for score updates (every 5 seconds)
      _startScorePolling();
      // After loading teams and scores, restore navigation state
      // Use a delay to ensure tab controllers are ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNavigationState();
      });
    });
  }

  // Start polling for score updates
  void _startScorePolling() {
    // Cancel any existing timer
    _scoreUpdateTimer?.cancel();
    
    // Poll every 5 seconds for score updates
    _scoreUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        // Reload scores from storage
        await _loadScores();
        
        // Check if scores have changed by comparing with last known scores
        bool scoresChanged = false;
        
        // Check if match scores changed
        if (_matchScores.length != (_lastKnownScores.length)) {
          scoresChanged = true;
        } else {
          for (var matchId in _matchScores.keys) {
            final currentScores = _matchScores[matchId];
            final lastScores = _lastKnownScores[matchId];
            
            if (lastScores == null) {
              scoresChanged = true;
              break;
            }
            // Use null assertion since we've checked for null above
            if (currentScores?.length != lastScores.length ||
                currentScores.toString() != lastScores.toString()) {
              scoresChanged = true;
              break;
            }
          }
        }
        
        if (scoresChanged && mounted) {
          // Update last known scores
          _lastKnownScores = Map<String, Map<String, int>>.from(_matchScores);
          // Clear cache and refresh UI
          _cachedStandings = null;
          _lastStandingsCacheKey = null;
          _standingsUpdateCounter++;
          setState(() {});
          print('Score update detected - refreshing UI');
        }
      } catch (e) {
        print('Error polling for score updates: $e');
      }
    });
  }

  // Save navigation state for this event
  Future<void> _saveNavigationState() async {
    try {
      await _scoreService.saveNavigationState(
        widget.sportName,
        widget.tournamentTitle,
        _bottomNavIndex,
        _tabController.index,
        _playoffTabController.index,
      );
    } catch (e) {
      print('Error saving navigation state: $e');
    }
  }

  // Load navigation state for this event
  Future<void> _loadNavigationState() async {
    try {
      final navState = await _scoreService.loadNavigationState(
        widget.sportName,
        widget.tournamentTitle,
      );
      
      if (navState != null && mounted) {
        final savedBottomNavIndex = navState['bottomNavIndex'] ?? 0;
        final savedTabIndex = navState['tabIndex'] ?? 0;
        final savedPlayoffTabIndex = navState['playoffTabIndex'] ?? 0;
        
        // Validate indices before restoring
        final validTabIndex = savedTabIndex >= 0 && savedTabIndex < _tabController.length 
            ? savedTabIndex 
            : 0;
        final validPlayoffTabIndex = savedPlayoffTabIndex >= 0 && savedPlayoffTabIndex < _playoffTabController.length 
            ? savedPlayoffTabIndex 
            : 0;
        final validBottomNavIndex = savedBottomNavIndex >= 0 && savedBottomNavIndex <= 1 
            ? savedBottomNavIndex 
            : 0;
        
        if (mounted) {
          setState(() {
            _bottomNavIndex = validBottomNavIndex;
          });
          
          // Restore tab indices after a small delay to ensure controllers are ready
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              if (_tabController.index != validTabIndex) {
                _tabController.animateTo(validTabIndex);
              }
              if (_playoffTabController.index != validPlayoffTabIndex) {
                _playoffTabController.animateTo(validPlayoffTabIndex);
              }
              print('Restored navigation state: bottomNavIndex=$_bottomNavIndex, tabIndex=$validTabIndex, playoffTabIndex=$validPlayoffTabIndex');
            }
          });
        }
      }
    } catch (e) {
      print('Error loading navigation state: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure current event is loaded first (needed for team filtering)
    if (_currentEvent == null) {
      _loadCurrentEvent();
    }
    // Load navigation state when dependencies change (but only once, after initial load)
    // This restores the user's last viewed tab/position for this event
    // Step 1: Ensure divisions and _selectedDivision are initialized
    _updateDivisions().then((_) async {
      // Ensure current event is loaded before proceeding
      if (_currentEvent == null) {
        await _loadCurrentEvent();
      }
      print('DEBUG: didChangeDependencies - _selectedDivision after updateDivisions: $_selectedDivision');
      if (_selectedDivision != null) {
        // Step 2: Load formats for this division
        await _loadMatchFormats();
        print('DEBUG: didChangeDependencies - Loaded match formats for $_selectedDivision');
        // Step 3: Load scores
        await _loadScores();
        print('DEBUG: didChangeDependencies - Loaded scores for $_selectedDivision');
        if (mounted) {
          setState(() {
            // Trigger UI rebuild now that division, formats, and scores are loaded
          });
        }
      }
    });
    _loadFinalsCompleted();
    // Reload teams to ensure we have the latest teams for the current event
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    // Reload teams to ensure we have the latest count from SharedPreferences (shared across accounts)
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

      // Recreate playoff tab controller if there are 8 teams (needs 2 tabs instead of 3)
      final requiredTabCount = _teams.length == 8 ? 2 : 3;
      if (_playoffTabController.length != requiredTabCount) {
        _playoffTabController.dispose();
        _playoffTabController = TabController(
          length: requiredTabCount,
          vsync: this,
        );
        _playoffTabController.addListener(() async {
          if (_playoffTabController.indexIsChanging) {
            await _saveScores();
            _refreshStandings();
            setState(() {
              _selectedMatch = null;
            });
          }
        });
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
                // Only show dialog for scoring users (management, owner, scoring)
                final hasNoScores = _hasNoScoresForCurrentDivision();
                if (hasNoScores && _authService.canScore) {
                  _hasShownGamesPerTeamDialogByDivision[currentDivision] = true;
                  _showGamesPerTeamDialog(
                    isFirstLoad: _isFirstLoad,
                    currentTabIndex: _tabController.index,
                  );
                } else {
                  // Scores exist or user can't score, mark as shown to prevent showing dialog
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
        // Load match formats before setState
        await _loadMatchFormats();

        setState(() {
          // Load scores for the current division
          // Always update scores from storage to ensure we have the latest data
          for (var entry in preliminaryScores.entries) {
            _matchScores[entry.key] = entry.value;
            print(
              'DEBUG: _loadScores - Loaded/Updated score for ${entry.key}: ${entry.value}',
            );
          }
          print(
            'DEBUG: _loadScores - After loading preliminary scores: $_matchScores',
          );

          // Clear standings cache to force recalculation with new scores
          _cachedStandings = null;
          _lastStandingsCacheKey = null;

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

            // Load division-specific playoff scores, always update from storage
            // This ensures we get the latest saved scores when returning to screen
            for (var entry in quarterFinalsScores.entries) {
              _playoffScores[entry.key] = entry.value;
              print(
                'DEBUG: _loadScores - Loaded/Updated QF score for ${entry.key}: ${entry.value}',
              );
            }

            for (var entry in semiFinalsScores.entries) {
              _playoffScores[entry.key] = entry.value;
              print(
                'DEBUG: _loadScores - Loaded/Updated SF score for ${entry.key}: ${entry.value}',
              );
            }

            for (var entry in finalsScores.entries) {
              _playoffScores[entry.key] = entry.value;
              print(
                'DEBUG: _loadScores - Loaded/Updated Finals score for ${entry.key}: ${entry.value}',
              );
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
    // Cancel score polling timer
    _scoreUpdateTimer?.cancel();
    _scoreUpdateTimer = null;
    
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
      // Save scores and navigation state when app resumes to ensure data is persisted
      _saveScores().catchError((e) {
        print('Error saving scores on app resume: $e');
      });
      _saveNavigationState().catchError((e) {
        print('Error saving navigation state on app resume: $e');
      });
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

  // Load match formats from persistent storage
  Future<void> _loadMatchFormats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final division = _selectedDivision ?? 'all';
      _matchFormats['QF'] = prefs.getString('${division}_qfFormat') ?? '1game';
      _matchFormats['SF'] = prefs.getString('${division}_sfFormat') ?? '1game';
      _matchFormats['Finals'] = prefs.getString('${division}_finalsFormat') ?? '1game';
      _gameWinningScores['QF'] = prefs.getInt('${division}_qfWinningScore') ?? 11;
      _gameWinningScores['SF'] = prefs.getInt('${division}_sfWinningScore') ?? 15;
      _gameWinningScores['Finals'] = prefs.getInt('${division}_finalsWinningScore') ?? 15;
      
      print('DEBUG: _loadMatchFormats - Loaded formats for division $division:');
      print('DEBUG: QF format: ${_matchFormats['QF']}');
      print('DEBUG: SF format: ${_matchFormats['SF']}');
      print('DEBUG: Finals format: ${_matchFormats['Finals']}');
    } catch (e) {
      print('Error loading match formats: $e');
    }
  }

  // Save match formats to persistent storage
  Future<void> _saveMatchFormats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final division = _selectedDivision ?? 'all';
      await prefs.setString('${division}_qfFormat', _matchFormats['QF'] ?? '1game');
      await prefs.setString('${division}_sfFormat', _matchFormats['SF'] ?? '1game');
      await prefs.setString('${division}_finalsFormat', _matchFormats['Finals'] ?? '1game');
      await prefs.setInt('${division}_qfWinningScore', _gameWinningScores['QF'] ?? 11);
      await prefs.setInt('${division}_sfWinningScore', _gameWinningScores['SF'] ?? 15);
      await prefs.setInt('${division}_finalsWinningScore', _gameWinningScores['Finals'] ?? 15);
      
      print('DEBUG: _saveMatchFormats - Saved formats for division $division:');
      print('DEBUG: QF format: ${_matchFormats['QF']}');
      print('DEBUG: SF format: ${_matchFormats['SF']}');
      print('DEBUG: Finals format: ${_matchFormats['Finals']}');
    } catch (e) {
      print('Error saving match formats: $e');
    }
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

      // Save preliminary settings (match formats are saved separately when changed)
      await _scoreService.savePreliminarySettingsForDivision(
        _selectedDivision ?? 'all',
        _gamesPerTeamByDivision[_selectedDivision ?? 'all'] ?? 1,
        _preliminaryGameWinningScoreByDivision[_selectedDivision ?? 'all'] ?? 11,
      );
      
      // Update last known scores after saving to prevent false positive updates in polling
      _lastKnownScores = Map<String, Map<String, int>>.from(_matchScores);
      
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
          
          // If in Playoffs tab (_bottomNavIndex == 1), navigate to Standings tab
          if (_bottomNavIndex == 1) {
            // In Playoffs tab, navigate back to Standings tab (Games tab)
            setState(() {
              _bottomNavIndex = 0; // Go to Preliminary Rounds/Standings tab
              _tabController.animateTo(1); // Switch to Standings tab
              // Save navigation state
              _saveNavigationState();
            });
          } else if (_bottomNavIndex == 0 && _tabController.index == 1) {
            // In Standings tab, navigate back to Preliminary tab
            setState(() {
              _tabController.animateTo(0); // Switch to Preliminary tab
              // Save navigation state
              _saveNavigationState();
            });
          } else {
            // In Preliminary tab, navigate back to main screen
            // Save navigation state before navigating away
            _saveNavigationState();
            Navigator.of(context).pop();
          }
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

    // For Semi Finals and Finals, always show best-of-3 and use 15 points
    final bool showBestOf3 = true;

    // Determine winner based on best of 3 (always)
    String? winner;
    final team1GamesWon = _getGamesWon(match.id, team1Id);
    final team2GamesWon = _getGamesWon(match.id, team2Id);
    winner = team1GamesWon >= 2
        ? match.team1Id
        : (team2GamesWon >= 2 ? match.team2Id : null);

    final isSelected = _selectedMatch?.id == match.id;

    // Get actual seeding numbers for the teams
    final team1Seeding = _getTeamSeeding(match.team1Id);
    final team2Seeding = _getTeamSeeding(match.team2Id);

    // Disable editing if Finals has started
    final bool sfLocked = _hasFinalsScores;

    return GestureDetector(
      onTap: (_authService.canScore && !sfLocked)
          ? () {
              setState(() {
                if (_selectedMatch?.id == match.id) {
                  _selectedMatch = null; // toggle off
                } else {
                  _selectedMatch = match; // select
                }
              });
            }
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
                  Builder(
                    builder: (context) {
                      // Calculate games won for display
                      final team1GamesWon = _getGamesWon(match.id, team1Id);
                      final team2GamesWon = _getGamesWon(match.id, team2Id);

                      return Column(
                        children: [
                          // Team 1 row
                          _buildTeamScoreRow(
                            match.team1,
                            team1GamesWon,
                            match.team1Id,
                            winner == match.team1Id,
                            match,
                            team1Seeding,
                            showBestOf3,
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
                            showBestOf3,
                          ),
                        ],
                      );
                    },
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
    bool showBestOf3,
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
        if (showBestOf3) ...[
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
        ],

        // Winner icon - only show if team won 2+ games (for best of 3) or 1 game (for 1 game format)
        Expanded(
          child: Center(
            child:
                isWinner && (showBestOf3 ? gamesWon >= 2 : gamesWon >= 1)
                    ? Icon(
                      match.day == 'Semi Finals'
                          ? Icons.check_circle
                          : match.day == 'Finals'
                              ? Icons.emoji_events
                              : Icons.check_circle,
                      size: match.day == 'Semi Finals' ? 20 : 24,
                      color:
                          match.day == 'Semi Finals'
                              ? const Color.fromARGB(175, 32, 176, 16)
                              : match.day == 'Finals'
                                  ? Colors.yellow[600]
                                  : const Color.fromARGB(175, 32, 176, 16),
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
      // Game 3 wasn't needed - show "--"
      displayText = '--';
    } else if (score != null) {
      // Show the actual score (even if 0)
      displayText = '$score';
    } else {
      // No score entered yet - show "--" for Game 3 in best of 3, "0" for others
      displayText = (gameNumber == 3) ? '--' : '0';
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
      match = _getSemiFinalsDirect().firstWhere(
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
      match = _getSemiFinalsDirect().firstWhere(
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

    // If not found in SF, try Finals (use direct method for consistency)
    if (match.id == '') {
      match = _getFinalsDirect().firstWhere(
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
    // Use the actual winning score from settings based on match day
    final int minScore;
    if (match.day == 'Quarter Finals') {
      minScore = _gameWinningScores['QF'] ?? 11;
    } else if (match.day == 'Semi Finals') {
      minScore = 15;
    } else if (match.day == 'Finals') {
      minScore = 15;
    } else {
      // Default to 15 for unknown match types
      minScore = 15;
    }

    // Team wins if they reach minScore and win by 2
    // Also ensure both teams have scores entered (not just one team with a score)
    if (teamScore == 0 && opponentScore == 0) return false;

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
        // Try QF first, then SF, then Finals
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
          match = _getSemiFinalsDirect().firstWhere(
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

        final opponentId =
            match.team1Id == teamId ? match.team2Id : match.team1Id;
        if (opponentId != null) {
          final opponentScore = _getGameScore(matchId, opponentId, i);
          // Get the correct winning score for this match based on match day
          final minScore =
              match.day == 'Quarter Finals'
                  ? (_gameWinningScores['QF'] ?? 11)
                  : (match.day == 'Semi Finals'
                      ? 15
                      : 15);
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

    // Use stored format to determine if we show best of 3
    final storedFormat = _matchFormats['QF'] ?? '1game';
    final showBestOf3 = storedFormat == 'bestof3';

    // Disable editing if later rounds have started
    final bool qfLocked = _hasSemiFinalsScores || _hasFinalsScores;

    return GestureDetector(
      onTap: (_authService.canScore && !qfLocked)
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
    final hasAnyScores = (game1Score != null && game1Score > 0) || (game2Score != null && game2Score > 0) || (game3Score != null && game3Score > 0);
    // Only show win UI when best of 3 actually means 2 games won
    final isWinner = showBestOf3
      ? (gamesWon >= 2)
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
        // Winner trophy - only if actually won
        Expanded(
          child: Center(
            child: (showBestOf3 && gamesWon >= 2 && hasAnyScores)
                ? Icon(
                    Icons.check_circle,
                    color: Colors.green[500],
                    size: 24,
                  )
                : (!showBestOf3 && isWinner && hasAnyScores)
                    ? Icon(
                        Icons.check_circle,
                        color: Colors.green[500],
                        size: 24,
                      )
                    : const SizedBox(width: 24, height: 24),
          ),
        ),
      ],
    );
  }

  // Build preliminary match card (original format)
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
          _showPreliminaryScoringDialog(match);
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
                                    ? Color.fromARGB(255, 105, 196, 2)
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
                                    ? Color.fromARGB(255, 105, 196, 2)
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

              // Winner label under correct team (left)
              Row(
                children: [
                  // Left: team1 - align Winner left under score
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (winningTeamId == match.team1Id && hasOpponent && winningTeamId != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'Winner',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Color.fromARGB(255, 105, 196, 2),
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Spacer (center area)
                  const SizedBox(width: 16),
                  // Right: team2 - align Winner right under score
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (winningTeamId == match.team2Id && hasOpponent && winningTeamId != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'Winner',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color.fromARGB(255, 105, 196, 2),
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
            // Toggle selection: tap to select, tap again to unselect
            if (_selectedMatch?.id == match.id) {
              _selectedMatch = null;
              _selectedGameNumber = null;
            } else {
              _selectedMatch = match;
              _selectedGameNumber = gameNumber;
            }
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
                              if (match.day == 'Finals') ...[
                                Icon(
                                  Icons.emoji_events,
                                  color: Colors.yellow[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                              ],
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
                              Text(
                                'Winner',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (match.day == 'Finals') ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.emoji_events,
                                  color: Colors.yellow[600],
                                  size: 16,
                                ),
                              ],
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
    // Get fresh standings - this will recalculate if cache is cleared
    final currentStandings = _standings;
    
    return Column(
      children: [
        // Standings Table - scrollable only inside
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                currentStandings.isEmpty
                    ? _buildEmptyStandingsState()
                    : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Header Row - fixed at top
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

                          // Data Rows - scrollable
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: false,
                              // Use update counter as key to force rebuild when standings change
                              key: ValueKey('standings_$_standingsUpdateCounter'),
                              itemCount: currentStandings.length,
                              itemBuilder: (context, index) {
                                if (index >= currentStandings.length) {
                                  return const SizedBox.shrink();
                                }
                                return _buildStandingRow(currentStandings[index]);
                              },
                            ),
                          ),

                          // Legend for playoff qualification - fixed at bottom of table
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

        // Show "View Playoffs" button to ALL users when playoffs have started or finals are completed
        Builder(
          builder: (context) {
            if (_playoffsStarted) {
              final division = _selectedDivision ?? 'all';
              final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;
              
              // Show button to all users when finals are completed
              if (finalsCompleted) {
                return Container(
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
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Playoffs tab
                            setState(() {
                              _bottomNavIndex = 1;
                              // Navigate to the latest playoff round (QF or SF), not directly to Finals
                              int targetPlayoffIndex;
                              if (_teams.length == 8) {
                                // 8-team case: tabs are [SF, Finals]
                                // If SF has scores, go to SF (index 0), otherwise go to Finals (index 1)
                                targetPlayoffIndex = _hasSemiFinalsScores ? 0 : 1;
                              } else {
                                // Normal case: tabs are [QF, SF, Finals]
                                // If QF has scores, go to QF (index 0)
                                // Else if SF has scores, go to SF (index 1)
                                // Otherwise go to Finals (index 2)
                                if (_hasQuarterFinalsScores) {
                                  targetPlayoffIndex = 0; // QF
                                } else if (_hasSemiFinalsScores) {
                                  targetPlayoffIndex = 1; // SF
                                } else {
                                  targetPlayoffIndex = 2; // Finals
                                }
                              }
                              _playoffTabController.animateTo(targetPlayoffIndex);
                            });
                            // Save navigation state after navigating
                            _saveNavigationState();
                          },
                          icon: const Icon(Icons.sports_esports),
                          label: const Text('Check Playoffs score'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // Show "View Playoffs" button to all users when playoffs have started (even if not completed)
              // If user can score, show both "Restart Playoffs" and "Go to Playoffs" buttons side by side
              if (_authService.canScore) {
                final division = _selectedDivision ?? 'all';
                final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;
                
                // Hide restart button if finals are completed
                if (finalsCompleted) {
                  return Container(
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
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to Playoffs tab
                              setState(() {
                                _bottomNavIndex = 1;
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
                  );
                }
                
                // Show both buttons side by side for scoring users
                final allQFZero = _areAllQuarterFinalsScoresZero;
                return Container(
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
                          onPressed: allQFZero ? _restartPlayoffs : null,
                          icon: Icon(allQFZero ? Icons.refresh : Icons.lock),
                          label: const Text('Restart Playoffs'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allQFZero
                                ? const Color.fromARGB(225, 243, 51, 33)
                                : Colors.grey[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Go to Playoffs button (right side)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Playoffs tab
                            setState(() {
                              _bottomNavIndex = 1;
                            });
                            // Save navigation state after navigating
                            _saveNavigationState();
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
                );
              }
              
              // For non-scoring users, show only "Go to Playoffs" button
              return Container(
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
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to Playoffs tab
                          setState(() {
                            _bottomNavIndex = 1;
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
              );
            }
            return const SizedBox.shrink();
          },
        ),
        
        // Start/Restart Playoffs Buttons (only for scoring users when playoffs have started)
        // Hide these buttons when playoffs have started - only show "Go to Playoffs" button
        // Commented out: When playoffs start, only "Go to Playoffs" button should be shown
        /*
        if (_authService.canScore && _playoffsStarted)
          Builder(
            builder: (context) {
              // Check if finals are completed for current division
              final division = _selectedDivision ?? 'all';
              final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;
              
              // Skip showing scoring buttons if finals are completed (view button already shown above)
              if (finalsCompleted) {
                return const SizedBox.shrink();
              }
              
              // When finals are NOT completed - show both buttons
              // Disable if QF has scores (normal case) OR SF has scores (8-team case)
              final hasPlayoffScores =
                  _hasQuarterFinalsScores ||
                  (_teams.length == 8 && _hasSemiFinalsScores);
              return Container(
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
                        onPressed: hasPlayoffScores ? null : _restartPlayoffs,
                        icon: Icon(
                          hasPlayoffScores ? Icons.lock : Icons.refresh,
                        ),
                        label: const Text('Restart Playoffs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hasPlayoffScores
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
                          // Save navigation state after navigating
                          _saveNavigationState();
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
              );
            },
          ),
        */
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
    // Get fresh standings for qualification calculation
    final currentStandings = _standings;
    // Calculate how many teams qualify for playoffs
    int qualifyingTeams = (currentStandings.length / 2).ceil();
    if (qualifyingTeams < 2) qualifyingTeams = 2;
    if (qualifyingTeams > currentStandings.length) {
      qualifyingTeams = currentStandings.length;
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
            child: Row(
              children: [
                Expanded(
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
              ],
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
              style: TextStyle(
                color: standing.pointDifference >= 0
                    ? const Color.fromARGB(255, 30, 255, 0)
                    : const Color.fromARGB(255, 129, 2, 2),
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

    // Use bottom nav index to determine current context
    if (_bottomNavIndex == 0) {
      // Preliminary view
      final isInPreliminary = _preliminaryMatches.any(
        (match) => match.id == _selectedMatch!.id,
      );
      print('DEBUG: _isSelectedMatchInCurrentTab - Preliminary view, isInPreliminary: $isInPreliminary');
      return isInPreliminary;
    }

    if (_bottomNavIndex == 1) {
      // Playoffs view - check playoff sub-tab
      final playoffSubTabIndex = _playoffTabController.index;

      if (_teams.length == 8) {
        // 8-team case: tabs are [SF, Finals]
        if (playoffSubTabIndex == 0) {
          final semiFinals = _getSemiFinals();
          final isInSemiFinals = semiFinals.any((m) => m.id == _selectedMatch!.id);
          print('DEBUG: _isSelectedMatchInCurrentTab - 8-team SF view, playoffSubTabIndex: $playoffSubTabIndex, semiFinals.length: ${semiFinals.length}, selectedMatch.id: ${_selectedMatch!.id}, selectedMatch.day: ${_selectedMatch!.day}, isInSemiFinals: $isInSemiFinals');
          print('DEBUG: 8-team SF match IDs: ${semiFinals.map((m) => '${m.id} (${m.team1} vs ${m.team2})').toList()}');
          // Also check by day property as a fallback
          if (!isInSemiFinals && _selectedMatch!.day == 'Semi Finals') {
            print('DEBUG: Match day is Semi Finals, allowing selection');
            return true;
          }
          return isInSemiFinals;
        } else if (playoffSubTabIndex == 1) {
          final finals = _getFinals();
          final isInFinals = finals.any((m) => m.id == _selectedMatch!.id);
          if (!isInFinals && _selectedMatch!.day == 'Finals') {
            return true;
          }
          return isInFinals;
        }
      } else {
        // Normal case: tabs are [QF, SF, Finals]
        if (playoffSubTabIndex == 0) {
          final quarterFinals = _getQuarterFinals();
          final isInQuarterFinals = quarterFinals.any((m) => m.id == _selectedMatch!.id);
          print('DEBUG: _isSelectedMatchInCurrentTab - QF view, isInQuarterFinals: $isInQuarterFinals');
          if (!isInQuarterFinals && _selectedMatch!.day == 'Quarter Finals') {
            return true;
          }
          return isInQuarterFinals;
        } else if (playoffSubTabIndex == 1) {
          final semiFinals = _getSemiFinals();
          final isInSemiFinals = semiFinals.any((m) => m.id == _selectedMatch!.id);
          print('DEBUG: _isSelectedMatchInCurrentTab - SF view, playoffSubTabIndex: $playoffSubTabIndex, semiFinals.length: ${semiFinals.length}, selectedMatch.id: ${_selectedMatch!.id}, selectedMatch.day: ${_selectedMatch!.day}, isInSemiFinals: $isInSemiFinals');
          print('DEBUG: SF match IDs: ${semiFinals.map((m) => '${m.id} (${m.team1} vs ${m.team2})').toList()}');
          // Also check by day property as a fallback
          if (!isInSemiFinals && _selectedMatch!.day == 'Semi Finals') {
            print('DEBUG: Match day is Semi Finals, allowing selection');
            return true;
          }
          return isInSemiFinals;
        } else if (playoffSubTabIndex == 2) {
          final finals = _getFinals();
          final isInFinals = finals.any((m) => m.id == _selectedMatch!.id);
          if (!isInFinals && _selectedMatch!.day == 'Finals') {
            return true;
          }
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
          // Save navigation state when bottom nav changes
          _saveNavigationState();
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
      // Fixed header (dropdown + tab bar) with scrollable content below
      return Column(
        children: [
          // Division dropdown - fixed at top
          if (_filteredAvailableDivisions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Stack(
                children: [
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
                        items: _filteredAvailableDivisions.map((String division) {
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
                          // Save scores before changing division
                          await _saveScores();
                          
                          _previousDivision = _selectedDivision;
                          setState(() {
                            _selectedDivision = newValue;
                            _selectedMatch = null;
                            _reshuffledMatches = null;
                            _cachedStandings = null;
                            _lastStandingsCacheKey = null;
                            _isFirstLoad = false;
                          });
                          if (newValue != null) {
                            await _scoreService.saveSelectedDivision(
                              widget.sportName,
                              newValue,
                            );
                          }
                          await _loadScores();
                          if (_bottomNavIndex == 1) {
                            final newDivisionPlayoffsStarted =
                                _playoffsStartedByDivision[newValue ?? ''] ?? false;
                            if (!newDivisionPlayoffsStarted) {
                              setState(() {
                                _bottomNavIndex = 0;
                              });
                            }
                          }
                          if (_previousDivision != newValue && _teams.isNotEmpty) {
                            final currentDivision = newValue ?? 'all';
                            final hasShownForDivision =
                                _hasShownGamesPerTeamDialogByDivision[currentDivision] ?? false;
                            if (!hasShownForDivision) {
                              final hasNoScores = _hasNoScoresForCurrentDivision();
                              // Only show dialog for scoring users (management, owner, scoring)
                              if (hasNoScores && _authService.canScore) {
                                _hasShownGamesPerTeamDialogByDivision[currentDivision] = true;
                                _showGamesPerTeamDialog(
                                  isFirstLoad: false,
                                  currentTabIndex: _tabController.index,
                                );
                              } else {
                                _hasShownGamesPerTeamDialogByDivision[currentDivision] = true;
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  // Settings button - only show for scoring users
                  if (_authService.canScore)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: (_playoffsStartedByDivision[_selectedDivision ?? ''] ?? false)
                              ? Colors.grey[400]
                              : const Color(0xFF2196F3),
                        ),
                        iconSize: 18,
                        onPressed: (_playoffsStartedByDivision[_selectedDivision ?? ''] ?? false)
                            ? null
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
          
          // TabBar - fixed below dropdown
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  ),
                ),
              ],
            ),
          ),
          
          // TabBarView - scrollable content (tabs stay fixed above)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPreliminaryRoundsTab(),
                _buildStandingsTab(),
              ],
            ),
          ),
        ],
      );
    } else {
      // Show playoffs content - actual playoff tab structure
      return Builder(
        builder: (context) {
          return Column(
            children: [
              // Division dropdown removed - divisions now come from events
              // Add padding at top
              const SizedBox(height: 16),
              
              // Playoff TabBar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              height: 44,
              child: Theme(
                data: Theme.of(context).copyWith(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  tabs: _teams.length == 8
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
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Playoff TabBarView
          Expanded(
            child: TabBarView(
              controller: _playoffTabController,
              children: _teams.length == 8
                  ? [
                      _buildSemiFinalsTab(),
                      _buildFinalsTab(),
                    ]
                  : [
                      _buildQuarterFinalsTab(),
                      _buildSemiFinalsTab(),
                      _buildFinalsTab(),
                    ],
            ),
          ),
        ],
      );
        },
      );
    }
  }

  // Build preliminary rounds tab
  Widget _buildPreliminaryRoundsTab() {
    if (_preliminaryMatches.isEmpty) {
      return _buildEmptyMatchesState();
    }

    return Column(
      children: [
        // List of matches - scrollable only inside
        Expanded(
          child: ListView.builder(
            shrinkWrap: false,
            padding: const EdgeInsets.all(16),
            itemCount: _preliminaryMatches.length,
            itemBuilder: (context, index) {
              final match = _preliminaryMatches[index];
              return _buildPreliminaryMatchCard(match);
            },
          ),
        ),
        // Fixed bottom action buttons - only show if finals are NOT completed
        Builder(
          builder: (context) {
            final division = _selectedDivision ?? 'all';
            final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;
            
            if (finalsCompleted || !_authService.canScore) {
              return const SizedBox.shrink();
            }
            
            return SafeArea(
              top: false,
              left: false,
              right: false,
              child: Container(
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
                child: _allPreliminaryGamesCompleted
                    ? ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to Standings tab
                          setState(() {
                            _tabController.animateTo(1); // Switch to Standings tab
                          });
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('See Standing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed:
                            _hasNoScores() ? _reshuffleTeams : _showReshuffleScoresDialog,
                        icon: Icon(
                          _hasNoScores() ? Icons.shuffle : Icons.lock,
                          size: 18,
                        ),
                        label: Text(_allPreliminaryGamesCompleted 
                            ? 'Games Completed' 
                            : 'Reshuffle Teams'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasNoScores() ? const Color(0xFF2196F3) : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
              ),
            );
          },
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
                    padding: const EdgeInsets.all(20),
                    itemCount: quarterFinals.length,
                    itemBuilder: (context, index) {
                      return _buildQuarterFinalsScoreboard(
                        quarterFinals[index],
                        index + 1,
                      );
                    },
                  ),
        ),

        // Start Scoring Button for Quarter Finals
        Builder(
          builder: (context) {
            final division = _selectedDivision ?? 'all';
            final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;
            
            // Don't show "Select a Match" button if finals are completed
            if (finalsCompleted || quarterFinals.isEmpty || !_authService.canScore) {
              // When finals are completed, don't show any button (just like SF tab)
              return const SizedBox.shrink();
            }
            
            return Container(
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
                    child: ElevatedButton.icon(
                      onPressed:
                          !_authService.canScore
                              ? null
                              : (_selectedMatch != null &&
                                  _isSelectedMatchInCurrentTab())
                                  ? _startScoring
                                  : null,
                      icon: Icon(
                        _hasScoresForSelectedMatch() ? Icons.edit : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(
                        _selectedMatch != null && _isSelectedMatchInCurrentTab()
                            ? (_hasScoresForSelectedMatch() ? 'Edit Scoring' : 'Start Scoring')
                            : 'Select a Match',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_selectedMatch != null && _isSelectedMatchInCurrentTab())
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

                // Start Semi Finals Button (disabled until all QF scores are set, or changed to "Check SF Score" if finals done)
                if (_authService.canScore)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: Builder(
                        builder: (context) {
                          final division = _selectedDivision ?? 'all';
                          final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;
                          
                          return ElevatedButton.icon(
                            onPressed:
                                _allQuarterFinalsScoresSet
                                    ? () {
                                      // Navigate to Semi Finals tab (0 if 8-team bracket, else 1)
                                      final targetIndex = _teams.length == 8 ? 0 : 1;
                                      _playoffTabController.animateTo(targetIndex);
                                    }
                                    : null, // disable until all QF scores are set
                            icon: Icon(
                              _allQuarterFinalsScoresSet
                                  ? (finalsCompleted ? Icons.score : Icons.arrow_forward)
                                  : Icons.lock,
                            ),
                            label: Text(
                              _allQuarterFinalsScoresSet
                                  ? (finalsCompleted ? 'Check SF Score' : 'Go to Semi Finals')
                                  : 'Complete all Games',
                              textAlign: TextAlign.center,
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
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
          },
        ),
      ],
    );
  }

  // Build Start Scoring button for playoff tabs
  Widget _buildStartScoringButton(bool isLocked) {
    // Force rebuild when _selectedMatch changes by using it in the build
    final selectedMatch = _selectedMatch;
    final bool isMatchSelected = selectedMatch != null && _isSelectedMatchInCurrentTab();
    final bool hasScores = isMatchSelected && _hasScoresForSelectedMatch();
    
    // Debug logging
    if (selectedMatch != null) {
      print('DEBUG: _buildStartScoringButton - selectedMatch.id: ${selectedMatch.id}, isMatchSelected: $isMatchSelected, isLocked: $isLocked, canScore: ${_authService.canScore}');
    }
    
    return ElevatedButton.icon(
      onPressed:
          (!_authService.canScore || isLocked)
              ? null
              : isMatchSelected
              ? _startScoring
              : null,
      icon: Icon(
        hasScores ? Icons.edit : Icons.play_arrow,
        size: 18,
      ),
      label: Text(
        !_authService.canScore
            ? 'Access Restricted'
            : isLocked
            ? 'Finals Started'
            : isMatchSelected
            ? (hasScores
                ? 'Edit Scoring'
                : 'Start Scoring')
            : 'Select a Match',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            !_authService.canScore
                ? Colors.red[400]
                : isLocked
                ? Colors.grey[400]
                : isMatchSelected
                ? const Color(0xFF2196F3)
                : Colors.grey[400],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Build Semi Finals tab
  Widget _buildSemiFinalsTab() {
    final semiFinals = _getSemiFinals();

    // Disable editing if Finals has started
    final bool sfLocked = _hasFinalsScores;

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

        // Start Scoring Button for Semi Finals - Hide entire button row when finals are completed
        Builder(
          builder: (context) {
            final division = _selectedDivision ?? 'all';
            final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;
            
            if (finalsCompleted || semiFinals.isEmpty || !_authService.canScore) {
              return const SizedBox.shrink();
            }
            
            return Container(
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
                  child: _buildStartScoringButton(sfLocked),
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
                                  // Navigate to Finals tab (1 if 8-team bracket, else 2)
                                  final targetIndex = _teams.length == 8 ? 1 : 2;
                                  _playoffTabController.animateTo(targetIndex);
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
          );
          },
        ),
      ],
    );
  }

  // Build Finals tab
  Widget _buildFinalsTab() {
    final finals = _getFinals();
    final division = _selectedDivision ?? 'all';
    final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;

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
                      final match = finals[index];
                      return GestureDetector(
                        onTap: (_authService.canScore && !finalsCompleted)
                            ? () {
                                setState(() {
                                  if (_selectedMatch?.id == match.id) {
                                    _selectedMatch = null;
                                  } else {
                                    _selectedMatch = match;
                                  }
                                });
                              }
                            : null,
                        child: _buildSemiFinalsScoreboard(
                          match,
                          index + 1,
                        ),
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
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  const Color(0xFF0F3460),
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

        // Finals action buttons - hide when finals are completed (just like QF and SF)
        if (finals.isNotEmpty && _authService.canScore && !finalsCompleted)
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
                // Start/Edit scoring
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_selectedMatch != null)
                        ? _startScoring
                        : null,
                    icon: const Icon(Icons.sports_score),
                    label: Text(
                      (_selectedMatch != null && _hasScoresForSelectedMatch()) ? 'Edit Scoring' : 'Start Scoring',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMatch != null
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
                // Complete Final button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_getFinalsWinner() != null)
                        ? () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => AlertDialog(
                                title: const Text('Complete Finals?'),
                                content: const Text('Are you sure you want to complete the final? You will not be able to edit the score again.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Yes, Complete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setState(() {
                                _finalsCompletedByDivision[division] = true;
                              });
                              await _saveFinalsCompleted();
                              
                              // Mark the event as completed
                              await _eventService.initialize();
                              final event = _eventService.findEventBySportAndTitle(
                                widget.sportName,
                                widget.tournamentTitle,
                              );
                              if (event != null) {
                                await _eventService.markEventCompleted(event.id);
                                print('Event ${event.id} marked as completed');
                              } else {
                                print('ERROR: Could not find event to mark as completed - sportName: "${widget.sportName}", tournamentTitle: "${widget.tournamentTitle}"');
                              }
                            }
                          }
                        : null,
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Complete Final'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_getFinalsWinner() != null)
                          ? const Color(0xFF38A169)
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
    final division = _selectedDivision ?? 'all';
    if (!_playoffsStarted) {
      return _getQuarterFinalsPlaceholders();
    }
    // If no cached QF matches for this division, generate and cache (and persist!).
    if (_playoffMatchesByDivision[division] == null) {
      final matches = _getQuarterFinalsDirect(); // existing logic
      _playoffMatchesByDivision[division] = matches;
      // TODO: Optionally persist to disk here if you want robust crash recovery (see ScoreService/SharedPreferences)
      print('DEBUG play: Generated new QF for division $division:');
      for (var m in matches) print('  ${m.id}: ${m.team1} vs ${m.team2}');
    } else {
      print('DEBUG play: Loaded cached QF for division $division:');
      for (var m in _playoffMatchesByDivision[division]!) print('  ${m.id}: ${m.team1} vs ${m.team2}');
    }
    return _playoffMatchesByDivision[division]!;
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

  // Build reset scores widget for Playoffs tab
  Widget _buildResetScoresWidget() {
    // Only show for owner users
    if (!RoleUtils.isOwner(_authService.currentUser?.role ?? 'user')) {
      return const SizedBox.shrink();
    }

    // Check if finals is completed for current division
    final division = _selectedDivision ?? 'all';
    final bool finalsCompleted = _finalsCompletedByDivision[division] ?? false;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: IconButton(
        onPressed: finalsCompleted ? null : _showResetPlayoffScoresDialog,
        icon: Icon(
          Icons.refresh,
          color: finalsCompleted ? Colors.grey[400] : Colors.red[600],
          size: 20,
        ),
        tooltip: finalsCompleted
            ? 'Reset disabled - Finals completed'
            : 'Reset All Playoff Scores',
        style: IconButton.styleFrom(
          backgroundColor: finalsCompleted ? Colors.grey[100] : Colors.red[50],
          foregroundColor: finalsCompleted ? Colors.grey[400] : Colors.red[600],
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: finalsCompleted ? Colors.grey[300]! : Colors.red[200]!,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  // Show confirmation dialog for resetting all playoff scores
  void _showResetPlayoffScoresDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset All Playoff Scores?'),
          content: const Text(
            'This will reset all scores for Quarter Finals, Semi Finals, and Finals. This action cannot be undone. Do you want to continue?',
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
                Navigator.of(context).pop();
                await _resetAllPlayoffScores();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset All Scores'),
            ),
          ],
        );
      },
    );
  }

  // Reset all playoff scores (QF, SF, Finals)
  Future<void> _resetAllPlayoffScores() async {
    try {
      // Clear all playoff scores from both storage mechanisms
      _matchScores.removeWhere((key, value) => 
        key.contains('_QF_') || 
        key.contains('_SF_') || 
        key.contains('_Finals_')
      );
      
      // Clear playoff scores from the main playoff scores storage
      _playoffScores.clear();
      
      print('DEBUG: Reset - Cleared _matchScores and _playoffScores');
      print('DEBUG: Reset - _matchScores keys: ${_matchScores.keys.toList()}');
      print('DEBUG: Reset - _playoffScores keys: ${_playoffScores.keys.toList()}');

      // Reset playoff state
      setState(() {
        _playoffsStartedByDivision.clear();
        _selectedMatch = null;
        _reshuffledMatches = null;
        _cachedStandings = null;
        _lastStandingsCacheKey = null;
      });

      // Save the cleared scores
      await _scoreService.savePreliminaryScoresForDivision(
        _selectedDivision ?? 'all',
        _getCurrentDivisionScores(),
      );

      // Clear playoff scores from persistent storage
      await _scoreService.savePlayoffScores({});
      await _scoreService.saveQuarterFinalsScoresForDivision(
        _selectedDivision ?? 'all',
        {},
      );
      await _scoreService.saveSemiFinalsScoresForDivision(
        _selectedDivision ?? 'all',
        {},
      );
      await _scoreService.saveFinalsScoresForDivision(
        _selectedDivision ?? 'all',
        {},
      );

      // Clear playoff started flags for all divisions
      for (String division in _availableDivisions) {
        await _scoreService.savePlayoffsStartedForDivision(division, false);
      }

      // Go to Standings tab (tab 0) if on Playoffs
      if (_tabController.index == 1) {
        setState(() {
          _tabController.index = 0;
        });
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All playoff scores have been reset'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error resetting playoff scores: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting scores: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Show scoring dialog for preliminary rounds
  void _showPreliminaryScoringDialog(Match match) {
    final team1Id = match.team1Id ?? '';
    final team2Id = match.team2Id ?? '';
    final team1Score = _getGameScore(match.id, team1Id, 1) ?? 0;
    final team2Score = _getGameScore(match.id, team2Id, 1) ?? 0;
    final minScore = _preliminaryGameWinningScore;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _PreliminaryScoringDialog(
          match: match,
          team1Score: team1Score,
          team2Score: team2Score,
          minScore: minScore,
          parentContext: context, // Pass parent context for snackbar
          onSave: (newTeam1Score, newTeam2Score) async {
            // Update scores in game-level format
            final scoresToSave = {
              '${team1Id}_game1': newTeam1Score,
              '${team2Id}_game1': newTeam2Score,
            };
            
            setState(() {
              _matchScores[match.id] = scoresToSave;
              _cachedStandings = null;
              _lastStandingsCacheKey = null;
              _standingsUpdateCounter++;
            });
            
            await _saveScores();
            
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
              // Show success snackbar after dialog closes
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Score saved successfully',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.fixed,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _showTeamRegisteredDialog() {
    if (!_authService.canScore) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final List<dynamic> teams = _teams;
          return AlertDialog(
            title: const Text("Registered Teams (Admin)"),
            content: Container(
              width: 320,
              constraints: const BoxConstraints(maxHeight: 400),
              child: teams.isEmpty
                  ? const Text('No teams registered.')
                  : ListView.builder(
                      itemCount: teams.length,
                      itemBuilder: (context, idx) {
                        final team = teams[idx];
                        return ListTile(
                          title: Text(team.name),
                          subtitle: team.division != null ? Text('Division: ${team.division}') : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx2) => AlertDialog(
                                  title: const Text('Delete Team'),
                                  content: Text('Are you sure you want to delete ${team.name}?'),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () => Navigator.pop(ctx2, false),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx2, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                setState(() {
                                  if (widget.sportName.toLowerCase().contains('basketball')) {
                                    try {
                                      _teamService.deleteTeam(team.id);
                                    } catch (_) {}
                                  } else if (widget.sportName.toLowerCase().contains('pickleball')) {
                                    try {
                                      _pickleballTeamService.deleteTeam(team.id);
                                    } catch (_) {}
                                  }
                                });
                                await _loadTeams();
                                setState(() {});
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  // TODO: Call _showTeamRegisteredDialog() from Admin tab or relevant location (e.g., an admin button/action)

  void _startSemiFinalsScoringFor(Match match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SemiFinalsScoringScreen(
          match: match,
          initialScores: _playoffScores[_getPlayoffMatchKey(match.id)],
          matchFormat: 'bestof3',
          gameWinningScore: 15,
          canAdjustSettings: false,
          isFirstCard: false,
          onScoresUpdated: (scores) async {
            setState(() {
              _playoffScores[_getPlayoffMatchKey(match.id)] = Map<String, int>.from(scores);
              _selectedMatch = null;
              _cachedStandings = null;
              _lastStandingsCacheKey = null;
            });
            try {
              await _scoreService.savePlayoffScores(_playoffScores);
              await _scoreService.saveSemiFinalsScoresForDivision(
                _selectedDivision ?? 'all',
                _getCurrentDivisionPlayoffScores(),
              );
            } catch (e) {
              print('Error saving SF scores (direct): $e');
            }
          },
        ),
      ),
    );
  }

  Future<void> _saveFinalsCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final division = _selectedDivision ?? 'all';
      await prefs.setBool('finals_completed_${widget.sportName}_$division', _finalsCompletedByDivision[division] ?? false);
    } catch (e) {
      print('Error saving finals completed: $e');
    }
  }

  Future<void> _loadFinalsCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final division = _selectedDivision ?? 'all';
      final v = prefs.getBool('finals_completed_${widget.sportName}_$division') ?? false;
      _finalsCompletedByDivision[division] = v;
    } catch (e) {
      print('Error loading finals completed: $e');
    }
  }

  // Reset state for new event/sport to prevent carryover
  void _resetStateForNewEvent() {
    // Clear playoff-related state maps
    _playoffsStartedByDivision.clear();
    _finalsCompletedByDivision.clear();
    _playoffScores.clear();
    _playoffMatchesByDivision.clear();
    _matchFormats.clear();
    _gameWinningScores.clear();
    _cachedStandings = null;
    _lastStandingsCacheKey = null;
    _standingsUpdateCounter = 0;
    _selectedMatch = null;
    _justRestartedPlayoffs = false;
    _matchesCache.clear();
    _reshuffledMatches = null;
    // DO NOT clear _currentEvent - it's needed to filter teams correctly
    // _currentEvent will be loaded in _loadCurrentEvent()
    print('Reset state for new event: ${widget.sportName} - ${widget.tournamentTitle}');
  }

  // Show prompt: "Do you want to create your own schedule?"
  void _showCustomSchedulePrompt(int selectedGames, int selectedScore) {
    // Capture values before dialog builder
    final division = _selectedDivision ?? 'all';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Custom Schedule'),
          content: const Text('Do you want to create your own schedule?'),
          actions: [
            TextButton(
              onPressed: () async {
                // Clear custom schedule flag to use automatic schedule
                await _scoreService.saveCustomScheduleForDivision(division, false);
                Navigator.of(context).pop(); // Close prompt
                // Continue with normal automatic Preliminary Rounds flow
                // (just close dialog, normal flow continues)
              },
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close prompt
                // Open custom schedule dialog
                _showCustomScheduleDialog(selectedGames, selectedScore);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('YES'),
            ),
          ],
        );
      },
    );
  }

  // Show custom schedule dialog with two columns
  void _showCustomScheduleDialog(int selectedGames, int selectedScore) {
    // Capture values before dialog builder
    final allTeams = _teams;
    final division = _selectedDivision ?? 'all';
    final sportName = widget.sportName;
    
    if (allTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No teams registered. Cannot create schedule.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Initialize state for custom schedule
    List<dynamic> availableTeams = List.from(allTeams);
    List<Map<String, dynamic>> matchups = []; // List of {team1: team, team2: team}
    String? selectedTeam1;
    String? selectedTeam2;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter available teams (teams not yet used in matchups)
            final usedTeamIds = <String>{};
            for (var matchup in matchups) {
              usedTeamIds.add(matchup['team1'].id);
              usedTeamIds.add(matchup['team2'].id);
            }
            final unassignedTeams = availableTeams.where((team) => !usedTeamIds.contains(team.id)).toList();

            // Check if all teams are assigned
            final allTeamsAssigned = unassignedTeams.isEmpty && matchups.isNotEmpty;

            return AlertDialog(
              title: const Text('Create Custom Schedule'),
              contentPadding: const EdgeInsets.all(16),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Row(
                  children: [
                    // Left Column - List of Teams
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Available Teams',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: unassignedTeams.isEmpty
                                  ? Center(
                                      child: Text(
                                        allTeamsAssigned
                                            ? 'All teams assigned'
                                            : 'No teams available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: unassignedTeams.length,
                                      itemBuilder: (context, index) {
                                        final team = unassignedTeams[index];
                                        return ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            radius: 16,
                                            child: Text(team.name[0].toUpperCase()),
                                          ),
                                          title: Text(
                                            team.name,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          subtitle: team.division != null
                                              ? Text(
                                                  team.division,
                                                  style: const TextStyle(fontSize: 12),
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right Column - Create Matchups
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Create Matchups',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Team 1 and Team 2 selectors
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            decoration: const InputDecoration(
                                              labelText: 'Team 1',
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            value: selectedTeam1,
                                            items: unassignedTeams.map((team) {
                                              return DropdownMenuItem<String>(
                                                value: team.id,
                                                child: Text(
                                                  team.name,
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setDialogState(() {
                                                selectedTeam1 = value;
                                              });
                                            },
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            'VS',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2196F3),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            decoration: const InputDecoration(
                                              labelText: 'Team 2',
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            value: selectedTeam2,
                                            items: unassignedTeams
                                                .where((team) => team.id != selectedTeam1)
                                                .map((team) {
                                              return DropdownMenuItem<String>(
                                                value: team.id,
                                                child: Text(
                                                  team.name,
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setDialogState(() {
                                                selectedTeam2 = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Add Matchup button
                                    ElevatedButton.icon(
                                      onPressed: (selectedTeam1 != null &&
                                              selectedTeam2 != null &&
                                              selectedTeam1 != selectedTeam2)
                                          ? () {
                                              // Find team objects
                                              final team1 = allTeams.firstWhere((t) => t.id == selectedTeam1);
                                              final team2 = allTeams.firstWhere((t) => t.id == selectedTeam2);

                                              // Add matchup
                                              setDialogState(() {
                                                matchups.add({
                                                  'team1': team1,
                                                  'team2': team2,
                                                });
                                                selectedTeam1 = null;
                                                selectedTeam2 = null;
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Matchup'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2196F3),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    // List of created matchups
                                    if (matchups.isEmpty)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'No matchups created yet',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ...matchups.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final matchup = entry.value;
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF2196F3),
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              '${matchup['team1'].name} vs ${matchup['team2'].name}',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                              onPressed: () {
                                                setDialogState(() {
                                                  matchups.removeAt(index);
                                                });
                                              },
                                            ),
                                          ),
                                        );
                                      }),
                                    // Show message if teams are left unassigned
                                    if (!allTeamsAssigned && matchups.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[50],
                                            border: Border.all(color: Colors.orange[200]!),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${unassignedTeams.length} team(s) remaining. All teams must be assigned before creating the schedule.',
                                            style: TextStyle(
                                              color: Colors.orange[800],
                                              fontSize: 12,
                                            ),
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
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Show cancel confirmation
                    showDialog(
                      context: context,
                      builder: (BuildContext cancelContext) {
                        return AlertDialog(
                          title: const Text('Cancel Custom Schedule?'),
                          content: const Text('Are you sure you want to cancel creating a custom schedule?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(cancelContext).pop(),
                              child: const Text('NO'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                // Clear custom schedule flag when canceling
                                await _scoreService.saveCustomScheduleForDivision(division, false);
                                
                                Navigator.of(cancelContext).pop(); // Close cancel confirmation
                                Navigator.of(dialogContext).pop(); // Close custom schedule dialog
                                
                                // Return to regular Schedule screen (already in progress)
                                // The cache will be cleared when the screen rebuilds
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('YES'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: allTeamsAssigned
                      ? () async {
                          // Create matches from custom schedule
                          List<Match> customMatches = [];
                          int matchId = 1;
                          int courtNumber = 1;
                          int timeSlot = 10;

                          for (var matchup in matchups) {
                            final team1 = matchup['team1'];
                            final team2 = matchup['team2'];
                            final divisionMatchId = '${division}_$matchId';

                            customMatches.add(
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
                              ),
                            );

                            matchId++;
                            courtNumber++;
                            if (courtNumber > 4) {
                              courtNumber = 1;
                              timeSlot++;
                            }
                          }

                          // Save custom matches to cache
                          final sortedTeamIds = allTeams.map((t) => t.id).toList()..sort();
                          String cacheKey = '${sportName}_${division}_${sortedTeamIds.join('_')}_custom';
                          
                          // Access parent state via closure to update cache
                          // Since we're in a method of _SportScheduleScreenState, we can access instance variables
                          _matchesCache[cacheKey] = customMatches;
                          _reshuffledMatches = null;

                          // Save custom schedule flag
                          await _scoreService.saveCustomScheduleForDivision(division, true);

                          if (mounted) {
                            Navigator.of(dialogContext).pop(); // Close dialog
                            // Refresh the UI to show custom matches
                            setState(() {});
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allTeamsAssigned ? const Color(0xFF38A169) : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    allTeamsAssigned ? 'Create Schedule' : 'Assign All Teams',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            );
          },
        );
      },
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
                  // Close settings screen and notify parent to update
                  Navigator.pop(context);
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

// Dialog widget for preliminary rounds scoring
class _PreliminaryScoringDialog extends StatefulWidget {
  final Match match;
  final int team1Score;
  final int team2Score;
  final int minScore;
  final BuildContext parentContext; // Parent context for showing snackbars
  final Function(int, int) onSave;

  const _PreliminaryScoringDialog({
    required this.match,
    required this.team1Score,
    required this.team2Score,
    required this.minScore,
    required this.parentContext,
    required this.onSave,
  });

  @override
  State<_PreliminaryScoringDialog> createState() => _PreliminaryScoringDialogState();
}

class _PreliminaryScoringDialogState extends State<_PreliminaryScoringDialog> {
  late int _team1Score;
  late int _team2Score;
  late int _initialTeam1Score;
  late int _initialTeam2Score;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _team1Score = widget.team1Score;
    _team2Score = widget.team2Score;
    _initialTeam1Score = widget.team1Score;
    _initialTeam2Score = widget.team2Score;
  }
  
  bool get _hasChanges {
    return _team1Score != _initialTeam1Score || _team2Score != _initialTeam2Score;
  }
  
  void _handleCancel() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text('You have unsaved changes. Are you sure you want to cancel? Changes will not be saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep Editing'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close confirmation dialog
                  Navigator.of(context).pop(); // Close scoring dialog
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Discard'),
              ),
            ],
          );
        },
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleDecreaseScore(bool isTeam1) {
    setState(() {
      if (isTeam1) {
        final currentScore = _team1Score;
        final newScore = currentScore - 1;
        _team1Score = newScore < 0 ? 0 : newScore;
        
        // Adjust opponent score if at/above minScore (use current value before update)
        if (_team2Score >= widget.minScore) {
          final requiredOpponentScore = _team1Score + 2;
          if (requiredOpponentScore >= widget.minScore) {
            _team2Score = requiredOpponentScore;
          } else {
            // Can't go below minScore, keep opponent at minScore
            _team2Score = widget.minScore;
          }
        }
      } else {
        final currentScore = _team2Score;
        final newScore = currentScore - 1;
        _team2Score = newScore < 0 ? 0 : newScore;
        
        // Adjust opponent score if at/above minScore (use current value before update)
        if (_team1Score >= widget.minScore) {
          final requiredOpponentScore = _team2Score + 2;
          if (requiredOpponentScore >= widget.minScore) {
            _team1Score = requiredOpponentScore;
          } else {
            // Can't go below minScore, keep opponent at minScore
            _team1Score = widget.minScore;
          }
        }
      }
    });
  }

  void _handleIncreaseScore(bool isTeam1) {
    setState(() {
      if (isTeam1) {
        // Don't increment if team has already won
        if (_isTeam1MaxReached()) {
          return;
        }
        _team1Score++;
      } else {
        // Don't increment if team has already won
        if (_isTeam2MaxReached()) {
          return;
        }
        _team2Score++;
      }
    });
  }
  
  // Check if team has reached max score
  // Disable increment if:
  // 1. Team has won (reached minScore and leading by 2+)
  // 2. Team is at minScore and opponent is not at minScore (team has won)
  // Allow increment if:
  // 1. Teams are tied at minScore (11-11, 15-15) - can continue to break tie
  // 2. Team is below minScore
  // 3. Team is at minScore but opponent is also at minScore and not leading by 2+
  bool _isTeam1MaxReached() {
    // If team1 has won (reached minScore and leading by 2+), disable increment
    if (_team1Score >= widget.minScore && _team1Score >= _team2Score + 2) {
      return true; // Team has won, disable further increment
    }
    
    // If team1 is at minScore but team2 is below minScore, team1 has won
    if (_team1Score >= widget.minScore && _team2Score < widget.minScore) {
      // Check if team1 is leading by 2+
      if (_team1Score >= _team2Score + 2) {
        return true; // Team has won
      }
    }
    
    // If both teams are at minScore and tied, allow continuing (11-11, 15-15)
    if (_team1Score == widget.minScore && _team2Score == widget.minScore) {
      return false; // Allow continuing when tied at minScore
    }
    
    // If team1 is at minScore but team2 is also at minScore and team1 is not leading by 2+
    // This means it's still ongoing (could be 11-10, 15-14, etc.), allow continuing
    if (_team1Score == widget.minScore && _team2Score == widget.minScore - 1) {
      return false; // Still ongoing, allow continuing
    }
    
    return false; // Default: allow increment
  }
  
  bool _isTeam2MaxReached() {
    // If team2 has won (reached minScore and leading by 2+), disable increment
    if (_team2Score >= widget.minScore && _team2Score >= _team1Score + 2) {
      return true; // Team has won, disable further increment
    }
    
    // If team2 is at minScore but team1 is below minScore, team2 has won
    if (_team2Score >= widget.minScore && _team1Score < widget.minScore) {
      // Check if team2 is leading by 2+
      if (_team2Score >= _team1Score + 2) {
        return true; // Team has won
      }
    }
    
    // If both teams are at minScore and tied, allow continuing (11-11, 15-15)
    if (_team2Score == widget.minScore && _team1Score == widget.minScore) {
      return false; // Allow continuing when tied at minScore
    }
    
    // If team2 is at minScore but team1 is also at minScore and team2 is not leading by 2+
    // This means it's still ongoing (could be 11-10, 15-14, etc.), allow continuing
    if (_team2Score == widget.minScore && _team1Score == widget.minScore - 1) {
      return false; // Still ongoing, allow continuing
    }
    
    return false; // Default: allow increment
  }
  
  // Check if a team has won (reached minScore and won by 2)
  bool _hasTeam1Won() {
    return _team1Score >= widget.minScore && _team1Score >= _team2Score + 2;
  }
  
  bool _hasTeam2Won() {
    return _team2Score >= widget.minScore && _team2Score >= _team1Score + 2;
  }

  void _saveScores() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Allow resetting to 0-0
      if (_team1Score == 0 && _team2Score == 0) {
        widget.onSave(0, 0);
        return;
      }

      // If any score is entered (not 0-0), at least one team must reach minScore
      if (_team1Score > 0 || _team2Score > 0) {
        // Check if at least one team has reached minScore
        if (_team1Score < widget.minScore && _team2Score < widget.minScore) {
          // Neither team has reached minScore - invalid
          // Close dialog first, then show snackbar using parent context
          Navigator.of(context).pop();
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(
              content: Text(
                'Score must be ${widget.minScore} (minimum score to win). Current: $_team1Score-$_team2Score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.fixed,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          setState(() {
            _isProcessing = false;
          });
          return;
        }
      }

      // Prevent ties - if both teams are at/above minScore, they must be different by at least 2
      if (_team1Score >= widget.minScore && _team2Score >= widget.minScore) {
        if (_team1Score == _team2Score) {
          // Close dialog first, then show snackbar using parent context
          Navigator.of(context).pop();
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot have a tie score. One team must win by 2 points. Current: $_team1Score-$_team2Score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.fixed,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          setState(() {
            _isProcessing = false;
          });
          return;
        }
      }

      // Validate win-by-2 rule when there are scores
      bool hasWinner = false;
      if (_team1Score >= widget.minScore && _team1Score >= _team2Score + 2) {
        hasWinner = true;
      } else if (_team2Score >= widget.minScore && _team2Score >= _team1Score + 2) {
        hasWinner = true;
      }

      // If one team has reached minScore, the other must be at least 2 points behind (win by 2)
      if (!hasWinner && (_team1Score >= widget.minScore || _team2Score >= widget.minScore)) {
        String errorMessage = 'Must win by 2 points. Current score: $_team1Score-$_team2Score';
        // Close dialog first, then show snackbar using parent context
        Navigator.of(context).pop();
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.fixed,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Save scores
      widget.onSave(_team1Score, _team2Score);
    } catch (e) {
      // Close dialog first, then show snackbar using parent context
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving scores: $e',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.fixed,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Score: ${widget.match.team1} vs ${widget.match.team2}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Team 1
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.match.team1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _team1Score <= 0 || _isProcessing
                              ? null
                              : () => _handleDecreaseScore(true),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.red[400],
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
                              '$_team1Score',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: (_isProcessing || _isTeam1MaxReached())
                              ? null
                              : () => _handleIncreaseScore(true),
                          icon: const Icon(Icons.add_circle_outline),
                          color: Colors.green[400],
                        ),
                      ],
                    ),
                  ],
                ),
                if (_hasTeam1Won())
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Winner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Team 2
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.match.team2,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _team2Score <= 0 || _isProcessing
                              ? null
                              : () => _handleDecreaseScore(false),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.red[400],
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
                              '$_team2Score',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: (_isProcessing || _isTeam2MaxReached())
                              ? null
                              : () => _handleIncreaseScore(false),
                          icon: const Icon(Icons.add_circle_outline),
                          color: Colors.green[400],
                        ),
                      ],
                    ),
                  ],
                ),
                if (_hasTeam2Won())
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Winner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : _handleCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _saveScores,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
      ),
    );
  }
}

// SemiFinalsScoringScreen has been extracted to playoff_scoring_screen.dart
// Using typedef to maintain backward compatibility
typedef SemiFinalsScoringScreen = PlayoffScoringScreen;

final Map<String, bool> _finalsCompletedByDivision = {};