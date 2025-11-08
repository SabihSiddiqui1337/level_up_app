class Event {
  final String id;
  final String title;
  final DateTime date;
  final String locationName;
  final String locationAddress;
  final String sportName;
  final String? description;
  final String? division; // Division for Basketball/Pickleball events
  final double? amount; // Registration amount (null means free)
  final DateTime createdAt;

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.locationName,
    required this.locationAddress,
    required this.sportName,
    required this.createdAt,
    this.description,
    this.division,
    this.amount,
  });

  // Convert Event to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'locationName': locationName,
      'locationAddress': locationAddress,
      'sportName': sportName,
      'description': description,
      'division': division,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create Event from JSON
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      date: DateTime.parse(json['date']),
      locationName: json['locationName'] ?? '',
      locationAddress: json['locationAddress'] ?? '',
      sportName: json['sportName'] ?? '',
      description: json['description'],
      division: json['division'],
      amount: json['amount'] != null ? (json['amount'] is double ? json['amount'] : (json['amount'] as num).toDouble()) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Create a copy of Event with updated fields
  Event copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? locationName,
    String? locationAddress,
    String? sportName,
    String? description,
    String? division,
    double? amount,
    DateTime? createdAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      sportName: sportName ?? this.sportName,
      description: description ?? this.description,
      division: division ?? this.division,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, date: $date, locationName: $locationName, locationAddress: $locationAddress, sportName: $sportName, description: $description, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
