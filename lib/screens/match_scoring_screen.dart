import 'package:flutter/material.dart';
import '../models/match.dart';
import '../utils/snackbar_utils.dart';

class MatchScoringScreen extends StatefulWidget {
  final Match match;
  final Map<String, int>? initialScores;
  final Function(Map<String, int>) onScoresUpdated;

  const MatchScoringScreen({
    super.key,
    required this.match,
    this.initialScores,
    required this.onScoresUpdated,
  });

  @override
  State<MatchScoringScreen> createState() => _MatchScoringScreenState();
}

class _MatchScoringScreenState extends State<MatchScoringScreen> {
  late TextEditingController _team1ScoreController;
  late TextEditingController _team2ScoreController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _team1ScoreController = TextEditingController(
      text: widget.initialScores?[widget.match.team1Id]?.toString() ?? '0',
    );
    _team2ScoreController = TextEditingController(
      text: widget.initialScores?[widget.match.team2Id]?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _team1ScoreController.dispose();
    _team2ScoreController.dispose();
    super.dispose();
  }

  void _handleDecreaseScore(TextEditingController controller, int currentScore, int maxScore) {
    final isSemiFinalsOrFinals =
        widget.match.day == 'Semi Finals' || widget.match.day == 'Finals';
    final minScore = isSemiFinalsOrFinals ? 15 : 11;
    
    // Determine which team's score is being decreased
    final isTeam1 = controller == _team1ScoreController;
    final otherController = isTeam1 ? _team2ScoreController : _team1ScoreController;
    
    final currentOtherScore = int.tryParse(otherController.text) ?? 0;
    final newScore = currentScore - 1;
    
    // Update the current team's score first
    controller.text = newScore.toString();
    
    // Adjust opponent's score when decreasing, based on win-by-2 logic
    // ALWAYS maintain exactly 2-point difference when opponent is at/above minScore
    if (currentOtherScore >= minScore) {
      // Calculate what opponent's score should be to maintain exactly 2-point lead
      final requiredOpponentScore = newScore + 2;
      
      // If required score is >= minScore, use it (maintain exactly 2-point difference)
      // Example: 18-16, decrease 16 to 15 → opponent 18 becomes 17 (maintain 17-15 = 2 point lead)
      // Example: 15-15, decrease to 13 → opponent becomes 15 (13+2=15, maintain 15-13 = 2 point lead)
      // Example: 15-15, decrease to 10 → opponent stays at 15 (10+2=12 < 15, can't go below minScore)
      if (requiredOpponentScore >= minScore) {
        otherController.text = requiredOpponentScore.toString();
      } else {
        // Can't go below minScore, keep opponent at minScore
        otherController.text = minScore.toString();
      }
    }
  }

