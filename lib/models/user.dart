class User {
  final String id;
  final String email;
  final String password;
  final String name;
  final String username;
  final String phone;
  final String role; // 'manager' or 'admin'
  final DateTime createdAt;
  final String? teamId; // If user is a team manager

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
  });

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
    );
  }
}
