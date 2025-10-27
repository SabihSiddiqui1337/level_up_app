import 'package:flutter/material.dart';
import '../models/match.dart';

/// Reusable match card widget
class MatchCard extends StatelessWidget {
  final Match match;
  final int team1Score;
  final int team2Score;
  final String? winningTeamId;
  final bool isSelected;
  final bool hasOpponent;
  final bool isLocked;
  final bool isSemiFinalsLocked;
  final bool isQuarterFinalsLocked;
  final bool canScore;
  final VoidCallback? onTap;
  final bool isPlayoffMatch;

  const MatchCard({
    super.key,
    required this.match,
    required this.team1Score,
    required this.team2Score,
    required this.winningTeamId,
    required this.isSelected,
    required this.hasOpponent,
    required this.isLocked,
    required this.isSemiFinalsLocked,
    required this.isQuarterFinalsLocked,
    required this.canScore,
    this.onTap,
    this.isPlayoffMatch = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          (hasOpponent &&
                  !isLocked &&
                  !isSemiFinalsLocked &&
                  !isQuarterFinalsLocked &&
                  canScore)
              ? onTap
              : null,
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
              _buildNormalMatchCard(),
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalMatchCard() {
    final hasScores = team1Score > 0 || team2Score > 0;
    final team1Won = winningTeamId == match.team1Id;
    final team2Won = winningTeamId == match.team2Id;

    // Get team display names
    String getTeamDisplayName(String teamName) {
      if (!isPlayoffMatch) return teamName;
      if (teamName == 'TBA') return 'TBA';
      // For playoff matches, return name as-is (seeding should be handled by caller)
      return teamName;
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                      getTeamDisplayName(match.team1),
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
                      getTeamDisplayName(match.team2),
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
}
