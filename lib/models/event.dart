class Event {
  final String id;
  final String title;
  final String date;
  final String location;
  final String address;

  const Event({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.address,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      location: json['location'] as String,
      address: json['address'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'location': location,
      'address': address,
    };
  }
}
