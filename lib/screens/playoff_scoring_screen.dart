// ignore_for_file: use_super_parameters, curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/match.dart';

/// Screen for scoring playoff matches (QF, SF, Finals)
/// Supports both 1-game and best-of-3 formats
class PlayoffScoringScreen extends StatefulWidget {
  final Match match;
  final Map<String, dynamic>? initialScores;
  final String matchFormat; // '1game' or 'bestof3'
  final int gameWinningScore; // 11 or 15
  final Function(Map<String, dynamic>) onScoresUpdated;
  final VoidCallback? onSettingsChange;
  final bool canAdjustSettings;
  final VoidCallback? onBackPressed;
  final bool? isFirstCard;
  final int?
  selectedGameNumber; // For preliminary rounds - which game is being scored

  const PlayoffScoringScreen({
    Key? key,
    required this.match,
    this.initialScores,
    required this.matchFormat,
    this.gameWinningScore = 15,
    required this.onScoresUpdated,
    this.onSettingsChange,
    this.canAdjustSettings = true,
    this.onBackPressed,
    this.isFirstCard,
    this.selectedGameNumber,
  }) : super(key: key);

  @override
  State<PlayoffScoringScreen> createState() => _PlayoffScoringScreenState();
}

class _PlayoffScoringScreenState extends State<PlayoffScoringScreen> {
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
          widget.selectedGameNumber != null
              ? 'Game ${widget.selectedGameNumber} Score'
              : widget.matchFormat == 'bestof3'
                  ? 'Game best of 3, ${widget.gameWinningScore} points'
                  : 'Game Score',
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
    return StatefulBuilder(
      builder: (context, setBuilderState) {
        // Generate keys INSIDE the builder to ensure they're always fresh
        final team1Key = '${widget.match.team1Id}_game$gameNumber';
        final team2Key = '${widget.match.team2Id}_game$gameNumber';
        
        // Debug: Verify keys are different
        if (team1Key == team2Key) {
          print('ERROR: team1Key and team2Key are the same! team1Id: ${widget.match.team1Id}, team2Id: ${widget.match.team2Id}');
        }
        
        bool currentIsGameDisabled = false;

        if (gameNumber == 1) {
          currentIsGameDisabled = false;
        } else if (gameNumber == 2 &&
            widget.matchFormat == 'bestof3' &&
            widget.match.team1Id != null &&
            widget.match.team2Id != null) {
          final team1Key = '${widget.match.team1Id}_game';
          final team2Key = '${widget.match.team2Id}_game';
          final game1Team1 = _scores['${team1Key}1'] ?? 0;
          final game1Team2 = _scores['${team2Key}1'] ?? 0;
          final minScore = widget.gameWinningScore;
          bool game1Complete =
              (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) ||
              (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2);
          currentIsGameDisabled = !game1Complete;
        } else if (gameNumber == 3) {
          if (widget.match.team1Id == null || widget.match.team2Id == null) {
            currentIsGameDisabled = true;
          } else {
            final team1Key = '${widget.match.team1Id}_game';
            final team2Key = '${widget.match.team2Id}_game';

            final game1Team1 = _scores['${team1Key}1'] ?? 0;
            final game1Team2 = _scores['${team2Key}1'] ?? 0;
            final game2Team1 = _scores['${team1Key}2'] ?? 0;
            final game2Team2 = _scores['${team2Key}2'] ?? 0;

            final minScore = widget.gameWinningScore;

            bool game1Complete =
                (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) ||
                (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2);
            bool game2Complete =
                (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2) ||
                (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2);

            if (game1Complete && game2Complete) {
              int team1GamesWon = 0;
              int team2GamesWon = 0;

              if (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) {
                team1GamesWon++;
              } else if (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2)
                team2GamesWon++;

              if (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2) {
                team1GamesWon++;
              } else if (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2)
                team2GamesWon++;

              currentIsGameDisabled = team1GamesWon == 2 || team2GamesWon == 2;
            } else {
              currentIsGameDisabled = true;
            }
          }
        }

        final displayIsDisabled = currentIsGameDisabled;

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
                    child: _buildTeamScoreRow(
                      widget.match.team1,
                      team1Key,
                      team2Key,
                      displayIsDisabled,
                      setBuilderState,
                      gameNumber,
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
                    child: _buildTeamScoreRow(
                      widget.match.team2,
                      team2Key,
                      team1Key,
                      displayIsDisabled,
                      setBuilderState,
                      gameNumber,
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

  Widget _buildTeamScoreRow(
    String teamName,
    String teamKey,
    String opponentKey,
    bool displayIsDisabled,
    StateSetter setBuilderState,
    int gameNumber,
  ) {
    // Read scores directly from _scores map to get the latest values
    // This ensures we always get the current score, not a stale value
    final teamScore = _scores[teamKey] ?? 0;
    final opponentScore = _scores[opponentKey] ?? 0;
    final minScore = widget.gameWinningScore;
    
    // Check if this team has won (reached minScore and leading by 2+)
    final hasWon = teamScore >= minScore && teamScore >= opponentScore + 2;
    
    return Column(
      children: [
        Text(
          teamName,
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
                  displayIsDisabled || teamScore <= 0
                      ? null
                      : () async {
                        // Check if decreasing this score will reset a later game
                        final gameMatch = RegExp(
                          r'_game(\d+)',
                        ).firstMatch(teamKey);
                        if (gameMatch != null) {
                          final currentGameNum = int.parse(gameMatch.group(1)!);

                          // Check if Game 2 has scores and we're decreasing Game 1
                          if (currentGameNum == 1) {
                            final team1Key = '${widget.match.team1Id}_game2';
                            final team2Key = '${widget.match.team2Id}_game2';
                            final game2HasScores =
                                (_scores[team1Key] ?? 0) > 0 ||
                                (_scores[team2Key] ?? 0) > 0;

                            if (game2HasScores) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Confirm Score Change'),
                                      content: const Text(
                                        'Are you sure you want to change the score for GAME 1? That will reset the score for Game 2 and make it disabled until the score limit is reached again.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[600],
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Yes, Reset'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirmed != true) {
                                return; // User cancelled
                              }
                            }
                          }

                          // Check if Game 3 has scores and we're decreasing Game 2
                          if (currentGameNum == 2) {
                            final team1Key = '${widget.match.team1Id}_game3';
                            final team2Key = '${widget.match.team2Id}_game3';
                            final game3HasScores =
                                (_scores[team1Key] ?? 0) > 0 ||
                                (_scores[team2Key] ?? 0) > 0;

                            if (game3HasScores) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Confirm Score Change'),
                                      content: const Text(
                                        'Are you sure you want to change the score for GAME 2? That will reset the score for Game 3 and make it disabled until the score limit is reached again.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[600],
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Yes, Reset'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirmed != true) {
                                return; // User cancelled
                              }
                            }
                          }
                        }

                        // Get the current score directly from _scores to ensure we have the latest value
                        final currentTeamScore = _scores[teamKey] ?? 0;
                        final newScore = currentTeamScore - 1;
                        // Update score using the method to handle opponent score adjustment when decreasing
                        // _updateScore already calls _checkAndResetDisabledGames() internally
                        _updateScore(teamKey, newScore);
                        // Trigger rebuild of ALL StatefulBuilders (all game cards) to update enabled/disabled states
                        setState(() {});
                      },
              icon: Icon(Icons.remove_circle_outline),
              color:
                  displayIsDisabled || teamScore <= 0
                      ? Colors.grey[400]
                      : Colors.red[400],
            ),
            Column(
              children: [
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
                      '$teamScore',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
                // Only show "Winner" for individual games in 1game format
                // For bestof3, don't show winner for individual games - only show match winner
                if (hasWon && widget.matchFormat == '1game') ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Winner',
                    style: TextStyle(
                      color: Color.fromARGB(255, 105, 196, 2),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            Builder(
              builder: (context) {
                final currentScore = _scores[teamKey] ?? 0;
                final currentOpponentScore = _scores[opponentKey] ?? 0;
                final minScore = widget.gameWinningScore;
                
                // Only disable increment if team has definitively won (reached minScore and leading by 2+)
                // Allow incrementing when tied at minScore (e.g., 11-11, 15-15) to continue until win-by-2
                final hasWon = currentScore >= minScore && currentScore >= currentOpponentScore + 2;
                final isDisabled = displayIsDisabled || hasWon;
                
                return IconButton(
                  onPressed: isDisabled ? null : () {
                    // Update the score in the map
                    final newScore = currentScore + 1;
                    
                    // Update ONLY this team's score
                    _scores[teamKey] = newScore;
                    
                    // Check if Game 2 or Game 3 should be enabled/disabled
                    _checkAndResetDisabledGames();
                    
                    // Trigger rebuild of ALL StatefulBuilders (all game cards) to update enabled/disabled states
                    // This ensures Game 2 becomes enabled when Game 1 is completed
                    setState(() {});
                  },
                  icon: Icon(Icons.add_circle_outline),
                  color: isDisabled
                      ? Colors.grey[400]
                      : Colors.green[400],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWinnerDisplay() {
    if (widget.match.team1Id == null || widget.match.team2Id == null) {
      return const SizedBox.shrink();
    }

    String? winner;

    if (widget.matchFormat == '1game') {
      final team1Score = _scores['${widget.match.team1Id}_game1'] ?? 0;
      final team2Score = _scores['${widget.match.team2Id}_game1'] ?? 0;

      if (team1Score >= widget.gameWinningScore &&
          team1Score >= team2Score + 2) {
        winner = widget.match.team1;
      } else if (team2Score >= widget.gameWinningScore &&
          team2Score >= team1Score + 2) {
        winner = widget.match.team2;
      }
    } else {
      final team1GamesWon = _getGamesWon(widget.match.team1Id!);
      final team2GamesWon = _getGamesWon(widget.match.team2Id!);

      if (team1GamesWon >= 2) {
        winner = widget.match.team1;
      } else if (team2GamesWon >= 2) {
        winner = widget.match.team2;
      }
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
    final minScore = widget.gameWinningScore;

    for (int i = 1; i <= 3; i++) {
      final teamKey = '${teamId}_game$i';
      final opponentKey =
          teamId == widget.match.team1Id
              ? '${widget.match.team2Id}_game$i'
              : '${widget.match.team1Id}_game$i';

      final teamScore = _scores[teamKey] ?? 0;
      final opponentScore = _scores[opponentKey] ?? 0;

      if (teamScore >= minScore && teamScore >= opponentScore + 2) {
        gamesWon++;
      }
    }
    return gamesWon;
  }

  void _handleBackButton() {
    if (widget.match.day == 'Quarter Finals') {
      bool hasAnyScores = false;
      for (int i = 1; i <= 3; i++) {
        final team1Key = '${widget.match.team1Id}_game$i';
        final team2Key = '${widget.match.team2Id}_game$i';
        final team1Score = _scores[team1Key] ?? 0;
        final team2Score = _scores[team2Key] ?? 0;
        if (team1Score > 0 || team2Score > 0) {
          hasAnyScores = true;
          break;
        }
      }

      if (hasAnyScores) {
        final bool isFirstCard = widget.isFirstCard ?? false;

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                isFirstCard ? 'Reset Match Settings' : 'Unsaved Changes',
              ),
              content: Text(
                isFirstCard
                    ? 'The match settings will be reset and you\'ll need to enter them again. Are you sure you want to go back?'
                    : 'Your changes will not be saved. Are you sure you want to go back?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (widget.onBackPressed != null) {
                      widget.onBackPressed!();
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
        return;
      }
    }

    bool hasIncompleteScore = false;
    final minScore = widget.matchFormat == '1game' ? 11 : 15;

    for (int i = 1; i <= 3; i++) {
      final team1Key = '${widget.match.team1Id}_game$i';
      final team2Key = '${widget.match.team2Id}_game$i';

      final team1Score = _scores[team1Key] ?? 0;
      final team2Score = _scores[team2Key] ?? 0;

      if (team1Score > 0 || team2Score > 0) {
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
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
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
    // Get current score directly from _scores map
    final currentScore = _scores[key] ?? 0;
    final minScore = widget.gameWinningScore;
    
    // Get the game number from the key (e.g., "team1_game2" -> 2)
    final gameMatch = RegExp(r'_game(\d+)').firstMatch(key);
    if (gameMatch == null) {
      // If no game number found, just update the score
      _scores[key] = newScore;
      _checkAndResetDisabledGames();
      return;
    }
    
    final gameNum = gameMatch.group(1)!;
    
    // Determine the other team's key
    final otherTeamKey =
        key.contains(widget.match.team1Id ?? '')
            ? '${widget.match.team2Id}_game$gameNum'
            : '${widget.match.team1Id}_game$gameNum';
    final otherTeamCurrentScore = _scores[otherTeamKey] ?? 0;
    
    // Update the current team's score first
    _scores[key] = newScore;
    
    // Only adjust opponent's score when DECREASING (not when increasing)
    if (newScore < currentScore) {
      // ALWAYS maintain exactly 2-point difference when opponent is at/above minScore
      if (otherTeamCurrentScore >= minScore) {
        // Calculate what opponent's score should be to maintain exactly 2-point lead
        final requiredOpponentScore = newScore + 2;
        
        // If required score is >= minScore, use it (maintain exactly 2-point difference)
        // Example: 18-16, decrease 16 to 15 → opponent 18 becomes 17 (maintain 17-15 = 2 point lead)
        // Example: 15-15, decrease to 13 → opponent becomes 15 (13+2=15, maintain 15-13 = 2 point lead)
        // Example: 15-15, decrease to 10 → opponent stays at 15 (10+2=12 < 15, can't go below minScore)
        if (requiredOpponentScore >= minScore) {
          _scores[otherTeamKey] = requiredOpponentScore;
        } else {
          // Can't go below minScore, keep opponent at minScore
          _scores[otherTeamKey] = minScore;
        }
      }
    }
    // When INCREASING, never adjust the opponent's score

    // Check if Game 2 or Game 3 should be reset after this score change
    _checkAndResetDisabledGames();
  }

  void _checkAndResetDisabledGames() {
    if (widget.match.team1Id == null || widget.match.team2Id == null) return;

    final team1Key = '${widget.match.team1Id}_game';
    final team2Key = '${widget.match.team2Id}_game';
    final minScore = widget.gameWinningScore;

    // Check Game 1 completion
    final game1Team1 = _scores['${team1Key}1'] ?? 0;
    final game1Team2 = _scores['${team2Key}1'] ?? 0;
    bool game1Complete =
        (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) ||
        (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2);

    // Reset Game 2 if it becomes disabled
    if (!game1Complete && widget.matchFormat == 'bestof3') {
      bool hadGame2Scores =
          (_scores['${team1Key}2'] ?? 0) > 0 ||
          (_scores['${team2Key}2'] ?? 0) > 0;
      if (hadGame2Scores) {
        _scores['${team1Key}2'] = 0;
        _scores['${team2Key}2'] = 0;
      }
    }

    // Reset Game 3 if it becomes disabled
    if (widget.matchFormat == 'bestof3') {
      final game2Team1 = _scores['${team1Key}2'] ?? 0;
      final game2Team2 = _scores['${team2Key}2'] ?? 0;
      bool game2Complete =
          (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2) ||
          (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2);

      // Game 3 is disabled if Game 1 or Game 2 is not complete
      bool game3ShouldBeDisabled = !game1Complete || !game2Complete;

      // Also check if match is already decided (2-0 or 0-2)
      if (game1Complete) {
        int team1GamesWon = 0;
        int team2GamesWon = 0;

        if (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) {
          team1GamesWon++;
        } else if (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2) {
          team2GamesWon++;
        }

        if (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2) {
          team1GamesWon++;
        } else if (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2) {
          team2GamesWon++;
        }

        // If match is decided (2-0 or 0-2), Game 3 should also be disabled
        bool matchDecided = team1GamesWon == 2 || team2GamesWon == 2;
        game3ShouldBeDisabled = game3ShouldBeDisabled || matchDecided;
      }

      // Reset Game 3 if it should be disabled and has scores
      if (game3ShouldBeDisabled) {
        bool hadGame3Scores =
            (_scores['${team1Key}3'] ?? 0) > 0 ||
            (_scores['${team2Key}3'] ?? 0) > 0;
        if (hadGame3Scores) {
          _scores['${team1Key}3'] = 0;
          _scores['${team2Key}3'] = 0;
        }
      }
    }
  }

  Future<void> _saveScores() async {
    final minScore = widget.gameWinningScore;
    // If all scores are zero, saving is allowed (will reset the card)
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
    if (allScoresAreZero) {
      setState(() { _isLoading = true; });
      try {
        final scoresToSave = _convertScoresForPreliminaries(_scores);
        await widget.onScoresUpdated(scoresToSave);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving scores: $e'), backgroundColor: Colors.red)
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
      return;
    }

    // For 1game format, validate the single game
    if (widget.matchFormat == '1game') {
      final t1 = _scores['${widget.match.team1Id}_game1'] ?? 0;
      final t2 = _scores['${widget.match.team2Id}_game1'] ?? 0;
      
      if (t1 == 0 && t2 == 0) {
        // Allow 0-0 to reset
        setState(() { _isLoading = true; });
        try {
          final scoresToSave = _convertScoresForPreliminaries(_scores);
          await widget.onScoresUpdated(scoresToSave);
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving scores: $e'), backgroundColor: Colors.red)
            );
          }
        } finally {
          if (mounted) setState(() { _isLoading = false; });
        }
        return;
      }
      
      // Validate: if any score is entered, one team must reach winning score and win by 2
      // Allow scores above minScore as long as win-by-2 is maintained
      bool hasWinner = false;
      if (t1 >= minScore && t1 >= t2 + 2) {
        hasWinner = true;
      }
      else if (t2 >= minScore && t2 >= t1 + 2) {
        hasWinner = true;
      }
      
      if (!hasWinner) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Score must be $minScore (minimum score to win) or 0-0. One team must reach $minScore and win by 2. Current: $t1-$t2'))
          );
        }
        return;
      }
    }
    
    // ENFORCE: for best of 3, every enabled game must have a valid winner
    if (widget.matchFormat == 'bestof3') {
      // figure out which games are enabled
      // Game 1 is always enabled
      List<int> enabledGames = [1];
      final team1Key = '${widget.match.team1Id}_game';
      final team2Key = '${widget.match.team2Id}_game';
      // Check if Game 1 was completed validly
      final game1Team1 = _scores['${team1Key}1'] ?? 0;
      final game1Team2 = _scores['${team2Key}1'] ?? 0;
      bool game1Complete = (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) || (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2);
      if (game1Complete) enabledGames.add(2);
      // Check Game 2 completion
      final game2Team1 = _scores['${team1Key}2'] ?? 0;
      final game2Team2 = _scores['${team2Key}2'] ?? 0;
      bool game2Complete = (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2) || (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2);
      // Only enable Game 3 if BOTH G1+G2 complete and neither team won 2 yet
      int team1Wins = 0, team2Wins = 0;
      if (game1Team1 >= minScore && game1Team1 >= game1Team2 + 2) team1Wins++;
      if (game1Team2 >= minScore && game1Team2 >= game1Team1 + 2) team2Wins++;
      if (game2Team1 >= minScore && game2Team1 >= game2Team2 + 2) team1Wins++;
      if (game2Team2 >= minScore && game2Team2 >= game2Team1 + 2) team2Wins++;
      bool matchDecided = team1Wins == 2 || team2Wins == 2;
      if (game1Complete && game2Complete && !matchDecided) enabledGames.add(3);
      // For each enabled game, check: must have a winner; if scores are both zero, it's incomplete
      for (final gameNum in enabledGames) {
        final t1 = _scores['$team1Key$gameNum'] ?? 0;
        final t2 = _scores['$team2Key$gameNum'] ?? 0;
        
        if (t1 == 0 && t2 == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter a valid score for every Game'))
            );
          }
          return;
        }
        
        // Validate: if any score is entered, one team must reach winning score and win by 2
        // Allow scores above minScore as long as win-by-2 is maintained
        bool hasWinner = false;
        if (t1 >= minScore && t1 >= t2 + 2) {
          hasWinner = true;
        }
        else if (t2 >= minScore && t2 >= t1 + 2) {
          hasWinner = true;
        }
        
        if (!hasWinner) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Score must be $minScore (minimum score to win) or 0-0. One team must reach $minScore and win by 2. Game $gameNum: $t1-$t2'))
            );
          }
          return;
        }
      }
    }

    // ... proceed with original allGamesValid logic ...
    setState(() { _isLoading = true; });
    try {
      final scoresToSave = _convertScoresForPreliminaries(_scores);
      await widget.onScoresUpdated(scoresToSave);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving scores: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Map<String, dynamic> _convertScoresForPreliminaries(
    Map<String, dynamic> scores,
  ) {
    final convertedScores = <String, dynamic>{};

    // Always include both teams
    if (widget.match.team1Id != null && widget.match.team2Id != null) {
      final team1Id = widget.match.team1Id!;
      final team2Id = widget.match.team2Id!;

      // For playoff matches (best-of-3), preserve individual game scores for display
      // For preliminary matches (1 game), we just use game1 scores
      if (widget.matchFormat == 'bestof3') {
        // For Semi Finals and Finals, preserve individual game scores for display
        // Also add team-level wins for winner determination
        int team1Wins = 0;
        int team2Wins = 0;

        for (int i = 1; i <= 3; i++) {
          final team1Key = '${team1Id}_game$i';
          final team2Key = '${team2Id}_game$i';
          final team1Score = scores[team1Key] ?? 0;
          final team2Score = scores[team2Key] ?? 0;

          // Preserve individual game scores for display
          convertedScores[team1Key] = team1Score;
          convertedScores[team2Key] = team2Score;

          // Count wins for winner determination
          if (team1Score > team2Score) team1Wins++;
          if (team2Score > team1Score) team2Wins++;
        }

        // Add team-level wins for winner determination
        convertedScores[team1Id] = team1Wins;
        convertedScores[team2Id] = team2Wins;
      } else {
        // For 1-game format, use the specific game number if provided
        final gameNumber = widget.selectedGameNumber ?? 1;
        final team1Key = '${team1Id}_game$gameNumber';
        final team2Key = '${team2Id}_game$gameNumber';

        // Store both the game-specific scores and team-level scores
        convertedScores[team1Key] = scores[team1Key] ?? 0;
        convertedScores[team2Key] = scores[team2Key] ?? 0;
        convertedScores[team1Id] = scores[team1Key] ?? 0;
        convertedScores[team2Id] = scores[team2Key] ?? 0;
      }
    }

    return convertedScores;
  }
}
