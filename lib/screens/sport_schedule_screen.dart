import 'package:flutter/material.dart';
import '../widgets/simple_app_bar.dart';
import '../models/match.dart';
import '../models/standing.dart';
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
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();
  final ScoreService _scoreService = ScoreService();

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

  // Bottom navigation state for playoffs
  int _bottomNavIndex = 0;

  // Get teams based on sport type and selected division
  List<dynamic> get _teams {
    List<dynamic> allTeams = [];
    if (widget.sportName.toLowerCase().contains('basketball')) {
      allTeams = _teamService.teams;
    } else if (widget.sportName.toLowerCase().contains('pickleball')) {
      allTeams = _pickleballTeamService.teams;
    }
    print(
      '_teams getter - sport: ${widget.sportName}, allTeams length: ${allTeams.length}',
    );

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
                onScoresUpdated: (scores) async {
                  print('Scores updated: $scores');
                  setState(() {
                    if (isPlayoffMatch) {
                      _playoffScores[_selectedMatch!.id] = scores;
                    } else {
                      _matchScores[_selectedMatch!.id] = scores;
                    }
                    _selectedMatch = null; // Clear selection after scoring
                  });

                  // Save scores to persistent storage
                  try {
                    if (isPlayoffMatch) {
                      await _scoreService.savePlayoffScores(_playoffScores);
                      print('Playoff scores saved: $_playoffScores');
                    } else {
                      await _scoreService.savePreliminaryScores(_matchScores);
                      print('Preliminary scores saved: $_matchScores');
                    }
                    print('Scores saved to storage successfully');
                  } catch (e) {
                    print('Error saving scores to storage: $e');
                  }

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
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _playoffsStarted = true;
                });
                // Switch to Playoffs bottom navigation
                setState(() {
                  _bottomNavIndex = 1;
                });
                // Save playoff state
                await _scoreService.savePlayoffsStarted(_playoffsStarted);
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
            'Are you sure you want to restart the playoffs? This will allow you to edit preliminary round scores again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _playoffsStarted = false;
                  _playoffScores.clear(); // Clear playoff scores
                });
                // Save playoff state
                await _scoreService.savePlayoffsStarted(_playoffsStarted);
              },
              child: const Text('Restart Playoffs'),
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
        // Shuffle teams for randomization
        List<dynamic> shuffledTeams = List.from(divisionTeams);
        shuffledTeams.shuffle();

        // Create all possible match combinations
        List<List<int>> possibleMatches = [];
        for (int i = 0; i < shuffledTeams.length; i++) {
          for (int j = i + 1; j < shuffledTeams.length; j++) {
            possibleMatches.add([i, j]);
          }
        }

        // Shuffle the possible matches for more randomization
        possibleMatches.shuffle();

        // Track games played per team
        Map<String, int> gamesPlayed = {};
        for (var team in shuffledTeams) {
          gamesPlayed[team.name] = 0;
        }

        // Generate matches ensuring each team plays exactly 3 games
        // Use a more controlled approach to prevent teams from playing more than 3 games
        List<List<int>> usedMatches = [];

        for (var match in possibleMatches) {
          final team1Index = match[0];
          final team2Index = match[1];
          final team1 = shuffledTeams[team1Index];
          final team2 = shuffledTeams[team2Index];

          // Check if both teams have played less than 3 games
          // AND this specific match hasn't been used yet
          if (gamesPlayed[team1.name]! < 3 &&
              gamesPlayed[team2.name]! < 3 &&
              !usedMatches.contains(match)) {
            matches.add(
              Match(
                id: '${matchId++}',
                day: 'Day 1',
                court: 'Court $courtNumber',
                time: '$timeSlot:00 AM',
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
              ),
            );

            // Mark this match as used
            usedMatches.add(match);

            gamesPlayed[team1.name] = gamesPlayed[team1.name]! + 1;
            gamesPlayed[team2.name] = gamesPlayed[team2.name]! + 1;

            // Alternate courts and time slots
            courtNumber = (courtNumber % 3) + 1;
            if (courtNumber == 1) timeSlot += 1;

            // Stop if all teams have played 3 games
            bool allTeamsPlayed3Games = gamesPlayed.values.every(
              (games) => games >= 3,
            );
            if (allTeamsPlayed3Games) break;
          }
        }

        // Debug: Print final games played
        print('Final games played: $gamesPlayed');
        print('Total matches created: ${matches.length}');

        // Validation: Ensure no team plays more than 3 games
        for (var entry in gamesPlayed.entries) {
          if (entry.value > 3) {
            print(
              'ERROR: Team ${entry.key} played ${entry.value} games (should be max 3)',
            );
          }
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
    print('_standings getter called - teams length: ${teams.length}');
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
        'pointDifference': 0,
      };
    }

    // First, count total games scheduled for each team
    for (var match in _preliminaryMatches) {
      // Skip "Waiting for Opponent" matches
      if (match.team2 == 'Waiting for Opponent') continue;

      // Count all scheduled matches (regardless of whether scores are entered)
      if (match.team1Id != null && match.team2Id != null) {
        if (teamStats.containsKey(match.team1Id!) &&
            teamStats.containsKey(match.team2Id!)) {
          teamStats[match.team1Id!]!['games'] =
              (teamStats[match.team1Id!]!['games']! + 1);
          teamStats[match.team2Id!]!['games'] =
              (teamStats[match.team2Id!]!['games']! + 1);
        }
      }
    }

    // Then, process match results for wins/losses/draws/points
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

    return standings;
  }

  // Get playoffs matches
  List<Match> get _playoffs {
    print('_playoffs getter called - _playoffsStarted: $_playoffsStarted');
    if (!_playoffsStarted) return [];

    final standings = _standings;
    print('_playoffs getter - standings length: ${standings.length}');
    if (standings.length < 2) return []; // Need at least 2 teams for playoffs

    List<Match> playoffMatches = [];
    int matchId = 1000; // Start playoff match IDs from 1000
    int courtNumber = 1;
    int timeSlot = 14; // Start at 2 PM for playoffs

    // Calculate how many teams qualify (half of total teams, minimum 2)
    int qualifyingTeams = (standings.length / 2).ceil();
    if (qualifyingTeams < 2) qualifyingTeams = 2;
    if (qualifyingTeams > standings.length) qualifyingTeams = standings.length;
    print('_playoffs getter - qualifyingTeams: $qualifyingTeams');

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

    // SEMI FINALS - Create semi-final matches based on quarter final results
    final quarterFinalsWinners = _getQuarterFinalsWinners();
    if (quarterFinalsWinners.length >= 2) {
      // Create semi-final matches with proper seeding
      for (int i = 0; i < quarterFinalsWinners.length / 2; i++) {
        final team1Index = i;
        final team2Index = quarterFinalsWinners.length - 1 - i;

        if (team2Index > team1Index) {
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
        }
      }
    } else {
      // Create waiting matches for semi-finals
      for (int i = 0; i < 2; i++) {
        playoffMatches.add(
          Match(
            id: '${matchId++}',
            day: 'Semi Finals',
            court: 'Court ${(i % 3) + 1}',
            time: '${timeSlot + i}:00 PM',
            team1: 'Waiting for Opponent',
            team2: 'Waiting for Opponent',
            team1Status: 'Waiting for Opponent',
            team2Status: 'Waiting for Opponent',
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
          team1: 'Waiting for Opponent',
          team2: 'Waiting for Opponent',
          team1Status: 'Waiting for Opponent',
          team2Status: 'Waiting for Opponent',
          team1Score: 0,
          team2Score: 0,
        ),
      );
    }

    print(
      '_playoffs getter - generated ${playoffMatches.length} playoff matches',
    );
    return playoffMatches;
  }

  // Get winners of quarter finals
  List<dynamic> _getQuarterFinalsWinners() {
    final quarterFinals = _getQuarterFinals();
    List<dynamic> winners = [];

    for (var match in quarterFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        final scores = _playoffScores[match.id];
        if (scores != null && scores.length >= 2) {
          final team1Score = scores[match.team1Id!] ?? 0;
          final team2Score = scores[match.team2Id!] ?? 0;

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
    final semiFinals = _getSemiFinals();
    List<dynamic> winners = [];

    for (var match in semiFinals) {
      if (match.team1Id != null && match.team2Id != null) {
        final scores = _playoffScores[match.id];
        if (scores != null && scores.length >= 2) {
          final team1Score = scores[match.team1Id!] ?? 0;
          final team2Score = scores[match.team2Id!] ?? 0;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _playoffTabController = TabController(length: 3, vsync: this);
    _loadTeams();
    _loadScores();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload teams and scores when screen becomes visible
    _loadTeams();
    _loadScores();
  }

  Future<void> _loadTeams() async {
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();
    if (mounted) {
      setState(() {
        // Clear the matches cache to force regeneration with new teams
        _matchesCache.clear();
        _updateDivisions();
        // Trigger rebuild to show updated teams
      });
    }
  }

  Future<void> _loadScores() async {
    try {
      final preliminaryScores = await _scoreService.loadPreliminaryScores();
      final playoffScores = await _scoreService.loadPlayoffScores();
      final playoffsStarted = await _scoreService.loadPlayoffsStarted();

      print('Loading scores - Preliminary: $preliminaryScores');
      print('Loading scores - Playoff: $playoffScores');
      print('Loading scores - Playoffs started: $playoffsStarted');

      if (mounted) {
        setState(() {
          _matchScores.clear();
          _matchScores.addAll(preliminaryScores);
          _playoffScores.clear();
          _playoffScores.addAll(playoffScores);
          _playoffsStarted = playoffsStarted;
        });
        print('Scores loaded successfully - _matchScores: $_matchScores');
      }
    } catch (e) {
      print('Error loading scores: $e');
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

  // Save scores to persistent storage
  Future<void> _saveScores() async {
    try {
      print('Saving scores in dispose - Preliminary: $_matchScores');
      print('Saving scores in dispose - Playoff: $_playoffScores');
      print('Saving scores in dispose - Playoffs started: $_playoffsStarted');

      await _scoreService.savePreliminaryScores(_matchScores);
      await _scoreService.savePlayoffScores(_playoffScores);
      await _scoreService.savePlayoffsStarted(_playoffsStarted);
      print('All scores and playoff state saved to storage successfully');
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
      bottomNavigationBar: _playoffsStarted ? _buildPlayoffsBottomNav() : null,
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
              _playoffsStarted
                  ? _buildPlayoffsContent()
                  : Column(
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
                                  widget.sportName.toLowerCase().contains(
                                        'pickleball',
                                      )
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
                                                widget.sportName
                                                        .toLowerCase()
                                                        .contains('pickleball')
                                                    ? Icons.sports_tennis
                                                    : Icons.sports_basketball,
                                                size: 16,
                                                color:
                                                    _selectedDivision ==
                                                            division
                                                        ? const Color(
                                                          0xFF2196F3,
                                                        )
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
                                                        _selectedDivision ==
                                                                division
                                                            ? FontWeight.w700
                                                            : FontWeight.w600,
                                                    color:
                                                        _selectedDivision ==
                                                                division
                                                            ? const Color(
                                                              0xFF2196F3,
                                                            )
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
              children: [
                // Reshuffle Teams button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _hasNoScores()
                            ? _reshuffleTeams
                            : _showResetScoresDialog,
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Reshuffle Teams'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3), // Always blue
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
                        _selectedMatch != null &&
                                _selectedMatch!.team2 != 'Waiting for Opponent'
                            ? _startScoring
                            : null,
                    icon: const Icon(Icons.sports_score),
                    label: Text(
                      _selectedMatch != null
                          ? (_selectedMatch!.team2 == 'Waiting for Opponent'
                              ? 'No Opponent Available'
                              : (_playoffsStarted
                                  ? (_playoffScores.containsKey(
                                        _selectedMatch!.id,
                                      )
                                      ? 'Edit Scoring'
                                      : 'Start Scoring')
                                  : (_matchScores.containsKey(
                                        _selectedMatch!.id,
                                      )
                                      ? 'Edit Scoring'
                                      : 'Start Scoring')))
                          : 'Start Scoring',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedMatch != null &&
                                  _selectedMatch!.team2 !=
                                      'Waiting for Opponent'
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
              ],
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

    // Check if this is a playoff match
    final isPlayoffMatch = _playoffs.contains(match);

    // Get seeding information for playoff matches
    String getTeamDisplayName(String teamName, String? teamId) {
      if (!isPlayoffMatch) return teamName;

      // Handle "Waiting for Opponent" case
      if (teamName == 'Waiting for Opponent') {
        return 'Waiting for Opponent';
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
                      getTeamDisplayName(match.team1, match.team1Id),
                      style: TextStyle(
                        color:
                            match.team1 == 'Waiting for Opponent'
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
                      getTeamDisplayName(match.team2, match.team2Id),
                      style: TextStyle(
                        color:
                            match.team2 == 'Waiting for Opponent'
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
            _standings.length >= 2)
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

        // Restart Playoffs Button (only show when playoffs have started)
        if (_playoffsStarted)
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
              onPressed: _restartPlayoffs,
              icon: const Icon(Icons.refresh),
              label: const Text('Restart Playoffs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
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
      if (match.team2 == 'Waiting for Opponent') continue;
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

  // Reshuffle teams method
  void _reshuffleTeams() {
    // Clear the matches cache to force regeneration
    final cacheKey =
        '${widget.sportName}_${_selectedDivision ?? 'all'}_${_teams.map((t) => t.id).join('_')}';
    _matchesCache.remove(cacheKey);

    // Clear any existing scores
    _matchScores.clear();
    _selectedMatch = null;

    // Force rebuild
    setState(() {});
  }

  // Show dialog when trying to reshuffle with scores
  void _showResetScoresDialog() {
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
        BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Games'),
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
                constraints: const BoxConstraints(maxWidth: 280),
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
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
                      vertical: 16,
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
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDivision = newValue;
                    });
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

  Widget _buildPlayoffsTab() {
    if (!_playoffsStarted) {
      return _buildEmptyPlayoffsState();
    }

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
                      return _buildMatchCard(quarterFinals[index]);
                    },
                  ),
        ),

        // Start Scoring Button for Quarter Finals
        if (quarterFinals.isNotEmpty)
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
                  child: ElevatedButton.icon(
                    onPressed: _selectedMatch != null ? _startScoring : null,
                    icon: const Icon(Icons.sports_score),
                    label: Text(
                      _selectedMatch != null
                          ? 'Start Scoring'
                          : 'Start Scoring',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedMatch != null
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
                    padding: const EdgeInsets.all(16),
                    itemCount: semiFinals.length,
                    itemBuilder: (context, index) {
                      return _buildMatchCard(semiFinals[index]);
                    },
                  ),
        ),

        // Start Scoring Button for Semi Finals
        if (semiFinals.isNotEmpty)
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
                  child: ElevatedButton.icon(
                    onPressed: _selectedMatch != null ? _startScoring : null,
                    icon: const Icon(Icons.sports_score),
                    label: Text(
                      _selectedMatch != null
                          ? 'Start Scoring'
                          : 'Start Scoring',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedMatch != null
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
                    padding: const EdgeInsets.all(16),
                    itemCount: finals.length,
                    itemBuilder: (context, index) {
                      return _buildMatchCard(finals[index]);
                    },
                  ),
        ),

        // Start Scoring Button for Finals
        if (finals.isNotEmpty)
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
                  child: ElevatedButton.icon(
                    onPressed: _selectedMatch != null ? _startScoring : null,
                    icon: const Icon(Icons.sports_score),
                    label: Text(
                      _selectedMatch != null
                          ? 'Start Scoring'
                          : 'Start Scoring',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedMatch != null
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
              ],
            ),
          ),
      ],
    );
  }

  // Get Quarter Finals matches
  List<Match> _getQuarterFinals() {
    return _playoffs.where((match) => match.day == 'Quarter Finals').toList();
  }

  // Get Semi Finals matches
  List<Match> _getSemiFinals() {
    return _playoffs.where((match) => match.day == 'Semi Finals').toList();
  }

  // Get Finals matches
  List<Match> _getFinals() {
    return _playoffs.where((match) => match.day == 'Finals').toList();
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
