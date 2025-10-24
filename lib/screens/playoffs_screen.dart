import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../services/score_service.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import 'match_scoring_screen.dart';

class PlayoffsScreen extends StatefulWidget {
  const PlayoffsScreen({super.key});

  @override
  State<PlayoffsScreen> createState() => _PlayoffsScreenState();
}

class _PlayoffsScreenState extends State<PlayoffsScreen> {
  final ScoreService _scoreService = ScoreService();
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();

  // Scoring state
  Match? _selectedMatch;
  final Map<String, Map<String, int>> _playoffScores = {};

  // Playoff matches
  List<Match> _playoffs = [];
  List<Standing> _standings = [];
  List<dynamic> _teams = [];
  bool _playoffsStarted = false;
  String _tournamentTitle = 'Basketball Tournament 2025';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Load teams and determine sport
    final basketballTeams = _teamService.teams;
    final pickleballTeams = _pickleballTeamService.teams;

    if (basketballTeams.isNotEmpty) {
      _teams = basketballTeams;
      _tournamentTitle = 'Basketball Tournament 2025';
    } else if (pickleballTeams.isNotEmpty) {
      _teams = pickleballTeams;
      _tournamentTitle = 'Thanksgiving Pickleball Tournament';
    }

    // Calculate standings
    _calculateStandings();

    // Check if playoffs have started
    _checkPlayoffsStatus();

    // Generate playoff bracket if started
    if (_playoffsStarted) {
      _generatePlayoffBracket();
    }

