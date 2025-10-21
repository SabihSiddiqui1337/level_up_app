class Player {
  final String id;
  final String name;
  final String position;
  final int jerseyNumber;
  final String phoneNumber;
  final String email;
  final int age;
  final double height; // in feet
  final double weight; // in pounds

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.jerseyNumber,
    required this.phoneNumber,
    required this.email,
    required this.age,
    required this.height,
    required this.weight,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'jerseyNumber': jerseyNumber,
      'phoneNumber': phoneNumber,
      'email': email,
      'age': age,
      'height': height,
      'weight': weight,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      position: json['position'],
      jerseyNumber: json['jerseyNumber'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      age: json['age'],
      height: json['height'],
      weight: json['weight'],
    );
  }
}
