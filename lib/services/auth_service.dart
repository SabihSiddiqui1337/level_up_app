import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  List<User> _users = [];
  User? _currentUser;
  
  // Store verification codes with expiration times
  // Key: normalized phone number, Value: {code: String, expiresAt: DateTime}
  final Map<String, Map<String, dynamic>> _verificationCodes = {};

  // Initialize the service
  Future<void> initialize() async {
    print('AuthService.initialize called');
    await _loadUsers();
    await _loadCurrentUser(); // Load current user session
    
    // Sync current user's role with users list (in case role was changed)
    // This will be done after admin accounts are updated, so we do it after the admin accounts loop

    // Define admin accounts to ensure they exist
    final adminAccounts = [
      // Admin accounts with scoring access
      User(
        id: '1',
        email: 'sabih-1337@live.com',
        password: 'admin123',
        name: 'Sabih Siddiqui - Owner',
        username: 'Sabih1337',
        phone: '8322903291',
        role: 'owner',
        createdAt: DateTime.now(),
      ),
    ];

    // Add admin accounts only if they don't already exist (by ID)
    // If they exist, update their role to match the hardcoded value
    bool hasChanges = false;
    for (final adminAccount in adminAccounts) {
      final existingIndex = _users.indexWhere((user) => user.id == adminAccount.id);
      if (existingIndex == -1) {
        _users.add(adminAccount);
        hasChanges = true;
        print('Added admin account: ${adminAccount.username}');
      } else {
        // Update existing user to match hardcoded role (in case it was changed)
        if (_users[existingIndex].role != adminAccount.role) {
          print('Updating user ${adminAccount.username} role from ${_users[existingIndex].role} to ${adminAccount.role}');
          _users[existingIndex] = adminAccount;
          hasChanges = true;
        }
      }
    }

    // Only save if we added new admin accounts
    if (hasChanges) {
      await _saveUsers();
    }
    
    // NOW sync current user's role with users list (after admin accounts are updated)
    if (_currentUser != null) {
      final userIndex = _users.indexWhere((u) => u.id == _currentUser!.id);
      if (userIndex != -1) {
        // Update current user with latest data from users list
        final updatedUser = _users[userIndex];
        if (updatedUser.role != _currentUser!.role) {
          print('⚠️ Role mismatch detected! Current user role: ${_currentUser!.role}, Users list role: ${updatedUser.role}');
          print('✅ Syncing current user role from "${_currentUser!.role}" to "${updatedUser.role}"');
        }
        _currentUser = updatedUser;
        await _saveCurrentUser();
        print('✅ Current user synced: ${_currentUser!.email} now has role: ${_currentUser!.role}');
      } else {
        print('⚠️ Current user ${_currentUser!.email} not found in users list, cannot sync role');
      }
    }
    
    print('AuthService initialized with ${_users.length} total users');
    print('User list: ${_users.map((u) => '${u.username}(${u.email})[${u.role}]').toList()}');
  }

  // Load users from SharedPreferences
  Future<void> loadUsers() async {
    await _loadUsers();
  }

  // Reset users data (for fixing email case issues)
  Future<void> resetUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('users');
      await prefs.remove('current_user');
      _users = [];
      _currentUser = null;
      print('Users data cleared. App will reinitialize with new data.');
    } catch (e) {
      print('Error resetting users: $e');
    }
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
        await prefs.setString(
          'current_user',
          json.encode(_currentUser!.toJson()),
        );
        print('Current user saved: ${_currentUser!.username}');
      } else {
        await prefs.remove('current_user');
        print('Current user cleared');
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
        _currentUser = User.fromJson(json.decode(userJson));
        print('Current user loaded: ${_currentUser!.username}');
      } else {
        _currentUser = null;
        print('No current user found');
      }
    } catch (e) {
      print('Error loading current user: $e');
      _currentUser = null;
    }
  }

  // Login method
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

      print('User found: ${user.name} (${user.username}) with role: ${user.role}');
      _currentUser = user;
      await _saveCurrentUser(); // Save current user session
      print('canScore after login: $canScore');
      return true;
    } catch (e) {
      print('User not found: $e');
      print('Tried to find user with email/username: $emailOrUsername');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String username,
    required String phone,
    String? height,
    String? weight,
    DateTime? dateOfBirth,
    String? jerseyNumber,
  }) async {
    print('AuthService.register called with: $email, $username, $phone');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Check for email conflicts
    try {
      _users.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
      );
      // If we get here, email exists
      throw Exception('EMAIL_TAKEN');
    } catch (e) {
      if (e.toString().contains('EMAIL_TAKEN')) {
        rethrow;
      }
      // StateError means email not found, which is good - continue checking
    }

    // Check for username conflicts
    try {
      _users.firstWhere(
        (user) => user.username.toLowerCase() == username.toLowerCase(),
      );
      // If we get here, username exists
      throw Exception('USERNAME_TAKEN');
    } catch (e) {
      if (e.toString().contains('USERNAME_TAKEN')) {
        rethrow;
      }
      // StateError means username not found, which is good - continue checking
    }

    // Check for phone conflicts (normalize phone numbers for comparison)
    try {
      // Normalize phone numbers by removing non-digit characters
      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      _users.firstWhere(
        (user) {
          final normalizedUserPhone = user.phone.replaceAll(RegExp(r'[^\d]'), '');
          return normalizedUserPhone == normalizedPhone;
        },
      );
      // If we get here, phone exists
      throw Exception('PHONE_TAKEN');
    } catch (e) {
      if (e.toString().contains('PHONE_TAKEN')) {
        rethrow;
      }
      // StateError means phone not found, which is good - proceed with registration
    }

    try {
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        email: email,
        password: password,
        username: username,
        phone: phone,
        role: 'user', // Default role for new users
        createdAt: DateTime.now(),
        height: height,
        weight: weight,
        dateOfBirth: dateOfBirth,
        jerseyNumber: jerseyNumber,
      );

      _users.add(newUser);
      await _saveUsers();
      print('User registered successfully: ${newUser.username}');
      return true;
    } catch (e) {
      print('Error registering user: $e');
      // Re-throw if it's one of our specific exceptions
      if (e.toString().contains('_TAKEN')) {
        rethrow;
      }
      throw Exception('Registration failed. Please try again.');
    }
  }

  // Logout method
  Future<void> logout() async {
    print('AuthService.logout called');
    _currentUser = null;
    await _saveCurrentUser();
  }

  // Get current user
  User? get currentUser => _currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _currentUser != null;

  // Check if user can score (has scoring, owner, or management role)
  bool get canScore {
    if (_currentUser == null) {
      print('canScore: No current user');
      return false;
    }
    final canScore = _currentUser!.role == 'scoring' ||
        _currentUser!.role == 'owner' ||
        _currentUser!.role == 'management';
    print('canScore check: User ${_currentUser!.email} has role "${_currentUser!.role}", canScore = $canScore');
    return canScore;
  }

  // Check if user has management or owner role
  bool get isManagement =>
      _currentUser != null &&
      (_currentUser!.role == 'management' || _currentUser!.role == 'owner');

  // Check if email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      _users.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
      );
      return true; // Email exists
    } catch (e) {
      return false; // Email doesn't exist
    }
  }

  // Add user (for admin purposes)
  Future<bool> addUser(User user) async {
    try {
      _users.add(user);
      await _saveUsers();
      print('User added: ${user.username}');
      return true;
    } catch (e) {
      print('Error adding user: $e');
      return false;
    }
  }

  // Update user (for admin purposes)
  Future<bool> updateUser(User user) async {
    try {
      final userIndex = _users.indexWhere((u) => u.id == user.id);
      if (userIndex != -1) {
        _users[userIndex] = user;
        await _saveUsers();
        print('User updated: ${user.username}');
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    required String name,
    required String phone,
    required String email,
    String? height,
    String? weight,
    DateTime? dateOfBirth,
    String? profilePicturePath,
    String? jerseyNumber,
  }) async {
    if (_currentUser == null) return false;

    try {
      // Find the user in the list and update
      final userIndex = _users.indexWhere(
        (user) => user.id == _currentUser!.id,
      );
      if (userIndex != -1) {
        _users[userIndex] = User(
          id: _currentUser!.id,
          name: name,
          email: email,
          password: _currentUser!.password, // Keep existing password
          username: _currentUser!.username,
          phone: phone,
          role: _currentUser!.role,
          createdAt: _currentUser!.createdAt,
          height: height ?? _currentUser!.height,
          weight: weight ?? _currentUser!.weight,
          dateOfBirth: dateOfBirth ?? _currentUser!.dateOfBirth,
          profilePicturePath: profilePicturePath ?? _currentUser!.profilePicturePath,
          jerseyNumber: jerseyNumber ?? _currentUser!.jerseyNumber,
        );

        // Update current user
        _currentUser = _users[userIndex];

        // Save to storage
        await _saveUsers();
        await _saveCurrentUser();

        print('Profile updated successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // Get all users (for admin purposes)
  List<User> get users => List.from(_users);

  // Get users by role
  List<User> getUsersByRole(String role) {
    return _users.where((user) => user.role == role).toList();
  }

  // Delete user (for admin purposes)
  Future<bool> deleteUser(String userId) async {
    try {
      _users.removeWhere((user) => user.id == userId);
      await _saveUsers();
      print('User deleted: $userId');
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // Send password reset email using Firebase Auth
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      // Check if email exists in local database first
      final emailExists = await checkEmailExists(email);
      if (!emailExists) {
        print('Email not found in local database: $email');
        return false;
      }

      // Send password reset email via Firebase Auth
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );
      
      print('Password reset email sent successfully to: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error sending password reset: ${e.code} - ${e.message}');
      // Handle specific Firebase Auth errors
      if (e.code == 'user-not-found') {
        print('User not found in Firebase Auth');
      } else if (e.code == 'invalid-email') {
        print('Invalid email address');
      }
      return false;
    } catch (e) {
      print('Error sending password reset email: $e');
      return false;
    }
  }

  // Check if phone number exists in database
  Future<bool> checkPhoneExists(String phone) async {
    try {
      // Normalize phone number (remove non-digit characters)
      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      _users.firstWhere(
        (user) {
          final normalizedUserPhone = user.phone.replaceAll(RegExp(r'[^\d]'), '');
          return normalizedUserPhone == normalizedPhone;
        },
      );
      return true; // Phone exists
    } catch (e) {
      return false; // Phone doesn't exist
    }
  }

  // Get user by phone number
  User? getUserByPhone(String phone) {
    try {
      // Normalize phone number (remove non-digit characters)
      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      return _users.firstWhere(
        (user) {
          final normalizedUserPhone = user.phone.replaceAll(RegExp(r'[^\d]'), '');
          return normalizedUserPhone == normalizedPhone;
        },
      );
    } catch (e) {
      return null;
    }
  }

  // Generate a 6-digit verification code
  String _generateVerificationCode() {
    return (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
  }

  // Send verification code via SMS (simulated)
  Future<String?> sendVerificationCode(String phone) async {
    try {
      // Normalize phone number
      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      
      // Check if phone number exists
      final phoneExists = await checkPhoneExists(phone);
      if (!phoneExists) {
        print('Phone number not found in database: $phone');
        return null;
      }

      // Generate verification code
      final code = _generateVerificationCode();
      
      // Set expiration time (10 minutes from now)
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));
      
      // Store code with expiration (replace any existing code for this phone)
      _verificationCodes[normalizedPhone] = {
        'code': code,
        'expiresAt': expiresAt.toIso8601String(),
      };
      
      // In a real app, you would send an actual SMS here
      // For now, we'll just print it (in production, use an SMS service like Twilio)
      print('SMS sent to $phone: Your LevelUpSports Code is: $code');
      
      // Simulate sending SMS (in production, replace this with actual SMS sending)
      await Future.delayed(const Duration(seconds: 1));
      
      return code;
    } catch (e) {
      print('Error sending verification code: $e');
      return null;
    }
  }

  // Verify code and check expiration
  Future<bool> verifyCode(String phone, String code) async {
    try {
      // Normalize phone number
      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      
      // Check if code exists for this phone
      if (!_verificationCodes.containsKey(normalizedPhone)) {
        print('No verification code found for phone: $phone');
        return false;
      }
      
      final storedData = _verificationCodes[normalizedPhone]!;
      final storedCode = storedData['code'] as String;
      final expiresAtStr = storedData['expiresAt'] as String;
      final expiresAt = DateTime.parse(expiresAtStr);
      
      // Check if code is expired
      if (DateTime.now().isAfter(expiresAt)) {
        print('Verification code expired for phone: $phone');
        // Remove expired code
        _verificationCodes.remove(normalizedPhone);
        return false;
      }
      
      // Check if code matches
      if (storedCode != code.trim()) {
        print('Invalid verification code for phone: $phone');
        return false;
      }
      
      // Code is valid and not expired
      // Don't remove the code yet - keep it until password is reset
      return true;
    } catch (e) {
      print('Error verifying code: $e');
      return false;
    }
  }

  // Clear verification code after successful password reset
  void clearVerificationCode(String phone) {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    _verificationCodes.remove(normalizedPhone);
  }

  // Reset password for a user by email (updates local database)
  Future<bool> resetPassword(String email, String newPassword) async {
    try {
      final userIndex = _users.indexWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
      );
      
      if (userIndex == -1) {
        print('User not found for password reset: $email');
        return false;
      }

      // Update the user's password
      _users[userIndex] = User(
        id: _users[userIndex].id,
        name: _users[userIndex].name,
        email: _users[userIndex].email,
        password: newPassword,
        username: _users[userIndex].username,
        phone: _users[userIndex].phone,
        role: _users[userIndex].role,
        createdAt: _users[userIndex].createdAt,
      );

      // If the current user is the one resetting, update current user too
      if (_currentUser != null && _currentUser!.email.toLowerCase() == email.toLowerCase()) {
        _currentUser = _users[userIndex];
        await _saveCurrentUser();
      }

      await _saveUsers();
      print('Password reset successful for: $email');
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  // Reset password by phone number
  Future<bool> resetPasswordByPhone(String phone, String newPassword) async {
    try {
      // Get user by phone number
      final user = getUserByPhone(phone);
      
      if (user == null) {
        print('User not found for password reset: $phone');
        return false;
      }

      // Find user index
      final userIndex = _users.indexWhere((u) => u.id == user.id);
      
      if (userIndex == -1) {
        print('User index not found for password reset: $phone');
        return false;
      }

      // Update the user's password
      _users[userIndex] = User(
        id: _users[userIndex].id,
        name: _users[userIndex].name,
        email: _users[userIndex].email,
        password: newPassword,
        username: _users[userIndex].username,
        phone: _users[userIndex].phone,
        role: _users[userIndex].role,
        createdAt: _users[userIndex].createdAt,
      );

      // If the current user is the one resetting, update current user too
      if (_currentUser != null && _currentUser!.id == user.id) {
        _currentUser = _users[userIndex];
        await _saveCurrentUser();
      }

      // Clear verification code after successful reset
      clearVerificationCode(phone);

      await _saveUsers();
      print('Password reset successful for phone: $phone');
      return true;
    } catch (e) {
      print('Error resetting password by phone: $e');
      return false;
    }
  }
}
