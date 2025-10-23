class PickleballPlayer {
  final String id;
  final String name;
  final String duprRating;

  PickleballPlayer({
    required this.id,
    required this.name,
    required this.duprRating,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'duprRating': duprRating};
  }

  factory PickleballPlayer.fromJson(Map<String, dynamic> json) {
    return PickleballPlayer(
      id: json['id'],
      name: json['name'],
      duprRating:
          json['duprRating'] ??
          '< 3.5', // Default value for backward compatibility
    );
  }
}
