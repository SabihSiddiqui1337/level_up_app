class User {
  final String id;
  final String email;
  final String password;
  final String name;
  final String username;
  final String phone;
  final String role; // 'user', 'scoring', or 'owner'
  final DateTime createdAt;
  final String? teamId; // If user is a team manager
  final bool needsPasswordSetup; // True if user needs to set password on first login
  final String? height; // Height in inches or cm
  final String? weight; // Weight in lbs or kg
  final DateTime? dateOfBirth; // Date of Birth
  final String? profilePicturePath; // Path to profile picture
  final String? jerseyNumber; // Jersey/Player number

  User({
    required this.id,
    required this.email,
    required this.password,
    required this.name,
    required this.username,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.teamId,
    this.needsPasswordSetup = false,
    this.height,
    this.weight,
    this.dateOfBirth,
    this.profilePicturePath,
    this.jerseyNumber,
  });

  // Calculate age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int calculatedAge = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'name': name,
      'username': username,
      'phone': phone,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'teamId': teamId,
      'needsPasswordSetup': needsPasswordSetup,
      'height': height,
      'weight': weight,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'profilePicturePath': profilePicturePath,
      'jerseyNumber': jerseyNumber,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      password: json['password'],
      name: json['name'],
      username: json['username'],
      phone: json['phone'],
      role: json['role'],
      createdAt: DateTime.parse(json['createdAt']),
      teamId: json['teamId'],
      needsPasswordSetup: json['needsPasswordSetup'] ?? false,
      height: json['height'],
      weight: json['weight'],
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.parse(json['dateOfBirth']) : null,
      profilePicturePath: json['profilePicturePath'],
      jerseyNumber: json['jerseyNumber'],
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? password,
    String? name,
    String? username,
    String? phone,
    String? role,
    DateTime? createdAt,
    String? teamId,
    bool? needsPasswordSetup,
    String? height,
    String? weight,
    DateTime? dateOfBirth,
    String? profilePicturePath,
    String? jerseyNumber,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      teamId: teamId ?? this.teamId,
      needsPasswordSetup: needsPasswordSetup ?? this.needsPasswordSetup,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
    );
  }
}
