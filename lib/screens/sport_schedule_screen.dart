import 'package:flutter/material.dart';
import '../widgets/simple_app_bar.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
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
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();

  // Division selection state
  String? _selectedDivision;
  List<String> _availableDivisions = [];

  // Cache for stable match generation
  final Map<String, List<Match>> _matchesCache = {};

  // Scoring state
  Match? _selectedMatch;
  final Map<String, Map<String, int>> _matchScores =
      {}; // matchId -> {team1Id: score, team2Id: score}

  // Playoffs state
  bool _playoffsStarted = false;
  final Map<String, Map<String, int>> _playoffScores = {};

  // Get teams based on sport type and selected division
  List<dynamic> get _teams {
    List<dynamic> allTeams = [];
    if (widget.sportName.toLowerCase().contains('basketball')) {
      allTeams = _teamService.teams;
    } else if (widget.sportName.toLowerCase().contains('pickleball')) {
      allTeams = _pickleballTeamService.teams;
    }

    // Filter by selected division if one is selected
    if (_selectedDivision != null) {
      return allTeams
          .where((team) => team.division == _selectedDivision)
          .toList();
    }

    return allTeams;
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
    if (match.team2 == 'Waiting for Opponent') {
      return;
    }

    setState(() {
      // If clicking the same match that's already selected, unselect it
      if (_selectedMatch?.id == match.id) {
        _selectedMatch = null;
      } else {
        // Otherwise, select the new match
        _selectedMatch = match;
      }
    });
  }

  void _startScoring() {
    if (_selectedMatch != null) {
      // Determine if this is a playoff match
      final isPlayoffMatch = _playoffs.contains(_selectedMatch!);

      // Navigate to dedicated scoring screen
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
                onScoresUpdated: (scores) {
                  print('Scores updated: $scores');
                  setState(() {
                    if (isPlayoffMatch) {
                      _playoffScores[_selectedMatch!.id] = scores;
                    } else {
                      _matchScores[_selectedMatch!.id] = scores;
                    }
                    _selectedMatch = null; // Clear selection after scoring
                  });
                  print(
                    'Match scores after update: ${isPlayoffMatch ? _playoffScores : _matchScores}',
                  );
                },
              ),
        ),
      );
    }
  }

  int _getTeamScore(String matchId, String? teamId) {
    if (teamId == null) return 0; // Handle "Waiting for Opponent" case

    // Check preliminary scores first
    final preliminaryScores = _matchScores[matchId];
    if (preliminaryScores != null) {
      final score = preliminaryScores[teamId] ?? 0;
      print(
        'Getting preliminary score for match $matchId, team $teamId: $score',
      );
      return score;
    }

    // Check playoff scores
    final playoffScores = _playoffScores[matchId];
    if (playoffScores != null) {
      final score = playoffScores[teamId] ?? 0;
      print('Getting playoff score for match $matchId, team $teamId: $score');
      return score;
    }

    return 0;
  }

  String? _getWinningTeamId(String matchId) {
    // Check preliminary scores first
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

    // Check playoff scores
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

    return null;
  }

  // Check if all preliminary games are completed
  bool get _allPreliminaryGamesCompleted {
    for (var match in _preliminaryMatches) {
      if (match.team2 == 'Waiting for Opponent') {
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
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _playoffsStarted = true;
                });
              },
              child: const Text('Start Playoffs'),
            ),
          ],
        );
      },
    );
  }

  // Get teams from service instead of hardcoded data
  List<Match> get _preliminaryMatches {
    final teams = _teams;
    if (teams.isEmpty) return [];

    // Create a cache key based on teams and division
    String cacheKey =
        '${widget.sportName}_${_selectedDivision ?? 'all'}_${teams.map((t) => t.id).join('_')}';

    // Return cached matches if available
    if (_matchesCache.containsKey(cacheKey)) {
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
      List<dynamic> divisionTeams = teamsByDivision[division]!;

      if (divisionTeams.length == 1) {
        // If only 1 team in division, show them as waiting for opponent
        matches.add(
          Match(
            id: '${matchId++}',
            day: 'Day 1',
            court: 'Court $courtNumber',
            time: '$timeSlot:00 AM',
            team1: divisionTeams[0].name,
            team2: 'Waiting for Opponent',
            team1Status: 'Ready',
            team2Status: 'TBD',
            team1Score: 0,
            team2Score: 0,
            team1Id: divisionTeams[0].id,
            team2Id: null, // No opponent yet
            team1Name: divisionTeams[0].name,
            team2Name: 'Waiting for Opponent',
          ),
        );
        courtNumber = (courtNumber % 3) + 1;
        if (courtNumber == 1) timeSlot += 1;
      } else {
        // Use deterministic sorting instead of random shuffle for stability
        List<dynamic> sortedTeams = List.from(divisionTeams);
        sortedTeams.sort(
          (a, b) => a.name.compareTo(b.name),
        ); // Sort by name for consistency

        // Create a list to track which teams have played each other
        Map<String, Set<String>> playedAgainst = {};
        for (var team in sortedTeams) {
          playedAgainst[team.name] = <String>{};
        }

        // Generate matches ensuring each team plays at least 2 games, max 3
        Map<String, int> gamesPlayed = {};
        for (var team in sortedTeams) {
          gamesPlayed[team.name] = 0;
        }

        int maxAttempts = 200; // Increased attempts
        int attempts = 0;

        while (attempts < maxAttempts) {
          // Find teams that need more games (minimum 2, maximum 3)
          List<dynamic> teamsNeedingGames =
              sortedTeams.where((team) {
                int games = gamesPlayed[team.name]!;
                return games < 3; // Allow up to 3 games
              }).toList();

          if (teamsNeedingGames.isEmpty) break;

          // Try to create a match between two teams that haven't played each other
          bool matchCreated = false;
          for (int i = 0; i < teamsNeedingGames.length && !matchCreated; i++) {
            for (
              int j = i + 1;
              j < teamsNeedingGames.length && !matchCreated;
              j++
            ) {
              String team1Name = teamsNeedingGames[i].name;
              String team2Name = teamsNeedingGames[j].name;

              // Check if these teams haven't played each other yet
              if (!playedAgainst[team1Name]!.contains(team2Name) &&
                  !playedAgainst[team2Name]!.contains(team1Name)) {
                // Create the match
                matches.add(
                  Match(
                    id: '${matchId++}',
                    day: 'Day 1',
                    court: 'Court $courtNumber',
                    time: '$timeSlot:00 AM',
                    team1: team1Name,
                    team2: team2Name,
                    team1Status: 'Not Checked-in',
                    team2Status: 'Not Checked-in',
                    team1Score: 0,
                    team2Score: 0,
                    team1Id: teamsNeedingGames[i].id,
                    team2Id: teamsNeedingGames[j].id,
                    team1Name: team1Name,
                    team2Name: team2Name,
                  ),
                );

                // Update tracking
                playedAgainst[team1Name]!.add(team2Name);
                playedAgainst[team2Name]!.add(team1Name);
                gamesPlayed[team1Name] = gamesPlayed[team1Name]! + 1;
                gamesPlayed[team2Name] = gamesPlayed[team2Name]! + 1;

                // Alternate courts and time slots
                courtNumber = (courtNumber % 3) + 1; // 3 courts max
                if (courtNumber == 1) {
                  timeSlot += 1; // Move to next hour
                }

                matchCreated = true;
              }
            }
          }

          if (!matchCreated) {
            // If we can't create more matches with current constraints, break
            break;
          }

          attempts++;
        }
      }
    }

    // Cache the matches for stability
    _matchesCache[cacheKey] = matches;
    return matches;
  }

  // Get standings from registered teams
  List<Standing> get _standings {
    final teams = _teams;
    if (teams.isEmpty) return [];

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
      };
    }

    // Process match results
    for (var match in _preliminaryMatches) {
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
              // Update games played
              teamStats[team1Id]!['games'] =
                  (teamStats[team1Id]!['games']! + 1);
              teamStats[team2Id]!['games'] =
                  (teamStats[team2Id]!['games']! + 1);

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
      standings.add(
        Standing(
          rank: i + 1,
          teamName: teams[i].name,
          games: stats['games']!,
          wins: stats['wins']!,
          draws: stats['draws']!,
          losses: stats['losses']!,
          technicalFouls: 0,
          pointDifference: 0,
          points: stats['points']!,
        ),
      );
    }

    // Sort by points (descending), then by wins (descending), then by losses (ascending)
    standings.sort((a, b) {
      // First priority: Points (higher is better)
      if (b.points != a.points) return b.points.compareTo(a.points);

      // Second priority: Wins (higher is better)
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);

      // Third priority: Losses (lower is better)
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

    return standings;
  }

  // Get playoffs matches
  List<Match> get _playoffs {
    if (!_playoffsStarted) return [];

    final standings = _standings;
    if (standings.length < 4) return []; // Need at least 4 teams for playoffs

    List<Match> playoffMatches = [];
    int matchId = 1000; // Start playoff match IDs from 1000
    int courtNumber = 1;
    int timeSlot = 14; // Start at 2 PM for playoffs

    // Quarter-finals: 1st vs 4th, 2nd vs 3rd
    if (standings.length >= 4) {
      // Find teams by their standings
      final team1 = _teams.firstWhere((t) => t.name == standings[0].teamName);
      final team4 = _teams.firstWhere((t) => t.name == standings[3].teamName);
      final team2 = _teams.firstWhere((t) => t.name == standings[1].teamName);
      final team3 = _teams.firstWhere((t) => t.name == standings[2].teamName);

      // 1st vs 4th
      playoffMatches.add(
        Match(
          id: '${matchId++}',
          day: 'Playoffs',
          court: 'Court $courtNumber',
          time: '$timeSlot:00 PM',
          team1: team1.name,
          team2: team4.name,
          team1Status: 'Ready',
          team2Status: 'Ready',
          team1Score: 0,
          team2Score: 0,
          team1Id: team1.id,
          team2Id: team4.id,
          team1Name: team1.name,
          team2Name: team4.name,
        ),
      );

      courtNumber = (courtNumber % 3) + 1;
      if (courtNumber == 1) timeSlot += 1;

      // 2nd vs 3rd
      playoffMatches.add(
        Match(
          id: '${matchId++}',
          day: 'Playoffs',
          court: 'Court $courtNumber',
          time: '$timeSlot:00 PM',
          team1: team2.name,
          team2: team3.name,
          team1Status: 'Ready',
          team2Status: 'Ready',
          team1Score: 0,
          team2Score: 0,
          team1Id: team2.id,
          team2Id: team3.id,
          team1Name: team2.name,
          team2Name: team3.name,
        ),
      );
    }

    return playoffMatches;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeams();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload teams when screen becomes visible
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();
    if (mounted) {
      setState(() {
        _updateDivisions();
        // Trigger rebuild to show updated teams
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Division Dropdown
              if (_availableDivisions.isNotEmpty) ...[
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDivision,
                        isExpanded: false,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF2196F3),
                          size: 20,
                        ),
                        hint: Text(
                          widget.sportName.toLowerCase().contains('pickleball')
                              ? 'Select DUPR Rating'
                              : 'Select Division',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: Colors.white,
                        menuMaxHeight: 180,
                        borderRadius: BorderRadius.circular(12),
                        items:
                            _availableDivisions.map((String division) {
                              return DropdownMenuItem<String>(
                                value: division,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Sport-specific icon
                                      Icon(
                                        widget.sportName.toLowerCase().contains(
                                              'pickleball',
                                            )
                                            ? Icons.sports_tennis
                                            : Icons.sports_basketball,
                                        size: 16,
                                        color:
                                            _selectedDivision == division
                                                ? const Color(0xFF2196F3)
                                                : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      // Division text with better styling
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: Text(
                                          division,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                _selectedDivision == division
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                            color:
                                                _selectedDivision == division
                                                    ? const Color(0xFF2196F3)
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      // Selection indicator
                                      if (_selectedDivision == division)
                                        const Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Color(0xFF2196F3),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDivision = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],

              // Spacing between dropdown and tab bar
              const SizedBox(height: 16),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Playoffs',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    _buildStandingsTab(),
                    _buildPlayoffsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreliminaryRoundsTab() {
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                _preliminaryMatches.isEmpty
                    ? _buildEmptyMatchesState()
                    : ListView.builder(
                      itemCount: _preliminaryMatches.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildMatchCard(_preliminaryMatches[index]),
                        );
                      },
                    ),
          ),
        ),
        // Fixed scoring button at bottom
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
            child: ElevatedButton.icon(
              onPressed:
                  _selectedMatch != null &&
                          _selectedMatch!.team2 != 'Waiting for Opponent'
                      ? _startScoring
                      : null,
              icon: const Icon(Icons.sports_score),
              label: Text(
                _selectedMatch != null
                    ? (_selectedMatch!.team2 == 'Waiting for Opponent'
                        ? 'No Opponent Available'
                        : (_matchScores.containsKey(_selectedMatch!.id)
                            ? 'Edit Scoring'
                            : 'Start Scoring'))
                    : 'Select a Match',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedMatch != null &&
                            _selectedMatch!.team2 != 'Waiting for Opponent'
                        ? const Color(0xFF2196F3)
                        : Colors.grey[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
    final hasOpponent = match.team2 != 'Waiting for Opponent';

    return GestureDetector(
      onTap: hasOpponent ? () => _selectMatch(match) : null,
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
                    child: const Center(
                      child: Icon(Icons.block, color: Colors.grey, size: 24),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          const SizedBox(height: 16),

          // Teams and Scores
          Row(
            children: [
              // Team 1 (Left side)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      match.team1,
                      style: TextStyle(
                        color: team1Won ? Colors.blue : Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$team1Score',
                      style: TextStyle(
                        color: team1Won ? Colors.blue : Colors.grey[400],
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Team 2 (Right side)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      match.team2,
                      style: TextStyle(
                        color: team2Won ? Colors.red : Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$team2Score',
                      style: TextStyle(
                        color: team2Won ? Colors.red : Colors.grey[400],
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
                                  ScheduleScreenKeys.drawsHeader,
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
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: _standings.length,
                            itemBuilder: (context, index) {
                              return _buildStandingRow(_standings[index]);
                            },
                          ),
                        ],
                      ),
                    ),
          ),
        ),

        // Start Playoffs Button (only show when all games are completed and playoffs haven't started)
        if (_allPreliminaryGamesCompleted &&
            !_playoffsStarted &&
            _standings.length >= 4)
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
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
              '${standing.draws}',
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

  Widget _buildPlayoffsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child:
          _playoffs.isEmpty
              ? _buildEmptyPlayoffsState()
              : ListView.builder(
                itemCount: _playoffs.length,
                itemBuilder: (context, index) {
                  return _buildMatchCard(_playoffs[index]);
                },
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

  Widget _buildEmptyPlayoffsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.games, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Playoff matches will appear here',
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
