class PickleballPlayer {
  final String id;
  final String name;
  final String duprRating;
  final String? userId; // Optional: link to user profile if not a guest

  PickleballPlayer({
    required this.id,
    required this.name,
    required this.duprRating,
    this.userId, // Optional: only set if linked to a user profile
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duprRating': duprRating,
      'userId': userId,
    };
  }

  factory PickleballPlayer.fromJson(Map<String, dynamic> json) {
    return PickleballPlayer(
      id: json['id'],
      name: json['name'],
      duprRating:
          json['duprRating'] ??
          '< 3.5', // Default value for backward compatibility
      userId: json['userId'],
    );
  }
}
