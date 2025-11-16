// ignore_for_file: use_build_context_synchronously, valid_regexps, depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/auth_service.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';
import '../services/update_service.dart';
import 'player_stats_screen.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 10 digits
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }

    // Format as XXX-XXX-XXXX
    String formatted = '';

    if (digitsOnly.isNotEmpty) {
      // First 3 digits
      if (digitsOnly.length <= 3) {
        formatted = digitsOnly;
      } else if (digitsOnly.length <= 6) {
        formatted = '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3)}';
      } else {
        formatted =
            '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class DateOfBirthFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    
    // Remove all non-digit characters
    String digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 8 digits (MMDDYYYY)
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }
    
    // Format as MM/DD/YYYY
    String formatted = '';
    
    if (digitsOnly.isNotEmpty) {
      // Month (2 digits)
      if (digitsOnly.length <= 2) {
        formatted = digitsOnly;
      }
      // Month + Day (up to 4 digits)
      else if (digitsOnly.length <= 4) {
        formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
      }
      // Month + Day + Year (up to 8 digits)
      else {
        formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, 4)}/${digitsOnly.substring(4)}';
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class HeightFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    
    // Allow digits, decimal point, and apostrophe
    String cleaned = text.replaceAll(RegExp(r"[^\d.'']"), '');
    
    // Count numbers (digits)
    int digitCount = cleaned.replaceAll(RegExp(r'[^\d]'), '').length;
    
    // Limit to 2 digits total
    if (digitCount > 2) {
      // If we're adding a digit, remove the last one
      if (text.length > oldValue.text.length) {
        // Find the last digit and remove it
        String newCleaned = oldValue.text.replaceAll(RegExp(r"[^\d.'']"), '');
        int oldDigitCount = newCleaned.replaceAll(RegExp(r'[^\d]'), '').length;
        if (oldDigitCount >= 2) {
          cleaned = oldValue.text.replaceAll(RegExp(r"[^\d.'']"), '');
        }
      } else {
        cleaned = oldValue.text.replaceAll(RegExp(r"[^\d.'']"), '');
      }
    }
    
    // Auto-format: Convert decimal to apostrophe (6.4 → 6'4)
    if (cleaned.contains('.')) {
      cleaned = cleaned.replaceAll('.', "'");
    }
    
    // Ensure only one apostrophe
    int apostropheCount = cleaned.split("'").length - 1;
    
    if (apostropheCount > 1) {
      cleaned = oldValue.text.replaceAll(RegExp(r'[^\d.\'']'), '');
      if (cleaned.contains('.')) {
        cleaned = cleaned.replaceAll('.', "'");
      }
      // Keep only the first apostrophe
      int firstApostrophe = cleaned.indexOf("'");
      if (firstApostrophe >= 0) {
        cleaned = cleaned.substring(0, firstApostrophe + 1) + 
                 cleaned.substring(firstApostrophe + 1).replaceAll("'", '');
      }
    }
    
    // Auto-format: If 2 digits without separator, format as feet'inches (45 → 4'5, 64 → 6'4)
    String digitsOnly = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length == 2 && !cleaned.contains("'")) {
      cleaned = "${digitsOnly[0]}'${digitsOnly[1]}";
    }
    
    // Limit format: ensure only 1 digit before apostrophe and 1 digit after (6'4 format)
    if (cleaned.contains("'")) {
      List<String> parts = cleaned.split("'");
      if (parts.length == 2) {
        String before = parts[0].replaceAll(RegExp(r'[^\d]'), '');
        String after = parts[1].replaceAll(RegExp(r'[^\d]'), '');
        // Limit before to 1 digit, after to 1 digit
        if (before.length > 1) before = before.substring(0, 1);
        if (after.length > 1) after = after.substring(0, 1);
        cleaned = "$before'$after";
      }
    } else {
      // No separator, limit to 2 digits (will auto-format to feet'inches when 2 digits)
      if (digitsOnly.length > 2) {
        cleaned = digitsOnly.substring(0, 2);
        // Auto-format if we have 2 digits
        if (cleaned.length == 2) {
          cleaned = "${cleaned[0]}'${cleaned[1]}";
        }
      }
    }
    
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const SettingsScreen({super.key, this.onHomePressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Information
            _buildSettingsCard([
              _buildSettingsItem(
                'Personal Information',
                Icons.person,
                () {
                  _navigateToProfile();
                },
                trailing: Icons.keyboard_arrow_right,
              ),
            ]),

            const SizedBox(height: 16),

            // Player Stats
            _buildSettingsCard([
              _buildSettingsItem(
                'Player Stats',
                Icons.analytics,
                () {
                  _navigateToPlayerStats();
                },
                trailing: Icons.keyboard_arrow_right,
              ),
            ]),

            const SizedBox(height: 16),

            // App Feedback
            _buildSettingsCard([
              _buildSettingsItem('App Feedback', Icons.feedback, () {
                _navigateToAppFeedback();
              }, trailing: Icons.keyboard_arrow_right),
            ]),

            const SizedBox(height: 16),

            // About
            _buildSettingsCard([
              _buildSettingsItem('About', Icons.info, () {
                _navigateToAbout();
              }, trailing: Icons.keyboard_arrow_right),
            ]),

            const SizedBox(height: 32),

            // App Version (auto from UpdateService)
            Center(
              child: FutureBuilder(
                future: Future.wait([
                  UpdateService.getCurrentVersion(),
                  UpdateService.getBuildNumber(),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      'v—',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    );
                  }
                  final data = snapshot.data as List<String>;
                  final version = data[0];
                  final build = data[1];
                  return Text(
                    'v$version + $build',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    IconData? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        trailing ?? Icons.keyboard_arrow_right,
        color: Colors.grey[400],
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
    );
    // Refresh the screen when returning from profile edit
    setState(() {});
  }

  void _navigateToPlayerStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayerStatsScreen()),
    );
  }

  void _navigateToAppFeedback() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('App Feedback'),
            content: const Text('Coming soon'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _navigateToAbout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About'),
            content: const Text('Coming soon'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _authService.logout();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  final _jerseyNumberController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;
  String? _profileImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = _authService.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _emailController.text = user.email;
      _heightController.text = user.height ?? '';
      _weightController.text = user.weight ?? '';
      _selectedDateOfBirth = user.dateOfBirth;
      if (_selectedDateOfBirth != null) {
        _dateOfBirthController.text = _formatDate(_selectedDateOfBirth!);
      }
      _jerseyNumberController.text = user.jerseyNumber ?? '';
      if (user.profilePicturePath != null && user.profilePicturePath!.isNotEmpty) {
        final imageFile = File(user.profilePicturePath!);
        if (imageFile.existsSync()) {
          _profileImagePath = user.profilePicturePath;
          _profileImage = imageFile;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _dateOfBirthController.dispose();
    _jerseyNumberController.dispose();
    super.dispose();
  }

  Future<String?> _saveImageToLocal(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp${path.extension(imageFile.path)}';
      final savedImage = await imageFile.copy('${directory.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final savedPath = await _saveImageToLocal(imageFile);
        if (savedPath != null) {
          setState(() {
            _profileImage = File(savedPath);
            _profileImagePath = savedPath;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Profile Picture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('See the image'),
                  onTap: () {
                    Navigator.pop(context);
                    _showFullScreenImage();
                  },
                ),
              if (_profileImage != null)
                const Divider(),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Photos'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showFullScreenImage() {
    if (_profileImage == null) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      _profileImage!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update profile using AuthService
      final success = await _authService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        height: _heightController.text.trim().isEmpty ? null : _heightController.text.trim(),
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        profilePicturePath: _profileImagePath,
        jerseyNumber: _jerseyNumberController.text.trim().isEmpty ? null : _jerseyNumberController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Personal Information'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImageOptionsDialog,
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFF2196F3),
                            radius: 40,
                            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                            child: _profileImage == null
                                ? Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text.substring(0, 1).toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImageOptionsDialog,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text
                          : 'User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _emailController.text.isNotEmpty
                          ? _emailController.text
                          : 'user@example.com',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form Fields
              _buildFormField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildFormField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildPhoneField(),

              const SizedBox(height: 16),

              // Height field
              _buildHeightField(),

              const SizedBox(height: 16),

              // Weight field
              _buildWeightField(),

              const SizedBox(height: 16),

              // Age field
              _buildAgeField(),

              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Update Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 12, // 10 digits + 2 dashes
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10), // Only allow 10 digits
        PhoneNumberFormatter(), // Custom formatter
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your phone number';
        }
        // Remove dashes for validation
        final digitsOnly = value.replaceAll('-', '');
        if (digitsOnly.length != 10) {
          return 'Enter 10-digit number';
        }
        return null;
      },
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'XXX-XXX-XXXX',
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: '', // Hide character counter
      ),
    );
  }

  Widget _buildHeightField() {
    return TextFormField(
      controller: _heightController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        HeightFormatter(),
        LengthLimitingTextInputFormatter(4), // Max: 6'4 or 6.2 (4 chars)
      ],
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Height',
        hintText: 'e.g., 6.2 or 6\'4',
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: const Icon(Icons.height, color: Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null; // Height is optional
        }
        // Validate format: allow 6.2 or 6'4 (2 digits max)
        final cleaned = value.trim().replaceAll("'", '.');
        final heightValue = double.tryParse(cleaned);
        if (heightValue == null || heightValue <= 0) {
          return 'Please enter a valid height (e.g., 6.2 or 6\'4)';
        }
        // Check digit count (max 2)
        final digitCount = value.replaceAll(RegExp(r'[^\d]'), '').length;
        if (digitCount > 2) {
          return 'Height can only contain 2 numbers';
        }
        return null;
      },
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3), // Max 3 digits
      ],
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Weight',
        hintText: 'e.g., 180 (lbs)',
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: const Icon(Icons.monitor_weight, color: Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null; // Weight is optional
        }
        final weightValue = double.tryParse(value.trim());
        if (weightValue == null || weightValue <= 0) {
          return 'Please enter a valid weight';
        }
        // Check digit count (max 3)
        final digitCount = value.replaceAll(RegExp(r'[^\d]'), '').length;
        if (digitCount > 3) {
          return 'Weight can only contain 3 numbers';
        }
        return null;
      },
    );
  }

  int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  String _formatDate(DateTime date) {
    // Format as MM/DD/YYYY with leading zeros
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }

  DateTime? _parseDate(String dateString) {
    // Parse MM/DD/YYYY format
    final parts = dateString.split('/');
    if (parts.length == 3) {
      try {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1900) {
          return DateTime(year, month, day);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Widget _buildAgeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _dateOfBirthController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            DateOfBirthFormatter(),
            LengthLimitingTextInputFormatter(10), // MM/DD/YYYY
          ],
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            hintText: 'MM/DD/YYYY',
            labelStyle: const TextStyle(color: Colors.black54),
            prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF2196F3)),
            suffixIcon: IconButton(
              icon: Icon(
                Icons.calendar_today,
                color: Colors.grey[600],
                size: 20,
              ),
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF2196F3),
                          onPrimary: Colors.white,
                          onSurface: Colors.black87,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: child!,
                      ),
                    );
                  },
                );
                if (picked != null && picked != _selectedDateOfBirth) {
                  setState(() {
                    _selectedDateOfBirth = picked;
                    _dateOfBirthController.text = _formatDate(picked);
                    // Update validation
                    _formKey.currentState?.validate();
                  });
                }
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            // Parse the input and update _selectedDateOfBirth
            if (value.length == 10) { // MM/DD/YYYY format
              final parsed = _parseDate(value);
              if (parsed != null) {
                setState(() {
                  _selectedDateOfBirth = parsed;
                  // Update validation
                  _formKey.currentState?.validate();
                });
              }
            } else if (value.isEmpty) {
              setState(() {
                _selectedDateOfBirth = null;
              });
            }
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null; // Date of birth is optional
            }
            if (value.length != 10) {
              return 'Please enter date in MM/DD/YYYY format';
            }
            final parsed = _parseDate(value);
            if (parsed == null) {
              return 'Please enter a valid date';
            }
            if (parsed.isAfter(DateTime.now())) {
              return 'Date of birth cannot be in the future';
            }
            // Check if age is reasonable (not more than 150 years old)
            final age = _calculateAge(parsed);
            if (age > 150) {
              return 'Please enter a valid date of birth';
            }
            return null;
          },
        ),
        if (_selectedDateOfBirth != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              'Age: ${_calculateAge(_selectedDateOfBirth!)} years',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _jerseyNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3), // Max 3 digits
          ],
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: 'Jersey Number',
            hintText: 'Enter your jersey number',
            labelStyle: const TextStyle(color: Colors.black54),
            prefixIcon: const Icon(Icons.confirmation_number, color: Color(0xFF2196F3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null; // Jersey number is optional
            }
            final jerseyNum = int.tryParse(value.trim());
            if (jerseyNum == null || jerseyNum <= 0) {
              return 'Please enter a valid jersey number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: true,
      validator: validator,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

class AppFeedbackScreen extends StatefulWidget {
  const AppFeedbackScreen({super.key});

  @override
  State<AppFeedbackScreen> createState() => _AppFeedbackScreenState();
}

class _AppFeedbackScreenState extends State<AppFeedbackScreen> {
  final _feedbackController = TextEditingController();
  final _authService = AuthService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter your feedback',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
          elevation: 4,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user info
      final currentUser = _authService.currentUser;
      final userName = currentUser?.name ?? 'Anonymous User';
      final userEmail = currentUser?.email ?? 'No email provided';

      // Create email content
      final emailBody = '''
App Feedback from Level Up Sports App

User Information:
- Name: $userName
- Email: $userEmail
- User ID: ${currentUser?.id ?? 'N/A'}

Feedback:
${_feedbackController.text.trim()}

---
Sent from Level Up Sports App
Time: ${DateTime.now().toString()}
''';

      // Show options dialog first (iOS workaround)
      _showEmailOptionsDialog(emailBody);
    } catch (e) {
      print('DEBUG: Error preparing email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error preparing email: $e',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
            elevation: 4,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showEmailOptionsDialog(String emailBody) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: const Text(
            'Choose how you\'d like to send your feedback:',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _feedbackController.clear();
                Navigator.pop(context); // Go back to settings
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _tryLaunchEmailClient(emailBody);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Email App'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showFallbackDialog(emailBody);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Copy Content'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tryLaunchEmailClient(String emailBody) async {
    try {
      // Get current user info
      final currentUser = _authService.currentUser;
      final userName = currentUser?.name ?? 'Anonymous User';

      // Create mailto URL
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'levelupsports96@gmail.com',
        query:
            'subject=${Uri.encodeComponent('App Feedback from $userName')}&body=${Uri.encodeComponent(emailBody)}',
      );

      // Try to launch email client with better error handling
      print('DEBUG: Attempting to launch email URI: $emailUri');

      try {
        // First try to launch directly without checking canLaunchUrl (iOS issue workaround)
        final launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          print('DEBUG: Email client launched successfully');
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Email client opened. Please send the email to submit your feedback.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                elevation: 4,
              ),
            );

            // Clear form and navigate back
            _feedbackController.clear();
            Navigator.pop(context);
          }
        } else {
          throw Exception('Failed to launch email client');
        }
      } catch (e) {
        print('DEBUG: Direct launch failed: $e');
        // If direct launch fails, try with canLaunchUrl check
        try {
          if (await canLaunchUrl(emailUri)) {
            final launched = await launchUrl(
              emailUri,
              mode: LaunchMode.externalApplication,
            );
            if (launched) {
              print('DEBUG: Email client launched successfully after retry');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Email client opened. Please send the email to submit your feedback.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 100,
                    ),
                    elevation: 4,
                  ),
                );

                _feedbackController.clear();
                Navigator.pop(context);
              }
            } else {
              throw Exception('Failed to launch email client after retry');
            }
          } else {
            throw Exception('No email client available on this device');
          }
        } catch (e2) {
          print('DEBUG: Both launch attempts failed: $e2');
          rethrow; // Re-throw to trigger fallback dialog
        }
      }
    } catch (e) {
      print('DEBUG: Error launching email client: $e');
      if (mounted) {
        // Show fallback dialog with email content
        _showFallbackDialog(emailBody);
      }
    }
  }

  void _showFallbackDialog(String emailBody) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Client Not Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please copy the following information and send it to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'levelupsports96@gmail.com',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Email Content:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  emailBody,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _feedbackController.clear();
                Navigator.pop(context); // Go back to settings
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Copy to clipboard
                Clipboard.setData(ClipboardData(text: emailBody));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email content copied to clipboard!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.of(context).pop();
                _feedbackController.clear();
                Navigator.pop(context); // Go back to settings
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Copy & Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('App Feedback'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summarize your feedback for the Level Up Sports App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _feedbackController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Enter your feedback here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child:
                    _isSubmitting
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Submitting...'),
                          ],
                        )
                        : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // App Icon
            Center(
              child: Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/app_logo.jpg',
                    width: 85,
                    height: 85,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Version
            Center(
              child: FutureBuilder(
                future: Future.wait([
                  UpdateService.getCurrentVersion(),
                  UpdateService.getBuildNumber(),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      'Version: v—',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    );
                  }
                  final data = snapshot.data as List<String>;
                  final version = data[0];
                  final build = data[1];
                  return Text(
                    'Version: v$version + $build',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),

            // Rate Us as a settings row
            _buildSettingsCard([
              _buildSettingsItem('Rate Us', Icons.star, () {
                // Handle rate us functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for rating our app!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }, trailing: Icons.keyboard_arrow_right),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    IconData? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        trailing ?? Icons.keyboard_arrow_right,
        color: Colors.grey[400],
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
