import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../services/score_service.dart';
import 'match_scoring_screen.dart';

class PlayoffScreen extends StatefulWidget {
  final String sportName;
  final String tournamentTitle;
  final List<Standing> standings;
  final List<dynamic> teams;

  const PlayoffScreen({
    super.key,
    required this.sportName,
    required this.tournamentTitle,
    required this.standings,
    required this.teams,
  });

  @override
  State<PlayoffScreen> createState() => _PlayoffScreenState();
}

class _PlayoffScreenState extends State<PlayoffScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScoreService _scoreService = ScoreService();

  // Scoring state
  Match? _selectedMatch;
  final Map<String, Map<String, int>> _quarterFinalsScores = {};
  final Map<String, Map<String, int>> _semiFinalsScores = {};
  final Map<String, Map<String, int>> _finalsScores = {};

  // Playoff rounds
  List<Match> _quarterFinals = [];
  List<Match> _semiFinals = [];
  List<Match> _finals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generatePlayoffBracket();
    _loadScores();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generatePlayoffBracket() {
    // Calculate how many teams qualify (half of total teams)
    int qualifyingTeams = (widget.standings.length / 2).ceil();
    if (qualifyingTeams < 2) {
      qualifyingTeams = 2;
    }
    if (qualifyingTeams > widget.standings.length) {
      qualifyingTeams = widget.standings.length;
    }

    // Generate Quarter Finals with proper seeding
    _quarterFinals = [];
    int matchId = 1000;
    int courtNumber = 1;
    int timeSlot = 14;

    for (int i = 0; i < qualifyingTeams / 2; i++) {
      final team1Index = i;
      final team2Index = qualifyingTeams - 1 - i;

      if (team2Index > team1Index) {
        final team1 = widget.teams.firstWhere(
          (t) => t.name == widget.standings[team1Index].teamName,
        );
        final team2 = widget.teams.firstWhere(
          (t) => t.name == widget.standings[team2Index].teamName,
        );

        _quarterFinals.add(
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
      final quarterScores = await _scoreService.loadQuarterFinalsScores();
      final semiScores = await _scoreService.loadSemiFinalsScores();
      final finalsScores = await _scoreService.loadFinalsScores();

      setState(() {
        _quarterFinalsScores.clear();
        _quarterFinalsScores.addAll(quarterScores);
        _semiFinalsScores.clear();
        _semiFinalsScores.addAll(semiScores);
        _finalsScores.clear();
        _finalsScores.addAll(finalsScores);

        // Generate next rounds based on completed matches
        _generateNextRounds();
      });
    } catch (e) {
      print('Error loading playoff scores: $e');
    }
  }

  void _generateNextRounds() {
    // Generate Semi Finals from Quarter Finals winners
    if (_quarterFinalsScores.isNotEmpty && _semiFinals.isEmpty) {
      _generateSemiFinals();
    }

    // Generate Finals from Semi Finals winners
    if (_semiFinalsScores.isNotEmpty && _finals.isEmpty) {
      _generateFinals();
    }
  }

  void _generateSemiFinals() {
    final quarterWinners = _getWinnersFromRound(
      _quarterFinals,
      _quarterFinalsScores,
    );

    if (quarterWinners.length >= 2) {
      _semiFinals = [];
      int matchId = 2000;
      int courtNumber = 1;
      int timeSlot = 16;

      for (int i = 0; i < quarterWinners.length; i += 2) {
        if (i + 1 < quarterWinners.length) {
          final team1 = quarterWinners[i];
          final team2 = quarterWinners[i + 1];

          _semiFinals.add(
            Match(
              id: 'SF${matchId++}',
              day: 'Semi Finals',
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
  }

  void _generateFinals() {
    final semiWinners = _getWinnersFromRound(_semiFinals, _semiFinalsScores);

    if (semiWinners.length >= 2) {
      _finals = [];
      int matchId = 3000;
      int courtNumber = 1;
      int timeSlot = 18;

      final team1 = semiWinners[0];
      final team2 = semiWinners[1];

      _finals.add(
        Match(
          id: 'F${matchId++}',
          day: 'Finals',
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
    }
  }

  List<dynamic> _getWinnersFromRound(
    List<Match> matches,
    Map<String, Map<String, int>> scores,
  ) {
    List<dynamic> winners = [];

    for (var match in matches) {
      final matchScores = scores[match.id];
      if (matchScores != null && matchScores.length >= 2) {
        final team1Score = matchScores[match.team1Id] ?? 0;
        final team2Score = matchScores[match.team2Id] ?? 0;

        if (team1Score > team2Score) {
          winners.add(widget.teams.firstWhere((t) => t.id == match.team1Id));
        } else if (team2Score > team1Score) {
          winners.add(widget.teams.firstWhere((t) => t.id == match.team2Id));
        }
      }
    }

    return winners;
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
      final matchToScore = _selectedMatch!; // capture before navigation/callbacks
      // Determine which round this match belongs to
      Map<String, Map<String, int>> currentScores = {};

      if (_quarterFinals.contains(matchToScore)) {
        currentScores = _quarterFinalsScores;
      } else if (_semiFinals.contains(matchToScore)) {
        currentScores = _semiFinalsScores;
      } else if (_finals.contains(matchToScore)) {
        currentScores = _finalsScores;
      }

      // Navigate to dedicated scoring screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MatchScoringScreen(
                match: matchToScore,
                initialScores: currentScores[matchToScore.id],
                onScoresUpdated: (scores) async {
                  setState(() {
                    if (_quarterFinals.contains(matchToScore)) {
                      _quarterFinalsScores[matchToScore.id] = scores;
                    } else if (_semiFinals.contains(matchToScore)) {
                      _semiFinalsScores[matchToScore.id] = scores;
                    } else if (_finals.contains(matchToScore)) {
                      _finalsScores[matchToScore.id] = scores;
                    }
                    _selectedMatch = null; // Clear selection after scoring

                    // Regenerate next rounds after scoring
                    _generateNextRounds();
                  });

                  // Save scores to persistent storage
                  try {
                    if (_quarterFinals.contains(matchToScore)) {
                      await _scoreService.saveQuarterFinalsScores(_quarterFinalsScores);
                    } else if (_semiFinals.contains(matchToScore)) {
                      await _scoreService.saveSemiFinalsScores(_semiFinalsScores);
                    } else if (_finals.contains(matchToScore)) {
                      await _scoreService.saveFinalsScores(_finalsScores);
                    }
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
    // Check all rounds for the score
    if (_quarterFinalsScores.containsKey(matchId)) {
      return _quarterFinalsScores[matchId]?[teamId] ?? 0;
    }
    if (_semiFinalsScores.containsKey(matchId)) {
      return _semiFinalsScores[matchId]?[teamId] ?? 0;
    }
    if (_finalsScores.containsKey(matchId)) {
      return _finalsScores[matchId]?[teamId] ?? 0;
    }
    return 0;
  }

  String? _getWinningTeamId(String matchId) {
    final quarterScore = _quarterFinalsScores[matchId];
    final semiScore = _semiFinalsScores[matchId];
    final finalsScore = _finalsScores[matchId];

    final scores = quarterScore ?? semiScore ?? finalsScore;
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
        title: Text('${widget.tournamentTitle} Playoffs'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Quarter Finals'),
            Tab(text: 'Semi Finals'),
            Tab(text: 'Finals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuarterFinalsTab(),
          _buildSemiFinalsTab(),
          _buildFinalsTab(),
        ],
      ),
      bottomNavigationBar: Container(
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
    );
  }

  Widget _buildQuarterFinalsTab() {
    return _buildRoundTab(_quarterFinals, _quarterFinalsScores);
  }

  Widget _buildSemiFinalsTab() {
    return _buildRoundTab(_semiFinals, _semiFinalsScores);
  }

  Widget _buildFinalsTab() {
    return _buildRoundTab(_finals, _finalsScores);
  }

  Widget _buildRoundTab(
    List<Match> matches,
    Map<String, Map<String, int>> scores,
  ) {
    if (matches.isEmpty) {
      return const Center(
        child: Text(
          'No matches available for this round',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              return _buildMatchCard(matches[index]);
            },
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
}
