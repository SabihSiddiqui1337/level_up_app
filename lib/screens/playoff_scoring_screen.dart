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
        title: Text('Game Score'),
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

    return StatefulBuilder(
      builder: (context, setBuilderState) {
        bool hadGame3Scores = false;
        if (gameNumber == 3 &&
            widget.match.team1Id != null &&
            widget.match.team2Id != null) {
          final team1Key = '${widget.match.team1Id}_game3';
          final team2Key = '${widget.match.team2Id}_game3';
          hadGame3Scores =
              (_scores[team1Key] ?? 0) > 0 || (_scores[team2Key] ?? 0) > 0;
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

            if (currentIsGameDisabled &&
                hadGame3Scores &&
                widget.match.team1Id != null &&
                widget.match.team2Id != null) {
              _scores['${team1Key}3'] = 0;
              _scores['${team2Key}3'] = 0;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setBuilderState(() {});
              });
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
                      team1Score,
                      team2Score,
                      team1Key,
                      displayIsDisabled,
                      setBuilderState,
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
                      team2Score,
                      team1Score,
                      team2Key,
                      displayIsDisabled,
                      setBuilderState,
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
    int teamScore,
    int opponentScore,
    String teamKey,
    bool displayIsDisabled,
    StateSetter setBuilderState,
  ) {
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
                      : () =>
                          _updateScore(teamKey, teamScore - 1, opponentScore),
              icon: Icon(Icons.remove_circle_outline),
              color:
                  displayIsDisabled || teamScore <= 0
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
                  '$teamScore',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                final hasReachedWinningScore =
                    teamScore >= widget.gameWinningScore &&
                    teamScore >= opponentScore + 2;
                if (displayIsDisabled || hasReachedWinningScore) {
                  return;
                }
                _updateScore(teamKey, teamScore + 1, opponentScore);
              },
              icon: Icon(Icons.add_circle_outline),
              color: () {
                final hasReachedWinningScore =
                    teamScore >= widget.gameWinningScore &&
                    teamScore >= opponentScore + 2;
                return displayIsDisabled || hasReachedWinningScore
                    ? Colors.grey[400]
                    : Colors.green[400];
              }(),
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

  void _updateScore(String key, int newScore, int opponentScore) {
    _scores[key] = newScore;
    setState(() {});
  }

  Future<void> _saveScores() async {
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
      setState(() {
        _isLoading = true;
      });
      try {
        final scoresToSave = _convertScoresForPreliminaries(_scores);
        await widget.onScoresUpdated(scoresToSave);
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

    final minScore = widget.gameWinningScore;

    bool allGamesValid = true;
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
          allGamesValid = false;
          break;
        }
      }
    }

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
      final scoresToSave = _convertScoresForPreliminaries(_scores);
      await widget.onScoresUpdated(scoresToSave);
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

  Map<String, dynamic> _convertScoresForPreliminaries(
    Map<String, dynamic> scores,
  ) {
    final convertedScores = <String, dynamic>{};

    // Always include both teams, even if one has 0 score
    if (widget.match.team1Id != null && widget.match.team2Id != null) {
      final team1Id = widget.match.team1Id!;
      final team2Id = widget.match.team2Id!;
      final team1Key = '${team1Id}_game1';
      final team2Key = '${team2Id}_game1';

      convertedScores[team1Id] = scores[team1Key] ?? 0;
      convertedScores[team2Id] = scores[team2Key] ?? 0;
    }

    return convertedScores;
  }
}