    _loadScores();
  }

  void _calculateStandings() {
    if (_teams.isEmpty) return;

    // Calculate standings logic (simplified version)
    Map<String, Map<String, int>> teamStats = {};

    // Initialize team stats
    for (var team in _teams) {
      teamStats[team.id] = {
        'games': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'points': 0,
        'pointDifference': 0,
      };
    }

    // Generate standings from calculated stats
    _standings = [];
    for (int i = 0; i < _teams.length; i++) {
      final teamId = _teams[i].id;
      final stats = teamStats[teamId]!;
      _standings.add(
        Standing(
          rank: i + 1,
          teamName: _teams[i].name,
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
  }

  void _checkPlayoffsStatus() {
    // Check if playoffs have started by looking for playoff scores
    _scoreService.loadPlayoffScores().then((scores) {
      setState(() {
        _playoffsStarted = scores.isNotEmpty;
      });
    });
  }

  void _generatePlayoffBracket() {
    if (!_playoffsStarted) return;

    // Calculate how many teams qualify (half of total teams)
    int qualifyingTeams = (_standings.length / 2).ceil();
    if (qualifyingTeams < 2) qualifyingTeams = 2;
    if (qualifyingTeams > _standings.length) {
      qualifyingTeams = _standings.length;
    }

    // Generate Quarter Finals with proper seeding
    _playoffs = [];
    int matchId = 1000;
    int courtNumber = 1;
    int timeSlot = 14;

    for (int i = 0; i < qualifyingTeams / 2; i++) {
      final team1Index = i;
      final team2Index = qualifyingTeams - 1 - i;

      if (team2Index > team1Index) {
        final team1 = _teams.firstWhere(
          (t) => t.name == _standings[team1Index].teamName,
        );
        final team2 = _teams.firstWhere(
          (t) => t.name == _standings[team2Index].teamName,
        );

        _playoffs.add(
          Match(
            id: 'QF${matchId++}',
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

        courtNumber = (courtNumber % 3) + 1;
        if (courtNumber == 1) timeSlot += 1;
      }
    }
  }

  void _loadScores() async {
    try {
      final playoffScores = await _scoreService.loadPlayoffScores();
      setState(() {
        _playoffScores.clear();
        _playoffScores.addAll(playoffScores);
      });
    } catch (e) {
      print('Error loading playoff scores: $e');
    }
  }

  void _selectMatch(Match match) {
    setState(() {
      if (_selectedMatch?.id == match.id) {
        _selectedMatch = null; // Deselect if same match
      } else {
        _selectedMatch = match;
      }
    });
  }

  void _startScoring() {
    if (_selectedMatch != null) {
      // Navigate to dedicated scoring screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MatchScoringScreen(
                match: _selectedMatch!,
                initialScores: _playoffScores[_selectedMatch!.id],
                onScoresUpdated: (scores) async {
                  setState(() {
                    _playoffScores[_selectedMatch!.id] = scores;
                    _selectedMatch = null; // Clear selection after scoring
                  });

                  // Save scores to persistent storage
                  try {
                    await _scoreService.savePlayoffScores(_playoffScores);
                    print('Playoff scores saved to storage successfully');
                  } catch (e) {
                    print('Error saving playoff scores to storage: $e');
                  }
                },
              ),
        ),
      );
    }
  }

  int _getTeamScore(String matchId, String? teamId) {
    return _playoffScores[matchId]?[teamId] ?? 0;
  }

  String? _getWinningTeamId(String matchId) {
    final scores = _playoffScores[matchId];
    if (scores == null || scores.length < 2) return null;

    final team1Score = scores.values.first;
    final team2Score = scores.values.last;

    if (team1Score > team2Score) {
      return scores.keys.first;
    } else if (team2Score > team1Score) {
      return scores.keys.last;
    }
    return null; // Draw
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('$_tournamentTitle Playoffs'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _playoffsStarted
              ? _buildPlayoffsContent()
              : _buildEmptyPlayoffsState(),
    );
  }

  Widget _buildPlayoffsContent() {
    return Column(
      children: [
        // Playoff Bracket Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$_tournamentTitle Playoffs',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Playoff Matches
        Expanded(
          child:
              _playoffs.isEmpty
                  ? _buildEmptyPlayoffsState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _playoffs.length,
                    itemBuilder: (context, index) {
                      return _buildMatchCard(_playoffs[index]);
                    },
                  ),
        ),

        // Start Scoring Button for Playoffs
        if (_playoffs.isNotEmpty)
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
            child: ElevatedButton.icon(
              onPressed: _selectedMatch != null ? _startScoring : null,
              icon: const Icon(Icons.sports_score),
              label: Text(
                _selectedMatch != null ? 'Start Scoring' : 'Select a Match',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedMatch != null
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

    return GestureDetector(
      onTap: () => _selectMatch(match),
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
                      ? Colors.yellow.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
              blurRadius: isSelected ? 20 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient:
                isSelected
                    ? const LinearGradient(
                      colors: [Color(0xFFFFF59D), Color(0xFFFFF176)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color: isSelected ? null : Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Date and Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          match.day,
                          style: TextStyle(
                            color: isSelected ? Colors.black87 : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black12 : Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Match',
                            style: TextStyle(
                              color: isSelected ? Colors.black87 : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          match.time,
                          style: TextStyle(
                            color: isSelected ? Colors.black87 : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Teams and Scores
                    Row(
                      children: [
                        // Team 1
                        Expanded(
                          child: _buildTeamSection(
                            teamName: match.team1,
                            score: team1Score,
                            isWinner: winningTeamId == match.team1Id,
                            isLeft: true,
                            isSelected: isSelected,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // VS
                        Text(
                          'VS',
                          style: TextStyle(
                            color: isSelected ? Colors.black54 : Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Team 2
                        Expanded(
                          child: _buildTeamSection(
                            teamName: match.team2,
                            score: team2Score,
                            isWinner: winningTeamId == match.team2Id,
                            isLeft: false,
                            isSelected: isSelected,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSection({
    required String teamName,
    required int score,
    required bool isWinner,
    required bool isLeft,
    required bool isSelected,
  }) {
    Color teamColor;
    if (isWinner) {
      teamColor = isLeft ? Colors.blue : Colors.red;
    } else {
      teamColor = isSelected ? Colors.black54 : Colors.grey;
    }

    return Column(
      children: [
        // Team Name
        Text(
          teamName,
          style: TextStyle(
            color: teamColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),

        // Score
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                isWinner
                    ? teamColor.withOpacity(0.2)
                    : (isSelected ? Colors.black12 : Colors.white12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isWinner ? teamColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$score',
              style: TextStyle(
                color: teamColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Winner indicator
        if (isWinner) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: teamColor, size: 16),
              const SizedBox(width: 4),
              Text(
                'Winner',
                style: TextStyle(
                  color: teamColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
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
}