  void _handleBackButton() {
    final team1Score = int.tryParse(_team1ScoreController.text) ?? 0;
    final team2Score = int.tryParse(_team2ScoreController.text) ?? 0;

    // Check if scores are incomplete (need at least 11 points for regular games)
    final isSemiFinalsOrFinals =
        widget.match.day == 'Semi Finals' || widget.match.day == 'Finals';
    final minScore = isSemiFinalsOrFinals ? 15 : 11;

    bool hasIncompleteScore = false;
    if (team1Score > 0 || team2Score > 0) {
      // Check if game has a winner using exact winning score rule
      bool hasWinner = false;

      if (team1Score == minScore && team1Score >= team2Score + 2) {
        hasWinner = true;
      } else if (team2Score == minScore && team2Score >= team1Score + 2) {
        hasWinner = true;
      }

      hasIncompleteScore = !hasWinner;
    }

    if (hasIncompleteScore) {
      // Check if there were previously saved scores
      final hasPreviousScores =
          widget.initialScores != null &&
          (widget.initialScores![widget.match.team1Id] != null ||
              widget.initialScores![widget.match.team2Id] != null);

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

  void _saveScores() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final team1Score = int.tryParse(_team1ScoreController.text) ?? 0;
      final team2Score = int.tryParse(_team2ScoreController.text) ?? 0;

      // Determine if this is a Semi Finals or Finals match (15 points win-by-2)
      // or a preliminary match (11 points win-by-2)
      final isSemiFinalsOrFinals =
          widget.match.day == 'Semi Finals' || widget.match.day == 'Finals';
      final minScore = isSemiFinalsOrFinals ? 15 : 11;
      final maxScore = minScore; // Max score equals winning score

      // Validate scores: check max score limit first
      String? validationError;

      // Check if any score exceeds max
      if (team1Score > maxScore || team2Score > maxScore) {
        validationError = 'Score cannot exceed $maxScore points. Current: $team1Score-$team2Score';
      }
      // Allow resetting to 0-0 (no validation error)
      else if (team1Score == 0 && team2Score == 0) {
        // No validation needed - allow saving 0-0 to reset scores
        validationError = null;
      }
      // Check if game has a winner using win-by-2 rule
      else {
        bool hasWinner = false;

        // Team 1 wins if they have at least minScore and lead by 2
        if (team1Score >= minScore && team1Score >= team2Score + 2) {
          hasWinner = true;
        }
        // Team 2 wins if they have at least minScore and lead by 2
        else if (team2Score >= minScore && team2Score >= team1Score + 2) {
          hasWinner = true;
        }

        if (!hasWinner) {
          if (team1Score < minScore && team2Score < minScore) {
            validationError = 'One team must reach at least $minScore points to win';
          } else {
            validationError = 'Must win by 2 points. Current score: $team1Score-$team2Score';
          }
        }
      }

      if (validationError != null) {
        SnackBarUtils.showError(
          context,
          message: validationError,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final scores = {
        widget.match.team1Id ?? '': team1Score,
        widget.match.team2Id ?? '': team2Score,
      };

      widget.onScoresUpdated(scores);

      // Show success message
      SnackBarUtils.showSuccess(
        context,
        message: 'Scores saved successfully!',
        duration: const Duration(seconds: 4),
      );

      // Navigate back with cleanup
      SnackBarUtils.popWithCleanup(context);
    } catch (e) {
      SnackBarUtils.showError(
        context,
        message: 'Error saving scores: $e',
        duration: const Duration(seconds: 5),
      );
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Match Scoring'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackButton,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Match Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '${widget.match.day} - ${widget.match.time}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.match.team1} vs ${widget.match.team2}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Scoring Section
            Expanded(
              child: Row(
                children: [
                  // Team 1
                  Expanded(
                    child: _buildSimpleTeamCard(
                      teamName: widget.match.team1,
                      controller: _team1ScoreController,
                      teamColor: Colors.blue,
                      maxScore:
                          widget.match.day == 'Semi Finals' ||
                                  widget.match.day == 'Finals'
                              ? 15
                              : 11,
                    ),
                  ),

                  const SizedBox(width: 20),

                  // VS
                  const Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Team 2
                  Expanded(
                    child: _buildSimpleTeamCard(
                      teamName: widget.match.team2,
                      controller: _team2ScoreController,
                      teamColor: Colors.red,
                      maxScore:
                          widget.match.day == 'Semi Finals' ||
                                  widget.match.day == 'Finals'
                              ? 15
                              : 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                // Save Button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _saveScores,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isProcessing ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isProcessing
                              ? const Text('Saving...')
                              : const Text('Save Scores'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTeamCard({
    required String teamName,
    required TextEditingController controller,
    required Color teamColor,
    required int maxScore,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Team Name
          Text(
            teamName,
            style: TextStyle(
              color: teamColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 20),

          // Score Input
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: teamColor.withOpacity(0.3)),
            ),
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              readOnly: true,
              enabled: false,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: teamColor,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Control Buttons
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final currentScore = int.tryParse(value.text) ?? 0;

              final minusDisabled = currentScore <= 0;
              final plusDisabled = currentScore >= maxScore;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decrease Button
                  IconButton(
                    onPressed:
                        minusDisabled
                            ? null
                            : () {
                              _handleDecreaseScore(controller, currentScore, maxScore);
                            },
                    icon: Icon(
                      Icons.remove,
                      color: minusDisabled ? Colors.grey : Colors.red,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          minusDisabled
                              ? Colors.grey.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                      shape: const CircleBorder(),
                    ),
                  ),

                  // Increase Button
                  IconButton(
                    onPressed: plusDisabled ? null : () {
                      // Don't allow incrementing beyond maxScore
                      controller.text = (currentScore + 1).toString();
                    },
                    icon: Icon(
                      Icons.add,
                      color: plusDisabled ? Colors.grey : Colors.green,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: plusDisabled 
                          ? Colors.grey.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
