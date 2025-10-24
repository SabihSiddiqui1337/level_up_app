import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _saveScores() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final team1Score = int.tryParse(_team1ScoreController.text) ?? 0;
      final team2Score = int.tryParse(_team2ScoreController.text) ?? 0;

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

  void _resetScores() {
    setState(() {
      _team1ScoreController.text = '0';
      _team2ScoreController.text = '0';
    });

    SnackBarUtils.showWarning(
      context,
      message: 'Scores reset to 0',
      duration: const Duration(seconds: 2),
    );
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
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                // Reset Button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _resetScores,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isProcessing ? Colors.grey : Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

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
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decrease Button
              IconButton(
                onPressed: () {
                  final currentScore = int.tryParse(controller.text) ?? 0;
                  if (currentScore > 0) {
                    controller.text = (currentScore - 1).toString();
                  }
                },
                icon: const Icon(Icons.remove, color: Colors.red),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  shape: const CircleBorder(),
                ),
              ),

              // Increase Button
              IconButton(
                onPressed: () {
                  final currentScore = int.tryParse(controller.text) ?? 0;
                  controller.text = (currentScore + 1).toString();
                },
                icon: const Icon(Icons.add, color: Colors.green),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
