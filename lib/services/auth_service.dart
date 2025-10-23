// ignore_for_file: avoid_print

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  List<User> _users = [];

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Initialize with persistent storage
  Future<void> initialize() async {
    print('AuthService.initialize called');
    await _loadUsers();
    await _loadCurrentUser(); // Load current user session

    // Only add demo users if no users exist in storage
    if (_users.isEmpty) {
      _users = [
        User(
          id: '1',
          email: 'admin@levelup.com',
          password: 'admin123',
          name: 'Admin User',
          username: 'admin',
          phone: '123-456-7890',
          role: 'owner',
          createdAt: DateTime.now(),
        ),
        User(
          id: '2',
          email: 'scoring@levelup.com',
          password: 'scoring123',
          name: 'John Scoring',
          username: 'scoring',
          phone: '987-654-3210',
          role: 'scoring',
          createdAt: DateTime.now(),
        ),
        User(
          id: '3',
          email: 'sabih',
          password: '1234567',
          name: 'Sabih',
          username: 'sabih',
          phone: '555-123-4567',
          role: 'scoring',
          createdAt: DateTime.now(),
        ),
      ];
      await _saveUsers();
      print('AuthService initialized with ${_users.length} demo users');
    } else {
      print('AuthService loaded ${_users.length} users from storage');
    }
  }

  // Load users from SharedPreferences
  Future<void> loadUsers() async {
    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('users');
      print('Loading users from storage...');
      print('usersJson is null: ${usersJson == null}');
      if (usersJson != null) {
        print('Found usersJson: ${usersJson.length} characters');
        final List<dynamic> usersList = json.decode(usersJson);
        _users = usersList.map((json) => User.fromJson(json)).toList();
        print('Loaded ${_users.length} users from storage');
        print('Loaded users: ${_users.map((u) => u.username).toList()}');
      } else {
        print('No users found in storage, starting with empty list');
        _users = [];
      }
    } catch (e) {
      print('Error loading users: $e');
      _users = [];
    }
  }

  // Save users to SharedPreferences
  Future<void> _saveUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = json.encode(
        _users.map((user) => user.toJson()).toList(),
      );
      print('Saving ${_users.length} users to storage...');
      print('Users to save: ${_users.map((u) => u.username).toList()}');
      await prefs.setString('users', usersJson);
      print('Successfully saved ${_users.length} users to storage');

      // Verify the save worked
      final savedJson = prefs.getString('users');
      print('Verification - saved data length: ${savedJson?.length ?? 0}');
    } catch (e) {
      print('Error saving users: $e');
    }
  }

  // Save current user session
  Future<void> _saveCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        final userJson = json.encode(_currentUser!.toJson());
        await prefs.setString('current_user', userJson);
        print('Saved current user: ${_currentUser!.username}');
      } else {
        await prefs.remove('current_user');
        print('Cleared current user session');
      }
    } catch (e) {
      print('Error saving current user: $e');
    }
  }

  // Load current user session
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = json.decode(userJson);
        _currentUser = User.fromJson(userMap);
        print('Loaded current user: ${_currentUser!.username}');
      } else {
        print('No current user found in storage');
      }
    } catch (e) {
      print('Error loading current user: $e');
      _currentUser = null;
    }
  }

  Future<bool> login(String emailOrUsername, String password) async {
    print('AuthService.login called with: $emailOrUsername, $password');
    print(
      'Available users: ${_users.map((u) => '${u.email}(${u.username})').toList()}',
    );
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    try {
      // Convert input to lowercase for case-insensitive comparison
      final lowerEmailOrUsername = emailOrUsername.toLowerCase();

      final user = _users.firstWhere(
        (user) =>
            (user.email.toLowerCase() == lowerEmailOrUsername ||
                user.username.toLowerCase() == lowerEmailOrUsername) &&
            user.password == password,
      );

      print('User found: ${user.name} (${user.username})');
      _currentUser = user;
      await _saveCurrentUser(); // Save current user session
      return true;
    } catch (e) {
      print('User not found: $e');
      print('Tried to find user with email/username: $emailOrUsername');
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String username,
    required String phone,
    String role = 'user',
  }) async {
    print('AuthService.register called with: $email, $username, $name');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Check if email already exists (case-insensitive)
    if (_users.any((user) => user.email.toLowerCase() == email.toLowerCase())) {
      print('Email already exists: $email');
      throw Exception('User with this email already exists');
    }

    // Check if username already exists (case-insensitive)
    if (_users.any(
      (user) => user.username.toLowerCase() == username.toLowerCase(),
    )) {
      print('Username already exists: $username');
      throw Exception('Username is already taken. Please try again.');
    }

    final newUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      password: password,
      name: name,
      username: username,
      phone: phone,
      role: role,
      createdAt: DateTime.now(),
    );

    print('Creating new user: ${newUser.name} (${newUser.username})');
    _users.add(newUser);
    await _saveUsers(); // Save to persistent storage
    print('Total users now: ${_users.length}');
    print('Users list: ${_users.map((u) => u.username).toList()}');

    // Don't auto-login during registration
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _saveCurrentUser(); // Clear current user session
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? email,
  }) async {
    if (_currentUser == null) return false;

    await Future.delayed(const Duration(seconds: 1));

    _currentUser = _currentUser!.copyWith(
      name: name ?? _currentUser!.name,
      phone: phone ?? _currentUser!.phone,
      email: email ?? _currentUser!.email,
    );

    // Update in users list
    final index = _users.indexWhere((user) => user.id == _currentUser!.id);
    if (index != -1) {
      _users[index] = _currentUser!;
    }

    // Save updated users to storage
    await _saveUsers();

    // Save updated current user session
    await _saveCurrentUser();

    print('Profile updated for user: ${_currentUser!.username}');
    return true;
  }

  List<User> get users => List.from(_users);

  List<User> getAllUsers() {
    return List.from(_users);
  }

  // Add a new user (for admin panel)
  Future<void> addUser(User user) async {
    _users.add(user);
    await _saveUsers();
  }

  // Update user
  Future<void> updateUser(User updatedUser) async {
    final index = _users.indexWhere((user) => user.id == updatedUser.id);
    if (index != -1) {
      _users[index] = updatedUser;
      await _saveUsers();
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    _users.removeWhere((user) => user.id == userId);
    await _saveUsers();
  }

  // Check if email exists in the database
  bool checkEmailExists(String email) {
    return _users.any(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
  }
}
